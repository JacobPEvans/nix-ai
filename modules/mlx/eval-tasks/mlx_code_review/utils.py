"""Scoring for code review bug detection."""


def process_results(doc, results):
    """Score whether the model detected the planted bug."""
    response = results[0].lower()
    keyword = doc["bug_keyword"].lower()

    # Check if the model's response mentions the bug category
    hit = keyword in response

    return {"bug_detection_rate": int(hit)}
