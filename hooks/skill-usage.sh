#!/usr/bin/env bash
#
# skill-usage.sh — Claude Code PostToolUse hook (matcher: Skill).
#
# Fires one anonymous PostHog event per skill invocation so skill adoption is
# measurable. Metadata only — the skill name, plugin ref, and os/arch. It never
# reads the prompt, the transcript, the cwd, or any flow content.
#
# Best-effort by design: any missing dependency, disabled flag, or network
# failure results in a silent `exit 0`. It must never block or fail a session.
#
# Opt out:  export KESTRACTL_TELEMETRY_DISABLED=true
#      or:  export KESTRA_SKILLS_TELEMETRY_DISABLED=true
#
# Override destination (defaults target Kestra's PostHog EU project):
#   KESTRA_SKILLS_POSTHOG_KEY   KESTRA_SKILLS_POSTHOG_HOST
set -euo pipefail

is_true() { case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in 1|true|yes|on) return 0;; *) return 1;; esac; }

is_true "${KESTRACTL_TELEMETRY_DISABLED:-}"     && exit 0
is_true "${KESTRA_SKILLS_TELEMETRY_DISABLED:-}" && exit 0

command -v curl >/dev/null 2>&1 || exit 0

POSTHOG_KEY="${KESTRA_SKILLS_POSTHOG_KEY:-phc_8lNe3YuQj9gyJcCJOGy4RwMCUFzHQ7siGPr8aeodhxR}"
POSTHOG_HOST="${KESTRA_SKILLS_POSTHOG_HOST:-https://eu.i.posthog.com}"
[ -n "$POSTHOG_KEY" ] || exit 0

# --- read the hook payload from stdin, pull out the skill name ---------------
payload="$(cat 2>/dev/null || true)"
skill=""
if command -v jq >/dev/null 2>&1; then
  skill="$(printf '%s' "$payload" | jq -r '.tool_input.skill // .tool_input.name // empty' 2>/dev/null || true)"
fi
if [ -z "$skill" ]; then
  skill="$(printf '%s' "$payload" | sed -n 's/.*"skill"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
fi
[ -n "$skill" ] || exit 0

# --- stable anonymous id (random, persisted; never derived from user data) ---
id_dir="${CLAUDE_PLUGIN_DATA:-${HOME:-/tmp}/.claude}"
id_file="${id_dir}/kestra-skills-telemetry-id"
distinct_id=""
if [ -r "$id_file" ]; then
  distinct_id="$(head -n1 "$id_file" 2>/dev/null || true)"
fi
if [ -z "$distinct_id" ]; then
  if command -v uuidgen >/dev/null 2>&1; then distinct_id="$(uuidgen)"; else
    distinct_id="anon-$(head -c16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo unknown)"
  fi
  ( mkdir -p "$id_dir" 2>/dev/null && printf '%s\n' "$distinct_id" > "$id_file" 2>/dev/null ) || true
fi

plugin_ref=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && command -v git >/dev/null 2>&1; then
  plugin_ref="$(git -C "$CLAUDE_PLUGIN_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
fi

esc() { printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

body="$(cat <<JSON
{"api_key":"$(esc "$POSTHOG_KEY")","event":"agent_skill_invoked","distinct_id":"$(esc "$distinct_id")","properties":{"skill":"$(esc "$skill")","plugin":"kestra-agent-skills","plugin_ref":"$(esc "$plugin_ref")","os":"$(esc "$(uname -s 2>/dev/null)")","arch":"$(esc "$(uname -m 2>/dev/null)")","source":"claude-code-hook","\$lib":"kestra-agent-skills"}}
JSON
)"

# fire-and-forget; capped so a slow network can't hang the session
( curl -sS -m 5 -o /dev/null \
    -X POST "${POSTHOG_HOST%/}/i/v0/e/" \
    -H 'Content-Type: application/json' \
    --data-raw "$body" >/dev/null 2>&1 || true ) &

exit 0
