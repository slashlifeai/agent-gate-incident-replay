# Agent Gate Incident Replay Domain

## Ubiquitous Language

| Term | Definition |
|---|---|
| Replay runtime | The browser-hosted v86 environment that restores a prepared VM state and runs incident modules. |
| Blackbox savestate | A VM checkpoint representing a booted, initialized replay environment. It is evidence substrate, not a browser cache. |
| Incident module | A self-contained directory mounted into the VM to replay one agent incident type. |
| Incident catalog | The published set of incident modules available for replay. |
| Gate core | The external `agent-gate-core` project that owns evidence schemas and deterministic verdict reduction. |
| Evidence trace | Runtime, audit, policy, transcript, and expected verdict material used to inspect a replay. |
| Release artifact | A large runtime binary, savestate, or incident pack published outside git history. |

## Domain Boundary

This repository owns: the browser replay runtime, v86/xterm loading surface, runtime manifest, savestate restore flow, incident module loading contract, public incident catalog layout, transcript and expected-verdict verification workflow, and release artifact manifests for replayable incidents.

This repository does NOT own: Agent Gate verdict semantics, `agent.gate.result.v0` reducer implementation, AI Workforce OS internals, credential broker internals, package lifecycle governance, policy engine behavior, third-party certification claims, or protected-branch/release approval.

## Relationship To Agent Gate Core

`agent-gate-core` is the source of truth for normalized evidence schemas and PASS/FAIL reducer behavior. This repository consumes that core in the VM image and documents which core version a runtime or incident module requires.

Incident modules may include policy events, transcripts, fixtures, and replay entrypoints, but they must not redefine verdict rules. If a module needs new evidence semantics, update `agent-gate-core` first.
