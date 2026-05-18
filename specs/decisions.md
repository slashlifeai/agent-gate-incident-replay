# Agent Gate Incident Replay Decisions

## Current Decisions

### Split Verdict Core From Replay Runtime

Decision: extract the Agent Gate evidence normalizer and deterministic reducer into a separate open-source `agent-gate-core` project.

Rationale: the core scripts are small, testable, and credible as public evidence infrastructure. Keeping verdict logic outside this repository makes the replay runtime easier to audit.

Consequence: this repository depends on `agent-gate-core` for verdict semantics and must not carry a private fork of `agent-gate-*` scripts.

### Use Savestate As Blackbox Evidence Substrate

Decision: treat v86 savestates as incident replay checkpoints, not only as boot acceleration cache.

Rationale: the target product story is closer to an aircraft flight recorder for AI agents. The value is the ability to restore a runtime state and replay what the agent saw, did, and triggered.

Consequence: manifests must pin savestate hashes and runtime versions. Release notes must describe whether a savestate is a base runtime checkpoint or an incident-specific capture.

### Mount Incident Modules Instead Of Baking Them Into The ISO

Decision: incident cases are mounted into the VM as modules rather than built into the base OS image.

Rationale: the project expects about 24 incident types. Baking every incident into the ISO would couple catalog updates to runtime rebuilds and make publication slower.

Consequence: the runtime must define a stable mounted module contract, and new incidents should not require an ISO rebuild unless they need new runtime capabilities.

### Keep Large Runtime Artifacts Out Of Git

Decision: VM images, savestates, BIOS files, v86/xterm vendor bundles, and other large runtime artifacts are fetched after clone and ignored by git.

Rationale: the source repository should remain small and reviewable while still supporting a local browser runtime once artifacts are fetched.

Consequence: release documentation must provide a public artifact acquisition path, and `manifest.json` should continue to describe local runtime filenames.
