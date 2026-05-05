---
name: hermes-agent-web
description: "Deploy and configure Hermes Agent web interfaces — official Dashboard, OpenAI-compatible API server, and third-party nesquena/hermes-webui. Covers setup, auth fixes, session merging across platforms, and Chinese localization."
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [hermes, web-ui, dashboard, api-server, deployment, localization, session-merging]
    added_by: Hermes Agent (AAOOAAOOAA 委托)
    date_added: 2026-05-04
---

# Hermes Agent Web Interfaces

Hermes Agent offers **two** web-interface options and a third-party alternative. Choose based on your needs.

---

## 1. Dashboard (`hermes dashboard`)

Full web management panel (FastAPI backend + React/Vite frontend).

| Field | Value |
|---|---|
| **Command** | `hermes dashboard [--port PORT] [--host HOST] [--tui] [--no-open]` |
| **Default URL** | `http://127.0.0.1:9119` |
| **Backend** | FastAPI + Uvicorn (`hermes_cli/web_server.py`) |
| **Frontend** | React 19 + Vite + Tailwind CSS v4 (`web/` dir) |
| **Features** | Config editor, API key management, session monitoring, embedded TUI chat (`--tui`) |

### Dependencies

```bash
pip install 'fastapi' 'uvicorn[standard]'
# For frontend build:
node.js + npm required
```

### Setup Steps

1. **Build frontend assets** (if `web_dist/` is empty or missing):
   ```bash
   cd ~/.hermes/hermes-agent/web/
   npm install
   npm run build
   ```
   Output lands in `hermes_cli/web_dist/`, served statically by FastAPI.

2. **Start the dashboard**:
   ```bash
   hermes dashboard
   ```
   Add `--tui` to enable the in-browser Chat tab (requires gateway running).

3. **Access** at `http://127.0.0.1:9119`

### Additional Options

| Flag | Effect |
|---|---|
| `--port PORT` | Change listen port (default 9119) |
| `--host HOST` | Change bind address (default 127.0.0.1) |
| `--insecure` | Allow binding to non-localhost (⚠ exposes secrets on network) |
| `--tui` | Enable embedded TUI chat tab via PTY/WebSocket |
| `--stop` | Kill all running dashboard processes |
| `--status` | List running dashboard processes |

### Development Mode

```bash
# Terminal 1: Start FastAPI backend
python -m hermes_cli.main web --no-open

# Terminal 2: Start Vite dev server with HMR + API proxy
cd web/
npm run dev
```

Vite dev server proxies `/api` → `http://127.0.0.1:9119`.

---

## 2. OpenAI-Compatible API Server (api_server)

Exposes an OpenAI-format HTTP API — any OpenAI-compatible frontend (Open WebUI, LobeChat, LibreChat, AnythingLLM, NextChat, ChatBox) can connect.

| Field | Value |
|---|---|
| **Default port** | `8642` |
| **Framework** | aiohost (`gateway/platforms/api_server.py`) |
| **Endpoints** | `/v1/chat/completions`, `/v1/responses`, `/v1/models`, `/health`, etc. |
| **Stateless** | Chat Completions is stateless; use `X-Hermes-Session-Id` header for continuity |
| **Stateful** | Responses API uses `previous_response_id` |

### Setup

Configure in gateway config (e.g. `~/.hermes/config.yaml` or via `hermes gateway setup`):

```yaml
platforms:
  api_server:
    enabled: true
    host: "127.0.0.1"
    port: 8642
```

Then start the gateway:
```bash
hermes gateway run
```

### Frontend Connection

Point your OpenAI-compatible frontend at `http://localhost:8642/v1` as the base URL. No API key needed for local access (key auth can be added via config).

---

## 3. Third-Party Web UI (`nesquena/hermes-webui`)

A community web UI for Hermes Agent, repository at `github.com/nesquena/hermes-webui`. Uses Python stdlib + pyyaml only — no FastAPI/uvicorn needed.

| Field | Value |
|---|---|
| **Default port** | `8787` |
| **Entry point** | `bootstrap.py` (auto-creates venv, starts `server.py`) |
| **Launcher** | `bash start.sh` |
| **Dependencies** | `pyyaml>=6.0` only (installed by bootstrap) |
| **Frontend** | Vanilla JS/HTML (no React/Vite build step) |
| **State dir** | `~/.hermes/webui/` |

### Setup Steps

```bash
# 1. Clone or upload the repo
git clone -b v0.50.34 https://github.com/nesquena/hermes-webui.git
# Chinese mirror fallback:
git clone -b v0.50.34 https://ghproxy.net/https://github.com/nesquena/hermes-webui.git

# 2. Configure environment
echo 'HERMES_WEBUI_PASSWORD=your_strong_password' > .env
echo 'HERMES_WEBUI_HOST=0.0.0.0' >> .env

# 3. Allow firewall
sudo ufw allow 8787/tcp

# 4. Start (use background=true, not nohup)
# In Hermes: terminal(background=true, command='cd ~/hermes-webui && bash start.sh')

# 5. Verify
tail -f ~/.hermes/webui/bootstrap-8787.log
ss -tlnp | grep 8787
```

