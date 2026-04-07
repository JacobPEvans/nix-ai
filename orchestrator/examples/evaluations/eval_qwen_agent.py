"""Qwen-Agent evaluation — official Qwen framework with FnCallAgent."""

# /// script
# dependencies = ["qwen-agent>=0.0.14", "soundfile>=0.13.0"]
# ///

import json
import os
import time

from qwen_agent.agents import FnCallAgent
from qwen_agent.tools.base import BaseTool, register_tool

API_URL = os.environ.get("MLX_API_URL", "http://127.0.0.1:11434/v1")
MODEL = os.environ["MLX_DEFAULT_MODEL"]


@register_tool("file_read")
class FileReadTool(BaseTool):
    description = "Read a file and return its contents"
    parameters = [{"name": "path", "type": "string", "description": "File path to read", "required": True}]

    def call(self, params: str, **kwargs) -> str:
        args = json.loads(params) if isinstance(params, str) else params
        try:
            with open(args["path"]) as f:
                return f.read()
        except FileNotFoundError:
            return f"Error: File not found: {args['path']}"


def run_agent(prompt: str) -> dict:
    llm_cfg = {"model": MODEL, "model_server": API_URL, "api_key": "EMPTY"}
    agent = FnCallAgent(llm=llm_cfg, function_list=["file_read"], name="eval-agent", description="File reader")

    start = time.time()
    messages = [{"role": "user", "content": prompt}]

    tool_calls_made = []
    answer = ""
    for response in agent.run(messages):
        for msg in response:
            if hasattr(msg, "function_call") and msg.function_call:
                tool_calls_made.append({"tool": msg.function_call.get("name", ""), "args": msg.function_call.get("arguments", "")})
            if msg.get("role") == "assistant" and msg.get("content"):
                answer = msg["content"]

    elapsed = time.time() - start
    return {
        "framework": "Qwen-Agent (FnCallAgent)",
        "answer": answer[:200] if answer else "(empty)",
        "tool_calls": tool_calls_made,
        "latency": round(elapsed, 2),
        "steps": len(tool_calls_made) + 1,
    }


if __name__ == "__main__":
    result = run_agent("Read the file at /tmp/eval-test.txt and summarize its contents in one sentence.")
    print(json.dumps(result, indent=2))
