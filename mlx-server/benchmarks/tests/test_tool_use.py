"""Benchmark: Tool Use Chains — MLX vs Claude Opus 4.6."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))
from common import timed_tool_loop, write_results, print_test_result


# ---------------------------------------------------------------------------
# Tool definitions (OpenAI function calling format)
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "file_read",
            "description": "Read a file from the filesystem.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Absolute path of the file to read."},
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "file_write",
            "description": "Write content to a file on the filesystem.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Absolute path of the file to write."},
                    "content": {"type": "string", "description": "Content to write into the file."},
                },
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "bash_exec",
            "description": "Execute a shell command and return its stdout/stderr output.",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {"type": "string", "description": "Shell command to execute."},
                },
                "required": ["command"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "grep_search",
            "description": "Search files for a pattern (like grep -r).",
            "parameters": {
                "type": "object",
                "properties": {
                    "pattern": {"type": "string", "description": "Pattern to search for."},
                    "path": {"type": "string", "description": "Directory or file path to search."},
                },
                "required": ["pattern", "path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "http_get",
            "description": "Perform an HTTP GET request and return the response body.",
            "parameters": {
                "type": "object",
                "properties": {
                    "url": {"type": "string", "description": "URL to fetch."},
                },
                "required": ["url"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "calculator",
            "description": "Evaluate a mathematical expression and return the numeric result.",
            "parameters": {
                "type": "object",
                "properties": {
                    "expression": {"type": "string", "description": "Math expression to evaluate."},
                },
                "required": ["expression"],
            },
        },
    },
]


# ---------------------------------------------------------------------------
# Simulated tool executor
# ---------------------------------------------------------------------------

class SimulatedToolExecutor:
    """Returns deterministic responses for each test scenario."""

    def __init__(self, scenario: str) -> None:
        self.scenario = scenario
        self._attempt_counts: dict[str, int] = {}

    def _attempt(self, key: str) -> int:
        self._attempt_counts[key] = self._attempt_counts.get(key, 0) + 1
        return self._attempt_counts[key]

    def __call__(self, tool_name: str, args_json: str) -> str:
        try:
            args = json.loads(args_json)
        except json.JSONDecodeError:
            args = {}

        if self.scenario == "config_port_check":
            return self._config_port_check(tool_name, args)
        if self.scenario == "grep_count_write":
            return self._grep_count_write(tool_name, args)
        if self.scenario == "csv_error_recovery":
            return self._csv_error_recovery(tool_name, args)
        if self.scenario == "api_error_recovery":
            return self._api_error_recovery(tool_name, args)
        if self.scenario == "refactor_chain":
            return self._refactor_chain(tool_name, args)
        return "Unknown scenario"

    # --- scenario handlers ---

    def _config_port_check(self, tool_name: str, args: dict) -> str:
        if tool_name == "file_read":
            return json.dumps({"database": {"host": "localhost", "port": 5432, "name": "myapp"}})
        if tool_name == "bash_exec":
            command = args.get("command", "")
            # Accept any port-check command that references 5432
            if "5432" in command or "port" in command.lower() or "lsof" in command or "netstat" in command or "ss" in command:
                return (
                    "COMMAND  PID  USER  FD  TYPE  DEVICE  SIZE/OFF  NODE  NAME\n"
                    "postgres  1234  postgres  5u  IPv4  12345  0t0  TCP  *:5432 (LISTEN)"
                )
            return ""
        return f"Tool '{tool_name}' not expected in this scenario."

    def _grep_count_write(self, tool_name: str, args: dict) -> str:
        if tool_name == "grep_search":
            return (
                "/src/main.py:12:# TODO: refactor this\n"
                "/src/utils.py:45:# TODO: add tests\n"
                "/src/models.py:78:# TODO: optimize query"
            )
        if tool_name == "file_write":
            return "File written successfully"
        return f"Tool '{tool_name}' not expected in this scenario."

    def _csv_error_recovery(self, tool_name: str, args: dict) -> str:
        if tool_name == "file_read":
            attempt = self._attempt("file_read")
            if attempt == 1:
                return "Error: file is temporarily locked, try again"
            return "month,revenue,costs\nJan,1000,800\nFeb,1500,900\nMar,2000,1200"
        if tool_name == "calculator":
            return "1500"
        if tool_name == "file_write":
            return "File written successfully"
        return f"Tool '{tool_name}' not expected in this scenario."

    def _api_error_recovery(self, tool_name: str, args: dict) -> str:
        if tool_name == "http_get":
            attempt = self._attempt("http_get")
            if attempt == 1:
                return "HTTP 500: Internal Server Error"
            return json.dumps([
                {"id": 41, "name": "Alice", "email": "alice@example.com"},
                {"id": 42, "name": "Bob", "email": "bob@example.com"},
                {"id": 43, "name": "Carol", "email": "carol@example.com"},
            ])
        if tool_name == "file_write":
            return "File written successfully"
        return f"Tool '{tool_name}' not expected in this scenario."

    def _refactor_chain(self, tool_name: str, args: dict) -> str:
        if tool_name == "file_read":
            return (
                "def greet(name):\n"
                "    return f'Hello, {name}!'\n"
                "\n"
                "def calculate_total(items):\n"
                "    \"\"\"Sum prices across a list of item dicts.\"\"\"\n"
                "    return sum(item['price'] for item in items)\n"
                "\n"
                "def format_currency(amount):\n"
                "    return f'${amount:.2f}'\n"
            )
        if tool_name == "file_write":
            return "File written successfully"
        if tool_name == "bash_exec":
            # Accept any syntax-check command for the new file
            command = args.get("command", "")
            if "calculator.py" in command or "ast.parse" in command or "py_compile" in command or "python3 -c" in command:
                return ""  # exit 0 — valid Python
            return ""
        return f"Tool '{tool_name}' not expected in this scenario."


# ---------------------------------------------------------------------------
# Individual test runners
# ---------------------------------------------------------------------------

def run_config_port_check() -> dict:
    """Read config file, find DB port, check if it is listening."""
    executor = SimulatedToolExecutor("config_port_check")
    messages = [
        {
            "role": "user",
            "content": (
                "Read the config file at /app/config.json, find the database port number, "
                "and check if that port is currently listening."
            ),
        }
    ]
    trace = timed_tool_loop(messages, TOOLS, executor)

    calls = trace["tool_calls"]
    tool_names = [c["tool"] for c in calls]
    tool_args = [c["args"] for c in calls]

    used_file_read = "file_read" in tool_names
    used_bash = "bash_exec" in tool_names
    port_in_bash = any(
        "5432" in a or "port" in a.lower()
        for t, a in zip(tool_names, tool_args)
        if t == "bash_exec"
    )

    score = 0.0
    if used_file_read:
        score += 0.5
        # Check file_read came before bash_exec
        if used_bash:
            fi = next((i for i, t in enumerate(tool_names) if t == "file_read"), -1)
            bi = next((i for i, t in enumerate(tool_names) if t == "bash_exec"), -1)
            if fi < bi:
                score += 0.25
    if port_in_bash or (used_bash and used_file_read):
        score += 0.25

    return {
        "name": "config_port_check",
        "score": round(min(score, 1.0), 4),
        "tokens": trace["tokens"],
        "latency": trace["latency"],
        "steps": trace["steps"],
        "tool_sequence": tool_names,
        "answer_preview": trace["answer"][:200],
    }


def run_grep_count_write() -> dict:
    """Find TODO comments, count files, write summary."""
    executor = SimulatedToolExecutor("grep_count_write")
    messages = [
        {
            "role": "user",
            "content": (
                "Find all Python files containing 'TODO' comments in /src, count how many "
                "there are, and write a summary to /reports/todo-summary.txt"
            ),
        }
    ]
    trace = timed_tool_loop(messages, TOOLS, executor)

    calls = trace["tool_calls"]
    tool_names = [c["tool"] for c in calls]
    tool_args = [c["args"] for c in calls]

    used_grep = "grep_search" in tool_names
    used_write = "file_write" in tool_names

    # Check the write contains a reference to 3 files
    count_in_write = any(
        "3" in a
        for t, a in zip(tool_names, tool_args)
        if t == "file_write"
    )

    score = 0.0
    if used_grep:
        score += 0.5
    if count_in_write:
        score += 0.25
    if used_write:
        score += 0.25

    return {
        "name": "grep_count_write",
        "score": round(min(score, 1.0), 4),
        "tokens": trace["tokens"],
        "latency": trace["latency"],
        "steps": trace["steps"],
        "tool_sequence": tool_names,
        "answer_preview": trace["answer"][:200],
    }


def run_csv_error_recovery() -> dict:
    """Read CSV with a transient lock error, compute average, write result."""
    executor = SimulatedToolExecutor("csv_error_recovery")
    messages = [
        {
            "role": "user",
            "content": (
                "Read the data file at /data/sales.csv, compute the average of the 'revenue' "
                "column, and write the result to /data/average.txt"
            ),
        }
    ]
    trace = timed_tool_loop(messages, TOOLS, executor)

    calls = trace["tool_calls"]
    tool_names = [c["tool"] for c in calls]
    tool_args = [c["args"] for c in calls]

    file_read_count = tool_names.count("file_read")
    retried = file_read_count >= 2
    used_calc = "calculator" in tool_names
    used_write = "file_write" in tool_names

    # Check that the written content references 1500
    correct_value = any(
        "1500" in a
        for t, a in zip(tool_names, tool_args)
        if t == "file_write"
    )
    # Also accept if the answer mentions 1500
    if not correct_value and "1500" in trace["answer"]:
        correct_value = True

    score = 0.0
    if retried:
        score += 0.25
    if used_calc or correct_value:
        score += 0.25
    if used_write:
        score += 0.25
    if retried and used_write and (used_calc or correct_value):
        score += 0.25

    return {
        "name": "csv_error_recovery",
        "score": round(min(score, 1.0), 4),
        "tokens": trace["tokens"],
        "latency": trace["latency"],
        "steps": trace["steps"],
        "tool_sequence": tool_names,
        "file_read_attempts": file_read_count,
        "answer_preview": trace["answer"][:200],
    }


def run_api_error_recovery() -> dict:
    """Fetch user list with initial 500, find user 42, write email."""
    executor = SimulatedToolExecutor("api_error_recovery")
    messages = [
        {
            "role": "user",
            "content": (
                "Fetch the user list from https://api.example.com/users, find the user with "
                "id 42, and write their email to /tmp/user-email.txt"
            ),
        }
    ]
    trace = timed_tool_loop(messages, TOOLS, executor)

    calls = trace["tool_calls"]
    tool_names = [c["tool"] for c in calls]
    tool_args = [c["args"] for c in calls]

    http_count = tool_names.count("http_get")
    retried = http_count >= 2
    found_user = "42" in " ".join(tool_args)
    correct_email = any(
        "bob@example.com" in a
        for t, a in zip(tool_names, tool_args)
        if t == "file_write"
    )
    used_write = "file_write" in tool_names

    score = 0.0
    if retried:
        score += 0.25
    if found_user:
        score += 0.25
    if correct_email:
        score += 0.25
    if used_write:
        score += 0.25

    return {
        "name": "api_error_recovery",
        "score": round(min(score, 1.0), 4),
        "tokens": trace["tokens"],
        "latency": trace["latency"],
        "steps": trace["steps"],
        "tool_sequence": tool_names,
        "http_attempts": http_count,
        "answer_preview": trace["answer"][:200],
    }


def run_refactor_chain() -> dict:
    """Read source file, extract function, write to new file, verify syntax."""
    executor = SimulatedToolExecutor("refactor_chain")
    messages = [
        {
            "role": "user",
            "content": (
                "Read the Python file at /src/legacy.py, extract the function called "
                "'calculate_total', write it to a new file /src/calculator.py, then verify "
                "the new file has valid Python syntax."
            ),
        }
    ]
    trace = timed_tool_loop(messages, TOOLS, executor)

    calls = trace["tool_calls"]
    tool_names = [c["tool"] for c in calls]
    tool_args = [c["args"] for c in calls]

    used_read = "file_read" in tool_names
    used_write = "file_write" in tool_names
    # The write should target calculator.py
    wrote_calculator = any(
        "calculator.py" in a
        for t, a in zip(tool_names, tool_args)
        if t == "file_write"
    )
    used_bash = "bash_exec" in tool_names
    verified_syntax = any(
        ("calculator.py" in a or "ast.parse" in a or "py_compile" in a or "python3 -c" in a)
        for t, a in zip(tool_names, tool_args)
        if t == "bash_exec"
    )

    score = 0.0
    if used_read:
        score += 0.33
    if used_write and wrote_calculator:
        score += 0.34
    elif used_write:
        score += 0.17
    if used_bash and verified_syntax:
        score += 0.33
    elif used_bash:
        score += 0.16

    return {
        "name": "refactor_chain",
        "score": round(min(score, 1.0), 4),
        "tokens": trace["tokens"],
        "latency": trace["latency"],
        "steps": trace["steps"],
        "tool_sequence": tool_names,
        "answer_preview": trace["answer"][:200],
    }


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    print("=== Tool Use Chains Benchmark ===")
    results = []

    runners = [
        run_config_port_check,
        run_grep_count_write,
        run_csv_error_recovery,
        run_api_error_recovery,
        run_refactor_chain,
    ]

    for runner in runners:
        result = runner()
        results.append(result)
        print_test_result(result["name"], result["score"], result["latency"], result["tokens"])

    write_results("tool_use", results)

    mean = sum(r["score"] for r in results) / len(results)
    print(f"\nMean score: {mean:.3f}")


if __name__ == "__main__":
    main()
