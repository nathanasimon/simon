# Simon

Memory for Claude Code. Simon records your sessions and injects relevant context into every new conversation automatically.

## What it does

- **Injects context on every prompt** — past conversations, active tasks, commitments, skills, and errors, retrieved in <2s with no LLM in the hot path
- **Records sessions** — parses JSONL transcripts into structured turns, extracts files touched, commands run, errors hit
- **Generates skills** — auto-generates reusable SKILL.md files from high-quality sessions; manual generation also available
- **Background worker** — async job queue handles summarization, entity extraction, and skill generation without blocking you

## Installation

```bash
npm install -g simon-memory
# or
bun install -g simon-memory
```

Needs Python 3.11+ and PostgreSQL.

```bash
createdb simon
psql simon < schema.sql
```

## Quick start

```bash
simon hooks install
simon worker start --daemon
```

That's it.

## CLI

```
simon hooks install/uninstall/status

simon retrieve --hook             # called by Claude Code hook
simon retrieve --query "..."      # test retrieval manually

simon record --hook               # called by Claude Code hook
simon record --all                # scan and record all sessions

simon context query "prompt"      # preview context injection
simon context show                # current state
simon context stats               # recording stats

simon skill create "description"
simon skill list / show / search / install / uninstall / auto-scan

simon worker start [--daemon] / stop / status
```

## Configuration

Defaults work for local dev. To override:

```toml
# ~/.config/simon/config.toml
[general]
db_url = "postgresql+asyncpg://localhost/simon"

[context]
max_context_tokens = 1500

[skills]
auto_generate = true
min_quality_score = 0.6
```

## Data

PostgreSQL tables: `agent_sessions`, `agent_turns`, `agent_turn_content`, `agent_turn_entities`, `agent_turn_artifacts`, `generated_skills`, `focus_jobs`, `projects`, `people`, `tasks`, `commitments`, `sprints`.

## License

MIT
