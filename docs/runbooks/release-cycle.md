# Release Cycle Runbook

Use this runbook when publishing browser runtime artifacts, blackbox savestates, or incident modules.

## Release Units

The repository has three release units:

1. Runtime source: `index.html`, `demo.js`, manifests, and browser assets.
2. Runtime artifacts: VM image and base blackbox savestate.
3. Incident modules: mounted replay packages and expected evidence.

Large binaries must be published as release artifacts or external object-store artifacts, not committed to git history.

## Runtime Release Checklist

- Pin runtime version.
- Pin `agent-gate-core` version included in the VM.
- Pin VM image hash.
- Pin base savestate hash.
- Confirm the savestate is compatible with the VM image.
- Record browser compatibility notes.

## Incident Release Checklist

- Validate `incident.json`.
- Confirm the entrypoint exists and is executable in the VM.
- Replay the incident from the mounted module.
- Capture transcript.
- Confirm expected verdict sequence.
- Record required runtime and `agent-gate-core` versions.

## Artifact Manifest Requirements

Every artifact manifest must include:

- logical artifact name;
- version;
- byte size;
- sha256;
- creation timestamp;
- compatible runtime version;
- compatible `agent-gate-core` version when applicable.
