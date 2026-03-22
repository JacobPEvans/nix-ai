"""File processing with counters."""
import os
import threading

processed_count = 0  # BUG 2: No lock protecting shared counter
results = []


def process_file(filepath):
    """Process a file if it exists."""
    global processed_count
    # BUG 1: TOCTOU - file could be deleted between check and open
    if os.path.exists(filepath):
        with open(filepath) as f:
            data = f.read()
        # BUG 2: Race condition on shared counter
        processed_count += 1
        results.append({"file": filepath, "size": len(data)})
        return True
    return False


def process_batch(filepaths):
    """Process multiple files concurrently."""
    threads = []
    for fp in filepaths:
        t = threading.Thread(target=process_file, args=(fp,))
        threads.append(t)
        t.start()
    for t in threads:
        t.join()
    return processed_count


def get_stats():
    """Return processing statistics."""
    return {"processed": processed_count, "total_results": len(results)}
