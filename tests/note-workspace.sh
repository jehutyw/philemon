#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
task_fixture=$(mktemp -d /tmp/philemon-note-workspace.XXXXXX)
# Keep the isolated fixture and screenshot for inspection; no real vault is modified.
cp -a ui "$task_fixture/ui"
cp tests/note-workspace.qml "$task_fixture/ui/shell.qml"
cp -a tests/fixtures/note-vault "$task_fixture/vault"
export PHILEMON_NOTE_TEST_VAULT="$task_fixture/vault"
export PHILEMON_NOTE_TEST_IMAGE="$task_fixture/workspace.png"
export XDG_STATE_HOME="$task_fixture/state"
export PHILEMON_BIN="${PHILEMON_TEST_BIN:-$PWD/target/debug/philemon}"
export QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1
task_output=$(timeout 20 qs -p "$task_fixture/ui/shell.qml" 2>&1) || { printf '%s\n' "$task_output"; exit 1; }
printf '%s\n' "$task_output"
[[ "$task_output" == *"NOTE WORKSPACE PASS:"* ]]
printf 'Fixture and screenshot: %s\n' "$task_fixture"
