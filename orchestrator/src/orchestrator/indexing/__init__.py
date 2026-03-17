"""Indexing subpackage — embedding pipeline and vector backends."""

from __future__ import annotations

from .embedder import (
    EmbeddingConfig,
    EmbeddingPipeline,
    FAISSBackend,
    QdrantBackend,
    VectorBackend,
)

__all__ = [
    "EmbeddingConfig",
    "EmbeddingPipeline",
    "FAISSBackend",
    "QdrantBackend",
    "VectorBackend",
]
