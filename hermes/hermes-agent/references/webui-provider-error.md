# WebUI Provider Error: `Provider 'X' is set in config.yaml but no API key was found`

## Symptom

WebUI at `http://host:8787` starts fine and shows the login page, but after login any chat attempt fails immediately with:

```
RuntimeError: Provider 'minimax-cn-custom' is set in config.yaml but no API key was found.
Set the MINIMAX-CN-CUSTOM_API_KEY environment variable, or switch to a different provider
with `hermes model`.
```

The suggested fix (setting `MINIMAX-CN-CUSTOM_API_KEY`) **does not work** — bash does not allow hyphens in variable names, so `export MINIMAX-CN-CUSTOM_API_KEY=...` is a syntax error.

## Root Cause

The error comes from `run_agent.py` which looks up the provider in `PROVIDER_REGISTRY` (defined in `hermes_cli/auth.py`). If the provider string from the session does not exist in `PROVIDER_REGISTRY`, it falls back to constructing a synthetic env var name like `MINIMAX-CN-CUSTOM_API_KEY`.

Common scenario:
- `config.yaml` correctly has `provider: minimax-cn`
- But the WebUI session file (`~/.hermes/webui/sessions/<id>.json`) has `model_provider: "minimax-cn-custom"` from a prior misconfiguration
- `minimax-cn-custom` is NOT in `PROVIDER_REGISTRY` (only `minimax-cn` is)
- The error message is misleading

## Fix (2-step)

### Step 1: Clear stale WebUI sessions

```bash
# Delete the corrupted session file
rm -f ~/.hermes/webui/sessions/<session_id>.json

# Also clear the sessions index if it still references the bad provider
echo '[]' > ~/.hermes/webui/sessions/_index.json
```

### Step 2: Restart WebUI with the correct env var

```bash
export MINIMAX_CN_API_KEY="sk-cp-YOUR_KEY_HERE"

cd /root/hermes-webui && \
HERMES_WEBUI_AGENT_DIR=/usr/local/lib/hermes-agent \
HERMES_WEBUI_HOST=0.0.0.0 \
HERMES_WEBUI_PORT=8787 \
HERMES_WEBUI_PASSWORD=hermes123 \
HERMES_WEBUI_STATE_DIR=/root/.hermes/webui \
/usr/local/lib/hermes-agent/venv/bin/python server.py
```

> Note: The key env var is `MINIMAX_CN_API_KEY` (underscores), NOT `MINIMAX-CN-CUSTOM_API_KEY` (hyphens).

## WebUI Auth Flow (for testing with curl)

WebUI uses cookie-based sessions, NOT Bearer tokens in headers.

```bash
# 1. Login (JSON body)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"password":"hermes123"}' \
  http://127.0.0.1:8787/api/auth/login \
  -c /tmp/cookies.txt -b /tmp/cookies.txt
# Returns: {"ok": true}

# 2. Use cookie jar for subsequent requests
curl -s http://127.0.0.1:8787/api/health -b /tmp/cookies.txt
```

## Finding the Real Provider

```bash
# Check what provider the session is actually using
grep "model_provider" ~/.hermes/webui/sessions/*.json

# Check config.yaml's actual provider
grep "^  provider:" ~/.hermes/config.yaml

# List providers known to PROVIDER_REGISTRY
grep "api_key_env_vars" /usr/local/lib/hermes-agent/hermes_cli/auth.py
```

### Persistent Session Corruption (auth.json is the real culprit)

**Known issue (2026-05-04):** Clearing sessions (`rm` + `_index.json = []`) does NOT permanently fix a corrupted `minimax-cn-custom` provider. The session file gets recreated with the wrong provider on every WebUI restart because `auth.json` still contains `minimax-cn-custom` in both `providers` and `credential_pool` sections.

**Session reconstruction chain:** `auth.json` → `providers.minimax-cn-custom` exists → `credential_pool.minimax-cn-custom` exists → WebUI seeds new sessions with this provider → error recurs.

**Complete fix — must clean auth.json AND sessions:**

```bash
# 1. Kill WebUI
kill <webui_pid>

# 2. Remove minimax-cn-custom from auth.json (both providers AND credential_pool sections)
python3 -c "
import json
with open('/root/.hermes/auth.json') as f:
    d = json.load(f)
d.get('providers', {}).pop('minimax-cn-custom', None)
d.get('credential_pool', {}).pop('minimax-cn-custom', None)
with open('/root/.hermes/auth.json', 'w') as f:
    json.dump(d, f, indent=2)
"

# 3. Clear all WebUI state
rm -f ~/.hermes/webui/sessions/*.json
echo '[]' > ~/.hermes/webui/sessions/_index.json
rm -f ~/.hermes/webui/models_cache.json

# 4. Restart WebUI with MINIMAX_CN_API_KEY (underscores, NOT hyphens)
cd /root/hermes-webui && \
export MINIMAX_CN_API_KEY="sk-cp-YOUR_KEY" && \
HERMES_WEBUI_AGENT_DIR=/usr/local/lib/hermes-agent \
HERMES_WEBUI_HOST=0.0.0.0 \
HERMES_WEBUI_PORT=8787 \
HERMES_WEBUI_PASSWORD=hermes123 \
HERMES_WEBUI_STATE_DIR=/root/.hermes/webui \
/usr/local/lib/hermes-agent/venv/bin/python server.py
```

**Why `rm` on sessions alone doesn't work:** WebUI reconstructs a session from `auth.json`'s credential pool on startup if `models_cache.json` is also stale. You must clean `auth.json` (removing the bad provider entry), `models_cache.json`, and the sessions directory together, then restart.

## Other Common Provider Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Provider 'X' not found in PROVIDER_REGISTRY` | Typo or stale session | Clear sessions, restart |
| `No API key found` after correct env var | WebUI process didn't inherit the env var | Restart WebUI in the same shell where env is set |
| `Authentication required` on all API calls | Not logged in or cookie expired | Re-login via `POST /api/auth/login` |
| `Invalid password` | Wrong password or password hash mismatch | Check `HERMES_WEBUI_PASSWORD` env var matches what you send |
