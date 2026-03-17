"""Tests for the semantic skill router.

These tests use mocked embeddings to avoid requiring a running
embedding server. Integration tests with a live endpoint are
in test_router_integration.py (requires Ollama with nomic-embed-text).
"""

from __future__ import annotations

from unittest.mock import patch

import numpy as np
import pytest

from orchestrator.router import RouteResult, SkillRouter, _cosine_similarity
from orchestrator.skill_schema import SkillDefinition


@pytest.fixture
def sample_skills() -> dict[str, SkillDefinition]:
    return {
        "code-review": SkillDefinition(
            name="code-review",
            description="Review code for quality, security, and best practices",
            examples=["Review this function", "Check for bugs in this code"],
        ),
        "code-explain": SkillDefinition(
            name="code-explain",
            description="Explain code in plain language for learning",
            examples=["What does this function do", "Explain this algorithm"],
        ),
        "vault-search": SkillDefinition(
            name="vault-search",
            description="Search an Obsidian vault for relevant notes and knowledge",
            examples=["Find notes about Python", "What do I know about deployment"],
        ),
    }


class TestCosineSimilarity:
    def test_identical_vectors(self):
        a = np.array([[1.0, 0.0, 0.0]])
        b = np.array([[1.0, 0.0, 0.0]])
        result = _cosine_similarity(a, b)
        assert np.isclose(result[0, 0], 1.0)

    def test_orthogonal_vectors(self):
        a = np.array([[1.0, 0.0]])
        b = np.array([[0.0, 1.0]])
        result = _cosine_similarity(a, b)
        assert np.isclose(result[0, 0], 0.0)

    def test_opposite_vectors(self):
        a = np.array([[1.0, 0.0]])
        b = np.array([[-1.0, 0.0]])
        result = _cosine_similarity(a, b)
        assert np.isclose(result[0, 0], -1.0)

    def test_multiple_candidates(self):
        query = np.array([[1.0, 0.0, 0.0]])
        candidates = np.array(
            [
                [1.0, 0.0, 0.0],  # identical
                [0.0, 1.0, 0.0],  # orthogonal
                [0.7, 0.7, 0.0],  # partial match
            ]
        )
        result = _cosine_similarity(query, candidates)
        assert result.shape == (1, 3)
        assert np.argmax(result[0]) == 0

    def test_zero_norm_vector(self):
        """Verify epsilon prevents division by zero for zero-norm vectors."""
        a = np.array([[0.0, 0.0, 0.0]])
        b = np.array([[1.0, 0.0, 0.0]])
        result = _cosine_similarity(a, b)
        assert not np.isnan(result[0, 0])
        assert np.isclose(result[0, 0], 0.0)


class TestSkillRouter:
    def test_register_skills_embeds_descriptions(self, sample_skills):
        router = SkillRouter()
        # Mock the embedding call
        mock_embeddings = np.random.default_rng(42).random((3, 384))
        with patch.object(router, "_embed", return_value=mock_embeddings):
            router.register_skills(sample_skills)

        assert len(router._skill_names) == 3
        assert router._embeddings is not None
        assert router._embeddings.shape == (3, 384)

    def test_route_returns_best_match(self, sample_skills):
        router = SkillRouter(threshold=0.3)
        # Create embeddings where code-review is closest to query
        # Skills are sorted alphabetically: code-explain, code-review, vault-search
        skill_embeddings = np.array(
            [
                [0.1, 0.9, 0.0],  # code-explain
                [0.9, 0.1, 0.0],  # code-review
                [0.0, 0.1, 0.9],  # vault-search
            ]
        )
        query_embedding = np.array([[0.85, 0.15, 0.0]])  # similar to code-review

        with patch.object(router, "_embed") as mock_embed:
            # First call: register skills
            mock_embed.return_value = skill_embeddings
            router.register_skills(sample_skills)
            # Second call: route query
            mock_embed.return_value = query_embedding
            results = router.route("Review my code", top_k=3)

        assert len(results) == 3
        assert results[0].skill_name == "code-review"
        assert results[0].score > results[1].score

    def test_route_best_returns_none_below_threshold(self, sample_skills):
        router = SkillRouter(threshold=0.99)
        skill_embeddings = np.array(
            [
                [1.0, 0.0, 0.0],
                [0.0, 1.0, 0.0],
                [0.0, 0.0, 1.0],
            ]
        )
        # Orthogonal to all skills
        query_embedding = np.array([[0.33, 0.33, 0.34]])

        with patch.object(router, "_embed") as mock_embed:
            mock_embed.return_value = skill_embeddings
            router.register_skills(sample_skills)
            mock_embed.return_value = query_embedding
            result = router.route_best("Something unrelated")

        assert result is None

    def test_route_empty_registry(self):
        router = SkillRouter()
        results = router.route("anything")
        assert results == []

    def test_route_best_empty_registry(self):
        router = SkillRouter()
        assert router.route_best("anything") is None

    def test_top_k_limits_results(self, sample_skills):
        router = SkillRouter(threshold=0.0)
        skill_embeddings = np.random.default_rng(42).random((3, 384))
        query_embedding = np.random.default_rng(99).random((1, 384))

        with patch.object(router, "_embed") as mock_embed:
            mock_embed.return_value = skill_embeddings
            router.register_skills(sample_skills)
            mock_embed.return_value = query_embedding
            results = router.route("test", top_k=2)

        assert len(results) == 2


class TestRouteResult:
    def test_fields(self):
        skill = SkillDefinition(name="test", description="test")
        result = RouteResult(
            skill_name="test",
            score=0.85,
            skill=skill,
        )
        assert result.skill_name == "test"
        assert result.score == 0.85
        assert not result.below_threshold
