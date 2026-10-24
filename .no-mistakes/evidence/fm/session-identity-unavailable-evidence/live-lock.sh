#!/usr/bin/env bash
set -eu
LAB=$(mktemp -d "$PWD/.live-lock.XXXXXX")
trap 'if [ -n "${owner:-}" ]; then kill "$owner" 2>/dev/null || true; wait "$owner" 2>/dev/null || true; fi; rm -rf "$LAB"' EXIT
bin/fm-lab-home.sh create "$LAB"
export FM_HOME="$LAB"
unset FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE CLAUDE_PID CLAUDE_CODE_SESSION_ID FM_SUPERVISION_MODEL
mkdir "$LAB/deny"
printf '#!/usr/bin/env bash\nexit 1\n' > "$LAB/deny/ps"
chmod +x "$LAB/deny/ps"
inspect() { bash -c '. bin/fm-session-lock-lib.sh; fm_session_lock_inspect "$FM_HOME/state"; printf "inspection=%s live_harness=%s\n" "$FM_LOCK_INSPECT_STATE" "$FM_LOCK_INSPECT_LIVE_HARNESS"'; }
echo '=== Real Codex ancestry: acquire, inspect, confirm ==='
bash bin/fm-lock.sh
bash bin/fm-lock.sh status
inspect
cp "$LAB/state/.lock" "$LAB/before"
bash bin/fm-lock.sh
cmp "$LAB/before" "$LAB/state/.lock"
echo '=== Denied process evidence, same live PID ==='
PATH="$LAB/deny:$PATH" bash bin/fm-lock.sh status
PATH="$LAB/deny:$PATH" inspect
if PATH="$LAB/deny:$PATH" bash bin/fm-lock.sh; then exit 8; else echo "acquisition exit=$?"; fi
cmp "$LAB/before" "$LAB/state/.lock"
echo 'lock bytes unchanged'
touch "$LAB/state/.last-watcher-beat"
PATH="$LAB/deny:$PATH" bash bin/fm-inbox.sh ready
echo '=== Observation restored ==='
bash bin/fm-lock.sh
bash bin/fm-lock.sh status
cmp "$LAB/before" "$LAB/state/.lock"
echo '=== Live non-harness owner ==='
printf '%s\n' "$$" > "$LAB/state/.lock"
bash bin/fm-lock.sh status
inspect
bash bin/fm-lock.sh
bash bin/fm-lock.sh status
echo '=== Dead and malformed owners ==='
sleep 0.01 & dead=$!; wait "$dead"
for value in "$dead" malformed; do
 printf '%s\n' "$value" > "$LAB/state/.lock"
 bash bin/fm-lock.sh status
 inspect
 bash bin/fm-lock.sh
 bash bin/fm-lock.sh status
done
echo '=== Persisted PID alone cannot prove ownership ==='
printf '%s\n' "$$" > "$LAB/state/.lock"
cp "$LAB/state/.lock" "$LAB/before"
if PATH="$LAB/deny:$PATH" bash bin/fm-lock.sh; then exit 9; else echo "acquisition exit=$?"; fi
cmp "$LAB/before" "$LAB/state/.lock"
echo 'lock bytes unchanged; disposable home removed on exit'

echo '=== Caller ancestry available, stored owner evidence denied ==='
sleep 60 & owner=$!
printf '%s\n' "$owner" > "$LAB/state/.lock"
cp "$LAB/state/.lock" "$LAB/before"
export LIVE_REAL_PS=$(command -v ps) LIVE_DENIED_PID="$owner"
cat > "$LAB/deny/ps" <<'PS'
#!/usr/bin/env bash
for arg in "$@"; do
 [ "$arg" != "$LIVE_DENIED_PID" ] || exit 1
done
exec "$LIVE_REAL_PS" "$@"
PS
PATH="$LAB/deny:$PATH" bash bin/fm-lock.sh status
if PATH="$LAB/deny:$PATH" bash bin/fm-lock.sh; then exit 10; else echo "acquisition exit=$?"; fi
cmp "$LAB/before" "$LAB/state/.lock"
echo 'live owner preserved despite independently verified caller ancestry'
