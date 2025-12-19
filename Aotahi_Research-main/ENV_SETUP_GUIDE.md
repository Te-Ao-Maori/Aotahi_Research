# Environment Variables Guide: Realm-Scoped Setup

This document shows how to configure environment variables for local development and Render deployment with realm-scoped OpenAI Assistants and Vector Stores.

---

## Local Development (.env file)

Copy this into your backend `.env` file and replace `REPLACE_ME` values with your actual IDs.

```bash
# ============================================================================
# GENERAL
# ============================================================================
DEBUG=true
LOG_LEVEL=INFO

# ============================================================================
# REALM SELECTION
# ============================================================================
# Choose which realm to run: "researcher" or "translator"
REALM_ID=researcher
REALM_CONFIG_PATH=mauri/realms/${REALM_ID}/manifest.json

# ============================================================================
# OPENAI (Researcher Realm)
# ============================================================================
OPENAI_API_KEY=sk-proj-xxxxx_REPLACE_ME
OPENAI_ASSISTANT_ID_RESEARCHER=asst_researcher_xxxxx_REPLACE_ME
OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_researcher_xxxxx_REPLACE_ME

# ============================================================================
# OPENAI (Translator Realm)
# ============================================================================
OPENAI_ASSISTANT_ID_TRANSLATOR=asst_translator_yyyyy_REPLACE_ME
OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_translator_yyyyy_REPLACE_ME

# ============================================================================
# SUPABASE
# ============================================================================
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...REPLACE_ME
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...REPLACE_ME

# ============================================================================
# VECTOR SEARCH
# ============================================================================
# Which vector store to use for recall: "openai", "supabase", "both"
VECTOR_STORE_TYPE=openai
VECTOR_EMBEDDING_MODEL=text-embedding-3-small
VECTOR_EMBEDDING_DIMENSION=1536

# ============================================================================
# AUTHENTICATION
# ============================================================================
BEARER_KEY=test-token-for-local-dev-only
PIPELINE_TOKEN=fa0df8a6e5a1492f8f6b9d86e7c3a0f4a9a8c7d6e5f4c3b2a1d0e9f8c7b6a5d4

# ============================================================================
# BACKEND URLS
# ============================================================================
TE_PO_URL=http://localhost:5000
TE_PO_BASE_URL=http://localhost:8000

# ============================================================================
# PROXY
# ============================================================================
PROXY_PORT=8100
VITE_API_URL=http://localhost:8100

# ============================================================================
# FRONTEND
# ============================================================================
VITE_PIPELINE_TOKEN=fa0df8a6e5a1492f8f6b9d86e7c3a0f4a9a8c7d6e5f4c3b2a1d0e9f8c7b6a5d4
VITE_API_TIMEOUT_MS=60000

# ============================================================================
# OPTIONAL: External Services
# ============================================================================
# Google Translate API (for fallback translations)
GOOGLE_TRANSLATE_API_KEY=REPLACE_ME

# AWS S3 (for audio file storage)
AWS_ACCESS_KEY_ID=REPLACE_ME
AWS_SECRET_ACCESS_KEY=REPLACE_ME
AWS_S3_BUCKET=aotahi-research
AWS_REGION=us-west-2

# Sentry (error tracking)
SENTRY_DSN=https://xxxxx@xxxx.ingest.sentry.io/xxxxx
```

---

## Render Deployment

Add these environment variables to your Render service. Use Render's dashboard or API:

```bash
# ============================================================================
# GENERAL
# ============================================================================
DEBUG=false
LOG_LEVEL=WARN

# ============================================================================
# REALM SELECTION
# ============================================================================
# For researcher realm
REALM_ID=researcher
REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json

# For translator realm (alternative)
# REALM_ID=translator
# REALM_CONFIG_PATH=mauri/realms/translator/manifest.json

# ============================================================================
# OPENAI
# ============================================================================
OPENAI_API_KEY=sk-proj-xxxxx_REPLACE_ME

# Researcher realm
OPENAI_ASSISTANT_ID_RESEARCHER=asst_researcher_xxxxx_REPLACE_ME
OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_researcher_xxxxx_REPLACE_ME

# Translator realm
OPENAI_ASSISTANT_ID_TRANSLATOR=asst_translator_yyyyy_REPLACE_ME
OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_translator_yyyyy_REPLACE_ME

# ============================================================================
# SUPABASE (use production database)
# ============================================================================
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...REPLACE_ME
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...REPLACE_ME

# ============================================================================
# VECTOR SEARCH
# ============================================================================
VECTOR_STORE_TYPE=openai
VECTOR_EMBEDDING_MODEL=text-embedding-3-small
VECTOR_EMBEDDING_DIMENSION=1536

# ============================================================================
# AUTHENTICATION
# ============================================================================
# Use strong, random values for production
BEARER_KEY=<generate-strong-random-token>
PIPELINE_TOKEN=<generate-strong-random-token>

# ============================================================================
# BACKEND URLs (Render)
# ============================================================================
# The backend will be served at https://<your-render-service>.onrender.com
TE_PO_BASE_URL=https://<your-render-service>.onrender.com

# ============================================================================
# OPTIONAL: Production Services
# ============================================================================
GOOGLE_TRANSLATE_API_KEY=REPLACE_ME
AWS_ACCESS_KEY_ID=REPLACE_ME
AWS_SECRET_ACCESS_KEY=REPLACE_ME
AWS_S3_BUCKET=aotahi-research
AWS_REGION=us-west-2
SENTRY_DSN=https://xxxxx@xxxx.ingest.sentry.io/xxxxx
```

