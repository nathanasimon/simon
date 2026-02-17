# Simon

**Memory for Claude Code.**

Simon watches your Claude Code sessions, learns what you're working on, and automatically feeds relevant context into every new conversation. It also generates reusable skills from your best sessions.

## The Problem

Every time you start a new Claude Code session, you start from scratch. Claude doesn't know what you were working on yesterday, what decisions you made, what errors you hit, or what patterns worked. You end up repeating yourself constantly.

## The Solution

Simon hooks into Claude Code and does two things:

1. **Records** every session — what you discussed, what files you touched, what commands you ran, what errors you encountered
2. **Retrieves** relevant context on every new prompt — past conversations, active tasks, commitments, skills — and injects it automatically

The result: Claude Code remembers your project, your patterns, and your priorities across every session.

## How It Works

```
You type a prompt in Claude Code
         |
         v
Simon intercepts it (UserPromptSubmit hook)
         |
    +---------+
    | Classify |  <500ms keyword matching — no LLM
    +---------+
         |
    +----------+
    | Retrieve  |  SQL queries for relevant context
    +----------+
         |
    +--------+
    | Format  |  Token-budget-aware formatting
    +--------+
         |
         v
Context injected into Claude Code:

  ## Focus Context

  [Conv] Fixed the pipeline bug (2h ago)
  [Task] Review PR #123 (in_progress, priority: high)
  [Skill] deploy-app: Deploy to production | 1. Build...
  [Commitment] from Alice: finalize Q1 plan by 2026-02-28
```

When a session ends, Simon records it and a background worker:
- Summarizes each conversation turn
- Extracts entities (projects, people)
- Extracts artifacts (files, commands, errors)
- Auto-generates a reusable SKILL.md if the session was high-quality

## Features

### Context Injection (< 2 seconds, no LLM)
- Keyword/regex classification against known projects, people, and file paths
- Parallel SQL retrieval of conversations, tasks, commitments, skills, and errors
- Token-budget-aware formatting — packs the most relevant context into ~1500 tokens
- Never blocks Claude Code — hooks wrapped in `bash -c '... || true'`

### Session Recording
- Parses Claude Code JSONL transcripts into structured turns
- Content-hash deduplication — re-recording is always safe
- Extracts files touched, commands run, errors encountered from tool calls
- Links sessions to projects by workspace path

