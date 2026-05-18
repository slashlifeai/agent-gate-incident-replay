#!/usr/bin/env sh
# deployment-approval-bypass — Agent Gate Incident Replay
#
# Two-act replay (~10 s):
#   Act 1: agent-x autonomously generates a diff and fires a prod
#          deployment trigger with no signed approval chain. Gate denies.
#   Act 2: the same diff with a valid 2-of-3 reviewer signature chain.
#          Gate permits.
#
# This script emits two parallel streams over stdout:
#
#   1. Compact log lines (single line per event) for the terminal pane.
#      These remain readable when the script is run standalone on a host.
#
#   2. <AG-TL>{...JSON...}</AG-TL> markers, one per stage.  The browser
#      harness intercepts them before they reach xterm and renders a
#      structured operational timeline in a side panel.  In a plain
#      terminal they're visible JSON — a developer affordance.
#
# Both streams describe the same events.  No second source of truth.

set -eu

pause() { sleep "${1:-0.6}"; }

# tl <json>  — emit one timeline marker.  Single-quote the JSON in the
# caller so no shell expansion happens inside the payload.
tl() { printf '<AG-TL>%s</AG-TL>\n' "$1"; }

# log <ts-label> <text>  — single compact line for the terminal pane.
log() { printf '\033[2m%s\033[0m  %s\n' "$1" "$2"; }

POLICY_HASH=9c4f2a7b1e6d3f8a5c0b9e2d7a4f1c8b6e3d0a7f4b1c8e5d2a9f6c3b0e7d4a1f

# ── reset + announce incident ─────────────────────────────────────────
tl '{"_reset":true,"incident":"deployment-approval-bypass","policy":"sl.ai.policy.deployment-approval","policy_hash":"'"$POLICY_HASH"'","node":"workforce-node-7"}'
printf '\n\033[1m  deployment-approval-bypass\033[0m  \033[2mpolicy '"$POLICY_HASH"'\033[0m\n\n'
pause 2

# ══════════════════════════════════════════════════════════════════════
# ACT 1  — deploy with no approval chain
# ══════════════════════════════════════════════════════════════════════
tl '{"_divider":true,"label":"ACT 1  agent fires prod deploy without a signed chain"}'
log "[03:14:07.118]" "agent.generation       agent-x  →  diff.patch"
tl '{"stage":"agent.generation","title":"AGENT GENERATION","status":"done","ts":"2026-05-18T03:14:07.118Z","act":1,"rows":[{"k":"actor","v":"agent-x"},{"k":"model","v":"claude-opus-4-7"},{"k":"self-review","v":"lgtm, ship it"},{"k":"approval-chain","v":"<none>"}],"code":"--- a/services/payments-api/config/runtime.toml\n+++ b/services/payments-api/config/runtime.toml\n- upstream_timeout_ms = 1500\n+ upstream_timeout_ms = 30000","code_lang":"diff"}'
pause 1.1

log "[03:14:07.402]" "deployment.trigger     payments-api @ prod"
tl '{"stage":"deployment.trigger","title":"DEPLOYMENT TRIGGER","status":"done","ts":"2026-05-18T03:14:07.402Z","act":1,"rows":[{"k":"target","v":"payments-api @ prod"},{"k":"commit","v":"f2c9e07a8b3d1e5f4c0b9e2d7a4f1c8b6e3d0a7f"},{"k":"trigger_id","v":"deploy-2026-05-18-031407"}]}'
pause 0.9

log "[03:14:07.418]" "approval.state         INVALID  (0/2 reviewers, self-approval)"
tl '{"stage":"approval.state.observed","title":"APPROVAL STATE OBSERVED","status":"fail","ts":"2026-05-18T03:14:07.418Z","act":1,"rows":[{"k":"commit signature","v":"0/required","fail":true},{"k":"reviewer signatures","v":"0/2","fail":true},{"k":"provenance attestation","v":"absent","fail":true},{"k":"self-approval","v":"agent-x","fail":true}]}'
pause 1.5

log "[03:14:07.421]" "policy.violation       approval_chain_invalid"
tl '{"stage":"policy.violation","title":"POLICY VIOLATION","status":"deny","ts":"2026-05-18T03:14:07.421Z","act":1,"rows":[{"k":"policy","v":"sl.ai.policy.deployment-approval"},{"k":"reason_code","v":"approval_chain_invalid"}]}'
pause 0.8

