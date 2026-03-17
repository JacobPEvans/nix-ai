"""Obsidian vault reader with structured metadata enrichment.

Parses .md files, extracts YAML frontmatter, [[wikilinks]], #tags,
> [!callouts], and ![[embeds]], returning LlamaIndex Documents.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_WIKILINK_RE = re.compile(r"!\[\[([^\]]+)\]\]|(?<!!)\[\[([^\]]+)\]\]")
_TAG_RE = re.compile(r"(?<![`\w])#([\w/-]+)")
_CALLOUT_RE = re.compile(r"^>\s*\[!(\w+)\]", re.MULTILINE)
_EMBED_RE = re.compile(r"!\[\[([^\]]+)\]\]")


def _parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Extract YAML frontmatter, returning (frontmatter_dict, body_text)."""
    match = _FRONTMATTER_RE.match(text)
    if not match:
        return {}, text
    try:
        data = yaml.safe_load(match.group(1))
    except yaml.YAMLError:
        logger.warning("Failed to parse frontmatter YAML — skipping")
        data = None
    if not isinstance(data, dict):
        data = {}
    return data, text[match.end() :]


def _extract_wikilinks(text: str) -> list[str]:
    """Extract [[wikilink]] targets (excludes ![[embeds]])."""
    links: list[str] = []
    for match in _WIKILINK_RE.finditer(text):
        raw = match.group(2)
        if raw is None:
            continue
        target = raw.split("|")[0].strip()
        if target:
            links.append(target)
    return links


def _extract_tags(text: str) -> list[str]:
    """Extract #tags and #nested/tags."""
    return _TAG_RE.findall(text)


def _extract_callouts(text: str) -> list[str]:
    """Extract callout types from > [!type] blocks."""
    return _CALLOUT_RE.findall(text)


def _extract_embeds(text: str) -> list[str]:
    """Extract ![[embed]] targets."""
    results: list[str] = []
    for match in _EMBED_RE.finditer(text):
        target = match.group(1).split("|")[0].strip()
        if target:
            results.append(target)
    return results


def _merge_tags(fm_tags_raw: Any, inline_tags: list[str]) -> list[str]:
    """Merge frontmatter and inline tags, deduplicating while preserving order."""
    if fm_tags_raw is None:
        fm_tags: list[str] = []
    elif isinstance(fm_tags_raw, str):
        fm_tags = [fm_tags_raw]
    elif isinstance(fm_tags_raw, list):
        fm_tags = [str(t) for t in fm_tags_raw if t is not None]
    else:
        fm_tags = []
    seen: set[str] = set()
    result: list[str] = []
    for tag in [*fm_tags, *inline_tags]:
        if tag not in seen:
            seen.add(tag)
            result.append(tag)
    return result


class ObsidianReader:
    """Reader for Obsidian vaults that produces LlamaIndex Documents with rich metadata."""

    def __init__(self, vault_path: str | Path) -> None:
        self.vault_path = Path(vault_path)

    def load_data(self, file_list: list[str | Path] | None = None) -> list[Any]:
        """Load documents from the vault with structured metadata."""
        try:
            from llama_index.core.schema import Document
        except ImportError:
            msg = "llama-index-core is required. Install with: pip install llama-index-core"
            raise ImportError(msg)  # noqa: TRY200

        paths = self._resolve_paths(file_list)
        documents: list[Any] = []

        for path in paths:
            try:
                raw = path.read_text(encoding="utf-8")
            except OSError as exc:
                logger.warning("Could not read %s: %s", path, exc)
                continue

            frontmatter, body = _parse_frontmatter(raw)
            try:
                mtime = path.stat().st_mtime
            except OSError:
                mtime = 0.0

            metadata = {
                "title": frontmatter.get("title") or path.stem,
                "tags": _merge_tags(frontmatter.get("tags"), _extract_tags(body)),
                "wikilinks": _extract_wikilinks(body),
                "embeds": _extract_embeds(raw),
                "callouts": _extract_callouts(body),
                "frontmatter": frontmatter,
                "path": str(path),
                "mtime": mtime,
            }
            documents.append(Document(text=body, metadata=metadata, id_=str(path)))

        logger.info("ObsidianReader: loaded %d documents from %s", len(documents), self.vault_path)
        return documents

    def _resolve_paths(self, file_list: list[str | Path] | None) -> list[Path]:
        """Resolve file paths, relative to vault root if not absolute."""
        if file_list is not None:
            resolved: list[Path] = []
            for entry in file_list:
                p = Path(entry)
                if not p.is_absolute():
                    p = self.vault_path / p
                if p.suffix == ".md" and p.is_file():
                    resolved.append(p)
                else:
                    logger.warning("Skipping non-existent or non-markdown path: %s", p)
            return resolved
        return sorted(self.vault_path.rglob("*.md"))
