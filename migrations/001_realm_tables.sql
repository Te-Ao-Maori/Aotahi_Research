-- Supabase Migration: Realm-Scoped Tables for Researcher & Translator
-- Created: 2025-12-16
-- Purpose: Prevent cross-contamination between realms, add realm isolation at DB level

-- ============================================================================
-- RESEARCHER REALM TABLES
-- ============================================================================

-- research_sessions: Thread/session metadata for researcher assistant
CREATE TABLE research_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  thread_id TEXT NOT NULL UNIQUE,
  assistant_id TEXT NOT NULL,
  vector_store_id TEXT NOT NULL,
  title TEXT,
  status TEXT DEFAULT 'active', -- active, archived, draft
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_research_sessions_realm_user ON research_sessions(realm_id, user_id);
CREATE INDEX idx_research_sessions_thread_id ON research_sessions(thread_id);
CREATE INDEX idx_research_sessions_assistant_id ON research_sessions(assistant_id);

-- research_notes: Summaries, citations, links from research
CREATE TABLE research_notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES research_sessions(id) ON DELETE CASCADE,
  realm_id TEXT NOT NULL,
  note_type TEXT, -- 'summary', 'citation', 'link', 'insight'
  content TEXT NOT NULL,
  source_url TEXT,
  confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_research_notes_session_id ON research_notes(session_id);
CREATE INDEX idx_research_notes_realm_id ON research_notes(realm_id);
CREATE INDEX idx_research_notes_note_type ON research_notes(note_type);

-- research_chunks: Chunked documents/text for embedding (optional)
CREATE TABLE research_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  source_id TEXT, -- document UUID or URL
  chunk_index INT,
  content TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_research_chunks_realm_source ON research_chunks(realm_id, source_id);

-- research_embeddings: Embeddings for chunks (Supabase pgvector)
-- Enable pgvector extension first: CREATE EXTENSION vector;
CREATE TABLE research_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chunk_id UUID REFERENCES research_chunks(id) ON DELETE CASCADE,
  realm_id TEXT NOT NULL,
  embedding VECTOR(1536), -- OpenAI embedding dimension
  model TEXT, -- 'text-embedding-3-small', 'text-embedding-3-large', etc.
  created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_research_embeddings_chunk_id ON research_embeddings(chunk_id);
CREATE INDEX idx_research_embeddings_realm_id ON research_embeddings(realm_id);
-- Vector index for similarity search (optional, for performance)
CREATE INDEX idx_research_embeddings_vector ON research_embeddings USING ivfflat (embedding vector_cosine_ops);

-- ============================================================================
-- TRANSLATOR REALM TABLES
-- ============================================================================

-- translations: Translation records with metadata
CREATE TABLE translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  source_text TEXT NOT NULL,
  target_text TEXT NOT NULL,
  source_lang TEXT, -- 'en', 'mi'
  target_lang TEXT, -- 'en', 'mi'
  dialect TEXT, -- 'northland', 'waikato', etc. (optional)
  model TEXT, -- 'gpt-4', 'gpt-3.5-turbo', 'custom'
  confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_translations_realm_user ON translations(realm_id, user_id);
CREATE INDEX idx_translations_source_text ON translations(source_text);
CREATE INDEX idx_translations_dialect ON translations(dialect);

-- translation_logs: Request/response metadata + performance
CREATE TABLE translation_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  translation_id UUID REFERENCES translations(id) ON DELETE SET NULL,
  request_tokens INT,
  response_tokens INT,
  latency_ms INT,
  status TEXT, -- 'success', 'error', 'timeout'
  error_message TEXT,
  created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_translation_logs_realm ON translation_logs(realm_id);
CREATE INDEX idx_translation_logs_translation_id ON translation_logs(translation_id);
CREATE INDEX idx_translation_logs_status ON translation_logs(status);

-- pronunciation_cache: Phonetic hints and audio
CREATE TABLE pronunciation_cache (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  text TEXT NOT NULL,
  ipa_phonetic TEXT,
  audio_url TEXT, -- S3, CDN URL
  confidence FLOAT CHECK (confidence >= 0 AND confidence <= 1),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_pronunciation_cache_realm_text ON pronunciation_cache(realm_id, text);
CREATE UNIQUE INDEX idx_pronunciation_cache_realm_text_unique ON pronunciation_cache(realm_id, text);

-- ============================================================================
-- ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
-- Uncomment below if you use RLS in Supabase (optional but recommended)

-- ALTER TABLE research_sessions ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE research_notes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE research_chunks ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE research_embeddings ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE translations ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE translation_logs ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE pronunciation_cache ENABLE ROW LEVEL SECURITY;

-- Example RLS policy for research_sessions (realm isolation):
-- CREATE POLICY "Users can only see their realm's sessions" ON research_sessions
--   FOR SELECT
--   USING (
--     -- Admin can see all, users see own realm
--     auth.jwt() ->> 'role' = 'admin' OR
--     (realm_id = auth.jwt() ->> 'realm_id' AND user_id = auth.uid())
--   );

-- ============================================================================
-- GRANTS (for service role, if using Supabase auth)
-- ============================================================================
-- Grant appropriate permissions to anon/authenticated roles

-- GRANT ALL ON research_sessions, research_notes, research_chunks, research_embeddings TO authenticated;
-- GRANT ALL ON translations, translation_logs, pronunciation_cache TO authenticated;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. All tables include realm_id for multi-tenant isolation
-- 2. Timestamps (created_at, updated_at) are auto-managed
-- 3. Indexes are created for common queries (realm_id, user_id, realm_id+user_id, etc.)
-- 4. pgvector extension must be enabled for research_embeddings
-- 5. RLS policies are commented out—enable them if your auth setup requires it
-- 6. Foreign keys use ON DELETE CASCADE to clean up orphaned records
