"""Obsidian Markdown vault reader for LlamaIndex document ingestion.

Parses an Obsidian vault directory and returns LlamaIndex Documents with rich
metadata extracted from YAML frontmatter, wikilinks, tags, callouts, and embeds.

The reader:
1. Walks the vault for .md files (or accepts an explicit file_list)
2. Parses YAML frontmatter between --- delimiters via yaml.safe_load
3. Extracts [[wikilinks]] and [[wikilink|alias]] forms as relationship edges
4. Extracts #tags including nested #topic/subtopic forms
5. Extracts ![[embed]] references (images, notes)
6. Extracts > [!type] callout blocks
7. Returns list[Document] with all metadata attached
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Any

import yaml

logger = logging.getLogger(__name__)

# Regex patterns compiled at module level for performance
_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
_WIKILINK_RE = re.compile(r"!\[\[([^\]]+)\]\]|(?<!!)\[\[([^\]]+)\]\]")
_TAG_RE = re.compile(r"(?<![`\w])#([\w/-]+)")
_CALLOUT_RE = re.compile(r"^>\s*\[!(\w+)\]", re.MULTILINE)
_EMBED_RE = re.compile(r"!\[\[([^\]]+)\]\]")


def _parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Extract YAML frontmatter from markdown text.

    Returns a (frontmatter_dict, body_text) tuple. If no frontmatter is
    present, the dict is empty and body_text is the full input.
    """
    match = _FRONTMATTER_RE.match(text)
    if not match:
        return {}, text

    raw_yaml = match.group(1)
    try:
        data = yaml.safe_load(raw_yaml)
    except yaml.YAMLError:
        logger.warning("Failed to parse frontmatter YAML — skipping frontmatter")
        data = None

    # Coerce non-dict results (None, lists, scalars) to empty dict
    if not isinstance(data, dict):
        data = {}

    body = text[match.end():]
    return data, body


def _extract_wikilinks(text: str) -> list[str]:
    """Extract all [[wikilink]] and [[wikilink|alias]] targets from text.

    Embeds (![[...]]) are excluded — those are captured separately.
    Returns a list of link targets (the part before any | alias separator).
    """
    links: list[str] = []
    for match in _WIKILINK_RE.finditer(text):
        # Group 1 = embed match (starts with !), group 2 = plain wikilink
        # Skip embeds — only collect plain wikilinks
        raw = match.group(2)
        if raw is None:
            continue
        target = raw.split("|")[0].strip()
        if target:
            links.append(target)
    return links


def _extract_tags(text: str) -> list[str]:
    """Extract all #tags and #nested/tags from text.

    The regex uses a negative lookbehind for backtick and word characters,
    so tags immediately preceded by a backtick or word char are skipped.
    This catches most cases but does not fully parse fenced/inline code
    spans — a tag preceded by a space inside backticks may still match.
    """
    return _TAG_RE.findall(text)


def _extract_callouts(text: str) -> list[str]:
    """Extract callout types from > [!type] blocks."""
    return _CALLOUT_RE.findall(text)


def _extract_embeds(text: str) -> list[str]:
    """Extract ![[embed]] targets (images and note embeds)."""
    results: list[str] = []
    for match in _EMBED_RE.finditer(text):
        target = match.group(1).split("|")[0].strip()
        if target:
            results.append(target)
    return results


def _parse_file(path: Path) -> dict[str, Any]:
    """Parse a single Obsidian markdown file into a metadata dict.

    Returns a dict with keys: title, tags, wikilinks, embeds, callouts,
    frontmatter, path, mtime, and body (the content with frontmatter stripped).
    """
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as exc:
        logger.warning("Could not read %s: %s", path, exc)
        return {}

    frontmatter, body = _parse_frontmatter(raw)

    # Merge frontmatter tags with inline tags; deduplicate while preserving order
    fm_tags_raw = frontmatter.get("tags")
    if fm_tags_raw is None:
        fm_tags: list[str] = []
    elif isinstance(fm_tags_raw, str):
        fm_tags = [fm_tags_raw]
    elif isinstance(fm_tags_raw, list):
        fm_tags = [str(t) for t in fm_tags_raw if t is not None]
    else:
        fm_tags = []
    inline_tags = _extract_tags(body)
    seen: set[str] = set()
    tags: list[str] = []
    for tag in [*fm_tags, *inline_tags]:
        if tag not in seen:
            seen.add(tag)
            tags.append(tag)

    # Wikilinks are extracted from the body only (frontmatter rarely has them)
    wikilinks = _extract_wikilinks(body)
    # Embeds use full raw text since ![[embed]] can appear in frontmatter
    embeds = _extract_embeds(raw)
    callouts = _extract_callouts(body)

    # Title: prefer frontmatter title, fall back to filename stem
    title: str = frontmatter.get("title") or path.stem

    try:
        mtime = path.stat().st_mtime
    except OSError:
        mtime = 0.0

    return {
        "title": title,
        "tags": tags,
        "wikilinks": wikilinks,
        "embeds": embeds,
        "callouts": callouts,
        "frontmatter": frontmatter,
        "path": str(path),
        "mtime": mtime,
        "body": body,
    }


class ObsidianReader:
    """Reader for Obsidian Markdown vaults.

    Walks a vault directory for .md files, parses each file's frontmatter,
    wikilinks, tags, callouts, and embeds, and returns a list of LlamaIndex
    Document objects with rich metadata.

    Args:
        vault_path: Path to the Obsidian vault root directory.
    """

    def __init__(self, vault_path: str | Path) -> None:
        self.vault_path = Path(vault_path)

    def load_data(
        self,
        file_list: list[str | Path] | None = None,
    ) -> list[Any]:
        """Load documents from the vault.

        Args:
            file_list: Optional list of specific file paths to process.
                If None, all .md files in the vault are processed.

        Returns:
            A list of Document objects (from llama_index.core.schema) with
            metadata including title, tags, wikilinks, embeds, callouts,
            frontmatter, path, and mtime. The document text is the full
            markdown content with frontmatter stripped.
        """
        try:
            from llama_index.core.schema import Document
        except ImportError:
            msg = (
                "llama-index-core is required for ObsidianReader. "
                "Install it with: pip install llama-index-core"
            )
            raise ImportError(msg)  # noqa: TRY200

        paths = self._resolve_paths(file_list)
        documents: list[Any] = []

        for path in paths:
            parsed = _parse_file(path)
            if not parsed:
                continue

            body = parsed.pop("body")
            metadata = parsed  # All remaining keys become metadata

            doc = Document(
                text=body,
                metadata=metadata,
                id_=str(path),
            )
            documents.append(doc)
            logger.debug("Loaded document: %s (%d chars)", path, len(body))

        logger.info("ObsidianReader: loaded %d documents from %s", len(documents), self.vault_path)
        return documents

    def _resolve_paths(self, file_list: list[str | Path] | None) -> list[Path]:
        """Resolve the list of paths to process.

        If file_list is provided, resolves each entry relative to the vault
        root if not already absolute. Otherwise, walks the vault directory.
        """
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
