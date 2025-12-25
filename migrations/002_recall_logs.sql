-- Supabase migration: recall logging table scoped by realm
CREATE TABLE IF NOT EXISTS recall_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  realm_id TEXT NOT NULL,
  query TEXT NOT NULL,
  matches INT,
  vector_store TEXT,
  response JSONB,
  created_at TIMESTAMP DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recall_logs_realm_id ON recall_logs(realm_id);
