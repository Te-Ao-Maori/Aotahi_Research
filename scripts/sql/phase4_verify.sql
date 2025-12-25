-- scripts/sql/phase4_verify.sql

-- 1) pgvector installed?
SELECT extname, extversion
FROM pg_extension
WHERE extname = 'vector';

-- 2) Try to install (requires privileges; safe if already installed)
CREATE EXTENSION IF NOT EXISTS vector;

-- 3) Confirm vector type exists
SELECT oid::regtype::text AS type_name
FROM pg_type
WHERE typname = 'vector';

-- 4) Tiny functional test (no tables needed)
SELECT '[1,2,3]'::vector AS sample_vector;

-- 5) Tables check (migrations validation)
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 6) Indexes check
SELECT
  t.relname AS table_name,
  i.relname AS index_name,
  pg_get_indexdef(ix.indexrelid) AS index_def
FROM pg_class t
JOIN pg_index ix ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
ORDER BY t.relname, i.relname;
