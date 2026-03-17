"""Tests for the Obsidian Markdown vault reader.

All fixtures are inline strings — no external fixture files required.
Tests use tmp_path to create a temporary vault directory on disk.
The llama_index.core.schema.Document import is mocked to avoid
requiring a full llama-index-core installation in CI environments
that only run unit tests.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any
from unittest.mock import MagicMock, patch

import pytest

from orchestrator.loaders.obsidian_reader import (
    ObsidianReader,
    _extract_callouts,
    _extract_embeds,
    _extract_tags,
    _extract_wikilinks,
    _parse_frontmatter,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_vault(tmp_path: Path, files: dict[str, str]) -> Path:
    """Write {filename: content} to a temporary vault directory."""
    vault = tmp_path / "vault"
    vault.mkdir()
    for name, content in files.items():
        (vault / name).write_text(content, encoding="utf-8")
    return vault


def _mock_document() -> MagicMock:
    """Return a fake Document class that records constructor kwargs."""
    doc_cls = MagicMock()
    doc_cls.side_effect = lambda **kwargs: kwargs  # Store kwargs as the "document"
    return doc_cls


# ---------------------------------------------------------------------------
# Unit tests: pure parsing helpers
# ---------------------------------------------------------------------------

class TestParseFrontmatter:
    def test_valid_frontmatter(self):
        text = "---\ntitle: My Note\ntags: [python, ai]\n---\nBody content here."
        fm, body = _parse_frontmatter(text)
        assert fm["title"] == "My Note"
        assert fm["tags"] == ["python", "ai"]
        assert body == "Body content here."

    def test_no_frontmatter(self):
        text = "Just plain content\nwith no frontmatter."
        fm, body = _parse_frontmatter(text)
        assert fm == {}
        assert body == text

    def test_empty_frontmatter_block(self):
        text = "---\n\n---\nContent after empty frontmatter."
        fm, body = _parse_frontmatter(text)
        assert fm == {}
        assert "Content" in body

    def test_frontmatter_with_nested_keys(self):
        text = "---\ntitle: Deep Note\nauthor: Jane\ndate: 2024-01-15\n---\nBody."
        fm, body = _parse_frontmatter(text)
        assert fm["author"] == "Jane"
        assert fm["date"].year == 2024  # PyYAML parses dates automatically


class TestExtractWikilinks:
    def test_simple_wikilink(self):
        assert "SomePage" in _extract_wikilinks("See [[SomePage]] for more.")

    def test_aliased_wikilink(self):
        links = _extract_wikilinks("[[ActualPage|Display Text]] is here.")
        assert "ActualPage" in links
        assert "Display Text" not in links

    def test_multiple_wikilinks(self):
        links = _extract_wikilinks("[[Alpha]] and [[Beta]] and [[Gamma|G]].")
        assert set(links) == {"Alpha", "Beta", "Gamma"}

    def test_embed_not_included(self):
        """Embeds (![[...]]) must NOT appear in wikilinks."""
        links = _extract_wikilinks("![[image.png]] and [[RealLink]]")
        assert "image.png" not in links
        assert "RealLink" in links

    def test_no_wikilinks(self):
        assert _extract_wikilinks("Plain text with no links.") == []


class TestExtractTags:
    def test_simple_tag(self):
        assert "python" in _extract_tags("This is #python code.")

    def test_nested_tag(self):
        tags = _extract_tags("Topic: #ai/llm is interesting.")
        assert "ai/llm" in tags

    def test_multiple_tags(self):
        tags = _extract_tags("#project #status/done #review")
        assert "project" in tags
        assert "status/done" in tags
        assert "review" in tags

    def test_no_tags(self):
        assert _extract_tags("No hash signs here at all.") == []


class TestExtractCallouts:
    def test_note_callout(self):
        text = "> [!note]\n> This is important."
        assert "note" in _extract_callouts(text)

    def test_warning_callout(self):
        text = "> [!warning]\n> Be careful here."
        assert "warning" in _extract_callouts(text)

    def test_multiple_callouts(self):
        text = "> [!note]\n> Info\n\n> [!tip]\n> Helpful."
        callouts = _extract_callouts(text)
        assert "note" in callouts
        assert "tip" in callouts

    def test_no_callouts(self):
        assert _extract_callouts("Regular blockquote\n> just a quote") == []


class TestExtractEmbeds:
    def test_image_embed(self):
        assert "screenshot.png" in _extract_embeds("![[screenshot.png]]")

    def test_note_embed(self):
        assert "OtherNote" in _extract_embeds("Inline note: ![[OtherNote]]")

    def test_aliased_embed(self):
        embeds = _extract_embeds("![[file.png|300]]")
        assert "file.png" in embeds

    def test_no_embeds(self):
        assert _extract_embeds("[[wikilink]] but no embeds") == []


# ---------------------------------------------------------------------------
# Integration tests: ObsidianReader.load_data with mock Document
# ---------------------------------------------------------------------------

@pytest.fixture
def doc_cls_patch():
    """Patch llama_index.core.schema.Document with a simple dict-returning mock.

    The import in ObsidianReader.load_data is a deferred ``from llama_index...``
    call, so we patch via sys.modules so the module-level import resolves to our
    mock for the duration of each test.
    """
    mock_doc = MagicMock()
    # Make Document(text=..., metadata=..., id_=...) return a plain dict for inspection
    mock_doc.side_effect = lambda text, metadata, id_: {"text": text, "metadata": metadata, "id_": id_}
    mock_schema = MagicMock(Document=mock_doc)
    mock_core = MagicMock()
    mock_core.schema = mock_schema
    mock_llama = MagicMock()
    mock_llama.core = mock_core
    with patch.dict(
        "sys.modules",
        {
            "llama_index": mock_llama,
            "llama_index.core": mock_core,
            "llama_index.core.schema": mock_schema,
        },
    ):
        yield mock_doc


class TestObsidianReaderLoadData:
    def test_vault_directory_walking(self, tmp_path: Path, doc_cls_patch: Any):
        """Reader finds all .md files recursively in the vault."""
        vault = _make_vault(tmp_path, {
            "note1.md": "# Note 1\nContent one.",
            "note2.md": "# Note 2\nContent two.",
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        assert len(docs) == 2

    def test_metadata_completeness(self, tmp_path: Path, doc_cls_patch: Any):
        """Every document must include all required metadata fields."""
        vault = _make_vault(tmp_path, {
            "complete.md": (
                "---\ntitle: Full Note\ntags: [alpha]\n---\n"
                "Body with [[Link]] and #beta and ![[img.png]] and\n> [!note]\n> text"
            ),
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        assert len(docs) == 1
        meta = docs[0]["metadata"]
        for field in ("title", "tags", "wikilinks", "embeds", "callouts", "frontmatter", "path", "mtime"):
            assert field in meta, f"Missing metadata field: {field}"

    def test_frontmatter_in_metadata(self, tmp_path: Path, doc_cls_patch: Any):
        """Frontmatter fields are preserved verbatim in metadata."""
        vault = _make_vault(tmp_path, {
            "fm.md": "---\ntitle: FM Note\nauthor: Alice\n---\nContent.",
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        fm = docs[0]["metadata"]["frontmatter"]
        assert fm["title"] == "FM Note"
        assert fm["author"] == "Alice"

    def test_incremental_mode_file_list(self, tmp_path: Path, doc_cls_patch: Any):
        """file_list parameter restricts processing to the given files only."""
        vault = _make_vault(tmp_path, {
            "included.md": "I should be included.",
            "excluded.md": "I should be excluded.",
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data(file_list=[vault / "included.md"])
        assert len(docs) == 1
        assert "included" in docs[0]["metadata"]["path"]

    def test_empty_file_handling(self, tmp_path: Path, doc_cls_patch: Any):
        """Empty .md files produce a document with empty body — no crash."""
        vault = _make_vault(tmp_path, {"empty.md": ""})
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        assert len(docs) == 1
        assert docs[0]["text"] == ""

    def test_file_with_no_special_syntax(self, tmp_path: Path, doc_cls_patch: Any):
        """Plain prose with no frontmatter, links, or tags still produces a document."""
        vault = _make_vault(tmp_path, {
            "plain.md": "This is just plain text with nothing special in it.",
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        assert len(docs) == 1
        meta = docs[0]["metadata"]
        assert meta["wikilinks"] == []
        assert meta["tags"] == []
        assert meta["embeds"] == []
        assert meta["callouts"] == []

    def test_title_fallback_to_filename(self, tmp_path: Path, doc_cls_patch: Any):
        """When no frontmatter title, the document title falls back to the file stem."""
        vault = _make_vault(tmp_path, {"my-great-note.md": "Content without frontmatter."})
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        assert docs[0]["metadata"]["title"] == "my-great-note"

    def test_wikilinks_in_metadata(self, tmp_path: Path, doc_cls_patch: Any):
        """Wikilinks extracted from body appear in document metadata."""
        vault = _make_vault(tmp_path, {
            "linked.md": "See [[PageA]] and [[PageB|Alias B]] for details.",
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        wl = docs[0]["metadata"]["wikilinks"]
        assert "PageA" in wl
        assert "PageB" in wl

    def test_tags_merged_from_frontmatter_and_body(self, tmp_path: Path, doc_cls_patch: Any):
        """Tags from frontmatter and inline #tags are merged without duplicates."""
        vault = _make_vault(tmp_path, {
            "tagged.md": "---\ntags: [project]\n---\nThis is #project and #status/active.",
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data()
        tags = docs[0]["metadata"]["tags"]
        assert "project" in tags
        assert "status/active" in tags
        # 'project' appears in both frontmatter and body; should appear once
        assert tags.count("project") == 1

    def test_incremental_mode_relative_paths(self, tmp_path: Path, doc_cls_patch: Any):
        """file_list with relative paths resolves correctly against vault root."""
        vault = _make_vault(tmp_path, {
            "relative.md": "Content of the relative file.",
        })
        reader = ObsidianReader(vault)
        docs = reader.load_data(file_list=["relative.md"])
        assert len(docs) == 1
        assert "relative" in docs[0]["metadata"]["path"]
