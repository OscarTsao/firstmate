#!/usr/bin/env bash
# Probe real codex CLI handling of the code_mode_host override in an isolated CODEX_HOME.
export CODEX_HOME=$(mktemp -d "${TMPDIR:-/tmp}/codexhome.XXXX")
run() {
  echo "\$ $*"
  "$@" 2>&1 | grep -v 'WARNING: proceeding'
  echo "rc=${PIPESTATUS[0]}"
  echo
}
filt() { grep -E '^(hooks|code_mode_host) ' || true; }
run codex --version
echo '# default feature state'
echo '$ codex features list | filter hooks/code_mode_host'
codex features list 2>/dev/null | filt; echo
echo '# crew/scout launch flags from the new template'
echo '$ codex --disable hooks -c features.code_mode_host=false features list | filter'
codex --disable hooks -c features.code_mode_host=false features list 2>/dev/null | filt; echo
echo '# older-codex simulation: a features.* key this codex does not know'
echo '$ codex -c features.no_such_feature_xyz=false features list >/dev/null'
codex -c features.no_such_feature_xyz=false features list >/dev/null 2>&1; echo "rc=$?"; echo
echo '# contrast: the --disable form the change deliberately avoids'
run codex --disable no_such_feature_xyz features list
rm -rf "$CODEX_HOME"
