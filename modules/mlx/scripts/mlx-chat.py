"""
mlx-chat — Interactive multi-turn chat against a local MLX inference server.

Usage:
  mlx-chat                              # Interactive mode
  mlx-chat "What is MLX?"               # Single prompt, then interactive
  mlx-chat --system "Be concise" "Hi"   # With system prompt
  cat file.md | mlx-chat "summarize"    # Pipe stdin as context
  mlx-chat --json "Extract entities"    # JSON output mode

Requires: MLX_API_URL and MLX_DEFAULT_MODEL env vars (set by modules/mlx.nix).
"""

import argparse
import os
import sys

import openai
from openai import OpenAI


def stream_response(client, model, messages):
    """Send a streaming chat request and print tokens as they arrive.

    Returns the complete response text so the caller can append it to the
    conversation history.
    """
    try:
        response = client.chat.completions.create(
            model=model, messages=messages, stream=True
        )
    except openai.APIConnectionError:
        print(
            "\nError: cannot reach MLX server. Is it running?",
            file=sys.stderr,
        )
        sys.exit(1)
    except openai.APIError as exc:
        print(f"\nAPI error: {exc}", file=sys.stderr)
        sys.exit(1)

    print("MLX: ", end="", flush=True)
    full_response = []
    for chunk in response:
        token = chunk.choices[0].delta.content
        if token:
            print(token, end="", flush=True)
            full_response.append(token)
    print("\n")
    return "".join(full_response)


def main():
    parser = argparse.ArgumentParser(
        description="Interactive chat with local MLX inference server"
    )
    parser.add_argument("prompt", nargs="*", help="Initial prompt (optional)")
    parser.add_argument(
        "--model", "-m", default=os.environ.get("MLX_DEFAULT_MODEL", ""),
        help="Model to use (default: $MLX_DEFAULT_MODEL)"
    )
    parser.add_argument(
        "--system", "-s", default=None,
        help="System prompt"
    )
    parser.add_argument(
        "--json", "-j", action="store_true",
        help="Request JSON output format"
    )
    args = parser.parse_args()

    api_url = os.environ.get("MLX_API_URL", "http://127.0.0.1:11435/v1")
    model = args.model or os.environ.get("MLX_DEFAULT_MODEL", "")
    if not model:
        print(
            "Error: no model specified. Set MLX_DEFAULT_MODEL or pass --model.",
            file=sys.stderr,
        )
        sys.exit(1)

    client = OpenAI(base_url=api_url, api_key="not-needed")

    messages = []
    if args.system:
        messages.append({"role": "system", "content": args.system})
    if args.json:
        json_instruction = "Respond with valid JSON only."
        if messages and messages[0]["role"] == "system":
            messages[0]["content"] += f" {json_instruction}"
        else:
            messages.insert(0, {"role": "system", "content": json_instruction})

    # Check for piped stdin
    stdin_content = ""
    if not sys.stdin.isatty():
        stdin_content = sys.stdin.read().strip()

    # Build initial prompt from args + stdin
    initial_prompt = " ".join(args.prompt) if args.prompt else ""
    if stdin_content and initial_prompt:
        initial_prompt = f"{initial_prompt}\n\n{stdin_content}"
    elif stdin_content:
        initial_prompt = stdin_content

    # Single-shot if stdin was piped (non-interactive)
    if not sys.stdin.isatty():
        if not initial_prompt:
            print("Error: No prompt provided via stdin or arguments.", file=sys.stderr)
            sys.exit(1)
        messages.append({"role": "user", "content": initial_prompt})
        try:
            response = client.chat.completions.create(
                model=model, messages=messages
            )
        except openai.APIConnectionError:
            print(
                "Error: cannot reach MLX server. Is it running?",
                file=sys.stderr,
            )
            sys.exit(1)
        except openai.APIError as exc:
            print(f"API error: {exc}", file=sys.stderr)
            sys.exit(1)
        print(response.choices[0].message.content)
        return

    # Interactive mode
    print(f"mlx-chat ({model}) — type 'exit' or Ctrl-D to quit")
    print()

    if initial_prompt:
        messages.append({"role": "user", "content": initial_prompt})
        print(f"You: {initial_prompt}")
        reply = stream_response(client, model, messages)
        messages.append({"role": "assistant", "content": reply})

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nBye!")
            break

        if not user_input or user_input.lower() in ("exit", "quit"):
            print("Bye!")
            break

        messages.append({"role": "user", "content": user_input})
        reply = stream_response(client, model, messages)
        messages.append({"role": "assistant", "content": reply})


if __name__ == "__main__":
    main()