log "[03:14:07.425]" "gate.decision          VERDICT: FAIL · deny"
tl '{"stage":"gate.decision","title":"GATE DECISION","status":"deny","ts":"2026-05-18T03:14:07.425Z","act":1,"rows":[{"k":"verdict","v":"FAIL","fail":true},{"k":"decision","v":"deny"}]}'
pause 2

log "[03:14:07.427]" "evidence.sealed        sha256:4e2c8a1f…"
tl '{"stage":"evidence.sealed","title":"EVIDENCE SEALED","status":"done","ts":"2026-05-18T03:14:07.427Z","act":1,"rows":[{"k":"evidence_sha256","v":"4e2c8a1f7b3d6e9c0a4f1b8e5d2c9f6a3b0d7e4c1a8f5b2e9d6c3a0f7b4e1d8c"},{"k":"policy_hash_sha256","v":"'"$POLICY_HASH"'"},{"k":"bootloader_stamped","v":"true"}]}'
pause 0.8

# ══════════════════════════════════════════════════════════════════════
# ACT 2  — same diff, signed approval chain attached
# ══════════════════════════════════════════════════════════════════════
tl '{"_divider":true,"label":"ACT 2  reviewers sign the chain; same diff re-submitted"}'
log "" ""
log "[03:45:22.118]" "commit.signature       ed25519 verified  (signer=agent-x)"
log "[03:45:22.224]" "reviewer.signature     alice@platform-owners"
log "[03:45:22.301]" "reviewer.signature     bob@platform-owners"
tl '{"stage":"signatures.collected","title":"SIGNATURES COLLECTED","status":"done","ts":"2026-05-18T03:45:22.301Z","act":2,"rows":[{"k":"commit signature","v":"ed25519 · agent-x","pass":true},{"k":"reviewer · alice","v":"alice@platform-owners","pass":true},{"k":"reviewer · bob","v":"bob@platform-owners","pass":true},{"k":"provenance attestation","v":"slsa/v1 · build-attestor@v0.4.2","pass":true}]}'
pause 0.9

log "[03:45:22.402]" "deployment.trigger     payments-api @ prod  (re-submit)"
tl '{"stage":"deployment.trigger.2","title":"DEPLOYMENT TRIGGER","status":"done","ts":"2026-05-18T03:45:22.402Z","act":2,"rows":[{"k":"target","v":"payments-api @ prod"},{"k":"commit","v":"f2c9e07a8b3d1e5f4c0b9e2d7a4f1c8b6e3d0a7f"},{"k":"trigger_id","v":"deploy-2026-05-18-034522"}]}'
pause 0.7

log "[03:45:22.418]" "approval.state         VALID  (2/2 reviewers, signed, attested)"
tl '{"stage":"approval.state.observed.2","title":"APPROVAL STATE OBSERVED","status":"pass","ts":"2026-05-18T03:45:22.418Z","act":2,"rows":[{"k":"commit signature","v":"verified","pass":true},{"k":"reviewer signatures","v":"2/2","pass":true},{"k":"provenance attestation","v":"present","pass":true},{"k":"self-approval","v":"none","pass":true}]}'
pause 0.7

log "[03:45:22.421]" "policy.evaluated       approval_chain_valid"
tl '{"stage":"policy.evaluated","title":"POLICY EVALUATED","status":"pass","ts":"2026-05-18T03:45:22.421Z","act":2,"rows":[{"k":"policy","v":"sl.ai.policy.deployment-approval"},{"k":"reason_code","v":"approval_chain_valid"}]}'
pause 0.7

log "[03:45:22.425]" "gate.decision          VERDICT: PASS · permit"
tl '{"stage":"gate.decision.2","title":"GATE DECISION","status":"pass","ts":"2026-05-18T03:45:22.425Z","act":2,"rows":[{"k":"verdict","v":"PASS","pass":true},{"k":"decision","v":"permit"}]}'
pause 2

log "[03:45:22.427]" "evidence.sealed        sha256:a7f4c1d8…"
tl '{"stage":"evidence.sealed.2","title":"EVIDENCE SEALED","status":"done","ts":"2026-05-18T03:45:22.427Z","act":2,"rows":[{"k":"evidence_sha256","v":"a7f4c1d8e5b2a9f6c3d0e7b4a1f8c5e2d9b6a3c0f7e4d1b8c5a2f9e6d3b0a7c4"},{"k":"policy_hash_sha256","v":"'"$POLICY_HASH"'"},{"k":"bootloader_stamped","v":"true"}]}'
pause 0.3

printf '\n\033[2m  two evidence bundles sealed under policy '"$POLICY_HASH"'\033[0m\n'
