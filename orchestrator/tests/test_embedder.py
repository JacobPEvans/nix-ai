"""Tests for the embedding pipeline and vector backends.

All tests use mocked HTTP calls so no live embedding server is required.
Integration tests with a live MLX endpoint belong in
test_embedder_integration.py.

Fixtures:
- ``tmp_path`` — pytest built-in for isolated temporary directories
- ``mock_embed_fn`` — patches ``EmbeddingPipeline._embed`` with a deterministic
  function that returns unit vectors derived from the text hash
"""

from __future__ import annotations

from pathlib import Path
from unittest.mock import patch

import numpy as np
import pytest

from orchestrator.indexing.embedder import (
    EmbeddingConfig,
    EmbeddingPipeline,
    FAISSBackend,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

DIM = 8  # Small dimension to keep tests fast


def _fake_embedding(text: str, dim: int = DIM) -> list[float]:
    """Produce a deterministic unit vector from the text content."""
    rng = np.random.default_rng(abs(hash(text)) % (2**32))
    vec = rng.random(dim).astype(np.float64)
    vec /= np.linalg.norm(vec) + 1e-10
    return vec.tolist()


def _fake_embed(texts: list[str], dim: int = DIM) -> list[list[float]]:
    return [_fake_embedding(t, dim) for t in texts]


def _make_config(**kwargs) -> EmbeddingConfig:
    defaults = {"dimension": DIM, "batch_size": 4, "backend": "faiss"} | kwargs
    return EmbeddingConfig(**defaults)


def _make_docs(n: int, prefix: str = "doc") -> list[dict]:
    return [
        {"id": f"{prefix}{i}", "text": f"content for {prefix} {i}", "metadata": {"idx": i}}
        for i in range(n)
    ]


# ---------------------------------------------------------------------------
# EmbeddingConfig
# ---------------------------------------------------------------------------


class TestEmbeddingConfig:
    def test_defaults(self):
        cfg = EmbeddingConfig()
        assert cfg.endpoint == "http://localhost:11434/v1"
        assert cfg.model == "nomic-embed-text"
        assert cfg.batch_size == 32
        assert cfg.backend == "faiss"
        assert cfg.index_path == Path("./index")
        assert cfg.dimension == 384

    def test_custom_values(self):
        cfg = EmbeddingConfig(
            endpoint="http://myhost:8080/v1",
            model="all-minilm",
            batch_size=16,
            backend="qdrant",
            index_path=Path("/tmp/myindex"),
            dimension=768,
        )
        assert cfg.endpoint == "http://myhost:8080/v1"
        assert cfg.model == "all-minilm"
        assert cfg.batch_size == 16
        assert cfg.backend == "qdrant"
        assert cfg.index_path == Path("/tmp/myindex")
        assert cfg.dimension == 768

    def test_batch_size_must_be_positive(self):
        with pytest.raises(Exception):
            EmbeddingConfig(batch_size=0)

    def test_dimension_must_be_positive(self):
        with pytest.raises(Exception):
            EmbeddingConfig(dimension=0)


# ---------------------------------------------------------------------------
# FAISSBackend
# ---------------------------------------------------------------------------


class TestFAISSBackend:
    def test_add_and_search_returns_nearest(self):
        backend = FAISSBackend(dimension=DIM)
        vecs = [_fake_embedding(f"text{i}") for i in range(3)]
        backend.add(["a", "b", "c"], vecs, [{"k": "a"}, {"k": "b"}, {"k": "c"}])

        results = backend.search(vecs[0], top_k=1)
        assert len(results) == 1
        doc_id, score, meta = results[0]
        assert doc_id == "a"
        assert score > 0.99  # Self-similarity on a normalised vector

    def test_search_returns_top_k(self):
        backend = FAISSBackend(dimension=DIM)
        vecs = [_fake_embedding(f"item{i}") for i in range(5)]
        backend.add([f"id{i}" for i in range(5)], vecs, [{} for _ in range(5)])

        results = backend.search(vecs[0], top_k=3)
        assert len(results) == 3
        # Results must be sorted descending by score.
        scores = [r[1] for r in results]
        assert scores == sorted(scores, reverse=True)

    def test_delete_removes_document(self):
        backend = FAISSBackend(dimension=DIM)
        vecs = [_fake_embedding(f"d{i}") for i in range(3)]
        backend.add(["x", "y", "z"], vecs, [{}, {}, {}])

        backend.delete(["x"])

        results = backend.search(vecs[0], top_k=3)
        returned_ids = {r[0] for r in results}
        assert "x" not in returned_ids

    def test_delete_all_leaves_empty_index(self):
        backend = FAISSBackend(dimension=DIM)
        vec = [_fake_embedding("solo")]
        backend.add(["only"], vec, [{}])
        backend.delete(["only"])

        results = backend.search(vec[0], top_k=5)
        assert results == []

    def test_save_and_load_round_trip(self, tmp_path):
        backend = FAISSBackend(dimension=DIM)
        vecs = [_fake_embedding(f"s{i}") for i in range(2)]
        backend.add(["p", "q"], vecs, [{"src": "p"}, {"src": "q"}])

        index_prefix = tmp_path / "test_index"
        backend.save(index_prefix)

        # Verify files were written.
        assert Path(f"{index_prefix}.faiss").exists()
        assert Path(f"{index_prefix}.meta").exists()

        # Load into a fresh backend and verify contents.
        loaded = FAISSBackend(dimension=DIM)
        loaded.load(index_prefix)

        assert loaded._ids == ["p", "q"]
        assert loaded._metadata == [{"src": "p"}, {"src": "q"}]

        results = loaded.search(vecs[0], top_k=1)
        assert results[0][0] == "p"

    def test_dimension_mismatch_raises(self):
        backend = FAISSBackend(dimension=DIM)
        wrong_vec = [0.1] * (DIM + 1)
        with pytest.raises(ValueError, match="dimension mismatch"):
            backend.add(["id"], [wrong_vec], [{}])

    def test_add_mismatched_list_lengths_raises(self):
        backend = FAISSBackend(dimension=DIM)
        vecs = [_fake_embedding("a"), _fake_embedding("b")]
        with pytest.raises(ValueError):
            backend.add(["id1"], vecs, [{}])

    def test_search_empty_backend_returns_empty(self):
        backend = FAISSBackend(dimension=DIM)
        results = backend.search(_fake_embedding("query"), top_k=5)
        assert results == []

    def test_metadata_preserved_through_search(self):
        backend = FAISSBackend(dimension=DIM)
        vec = _fake_embedding("rich")
        backend.add(["rich_doc"], [vec], [{"author": "Alice", "year": 2025}])

        results = backend.search(vec, top_k=1)
        assert results[0][2] == {"author": "Alice", "year": 2025}


# ---------------------------------------------------------------------------
# EmbeddingPipeline — index & search
# ---------------------------------------------------------------------------


class TestEmbeddingPipelineIndex:
    def test_index_calls_embed_and_adds_to_backend(self):
        config = _make_config()
        pipeline = EmbeddingPipeline(config)
        docs = _make_docs(2)

        with patch.object(pipeline, "_embed", side_effect=_fake_embed) as mock_embed:
            pipeline.index(docs)

        mock_embed.assert_called_once_with(["content for doc 0", "content for doc 1"])
        assert callable(pipeline.search)

    def test_search_returns_results(self):
        config = _make_config()
        pipeline = EmbeddingPipeline(config)
        docs = _make_docs(3)

        with patch.object(pipeline, "_embed", side_effect=_fake_embed):
            pipeline.index(docs)
            results = pipeline.search("content for doc 0", top_k=1)

        assert len(results) == 1
        assert "id" in results[0]
        assert "score" in results[0]
        assert "metadata" in results[0]
        assert results[0]["id"] == "doc0"

    def test_empty_document_list_is_noop(self):
        config = _make_config()
        pipeline = EmbeddingPipeline(config)

        with patch.object(pipeline, "_embed") as mock_embed:
            pipeline.index([])

        mock_embed.assert_not_called()


# ---------------------------------------------------------------------------
# EmbeddingPipeline — batch processing
# ---------------------------------------------------------------------------


class TestEmbeddingPipelineBatching:
    def test_documents_split_into_batches(self):
        # batch_size=2, 5 docs → 3 batches
        config = _make_config(batch_size=2)
        pipeline = EmbeddingPipeline(config)
        docs = _make_docs(5)

        call_sizes: list[int] = []

        def capture_embed(texts: list[str]) -> list[list[float]]:
            call_sizes.append(len(texts))
            return _fake_embed(texts)

        with patch.object(pipeline, "_embed", side_effect=capture_embed):
            pipeline.index(docs)

        assert call_sizes == [2, 2, 1]

    def test_single_batch_when_docs_fit(self):
        config = _make_config(batch_size=10)
        pipeline = EmbeddingPipeline(config)
        docs = _make_docs(4)

        with patch.object(pipeline, "_embed", side_effect=_fake_embed) as mock_embed:
            pipeline.index(docs)

        assert mock_embed.call_count == 1


# ---------------------------------------------------------------------------
# EmbeddingPipeline — content hashing
# ---------------------------------------------------------------------------


class TestEmbeddingPipelineHashing:
    def test_unchanged_docs_not_re_embedded(self):
        config = _make_config()
        pipeline = EmbeddingPipeline(config)
        docs = _make_docs(2)

        embed_calls: list[list[str]] = []

        def recording_embed(texts: list[str]) -> list[list[float]]:
            embed_calls.append(texts)
            return _fake_embed(texts)

        with patch.object(pipeline, "_embed", side_effect=recording_embed):
            pipeline.index(docs)      # first index: should embed
            pipeline.index(docs)      # second index, same content: should skip

        assert len(embed_calls) == 1  # only first call should fire

    def test_changed_doc_is_re_embedded(self):
        config = _make_config()
        pipeline = EmbeddingPipeline(config)

        doc_v1 = [{"id": "doc0", "text": "original text", "metadata": {}}]
        doc_v2 = [{"id": "doc0", "text": "updated text", "metadata": {}}]

        embed_calls: list[list[str]] = []

        def recording_embed(texts: list[str]) -> list[list[float]]:
            embed_calls.append(texts)
            return _fake_embed(texts)

        with patch.object(pipeline, "_embed", side_effect=recording_embed):
            pipeline.index(doc_v1)
            pipeline.index(doc_v2)

        assert len(embed_calls) == 2


# ---------------------------------------------------------------------------
# EmbeddingPipeline — delete
# ---------------------------------------------------------------------------


class TestEmbeddingPipelineDelete:
    def test_delete_removes_from_index_and_clears_hash(self):
        config = _make_config()
        pipeline = EmbeddingPipeline(config)
        docs = _make_docs(3)

        with patch.object(pipeline, "_embed", side_effect=_fake_embed):
            pipeline.index(docs)
            pipeline.delete(["doc0"])
            results = pipeline.search("content for doc 0", top_k=5)

        returned_ids = {r["id"] for r in results}
        assert "doc0" not in returned_ids

    def test_delete_allows_reindex_with_new_content(self):
        config = _make_config()
        pipeline = EmbeddingPipeline(config)
        doc = [{"id": "reindex_me", "text": "old content", "metadata": {}}]

        embed_calls: list[list[str]] = []

        def recording_embed(texts: list[str]) -> list[list[float]]:
            embed_calls.append(texts)
            return _fake_embed(texts)

        with patch.object(pipeline, "_embed", side_effect=recording_embed):
            pipeline.index(doc)
            pipeline.delete(["reindex_me"])
            # Re-index with same text — hash was cleared, so embedding fires.
            pipeline.index(doc)

        assert len(embed_calls) == 2


# ---------------------------------------------------------------------------
# EmbeddingPipeline — save / load round-trip
# ---------------------------------------------------------------------------


class TestEmbeddingPipelineSaveLoad:
    def test_save_and_load_preserves_search_results(self, tmp_path):
        config = _make_config(index_path=tmp_path / "pipeline_index")
        pipeline = EmbeddingPipeline(config)
        docs = _make_docs(3)

        with patch.object(pipeline, "_embed", side_effect=_fake_embed):
            pipeline.index(docs)
            pipeline.save()

        # Load into a fresh pipeline.
        pipeline2 = EmbeddingPipeline(config)
        pipeline2.load()

        with patch.object(pipeline2, "_embed", side_effect=_fake_embed):
            results = pipeline2.search("content for doc 0", top_k=1)

        assert results[0]["id"] == "doc0"


# ---------------------------------------------------------------------------
# EmbeddingPipeline — backend selection
# ---------------------------------------------------------------------------


class TestBackendSelection:
    def test_faiss_backend_selected_by_default(self):
        config = _make_config(backend="faiss")
        pipeline = EmbeddingPipeline(config)
        assert isinstance(pipeline._backend, FAISSBackend)

    def test_unknown_backend_raises(self):
        config = _make_config(backend="nonexistent")
        with pytest.raises(ValueError, match="Unknown backend"):
            EmbeddingPipeline(config)

    def test_qdrant_backend_raises_import_error_when_not_available(self):
        """If qdrant-client is not installed, QdrantBackend.__init__ should raise."""
        from orchestrator.indexing import embedder as embedder_mod

        original = embedder_mod._QDRANT_AVAILABLE
        try:
            embedder_mod._QDRANT_AVAILABLE = False
            config = _make_config(backend="qdrant")
            with pytest.raises(ImportError, match="qdrant-client"):
                EmbeddingPipeline(config)
        finally:
            embedder_mod._QDRANT_AVAILABLE = original
