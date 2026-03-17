"""Indexing subpackage — embedding pipeline backed by llama-index."""

from __future__ import annotations

from .pipeline import (
    EmbeddingConfig,
    EmbeddingPipeline,
)

__all__ = [
    "EmbeddingConfig",
    "EmbeddingPipeline",
]
