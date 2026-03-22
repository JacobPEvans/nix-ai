"""Data processing with caching."""
import json

_cache = {}


def load_config(filepath):
    """Load configuration from JSON file."""
    # BUG 1: File handle not closed in exception path
    f = open(filepath)
    try:
        data = json.load(f)
        return data
    except json.JSONDecodeError:
        # File handle leaks here - f.close() never called on error
        return {"error": "Invalid JSON", "file": filepath}
    # f.close() only reached on success path implicitly... actually never reached
    # because we return in both branches


def get_data(key, compute_fn):
    """Get data from cache or compute it."""
    # BUG 2: Cache grows unbounded - no eviction policy
    if key not in _cache:
        _cache[key] = compute_fn()
    return _cache[key]


def process_records(records):
    """Process a batch of records, caching results."""
    results = []
    for record in records:
        key = record.get("id", str(record))
        result = get_data(key, lambda: transform(record))
        results.append(result)
    return results


def transform(record):
    """Transform a single record."""
    return {k: str(v).upper() for k, v in record.items()}
