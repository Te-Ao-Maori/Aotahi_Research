-- Supabase pgvector search + policies helper
-- Run after migrations/001_realm_tables.sql

-- 1. Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Match function for research embeddings, filtered by realm_id
CREATE OR REPLACE FUNCTION match_research_embeddings(
  query_embedding vector(1536),
  match_count INT,
  filter_realm_id TEXT
)
RETURNS TABLE(
  chunk_id UUID,
  source_id TEXT,
  content TEXT,
  similarity FLOAT,
  metadata JSONB
) AS $$
DECLARE
  chunk_has_metadata BOOL;
  qry TEXT;
BEGIN
  SELECT EXISTS(
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'research_chunks'
      AND column_name = 'metadata'
  ) INTO chunk_has_metadata;

  IF chunk_has_metadata THEN
    qry := $f$
      SELECT
        re.chunk_id,
        rc.source_id,
        rc.content,
        (1 - (re.embedding <=> $1)) AS similarity,
        COALESCE(rc.metadata, re.metadata) AS metadata
      FROM research_embeddings AS re
      INNER JOIN research_chunks AS rc ON rc.id = re.chunk_id
      WHERE re.realm_id = $3
      ORDER BY re.embedding <=> $1
      LIMIT $2
    $f$;
  ELSE
    qry := $f$
      SELECT
        re.chunk_id,
        rc.source_id,
        rc.content,
        (1 - (re.embedding <=> $1)) AS similarity,
        re.metadata AS metadata
      FROM research_embeddings AS re
      INNER JOIN research_chunks AS rc ON rc.id = re.chunk_id
      WHERE re.realm_id = $3
      ORDER BY re.embedding <=> $1
      LIMIT $2
    $f$;
  END IF;

  RETURN QUERY EXECUTE qry USING query_embedding, match_count, filter_realm_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- 3. RLS policies (optional but recommended)
ALTER TABLE research_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE research_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE research_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE research_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE translation_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pronunciation_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY research_sessions_realm_policy ON research_sessions
  FOR ALL USING (realm_id = auth.jwt() ->> 'realm_id');
CREATE POLICY research_notes_realm_policy ON research_notes
  FOR ALL USING (realm_id = auth.jwt() ->> 'realm_id');
CREATE POLICY research_chunks_realm_policy ON research_chunks
  FOR ALL USING (realm_id = auth.jwt() ->> 'realm_id');
CREATE POLICY research_embeddings_realm_policy ON research_embeddings
  FOR ALL USING (realm_id = auth.jwt() ->> 'realm_id');
CREATE POLICY translations_realm_policy ON translations
  FOR ALL USING (realm_id = auth.jwt() ->> 'realm_id');
CREATE POLICY translation_logs_realm_policy ON translation_logs
  FOR ALL USING (realm_id = auth.jwt() ->> 'realm_id');
CREATE POLICY pronunciation_cache_realm_policy ON pronunciation_cache
  FOR ALL USING (realm_id = auth.jwt() ->> 'realm_id');
