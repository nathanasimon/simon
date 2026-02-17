-- Simon Database Schema
-- Run: psql -d simon -f schema.sql

-- People you interact with
CREATE TABLE IF NOT EXISTS people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    relationship TEXT CHECK (relationship IN
        ('colleague', 'advisor', 'friend', 'family', 'vendor', 'acquaintance', 'unknown')),
    organization TEXT,
    first_contact TIMESTAMPTZ,
    last_contact TIMESTAMPTZ,
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Projects (auto-tiered)
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    tier TEXT CHECK (tier IN ('fleeting', 'simple', 'complex', 'life_thread')) DEFAULT 'simple',
    status TEXT CHECK (status IN ('active', 'paused', 'completed', 'abandoned')) DEFAULT 'active',
    description TEXT,
    first_mention TIMESTAMPTZ,
    last_activity TIMESTAMPTZ,
    mention_count INTEGER DEFAULT 0,
    source_diversity INTEGER DEFAULT 0,
    people_count INTEGER DEFAULT 0,
    user_pinned BOOLEAN DEFAULT FALSE,
    user_priority TEXT CHECK (user_priority IN ('critical', 'high', 'normal', 'low')),
    user_deadline DATE,
    user_deadline_note TEXT,
    auto_archive_after DATE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Sprints (time-bounded priority overrides)
CREATE TABLE IF NOT EXISTS sprints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    priority_boost FLOAT DEFAULT 2.0,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    auto_archive_project BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tasks / Kanban items
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT CHECK (status IN ('backlog', 'in_progress', 'waiting', 'done')) DEFAULT 'backlog',
    priority TEXT CHECK (priority IN ('urgent', 'high', 'normal', 'low')) DEFAULT 'normal',
    assigned_to UUID REFERENCES people(id) ON DELETE SET NULL,
    waiting_on UUID REFERENCES people(id) ON DELETE SET NULL,
    waiting_since TIMESTAMPTZ,
    due_date DATE,
    user_pinned BOOLEAN DEFAULT FALSE,
    user_priority TEXT CHECK (user_priority IN ('urgent', 'high', 'normal', 'low')),
    source_type TEXT,
    source_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Commitments (promises you or others made)
CREATE TABLE IF NOT EXISTS commitments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES people(id) ON DELETE SET NULL,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    direction TEXT CHECK (direction IN ('from_me', 'to_me')) NOT NULL,
    description TEXT NOT NULL,
    deadline DATE,
    status TEXT CHECK (status IN ('open', 'fulfilled', 'broken', 'cancelled')) DEFAULT 'open',
    source_type TEXT,
    source_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    fulfilled_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- CONTEXT SYSTEM TABLES
-- =====================================================

-- Agent sessions (one per Claude Code session)
CREATE TABLE IF NOT EXISTS agent_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id TEXT NOT NULL UNIQUE,
    transcript_path TEXT,
    workspace_path TEXT,
    provider TEXT DEFAULT 'claude',
    session_title TEXT,
    session_summary TEXT,
    started_at TIMESTAMPTZ,
    last_activity_at TIMESTAMPTZ,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    turn_count INTEGER DEFAULT 0,
    is_processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual conversation turns
CREATE TABLE IF NOT EXISTS agent_turns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES agent_sessions(id) ON DELETE CASCADE,
    turn_number INTEGER NOT NULL,
    user_message TEXT,
    assistant_summary TEXT,
    turn_title TEXT,
    content_hash TEXT NOT NULL,
    model_name TEXT,
    tool_names TEXT[],
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, turn_number)
);

-- Full raw turn content (separated for query performance)
CREATE TABLE IF NOT EXISTS agent_turn_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turn_id UUID NOT NULL REFERENCES agent_turns(id) ON DELETE CASCADE UNIQUE,
    raw_jsonl TEXT NOT NULL,
    assistant_text TEXT,
    content_size INTEGER,
    files_touched TEXT[],
    commands_run TEXT[],
    errors_encountered TEXT[],
    tool_call_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Entity links from conversation turns