### Chinese Network Workarounds

- **GitHub clone timeout**: Use `https://ghproxy.net/https://github.com/...` mirror prefix
- **Zip upload**: On QQ/WeChat platforms, user can upload the repo as zip; it lands in `~/.hermes/cache/documents/` with random filenames

### Background Process Technique

When launching long-running servers in Hermes Agent, **do NOT use `nohup` or shell background wrappers**. Instead:

```python
terminal(background=true, command='...', timeout=120)
```

Then use the `process` tool to check status/output:
```python
process(action='poll', session_id='<returned_session_id>')
```

### Environment Variables

| Variable | Default | Description |
|---|---|---|
| `HERMES_WEBUI_PASSWORD` | (required) | Login password |
| `HERMES_WEBUI_HOST` | `127.0.0.1` | Bind address |
| `HERMES_WEBUI_PORT` | `8787` | Listen port |
| `HERMES_WEBUI_PYTHON` | auto-detect | Path to Python interpreter |
| `HERMES_WEBUI_SKIP_ONBOARDING` | (unset) | Set to `1` to skip first-run wizard |

---

## 4. Dealing with Auth Errors After Starting the Web UI

When the web UI reports `"Provider 'X' is configured but not yet authenticated"`, the provider IS typically configured in `config.yaml` but not recognized by the credential system.

### Fix

```bash
# 1. Register the API key in the auth credential pool
hermes auth add <provider> --type api-key --api-key <your-api-key>

# 2. Add the env var so credential-pool discovery finds it
echo '<PROVIDER>_API_KEY=<your-api-key>' >> ~/.hermes/.env

# 3. Restart the web UI for changes to take effect
```

### Why This Happens

- `config.yaml` stores the key under `providers.<provider>.api_key` — the agent core uses this directly
- `auth.json` uses a separate `credential_pool` structure — the web UI dashboard checks this, not `config.yaml`
- The `.env` file bridges the gap: the credential-pool loader auto-discovers env vars at startup

---

## 5. Session Merging — Show Gateway Platform Conversations in the Web UI

The third-party web UI can display conversations from ALL Hermes Gateway platforms (QQ Bot, Telegram, Discord, etc.) alongside web UI sessions. This is a **read-only bridge**.

### Architecture

The web UI (`api/models.py`) reads sessions from two sources:

1. **WebUI Sessions** — local JSON files in `~/.hermes/webui/`
2. **CLI/Agent Sessions** — read from `~/.hermes/state.db` SQLite via `get_cli_sessions()`

The `get_cli_sessions()` query includes ALL non-webui sessions (`WHERE s.source != 'webui'`), so QQ Bot, Telegram, Discord, etc. sessions are automatically visible.

### Enable Gateway Session Visibility

**Setting**: `show_cli_sessions` in `~/.hermes/webui/settings.json`

```bash
python3 -c "
import json
with open('/home/ubuntu/.hermes/webui/settings.json') as f:
    d = json.load(f)
d['show_cli_sessions'] = True
with open('/home/ubuntu/.hermes/webui/settings.json', 'w') as f:
    json.dump(d, f, indent=2)
"
```

Or via UI: Settings → Preferences → "Show agent sessions".

### Verification

```bash
sqlite3 ~/.hermes/state.db "SELECT id, title, source, message_count FROM sessions ORDER BY started_at DESC;"
```

---

## 6. Chinese Localization

The web UI has a built-in i18n system (`static/i18n.js`) supporting English, Spanish, German, Simplified Chinese, and Traditional Chinese. Missing keys fall back to English automatically.

### Adding/Updating Chinese Translations

1. Edit `static/i18n.js` — find the `zh` locale object
2. Add missing keys (copy key names from the `en` locale)
3. Use **natural Chinese**, not machine translation
4. Refresh the web UI page (no server restart needed for static file changes)
5. Select "简体中文" from Settings → Preferences → Language

---

## Pitfalls

- **Frontend not built**: `hermes dashboard` starts the server but serves nothing if `web_dist/` is empty. Verify with `ls web_dist/`.
- **Missing fastapi/uvicorn**: ImportError at startup — install with `pip install 'fastapi' 'uvicorn[standard]'`.
- **Port conflicts**: Check if port 9119 or 8642 is already in use before starting.
- **Security**: Both interfaces default to 127.0.0.1 only. Use `--insecure` / `0.0.0.0` only with explicit user consent.
- **Session token**: Dashboard generates a random session token on each start. If the frontend shows 401s, restart the dashboard.
- **QQ attachment cache**: Downloads from QQ go to `~/.hermes/cache/documents/` with unpredictable filenames. Use `find ~/.hermes/cache/ -mmin -60 -type f` to locate recently-downloaded files.
- **Background process**: Use `terminal(background=true)` not `nohup` or `&`. Shell-level background wrappers are blocked.

## Verification

```bash
# Check if dashboard is running
hermes dashboard --status

# Test API server health
curl http://127.0.0.1:8642/health

# Test third-party web UI
curl http://127.0.0.1:8787/health

# Test dashboard
curl http://127.0.0.1:9119/

# Port check for all web interfaces
ss -tlnp | grep -E '8787|8642|9119'
```
