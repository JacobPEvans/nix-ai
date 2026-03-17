"""Embedding pipeline with pluggable vector backends.

Provides a unified EmbeddingPipeline that:
1. Batches documents and calls an OpenAI-compatible embedding endpoint
2. Stores vectors in a pluggable VectorBackend (FAISS or Qdrant)
3. Skips re-embedding of unchanged documents via content hashing
4. Supports save/load for persistent indexes

The FAISS backend uses IndexFlatIP (inner product) on L2-normalised
vectors, which is equivalent to cosine similarity. A JSON sidecar file
stores per-document metadata alongside the binary FAISS index.

Qdrant support is optional — import errors are caught at import time
so the module can be loaded without qdrant-client installed.
"""

from __future__ import annotations

import hashlib
import json
import logging
from pathlib import Path
from typing import Any, Protocol, runtime_checkable

import faiss
import numpy as np
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Optional Qdrant import
# ---------------------------------------------------------------------------

try:
    from qdrant_client import QdrantClient
    from qdrant_client.models import Distance, PointStruct, VectorParams

    _QDRANT_AVAILABLE = True
except ImportError:
    _QDRANT_AVAILABLE = False
    QdrantClient = None  # type: ignore[assignment,misc]


# ---------------------------------------------------------------------------
# VectorBackend protocol
# ---------------------------------------------------------------------------


@runtime_checkable
class VectorBackend(Protocol):
    """Protocol for pluggable vector storage backends.

    All methods operate on lists so callers can batch freely.
    Similarity scores are in [0, 1] (higher = more similar).
    """

    def add(
        self,
        ids: list[str],
        embeddings: list[list[float]],
        metadata: list[dict[str, Any]],
    ) -> None:
        """Add vectors and their metadata to the backend.

        Args:
            ids: Stable, unique identifiers for each document.
            embeddings: Dense vectors — must all share the same dimension.
            metadata: Arbitrary per-document metadata (serialisable to JSON).
        """
        ...

    def search(
        self,
        query_embedding: list[float],
        top_k: int,
    ) -> list[tuple[str, float, dict[str, Any]]]:
        """Return the top-k nearest neighbours.

        Args:
            query_embedding: The query vector.
            top_k: Maximum number of results to return.

        Returns:
            List of (id, score, metadata) triples sorted by score descending.
        """
        ...

    def delete(self, ids: list[str]) -> None:
        """Remove documents by id."""
        ...

    def save(self, path: str | Path) -> None:
        """Persist the index to *path* (may be a directory or file prefix)."""
        ...

    def load(self, path: str | Path) -> None:
        """Load a previously persisted index from *path*."""
        ...


# ---------------------------------------------------------------------------
# FAISS backend
# ---------------------------------------------------------------------------


