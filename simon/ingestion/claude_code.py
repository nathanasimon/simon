"""Claude Code session parsing — slimmed down for recorder use only.

Contains only the functions needed by the context recorder:
session parsing, timestamp handling, content hashing, and turn grouping.
"""

import hashlib
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Default location for Claude Code session files
CLAUDE_SESSIONS_DIR = Path.home() / ".claude" / "projects"


def _parse_timestamp(ts: Optional[str]) -> Optional[datetime]:
    """Parse an ISO timestamp string, returning None on failure."""
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def _extract_text_content(content) -> str:
    """Extract plain text from a message content field.

    Content can be a string (user messages) or a list of content blocks
    (assistant messages with text/tool_use/tool_result blocks).
    """
    if isinstance(content, str):
        return content

    if isinstance(content, list):
        text_parts = []
        for block in content:
            if isinstance(block, dict) and block.get("type") == "text":
                text_parts.append(block.get("text", ""))
        return "\n".join(text_parts)

    return ""


def _extract_tool_names(content) -> list[str]:
    """Extract tool names from assistant message content blocks.

    Args:
        content: Message content (string or list of blocks).

    Returns:
        List of unique tool names used in this message.
    """
    if not isinstance(content, list):
        return []

    tools = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "tool_use":
            name = block.get("name", "")
            if name and name not in tools:
                tools.append(name)
    return tools


def compute_content_hash(content: str) -> str:
    """Compute MD5 hash for content deduplication.

    Args:
        content: Text content to hash.

    Returns:
        Hex digest of MD5 hash.
    """
    return hashlib.md5(content.encode()).hexdigest()


def _finalize_turn(turn: dict, index: int) -> None:
    """Finalize a turn dict by computing hash and cleaning up fields.

    Args:
        turn: Mutable turn dict to finalize in place.
        index: Zero-based turn index.
    """
    raw_jsonl = "\n".join(turn.pop("raw_lines"))
    assistant_text = "\n".join(turn.pop("assistant_texts"))

    turn["turn_number"] = index
    turn["assistant_text"] = assistant_text
    turn["raw_jsonl"] = raw_jsonl
    turn["content_hash"] = compute_content_hash(raw_jsonl)


def parse_session_into_turns(path: Path) -> list[dict]:
    """Parse a Claude Code JSONL session file into structured turns.

    A "turn" is a user message followed by the assistant's complete response
    (which may include tool calls, thinking, and text blocks).

    Args:
        path: Path to the .jsonl session file.

    Returns:
        List of turn dicts with keys: turn_number, user_message,
        assistant_text, tool_names, model_name, started_at, ended_at,
        raw_jsonl, content_hash.
    """
    if not path.exists():
        return []

    # First pass: collect all non-sidechain, non-meta messages
    messages = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = obj.get("type")
            if msg_type not in ("user", "assistant"):
                continue

            if obj.get("isSidechain") or obj.get("isMeta"):
                continue

            message = obj.get("message", {})
            if not isinstance(message, dict):
                continue

            role = message.get("role", "")
            content = message.get("content", "")
            text_content = _extract_text_content(content)

            # Skip command messages
            if text_content and text_content.strip().startswith(("<command-name>", "<local-command")):
                continue

            messages.append({
                "role": role,
                "content": content,
                "text": text_content,
                "timestamp": obj.get("timestamp", ""),
                "model": message.get("model", ""),
                "raw_line": line,
            })

    # Second pass: group into turns (user message + assistant responses)
    turns = []
    current_turn: Optional[dict] = None

    for msg in messages:
        if msg["role"] == "user":
            # Start a new turn
            if current_turn and current_turn.get("user_message"):
                _finalize_turn(current_turn, len(turns))
                turns.append(current_turn)

            current_turn = {
                "user_message": msg["text"],
                "assistant_texts": [],
                "tool_names": [],
                "model_name": None,
                "started_at": msg["timestamp"],
                "ended_at": msg["timestamp"],
                "raw_lines": [msg["raw_line"]],
            }
        elif msg["role"] == "assistant" and current_turn is not None:
            # Append to current turn
            if msg["text"]:
                current_turn["assistant_texts"].append(msg["text"])
            tools = _extract_tool_names(msg["content"])
            for t in tools:
                if t not in current_turn["tool_names"]:
                    current_turn["tool_names"].append(t)
            if msg["model"] and not current_turn["model_name"]:
                current_turn["model_name"] = msg["model"]
            current_turn["ended_at"] = msg["timestamp"] or current_turn["ended_at"]
            current_turn["raw_lines"].append(msg["raw_line"])

    # Finalize last turn
    if current_turn and current_turn.get("user_message"):
        _finalize_turn(current_turn, len(turns))
        turns.append(current_turn)

    return turns
