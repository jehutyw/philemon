#!/usr/bin/env bash
# Exercises the actual CLI handoff without launching Obsidian or changing a vault.
set -euo pipefail
cd "$(dirname "$0")/.."
task_fixture=$(mktemp -d /tmp/philemon-obsidian-open.XXXXXX)
trap 'rm -r -- "$task_fixture"' EXIT
mkdir "$task_fixture/bin"
ln -s "$PWD/tests/fixtures/obsidian-gio" "$task_fixture/bin/gio"
touch "$task_fixture/café # &?.md" "$task_fixture/attachment.pdf"
export PHILEMON_OBSIDIAN_CAPTURE="$task_fixture/captured"
PATH="$task_fixture/bin:$PATH" ./target/debug/philemon --open-obsidian "$task_fixture/café # &?.md"
for task_attempt in {1..100}; do
    test -f "$PHILEMON_OBSIDIAN_CAPTURE" && break
    sleep 0.02
done
task_expected="obsidian://open?path=${task_fixture//\//%2F}%2Fcaf%C3%A9%20%23%20%26%3F.md"
test "$(< "$PHILEMON_OBSIDIAN_CAPTURE")" = "$task_expected"
for task_invalid in "$task_fixture" "$task_fixture/missing.md" "$task_fixture/attachment.pdf"; do
    if ./target/debug/philemon --open-obsidian "$task_invalid" 2>/dev/null; then
        echo "FAIL: invalid note accepted"
        exit 1
    fi
done
echo "PASS: encoded note handoff; directories, missing notes and non-Markdown refused"