---

## How to Get the Required Values

### OpenAI Assistant & Vector Store IDs

1. Go to https://platform.openai.com/assistants
2. Create a new Assistant or use an existing one
3. Copy the **Assistant ID** (starts with `asst_`)
4. In the Assistant settings, create or select a **Vector Store** (File search)
5. Copy the **Vector Store ID** (starts with `vs_`)
6. Set in environment:
   ```bash
   OPENAI_ASSISTANT_ID_RESEARCHER=asst_xxxxx
   OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_xxxxx
   ```

### OpenAI API Key

1. Go to https://platform.openai.com/api/keys
2. Create a new API key
3. Copy the key and set:
   ```bash
   OPENAI_API_KEY=sk-proj-xxxxx
   ```

### Supabase Project URL & Keys

1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **Anon public key** → `SUPABASE_KEY`
   - **Service role secret key** → `SUPABASE_SERVICE_ROLE_KEY`

### AWS S3 (Optional, for audio storage)

1. Go to https://console.aws.amazon.com/iam/
2. Create a new IAM user with S3 access
3. Get the **Access Key ID** and **Secret Access Key**
4. Create an S3 bucket (e.g., `aotahi-research`)
5. Set in environment:
   ```bash
   AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
   AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   AWS_S3_BUCKET=aotahi-research
   AWS_REGION=us-west-2
   ```

---

## Switching Between Realms

To switch between researcher and translator realms, change these two variables:

```bash
# For researcher realm:
export REALM_ID=researcher
export REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json

# For translator realm:
export REALM_ID=translator
export REALM_CONFIG_PATH=mauri/realms/translator/manifest.json

# Then restart your backend:
python -m uvicorn main:app --reload
```

Or, if running via `start_dev.sh`, edit the script to set `REALM_ID` before launching.

---

## Render Deployment Script

If deploying via Render, use this shell command in the build settings:

```bash
# Build
pip install -r requirements.txt

# Run
python -m uvicorn main:app --host 0.0.0.0 --port $PORT
```

Make sure to add all environment variables (OPENAI_API_KEY, SUPABASE_URL, etc.) to the Render service environment before deploying.

---

## Validation Checklist

After setting up environment variables, verify:

```bash
# Check that environment is loaded
echo $REALM_ID
echo $OPENAI_API_KEY
echo $SUPABASE_URL

# Test backend connectivity
curl http://localhost:8000/health

# Test OpenAI connectivity
python -c "import openai; print(openai.OpenAI().models.list())"

# Test Supabase connectivity
curl -X GET "https://xxxx.supabase.co/rest/v1/research_sessions?select=id" \
  -H "Authorization: Bearer $SUPABASE_KEY"
```

---

## Security Best Practices

1. **Never commit `.env` to git.** Add it to `.gitignore`:
   ```
   .env
   .env.local
   .env.*.local
   ```

2. **Use `.env.example`** for documentation:
   ```bash
   # .env.example (checked into git)
   DEBUG=false
   LOG_LEVEL=WARN
   REALM_ID=researcher
   REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json
   OPENAI_API_KEY=sk-proj-REPLACE_ME
   OPENAI_ASSISTANT_ID_RESEARCHER=asst_REPLACE_ME
   OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_REPLACE_ME
   # ... etc
   ```

3. **Rotate API keys regularly** (every 3-6 months).

4. **Use Render secrets** instead of checking in plaintext:
   - In Render dashboard, go to **Environment** → **Add Secret**
   - Reference as `$VARIABLE_NAME` in environment variables

5. **Restrict Supabase key permissions:**
   - Use `SUPABASE_KEY` (anon key) for frontend
   - Use `SUPABASE_SERVICE_ROLE_KEY` (service role) only on backend
   - Create RLS policies to restrict row access by `realm_id`

---

## Multi-Realm Production Setup

If running multiple realms in production (e.g., separate Render services):

**Service 1: Researcher Realm**
```
REALM_ID=researcher
REALM_CONFIG_PATH=mauri/realms/researcher/manifest.json
OPENAI_ASSISTANT_ID_RESEARCHER=asst_xxxxx
OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_xxxxx
OPENAI_ASSISTANT_ID_TRANSLATOR=asst_yyyyy  (unused, but keep for completeness)
OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_yyyyy (unused, but keep for completeness)
```

**Service 2: Translator Realm**
```
REALM_ID=translator
REALM_CONFIG_PATH=mauri/realms/translator/manifest.json
OPENAI_ASSISTANT_ID_RESEARCHER=asst_xxxxx  (unused, but keep for completeness)
OPENAI_VECTOR_STORE_ID_RESEARCHER=vs_xxxxx (unused, but keep for completeness)
OPENAI_ASSISTANT_ID_TRANSLATOR=asst_yyyyy
OPENAI_VECTOR_STORE_ID_TRANSLATOR=vs_yyyyy
```

Both services share the same Supabase project, but query data filtered by `realm_id`.

---

## Troubleshooting

### "Realm not found" error
Check that `REALM_CONFIG_PATH` points to a valid file:
```bash
ls -la mauri/realms/researcher/manifest.json
```

### "Invalid OpenAI API key"
Verify the key format (should start with `sk-proj-`):
```bash
echo $OPENAI_API_KEY | head -c 20
```

### "Supabase connection refused"
Check that `SUPABASE_URL` is correct:
```bash
curl -I https://xxxx.supabase.co
```

### "Vector store not found"
Make sure `OPENAI_VECTOR_STORE_ID_RESEARCHER` is set correctly in OpenAI dashboard.