### Skill System
- **Auto-generate**: Quality-gates completed sessions, then Haiku generates SKILL.md files
- **Manual create**: `simon skill create "description"` generates on demand
- **Public registry**: `simon skill search "query"` searches GitHub repos
- **Context injection**: Installed skills are automatically surfaced when Simon detects relevance
- Skills follow the [Claude Code Agent Skills](https://docs.anthropic.com/en/docs/claude-code/skills) standard

### Background Worker
- Durable job queue with lease-based locking (PostgreSQL)
- Priority-ordered processing: session parse, turn summaries, entity extraction, artifacts, skill generation
- Graceful degradation — LLM summarization falls back to truncation

## Architecture

```
simon/
├── context/          # Core memory system
│   ├── classifier.py     # <500ms keyword/regex prompt classification
│   ├── retriever.py      # SQL-based context retrieval + skill matching
│   ├── formatter.py      # Token-budget-aware formatting
│   ├── recorder.py       # Session recording + deduplication
│   ├── artifact_extractor.py  # JSONL parsing for files/commands/errors
│   ├── project_state.py  # Per-workspace project selection
│   └── worker.py         # Background job processor
├── skills/           # Skill generation & management
│   ├── generator.py      # Haiku-powered SKILL.md generation
│   ├── analyzer.py       # Session quality scoring
│   ├── installer.py      # Disk I/O for SKILL.md files
│   └── registry.py       # Public skill search via GitHub
├── storage/          # Data layer
│   ├── models.py         # SQLAlchemy ORM models
│   ├── db.py             # Async PostgreSQL sessions
│   └── jobs.py           # Durable job queue with lease locking
├── ingestion/        # Session parsing
│   └── claude_code.py    # JSONL transcript parser
└── cli/              # Typer CLI
    ├── main.py           # Entry point (simon command)
    ├── hooks_cmd.py      # simon hooks install/uninstall/status
    ├── retrieve_cmd.py   # simon retrieve --hook / --query
    ├── record_cmd.py     # simon record --hook / --all
    ├── context_cmd.py    # simon context query/show/stats
    ├── skill_cmd.py      # simon skill create/list/search/install
    └── worker_cmd.py     # simon worker start/stop/status
```

## Installation

### With npm or bun (recommended)

```bash
npm install -g simon-memory
# or
bun install -g simon-memory
```

Simon auto-creates a Python virtualenv on first run. Just needs Python 3.11+ on your system.

### With pacman (Arch Linux)

```bash
git clone https://github.com/nathanasimon/simon
cd simon
makepkg -si
```

### With pip

```bash
pip install git+https://github.com/nathanasimon/simon
```

### From source

```bash
git clone https://github.com/nathanasimon/simon
cd simon
pip install -e ".[dev]"
```

### Database Setup

Simon needs PostgreSQL:

```bash
createdb simon
psql simon < schema.sql
```

### Configuration (optional — defaults work for local dev)

```bash
mkdir -p ~/.config/simon
cat > ~/.config/simon/config.toml << 'EOF'
[general]
db_url = "postgresql+asyncpg://localhost/simon"

[anthropic]
# Uses ANTHROPIC_API_KEY env var by default

[context]
max_context_tokens = 1500

[skills]
auto_generate = true
min_quality_score = 0.6
EOF
```

## Quick Start

```bash
# Install hooks into Claude Code
simon hooks install

# Start the background worker
simon worker start --daemon

# That's it. Simon is now recording and injecting context.
```

## How Recording Works

When you end a Claude Code session, the Stop hook fires:
1. Reads the JSONL transcript
2. Parses into structured turns (user message + assistant response)
3. Deduplicates by content hash (re-recording is safe)
4. Enqueues background processing jobs

The worker picks up jobs in priority order:
1. **session_process** — Parse and store the transcript
2. **turn_summary** — Generate title + summary per turn (Haiku or truncation fallback)
3. **entity_extract** — Match projects/people via keyword regex
4. **artifact_extract** — Parse JSONL for files read/written, commands run, errors
5. **session_summary** — Aggregate turn summaries
6. **skill_extract** — Quality-gate, then auto-generate SKILL.md if score >= 0.6

## How Retrieval Works

On every prompt, in <2 seconds:
1. **Classify** — Keyword/regex matching against known projects, people, file paths
2. **Retrieve** — Parallel SQL queries for conversations, tasks, commitments, skills, errors
3. **Format** — Greedy token-budget packing, sorted by relevance score

## CLI Reference

```
simon hooks install [--force]     # Install Claude Code hooks
simon hooks uninstall             # Remove hooks
simon hooks status                # Show hook status

simon retrieve --hook             # Hook mode (stdin/stdout JSON)
simon retrieve --query "..."      # Test retrieval manually

simon record --hook               # Hook mode (enqueue recording)
simon record --all                # Scan and record all sessions

simon context query "prompt"      # Preview context injection
simon context show                # Show current state
simon context stats               # Show recording statistics

simon skill create "description"  # Generate a new skill
simon skill list [--scope]        # List installed skills
simon skill show <name>           # Show skill content
simon skill search "query"        # Search public registries
simon skill install <repo/path>   # Install from GitHub
simon skill uninstall <name>      # Remove a skill
simon skill auto-scan             # Auto-generate from recent sessions

simon worker start [--daemon]     # Start background worker
simon worker stop                 # Stop worker
simon worker status               # Show worker + job stats
```

## Data Model

Everything lives in PostgreSQL:

| Table | Purpose |
|-------|---------|
| `agent_sessions` | One row per Claude Code session |
| `agent_turns` | One row per user/assistant exchange |
| `agent_turn_content` | Raw JSONL + extracted text per turn |
| `agent_turn_entities` | Project/person mentions per turn |
| `agent_turn_artifacts` | Files, commands, errors per turn |
| `generated_skills` | Auto-generated skill tracking |
| `focus_jobs` | Durable job queue with lease locking |
| `projects` | Known projects (for context matching) |
| `people` | Known people (for context matching) |
| `tasks` | Tasks (surfaced as context) |
| `commitments` | Commitments (surfaced as context) |
| `sprints` | Time-bounded priority boosts |

## Design Principles

- **Sub-2-second retrieval** — No LLM in the hot path. Classification is pure regex/keyword matching.
- **Never block Claude Code** — Hooks are wrapped in `bash -c '... || true'` so failures are silent.
- **Incremental recording** — Content-hash dedup means re-recording the same session is always safe.
- **Graceful degradation** — LLM summarization falls back to truncation. Missing DB returns empty context.
- **Token budgeting** — Conservative char/4 estimation, greedy packing by relevance score.

## Relationship to Focus

Simon is extracted from [Focus](https://github.com/nathanasimon/focus), a full-stack PKM system that also handles email ingestion, vault generation, and more. Simon is the standalone memory layer — it works with any project, not just Focus.

## License

MIT
