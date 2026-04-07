"""smolagents evaluation — HuggingFace code agents with OpenAI-compatible backend."""

# /// script
# dependencies = ["smolagents>=1.0.0"]
# ///

import json
import os
import time

from smolagents import OpenAIServerModel, ToolCallingAgent, tool

API_URL = os.environ.get("MLX_API_URL", "http://127.0.0.1:11434/v1")
MODEL = os.environ["MLX_DEFAULT_MODEL"]


@tool
def file_read(path: str) -> str:
    """Read a file and return its contents.

    Args:
        path: File path to read.
    """
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return f"Error: File not found: {path}"


def run_agent(prompt: str) -> dict:
    model = OpenAIServerModel(model_id=MODEL, api_base=API_URL, api_key="EMPTY")
    agent = ToolCallingAgent(tools=[file_read], model=model, max_steps=5)

    start = time.time()
    try:
        answer = agent.run(prompt)
    except Exception as e:
        answer = f"Error: {e}"
    elapsed = time.time() - start

    return {
        "framework": "smolagents (ToolCallingAgent)",
        "answer": str(answer)[:200] if answer else "(empty)",
        "latency": round(elapsed, 2),
    }


if __name__ == "__main__":
    result = run_agent("Read the file at /tmp/eval-test.txt and summarize its contents in one sentence.")
    print(json.dumps(result, indent=2))
