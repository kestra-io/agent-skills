#!/usr/bin/env bash
# Fail if the plugin manifests disagree, or disagree with the tag given as $1 (vX.Y.Z).
set -euo pipefail
cd "$(dirname "$0")/.."
files=(plugin.json .claude-plugin/plugin.json .cursor-plugin/plugin.json)
expected="${1:+${1#v}}"
for f in "${files[@]}"; do
  v=$(jq -r '.version // empty' "$f")
  [ -n "$v" ] || { echo "$f: missing version"; exit 1; }
  expected="${expected:-$v}"
  [ "$v" = "$expected" ] || { echo "$f: version $v, expected $expected"; exit 1; }
done
echo "all manifests at $expected"
