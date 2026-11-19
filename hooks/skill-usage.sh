#!/usr/bin/env bash
# Anonymous per-skill usage event (PostHog). Runs after the Skill tool.
# Sends: skill name, plugin ref, os/arch. Never reads prompt, transcript, cwd or flow content.
# Best effort: any problem exits 0 silently.
# Opt out: KESTRA_SKILLS_TELEMETRY_DISABLED=true or KESTRACTL_TELEMETRY_DISABLED=true.

is_true() { case "$(printf %s "$1" | tr '[:upper:]' '[:lower:]')" in 1|true|yes) return 0 ;; esac; return 1; }
is_true "$KESTRA_SKILLS_TELEMETRY_DISABLED" && exit 0
is_true "$KESTRACTL_TELEMETRY_DISABLED" && exit 0
command -v curl >/dev/null && command -v jq >/dev/null || exit 0

root="${CLAUDE_PLUGIN_ROOT:-}"
key="${KESTRA_SKILLS_POSTHOG_KEY:-phc_8lNe3YuQj9gyJcCJOGy4RwMCUFzHQ7siGPr8aeodhxR}"
host="${KESTRA_SKILLS_POSTHOG_HOST:-https://kestra.io/t}"
[ -n "$root" ] || exit 0

# Only our skills: the hook also fires for skills of other plugins.
skill=$(jq -r '.tool_input.skill // empty' 2>/dev/null)
skill="${skill#kestra:}"
case "$skill" in ""|*/*|*..*) exit 0 ;; esac
[ -d "$root/skills/$skill" ] || exit 0

# Random anonymous id, persisted across sessions.
data="${CLAUDE_PLUGIN_DATA:-$HOME/.cache/kestra-agent-skills}"
mkdir -p "$data" 2>/dev/null
id=$(cat "$data/id" 2>/dev/null)
if [ -z "$id" ]; then
  id=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null) || exit 0
  printf %s "$id" > "$data/id" 2>/dev/null
fi

body=$(jq -n --arg k "$key" --arg id "$id" --arg s "$skill" --arg r "$(basename "$root")" \
  --arg os "$(uname -s)" --arg arch "$(uname -m)" \
  '{api_key:$k,event:"agent_skill_invoked",distinct_id:$id,properties:{skill:$s,plugin_ref:$r,os:$os,arch:$arch,source:"claude-code-hook","$process_person_profile":false}}')

( curl -s -m 5 -X POST -H 'Content-Type: application/json' -d "$body" "$host/i/v0/e/" >/dev/null 2>&1 & )
exit 0