CREATE TABLE IF NOT EXISTS agent_turn_entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turn_id UUID NOT NULL REFERENCES agent_turns(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    entity_name TEXT,
    confidence FLOAT DEFAULT 1.0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Turn artifacts (files, commands, errors extracted from tool calls)
CREATE TABLE IF NOT EXISTS agent_turn_artifacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turn_id UUID NOT NULL REFERENCES agent_turns(id) ON DELETE CASCADE,
    artifact_type TEXT NOT NULL,
    artifact_value TEXT NOT NULL,
    artifact_metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- SKILLS SYSTEM TABLES
-- =====================================================

-- Track auto-generated and installed skills
CREATE TABLE IF NOT EXISTS generated_skills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    source TEXT NOT NULL,  -- "auto", "manual", "registry"
    source_session_id TEXT,
    source_repo TEXT,
    installed_path TEXT NOT NULL,
    scope TEXT NOT NULL,  -- "personal" or "project"
    quality_score FLOAT,
    skill_content_hash TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Durable job queue with lease-based locking
CREATE TABLE IF NOT EXISTS focus_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind TEXT NOT NULL,
    dedupe_key TEXT UNIQUE,
    payload JSONB NOT NULL,
    status TEXT DEFAULT 'queued'
        CHECK (status IN ('queued', 'processing', 'retry', 'done', 'failed')),
    priority INTEGER DEFAULT 10,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 10,
    locked_until TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_people_email ON people(email);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_tier ON projects(tier);
CREATE INDEX IF NOT EXISTS idx_projects_pinned ON projects(user_pinned) WHERE user_pinned = TRUE;
CREATE INDEX IF NOT EXISTS idx_projects_deadline ON projects(user_deadline) WHERE user_deadline IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_pinned ON tasks(user_pinned) WHERE user_pinned = TRUE;
CREATE INDEX IF NOT EXISTS idx_tasks_due ON tasks(due_date) WHERE due_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_commitments_status ON commitments(status);
CREATE INDEX IF NOT EXISTS idx_commitments_direction ON commitments(direction);
CREATE INDEX IF NOT EXISTS idx_sprints_active ON sprints(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_sprints_dates ON sprints(starts_at, ends_at);

-- Context system indexes
CREATE INDEX IF NOT EXISTS idx_agent_sessions_workspace ON agent_sessions(workspace_path);
CREATE INDEX IF NOT EXISTS idx_agent_sessions_project ON agent_sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_agent_sessions_processed ON agent_sessions(is_processed) WHERE is_processed = FALSE;
CREATE INDEX IF NOT EXISTS idx_agent_sessions_activity ON agent_sessions(last_activity_at);
CREATE INDEX IF NOT EXISTS idx_agent_turns_session ON agent_turns(session_id);
CREATE INDEX IF NOT EXISTS idx_agent_turns_hash ON agent_turns(content_hash);
CREATE INDEX IF NOT EXISTS idx_agent_turns_started ON agent_turns(started_at);
CREATE INDEX IF NOT EXISTS idx_agent_turn_entities_turn ON agent_turn_entities(turn_id);
CREATE INDEX IF NOT EXISTS idx_agent_turn_entities_entity ON agent_turn_entities(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_agent_turn_artifacts_turn ON agent_turn_artifacts(turn_id);
CREATE INDEX IF NOT EXISTS idx_agent_turn_artifacts_type ON agent_turn_artifacts(artifact_type);

-- Skills indexes
CREATE INDEX IF NOT EXISTS idx_generated_skills_name ON generated_skills(name);
CREATE INDEX IF NOT EXISTS idx_generated_skills_source ON generated_skills(source);
CREATE INDEX IF NOT EXISTS idx_generated_skills_hash ON generated_skills(skill_content_hash);

-- Job queue indexes
CREATE INDEX IF NOT EXISTS idx_focus_jobs_claimable ON focus_jobs(priority, created_at) WHERE status IN ('queued', 'retry');
CREATE INDEX IF NOT EXISTS idx_focus_jobs_kind ON focus_jobs(kind);
CREATE INDEX IF NOT EXISTS idx_focus_jobs_locked ON focus_jobs(locked_until) WHERE status = 'processing';
CREATE INDEX IF NOT EXISTS idx_focus_jobs_dedupe ON focus_jobs(dedupe_key);
