"""Benchmark: Structured Output — MLX vs Claude Opus 4.6."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from common import timed_completion, score_json_schema, score_json_valid, write_results, print_test_result

_SYSTEM = (
    "You are a data generation assistant. Respond with ONLY valid JSON matching the "
    "requested schema. No markdown code blocks, no prose, no explanation — just the raw JSON."
)


# ---------------------------------------------------------------------------
# Test 1: flat_object
# ---------------------------------------------------------------------------
def test_flat_object() -> dict:
    name = "flat_object"
    schema = {
        "type": "object",
        "required": ["name", "age", "email", "active", "score"],
        "properties": {
            "name": {"type": "string"},
            "age": {"type": "integer"},
            "email": {"type": "string"},
            "active": {"type": "boolean"},
            "score": {"type": "number", "minimum": 0, "maximum": 100},
        },
        "additionalProperties": False,
    }
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Generate a person record with fields: name (string), age (integer), "
                        "email (string), active (boolean), score (number between 0 and 100)."
                    ),
                },
            ],
            max_tokens=512,
        )
        score = score_json_schema(schema, content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 2: nested_object
# ---------------------------------------------------------------------------
def test_nested_object() -> dict:
    name = "nested_object"
    schema = {
        "type": "object",
        "required": ["name", "address", "founded_year"],
        "properties": {
            "name": {"type": "string"},
            "address": {
                "type": "object",
                "required": ["street", "city", "country", "zip"],
                "properties": {
                    "street": {"type": "string"},
                    "city": {"type": "string"},
                    "country": {"type": "string"},
                    "zip": {"type": "string"},
                },
                "additionalProperties": False,
            },
            "founded_year": {"type": "integer"},
        },
        "additionalProperties": False,
    }
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Generate a company record: name (string), address (object with street, "
                        "city, country strings, zip string), founded_year (integer)."
                    ),
                },
            ],
            max_tokens=512,
        )
        score = score_json_schema(schema, content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 3: array_of_objects
# ---------------------------------------------------------------------------
def test_array_of_objects() -> dict:
    name = "array_of_objects"
    schema = {
        "type": "array",
        "minItems": 3,
        "maxItems": 3,
        "items": {
            "type": "object",
            "required": ["title", "author", "year", "genres"],
            "properties": {
                "title": {"type": "string"},
                "author": {"type": "string"},
                "year": {"type": "integer"},
                "genres": {
                    "type": "array",
                    "items": {"type": "string"},
                },
            },
            "additionalProperties": False,
        },
    }
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Generate an array of exactly 3 book records. Each book has: "
                        "title (string), author (string), year (integer), genres (array of strings)."
                    ),
                },
            ],
            max_tokens=768,
        )
        score = score_json_schema(schema, content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 4: enum_fields
# ---------------------------------------------------------------------------
def test_enum_fields() -> dict:
    name = "enum_fields"
    schema = {
        "type": "object",
        "required": ["title", "priority", "status"],
        "properties": {
            "title": {"type": "string"},
            "priority": {"type": "string", "enum": ["low", "medium", "high", "critical"]},
            "status": {"type": "string", "enum": ["todo", "in_progress", "done", "cancelled"]},
        },
        "additionalProperties": False,
    }
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Generate a task record with: title (string), priority (one of: "
                        "'low', 'medium', 'high', 'critical'), status (one of: 'todo', "
                        "'in_progress', 'done', 'cancelled')."
                    ),
                },
            ],
            max_tokens=256,
        )
        score = score_json_schema(schema, content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 5: optional_required
# ---------------------------------------------------------------------------
def test_optional_required() -> dict:
    name = "optional_required"
    schema = {
        "type": "object",
        "required": ["username", "email"],
        "properties": {
            "username": {"type": "string"},
            "email": {"type": "string"},
            "bio": {"type": "string"},
            "website": {"type": "string"},
            "avatar_url": {"type": "string"},
        },
        "additionalProperties": False,
    }
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Generate a user profile. Required fields: username (string), email (string). "
                        "Optional fields: bio (string), website (string), avatar_url (string). "
                        "Include at least the required fields."
                    ),
                },
            ],
            max_tokens=512,
        )
        score = score_json_schema(schema, content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 6: recursive_structure
# ---------------------------------------------------------------------------
def _score_recursive_structure(text: str) -> float:
    """Validate a file system tree: valid JSON, has name/type, directories have children."""
    import json

    parse_score, obj = score_json_valid(text)
    if obj is None:
        return 0.0

    def check_node(node: object, depth: int) -> tuple[bool, int]:
        """Return (valid, max_depth_reached)."""
        if not isinstance(node, dict):
            return False, depth
        if "name" not in node or "type" not in node:
            return False, depth
        if node["type"] not in ("file", "directory"):
            return False, depth
        if node["type"] == "directory":
            children = node.get("children", [])
            if not isinstance(children, list):
                return False, depth
            max_depth = depth
            for child in children:
                valid, child_depth = check_node(child, depth + 1)
                if not valid:
                    return False, depth
                max_depth = max(max_depth, child_depth)
            return True, max_depth
        return True, depth

    valid, max_depth = check_node(obj, 0)
    if not valid:
        return 0.0
    # Require at least 3 levels of nesting (depth 0, 1, 2)
    depth_score = min(1.0, max_depth / 2)
    return parse_score * depth_score


def test_recursive_structure() -> dict:
    name = "recursive_structure"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Generate a file system tree with at least 3 levels of nesting. Each node "
                        "has: name (string), type ('file' or 'directory'), and if it's a directory, "
                        "a 'children' array of the same node type."
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = _score_recursive_structure(content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 7: api_response
# ---------------------------------------------------------------------------
def test_api_response() -> dict:
    name = "api_response"
    schema = {
        "type": "object",
        "required": ["status", "data", "pagination", "errors"],
        "properties": {
            "status": {"type": "integer"},
            "data": {
                "type": "array",
                "items": {
                    "type": "object",
                    "required": ["id", "name", "email"],
                    "properties": {
                        "id": {"type": "integer"},
                        "name": {"type": "string"},
                        "email": {"type": "string"},
                    },
                },
            },
            "pagination": {
                "type": "object",
                "required": ["page", "per_page", "total", "total_pages"],
                "properties": {
                    "page": {"type": "integer"},
                    "per_page": {"type": "integer"},
                    "total": {"type": "integer"},
                    "total_pages": {"type": "integer"},
                },
                "additionalProperties": False,
            },
            "errors": {
                "oneOf": [
                    {"type": "null"},
                    {"type": "array", "items": {"type": "string"}},
                ]
            },
        },
        "additionalProperties": False,
    }
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Generate a REST API response for a paginated list endpoint. Include: "
                        "status (integer), data (array of user objects with id, name, email), "
                        "pagination (object with page, per_page, total, total_pages integers), "
                        "and errors (null or array of strings)."
                    ),
                },
            ],
            max_tokens=768,
        )
        score = score_json_schema(schema, content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 8: conflicting_instructions
# ---------------------------------------------------------------------------
def test_conflicting_instructions() -> dict:
    """System prompt says JSON-only; user prompt asks for plain English. System should win."""
    name = "conflicting_instructions"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Give me a single user object. Actually, on second thought, just describe "
                        "the user in plain English."
                    ),
                },
            ],
            max_tokens=512,
        )
        # Score 1.0 if model followed system prompt (returned JSON), 0.0 if prose
        parse_score, obj = score_json_valid(content)
        score = parse_score if obj is not None else 0.0
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    print("=== Structured Output Benchmark ===")
    tests = [
        test_flat_object,
        test_nested_object,
        test_array_of_objects,
        test_enum_fields,
        test_optional_required,
        test_recursive_structure,
        test_api_response,
        test_conflicting_instructions,
    ]

    results: list[dict] = []
    for fn in tests:
        result = fn()
        results.append(result)

    write_results("structured_output", results)

    total = len(results)
    mean_score = sum(r["score"] for r in results) / max(total, 1)
    passed = sum(1 for r in results if r["score"] >= 0.8)
    print(f"\n  Category summary: {passed}/{total} passed  |  mean score: {mean_score:.2f}")


if __name__ == "__main__":
    main()
