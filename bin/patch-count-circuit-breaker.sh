#!/usr/bin/env bash
# Patch-count circuit breaker for Claude Code Stop / SubagentStop hooks.
#
# Fires when >=2 consecutive "Fix story X.Y:" commits at HEAD share the
# same story id — the chase-the-symptom pattern that Epic 85.1 walked
# into five times before the actual fix landed. Injects a non-blocking
# reminder via hookSpecificOutput.additionalContext (Claude Code v2.1.163,
# 04 Jun 2026) so the agent sees the rule at the next prompt without the
# session being aborted.
#
# See:
#   memory/feedback_patch_count_circuit_breaker.md       (the rule)
#   memory/feedback_progress_check_and_substantiation.md (Q1/Q2 referenced)
#   memory/feedback_falsification_first_for_framings.md  (named-mechanism case)
#   docs/planning-artifacts/research/technical-claude-code-skills-research-2026-03-27.md
#     section "Update 2026-06-11" for the v2.1.163 primitive sourcing.

set -u

# Errors in this hook must not break the session — exit silently on any failure.
trap 'exit 0' ERR

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Walk from HEAD backwards counting consecutive Fix-story commits sharing
# the same story id. Break on first non-match or story-id change.
declare -i COUNT=0
STORY=""
while IFS= read -r SUBJECT; do
  if [[ "$SUBJECT" =~ ^Fix\ story\ ([0-9]+\.[0-9]+): ]]; then
    THIS="${BASH_REMATCH[1]}"
    if [[ -z "$STORY" ]]; then
      STORY="$THIS"
      COUNT=1
    elif [[ "$THIS" == "$STORY" ]]; then
      COUNT=$((COUNT + 1))
    else
      break
    fi
  else
    break
  fi
done < <(git log --format=%s -10 2>/dev/null)

# Threshold: >=2 same-story fix commits at HEAD → fire.
[[ $COUNT -lt 2 ]] && exit 0

MSG="Patch-count circuit breaker: ${COUNT} consecutive \`Fix story ${STORY}:\` commits detected at HEAD. Per memory/feedback_patch_count_circuit_breaker.md, the next commit MUST be diagnostic, not another patch — the upstream progress-check (memory/feedback_progress_check_and_substantiation.md) did not fire and you are in a chase-the-symptom loop. Before authoring another fix, answer in writing: (Q1) Am I really going forward? What signal would have indicated progress? Did it appear, even partially? (Q2) Can I substantiate the premise driving the next attempt? What evidence would I cite to a skeptic? If the premise is a named-mechanism framing (\"X causes Y\"), the next action MUST be a falsification observation distinguishing \"X is the cause\" from \"X is not\" — not a patch. See memory/feedback_falsification_first_for_framings.md."

printf '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":%s}}\n' \
  "$(printf '%s' "$MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"