class FAISSBackend:
    """Vector backend backed by a FAISS IndexFlatIP index.

    Vectors are L2-normalised before insertion so that inner product
    equals cosine similarity.  A JSON sidecar file stores per-document
    ids and metadata alongside the FAISS binary index.

    File layout (given *path* prefix)::

        <path>.faiss   — FAISS binary index
        <path>.meta    — JSON sidecar {"ids": [...], "metadata": [...]}
    """

    def __init__(self, dimension: int = 384) -> None:
        self.dimension = dimension
        self._index: faiss.IndexFlatIP = faiss.IndexFlatIP(dimension)
        # Parallel lists keyed by insertion order; FAISS uses integer positions.
        self._ids: list[str] = []
        self._metadata: list[dict[str, Any]] = []

    # ------------------------------------------------------------------
    # VectorBackend implementation
    # ------------------------------------------------------------------

    def add(
        self,
        ids: list[str],
        embeddings: list[list[float]],
        metadata: list[dict[str, Any]],
    ) -> None:
        if not ids:
            return
        if len(ids) != len(embeddings) or len(ids) != len(metadata):
            msg = "ids, embeddings and metadata must have the same length"
            raise ValueError(msg)

        arr = np.array(embeddings, dtype=np.float32)
        if arr.shape[1] != self.dimension:
            msg = (
                f"Embedding dimension mismatch: expected {self.dimension}, "
                f"got {arr.shape[1]}"
            )
            raise ValueError(msg)

        # Normalise to unit length so IndexFlatIP == cosine similarity.
        norms = np.linalg.norm(arr, axis=1, keepdims=True) + 1e-10
        arr = arr / norms

        self._index.add(arr)  # type: ignore[arg-type]
        self._ids.extend(ids)
        self._metadata.extend(metadata)
        logger.debug("FAISSBackend: added %d vectors (total %d)", len(ids), len(self._ids))

    def search(
        self,
        query_embedding: list[float],
        top_k: int,
    ) -> list[tuple[str, float, dict[str, Any]]]:
        if self._index.ntotal == 0:
            return []

        top_k = min(top_k, self._index.ntotal)
        arr = np.array([query_embedding], dtype=np.float32)
        norms = np.linalg.norm(arr, axis=1, keepdims=True) + 1e-10
        arr = arr / norms

        scores, indices = self._index.search(arr, top_k)  # type: ignore[arg-type]
        results: list[tuple[str, float, dict[str, Any]]] = []
        for score, idx in zip(scores[0], indices[0]):
            if idx == -1:
                continue
            results.append((self._ids[idx], float(score), self._metadata[idx]))
        return results

    def delete(self, ids: list[str]) -> None:
        """Remove documents by id.

        FAISS IndexFlatIP does not support direct removal, so we rebuild
        the index from scratch excluding the deleted ids.
        """
        to_delete = set(ids)
        keep_positions = [i for i, doc_id in enumerate(self._ids) if doc_id not in to_delete]

        if not keep_positions:
            self._index = faiss.IndexFlatIP(self.dimension)
            self._ids = []
            self._metadata = []
            return

        # Reconstruct vectors for kept positions.
        kept_vectors = np.zeros((len(keep_positions), self.dimension), dtype=np.float32)
        for new_pos, old_pos in enumerate(keep_positions):
            self._index.reconstruct(old_pos, kept_vectors[new_pos])

        self._index = faiss.IndexFlatIP(self.dimension)
        self._index.add(kept_vectors)  # type: ignore[arg-type]
        self._ids = [self._ids[i] for i in keep_positions]
        self._metadata = [self._metadata[i] for i in keep_positions]
        logger.debug("FAISSBackend: deleted %d vectors (remaining %d)", len(ids), len(self._ids))

    def save(self, path: str | Path) -> None:
        """Write FAISS index and JSON sidecar to *path* (used as prefix)."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)

        faiss_path = Path(f"{path}.faiss")
        meta_path = Path(f"{path}.meta")

        faiss.write_index(self._index, str(faiss_path))
        meta_path.write_text(
            json.dumps({"ids": self._ids, "metadata": self._metadata}),
            encoding="utf-8",
        )
        logger.info("FAISSBackend: saved index to %s", path)

    def load(self, path: str | Path) -> None:
        """Load FAISS index and JSON sidecar from *path* (used as prefix)."""
        path = Path(path)
        faiss_path = Path(f"{path}.faiss")
        meta_path = Path(f"{path}.meta")

        self._index = faiss.read_index(str(faiss_path))
        sidecar = json.loads(meta_path.read_text(encoding="utf-8"))
        self._ids = sidecar["ids"]
        self._metadata = sidecar["metadata"]
        self.dimension = self._index.d
        logger.info(
            "FAISSBackend: loaded index (%d vectors) from %s",
            self._index.ntotal,
            path,
        )


# ---------------------------------------------------------------------------
# Qdrant backend (optional)
# ---------------------------------------------------------------------------


class QdrantBackend:
    """Vector backend backed by an in-memory Qdrant collection.

    Requires the ``qdrant`` optional dependency::

        pip install orchestrator[qdrant]

    By default creates a transient in-memory collection suitable for
    testing and short-lived pipelines.  For persistent storage, pass
    a *url* pointing at a running Qdrant server.
    """

    COLLECTION = "orchestrator"

    def __init__(self, dimension: int = 384, url: str | None = None) -> None:
        if not _QDRANT_AVAILABLE:
            msg = (
                "qdrant-client is not installed. "
                "Install with: pip install orchestrator[qdrant]"
            )
            raise ImportError(msg)

        self.dimension = dimension
        self._client: QdrantClient = (
            QdrantClient(url=url) if url else QdrantClient(":memory:")
        )
        self._client.recreate_collection(  # type: ignore[attr-defined]
            collection_name=self.COLLECTION,
            vectors_config=VectorParams(size=dimension, distance=Distance.COSINE),
        )

    # ------------------------------------------------------------------
    # VectorBackend implementation
    # ------------------------------------------------------------------

    def add(
        self,
        ids: list[str],
        embeddings: list[list[float]],
        metadata: list[dict[str, Any]],
    ) -> None:
        if not ids:
            return
        if len(ids) != len(embeddings) or len(ids) != len(metadata):
            msg = "ids, embeddings and metadata must have the same length"
            raise ValueError(msg)

        # Qdrant supports string point IDs natively — use doc_id directly
        # to avoid hash collisions from integer conversion.
        points = [
            PointStruct(
                id=doc_id,
                vector=emb,
                payload=meta,
            )
            for doc_id, emb, meta in zip(ids, embeddings, metadata)
        ]
        self._client.upsert(collection_name=self.COLLECTION, points=points)
        logger.debug("QdrantBackend: upserted %d points", len(ids))

    def search(
        self,
        query_embedding: list[float],
        top_k: int,
    ) -> list[tuple[str, float, dict[str, Any]]]:
        hits = self._client.search(
            collection_name=self.COLLECTION,
            query_vector=query_embedding,
            limit=top_k,
        )
        results: list[tuple[str, float, dict[str, Any]]] = []
        for hit in hits:
            payload = dict(hit.payload or {})
            doc_id = str(hit.id)
            results.append((doc_id, float(hit.score), payload))
        return results

    def delete(self, ids: list[str]) -> None:
        from qdrant_client.models import PointIdsList

        # Qdrant point IDs are strings, so pass them directly.
        self._client.delete(
            collection_name=self.COLLECTION,
            points_selector=PointIdsList(points=ids),
        )
        logger.debug("QdrantBackend: deleted %d points", len(ids))

    def save(self, path: str | Path) -> None:
        """No-op for in-memory mode; override for persistent deployments."""
        logger.warning(
            "QdrantBackend.save() is a no-op for in-memory collections. "
            "Use a persistent Qdrant server for durability."
        )

    def load(self, path: str | Path) -> None:
        """No-op for in-memory mode; override for persistent deployments."""
        logger.warning(
            "QdrantBackend.load() is a no-op for in-memory collections. "
            "Use a persistent Qdrant server for durability."
        )


# ---------------------------------------------------------------------------
# Configuration model
# ---------------------------------------------------------------------------


class EmbeddingConfig(BaseModel):
    """Configuration for the EmbeddingPipeline."""

    endpoint: str = Field(
        default="http://localhost:11434/v1",
        description="OpenAI-compatible embedding endpoint (Ollama default)",
    )
    model: str = Field(
        default="nomic-embed-text",
        description="Embedding model identifier",
    )
    batch_size: int = Field(
        default=32,
        gt=0,
        description="Number of documents per embedding batch",
    )
    backend: str = Field(
        default="faiss",
        description="Vector backend to use: 'faiss' or 'qdrant'",
    )
    index_path: Path = Field(
        default=Path("./index"),
        description="File path prefix for persisting the index",
    )
    dimension: int = Field(
        default=384,
        gt=0,
        description="Embedding vector dimension (must match model output)",
    )


# ---------------------------------------------------------------------------
# Embedding pipeline
# ---------------------------------------------------------------------------


class EmbeddingPipeline:
    """High-level embedding pipeline for indexing and searching documents.

    Documents are dicts with required fields ``id`` and ``text``, plus an
    optional ``metadata`` dict for arbitrary extra data.

    Content hashing (SHA-256 of the ``text`` field) prevents re-embedding
    documents whose content has not changed since the last call to
    :meth:`index`.

    Example::

        config = EmbeddingConfig(model="nomic-embed-text")
        pipeline = EmbeddingPipeline(config)
        pipeline.index([{"id": "doc1", "text": "Hello world", "metadata": {}}])
        results = pipeline.search("hello", top_k=3)
    """

    def __init__(self, config: EmbeddingConfig) -> None:
        self.config = config
        self._backend: VectorBackend = self._make_backend()
        # Maps doc_id -> SHA-256 of its last indexed text.
        self._hashes: dict[str, str] = {}
        self._client: Any = None  # lazy openai.OpenAI instance

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _make_backend(self) -> VectorBackend:
        backend_name = self.config.backend.lower()
        if backend_name == "faiss":
            return FAISSBackend(dimension=self.config.dimension)
        if backend_name == "qdrant":
            return QdrantBackend(dimension=self.config.dimension)
        msg = f"Unknown backend '{self.config.backend}'. Choose 'faiss' or 'qdrant'."
        raise ValueError(msg)

    def _get_client(self) -> Any:
        """Lazy-initialise an OpenAI client pointed at the configured endpoint."""
        if self._client is None:
            from openai import OpenAI

            self._client = OpenAI(
                base_url=self.config.endpoint,
                api_key="not-needed",
            )
        return self._client

    def _embed(self, texts: list[str]) -> list[list[float]]:
        """Embed a list of texts via the OpenAI-compatible endpoint.

        Returns one embedding per input text, in the same order.
        """
        client = self._get_client()
        response = client.embeddings.create(
            model=self.config.model,
            input=texts,
        )
        return [item.embedding for item in response.data]

    @staticmethod
    def _hash_text(text: str) -> str:
        return hashlib.sha256(text.encode()).hexdigest()

    def _batched(self, items: list[Any]) -> list[list[Any]]:
        """Split *items* into batches of at most ``config.batch_size``."""
        size = self.config.batch_size
        return [items[i : i + size] for i in range(0, len(items), size)]

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def index(self, documents: list[dict[str, Any]]) -> None:
        """Embed documents and add them to the vector backend.

        Each document must contain:
        - ``id`` (str): Stable unique identifier.
        - ``text`` (str): Content to embed.
        - ``metadata`` (dict, optional): Arbitrary extra data stored alongside
          the vector.

        Documents whose ``text`` has not changed since the last call are
        skipped to avoid unnecessary embedding API calls.

        Args:
            documents: List of document dicts.
        """
        if not documents:
            logger.debug("EmbeddingPipeline.index: no documents provided, skipping")
            return

        # Filter out documents whose content is unchanged.
        new_docs = []
        for doc in documents:
            doc_id = doc["id"]
            text = doc["text"]
            text_hash = self._hash_text(text)
            if self._hashes.get(doc_id) == text_hash:
                logger.debug("Skipping unchanged document '%s'", doc_id)
                continue
            self._hashes[doc_id] = text_hash
            new_docs.append(doc)

        if not new_docs:
            logger.debug("EmbeddingPipeline.index: all documents unchanged, nothing to embed")
            return

        # Process in batches.
        for batch in self._batched(new_docs):
            texts = [doc["text"] for doc in batch]
            ids = [doc["id"] for doc in batch]
            metadata = [doc.get("metadata", {}) for doc in batch]

            embeddings = self._embed(texts)
            self._backend.add(ids, embeddings, metadata)
            logger.debug("EmbeddingPipeline: indexed batch of %d documents", len(batch))

        logger.info("EmbeddingPipeline: indexed %d documents", len(new_docs))

    def search(self, query: str, top_k: int = 5) -> list[dict[str, Any]]:
        """Embed *query* and return the top-k nearest documents.

        Args:
            query: The search query text.
            top_k: Maximum number of results to return.

        Returns:
            List of result dicts, each containing ``id``, ``score``, and
            ``metadata``, sorted by ``score`` descending.
        """
        query_embedding = self._embed([query])[0]
        hits = self._backend.search(query_embedding, top_k)
        return [
            {"id": doc_id, "score": score, "metadata": meta}
            for doc_id, score, meta in hits
        ]

    def delete(self, ids: list[str]) -> None:
        """Remove documents from the index by id.

        Also clears the content hash so the document can be re-indexed
        with new content later.

        Args:
            ids: Document ids to remove.
        """
        self._backend.delete(ids)
        for doc_id in ids:
            self._hashes.pop(doc_id, None)

    def save(self, path: str | Path | None = None) -> None:
        """Persist the index to disk.

        Args:
            path: Override the ``index_path`` from config if provided.
        """
        target = Path(path) if path is not None else self.config.index_path
        self._backend.save(target)

    def load(self, path: str | Path | None = None) -> None:
        """Load a previously saved index from disk.

        Args:
            path: Override the ``index_path`` from config if provided.
        """
        target = Path(path) if path is not None else self.config.index_path
        self._backend.load(target)
