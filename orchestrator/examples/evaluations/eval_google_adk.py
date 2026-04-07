"""Google ADK evaluation — Agent Development Kit with local vLLM backend."""

# /// script
# dependencies = ["google-adk>=0.5.0"]
# ///

import json
import os
import time

from google.adk.agents import Agent
from google.adk.models.lite_llm import LiteLlm

API_URL = os.environ.get("MLX_API_URL", "http://127.0.0.1:11434/v1")
MODEL = os.environ["MLX_DEFAULT_MODEL"]


def file_read(path: str) -> str:
    """Read a file and return its contents.

    Args:
        path: File path to read.

    Returns:
        The file contents as a string.
    """
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return f"Error: File not found: {path}"


def run_agent(prompt: str) -> dict:
    model = LiteLlm(model=f"openai/{MODEL}", api_base=API_URL, api_key="EMPTY")
    agent = Agent(
        name="eval-agent",
        model=model,
        instruction="You are a helpful assistant. Use tools when needed.",
        tools=[file_read],
    )

    start = time.time()
    try:
        # ADK uses async — run synchronously for evaluation
        import asyncio

        async def _run():
            from google.adk.runners import Runner
            from google.adk.sessions import InMemorySessionService

            session_service = InMemorySessionService()
            runner = Runner(agent=agent, app_name="eval", session_service=session_service)
            session = await session_service.create_session(app_name="eval", user_id="eval-user")

            from google.genai.types import Content, Part

            user_msg = Content(role="user", parts=[Part(text=prompt)])
            result_text = ""
            async for event in runner.run(user_id="eval-user", session_id=session.id, new_message=user_msg):
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        if hasattr(part, "text") and part.text:
                            result_text = part.text
            return result_text

        answer = asyncio.run(_run())
    except Exception as e:
        answer = f"Error: {e}"

    elapsed = time.time() - start
    return {
        "framework": "Google ADK (LiteLLM + vLLM)",
        "answer": str(answer)[:200] if answer else "(empty)",
        "latency": round(elapsed, 2),
    }


if __name__ == "__main__":
    result = run_agent("Read the file at /tmp/eval-test.txt and summarize its contents in one sentence.")
    print(json.dumps(result, indent=2))
