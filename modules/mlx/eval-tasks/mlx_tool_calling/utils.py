"""Scoring for tool-calling decision accuracy."""

import re


def process_results(doc, results):
    """Score whether the model made the correct tool-calling decision."""
    response = results[0].lower()
    expected = doc["expected"].lower()

    if expected == "call":
        # Model should have produced a function/tool call
        hit = bool(
            re.search(r"(function_call|tool_calls|\"name\"\s*:)", response)
            or re.search(r"get_weather", response)
        )
    else:
        # Model should have answered directly without calling a tool
        hit = not bool(
            re.search(r"(function_call|tool_calls|\"name\"\s*:)", response)
            and re.search(r"get_weather", response)
        )

    return {"tool_accuracy": int(hit)}
