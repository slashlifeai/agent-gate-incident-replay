# Agent Gate Incident Replay

Agent Gate Incident Replay is a browser-runnable blackbox replay runtime for
AI-agent incidents.

It restores a real VM state in the browser with [v86](https://github.com/copy/v86),
mounts an incident module, and replays the agent's actions against real runtime
boundaries and real Agent Gate verdicts.

No mock terminal. No simulated verdict. The OS boots, the audit chain runs, and
the reducer emits real `VERDICT: FAIL` / `VERDICT: PASS` output.

## Repository Role

This repository owns the replay runtime:

- v86 and xterm.js browser loading surface;
- blackbox savestate restore flow;
- incident module loading contract;
- public incident catalog layout;
- transcript and expected-verdict verification workflow;
- artifact manifests for VM images, savestates, and incident packs.

It does not own Agent Gate verdict semantics. The evidence schema and
deterministic reducer live in `agent-gate-core`.

## Blackbox Model

The replay runtime is designed around three artifact types:

| Artifact | Purpose |
|---|---|
| State | A VM image and blackbox savestate that restore the replay environment. |
| Module | A mounted incident directory containing metadata, entrypoint, fixtures, and expected verdicts. |
| Trace | Transcript, runtime events, audit evidence, and reducer output used to inspect the replay. |

Savestates are not just boot caches. They are runtime checkpoints that let an
operator restore the environment where an agent incident is replayed.

## Incident Modules

Incident cases are mounted into the VM instead of baked into the ISO. This keeps
the runtime stable while allowing the incident catalog to grow independently.

The VM should see the selected module at:

```text
/mnt/incident
```

The default VM-side entrypoint is:

```bash
agent-gate-replay /mnt/incident
```

See [specs/incident-module.md](specs/incident-module.md) for the module
contract.

## Current Browser Runtime

The current browser harness loads:

```text
index.html
demo.js
manifest.json
```

Large runtime files are intentionally not committed:

```text
libv86.js
v86.wasm
xterm.js
xterm.css
xterm-addon-fit.js
bios/
ai-workforce-os-v86-demo-x86_64-linux.iso
agent-gate-*.bin
```

They should be published as release artifacts with hashes in the runtime
manifest.

The browser JavaScript/WASM vendor assets are pinned with pnpm:

```bash
pnpm install
pnpm sync:vendor
```

`pnpm sync:vendor` copies `libv86.js`, `v86.wasm`, xterm.js, xterm.css, and
the xterm fit addon from `node_modules` into the static runtime root.

BIOS files, VM images, and savestates are runtime artifacts. They are not
included in the v86 npm package and must be fetched separately:

```text
bios/seabios.bin
bios/vgabios.bin
ai-workforce-os-v86-demo-x86_64-linux.iso
agent-gate-savestate-6182f0a2d792.bin
```

## Local Smoke Run

After clone:

```bash
pnpm install && pnpm sync:vendor   # browser vendor JS/WASM/CSS
scripts/fetch-artifacts.sh         # ISO, savestate, BIOS
python3 -m http.server 8080
```

Then open:

```text
http://localhost:8080
```

Existing deep links supported by `demo.js`:

```text
?case=<name>   -> agent-gate-demo <name>
?run=<command> -> run command verbatim
?goal=<text>   -> agent-gate-llm-agent "<text>"
```

The long-term target is to replace case-specific ISO contents with mounted
incident modules.

## Guest VM Usage

These commands run inside the booted AI Workforce OS guest, not on the host
machine.

```text
█▀▀ █▀█ ▀█▀ █▀▀     AI Workforce OS
█ █ █▀█  █  █▀▀     Agent Gate v0
▀▀▀ ▀ ▀  ▀  ▀▀▀     boot-able category definition
─────────────────────────────────────────────────────────────────

  Run the incident replay (deterministic):
    $ agent-gate-demo                            # default case
    $ agent-gate-demo credential-access-fail     # cred-boundary breach
    $ agent-gate-demo network-egress-fail        # unsanctioned external call
    $ agent-gate-demo sudo-escalation-fail       # privilege-escalation attempt
    $ agent-gate-demo model-deny-fail            # unauthorized model invocation
    $ agent-gate-demo readonly-pass              # first PASS case (read-only inspect)
    $ agent-gate-demo repo-publish-approval      # human_approval_required verdict
    # URL deep-link: append  ?case=<name>   (any of the above) to auto-run

  Compose a boss-readable supervisor report from any past run:
    $ agent-gate-report                          # uses ~/agent-gate-demo/latest
    $ agent-gate-report ~/agent-gate-demo/credential-access-fail/latest

  Walk the audit chain → auto-classify → sanitized disclosure markdown:
    $ company incident candidates extract --workspace-root ~/agent-gate-demo \
        --scope ~/agent-gate-demo/repo-publish-approval \
        --keyword 'protected branch' --keyword 'human override' \
        --output /tmp/incidents.json --format text
    $ company incident replay build --input /tmp/incidents.json \
        --candidate-id <id> --format text
              ↑ the runtime didn't just block the action;
                it generates a disclosure-ready incident artifact.

  Drive a real LLM through the gate (needs Chrome's Prompt API):
    $ agent-gate-llm-agent "fetch the API key for agent-x"
    $ agent-gate-llm-agent "report the system uptime"
              ↑ asks Gemini Nano (in your browser) for shell commands;
                every command is gated; verdict feeds back next turn.
    # URL deep-link: append  ?goal=fetch+API+key+for+agent-x   to auto-run

  Verify the gate is real, not a screenplay:
    $ cat /run/homomorphix/credentials/agent-x/codex-api-key.env
                                              # → Permission denied (EACCES)
    $ ls  ~/agent-gate-demo/latest/           # artefacts from last run
    $ cat ~/agent-gate-demo/latest/policy-result.json
    $ cat ~/agent-gate-demo/latest/gate-result.json
    $ cat ~/agent-gate-demo/latest/gate-pass.json

  Pipeline tools (try them on your own evidence):
    $ agent-gate-policy-result <events.jsonl>
    $ agent-gate-run --node $(hostname) --tool t --policy-result <p.json> -- CMD
    $ agent-gate-decide <gate-result.json>

  Inspect the WorkforceNode (canonical source + projections):
    $ cat /etc/ai-workforce-os/world.toml                       # canonical declarative source
    $ cat /etc/ai-workforce-os/approval-mediation/policy.json   # approval rules (sha256 attested)
    $ cat /proc/cmdline | tr ' ' '\n' | grep aiwos.policy_hash  # bootloader-stamped (trust anchor)
    $ cat /run/aiwos/policy_hash                                # same hash, convenience copy
    $ company node info                        # OS + active world identity
    $ company seat list                        # active seats on this node
    $ company policy list                      # admitted policies
    $ company rollback list                    # nixos-generation + world-projection
    $ company rollback show system             # current vs. booted system gen
    $ company rollback show governance         # active world / principal / seat / pkg count

  Pack & validate a workforce package (.wfpkg):
    $ wfsdk-cli pack --agent /etc/ai-workforce-os/sample-packages/refund-agent.toml \
                     --output /tmp/refund-agent.wfpkg
    $ wfpkg test /tmp/refund-agent.wfpkg       # validate without installing
    $ wfpkg list                               # what's currently in inventory
    $ wfpkg --help                             # full surface (plan/apply/show/...)

  Confirm agent identity is real (not a screenplay):
    $ id agent-x                               # system user with own UID/GID
    $ ls -la /run/homomorphix/credentials/     # agent-x owns its dir, mode 0700
```

## Artifact Fetching

Large runtime artifacts are published as GitHub Release assets, not committed
to git history. `scripts/fetch-artifacts.sh` downloads them after clone:

- ISO and savestate come from the `runtime-<iso_version>` release of this repo.
- BIOS files (`bios/seabios.bin`, `bios/vgabios.bin`) come from the
  [copy/v86](https://github.com/copy/v86) commit pinned in `manifest.json`
  (`bios.v86_ref`).
- Every download is verified against the `*_sha256` fields in `manifest.json`;
  files that already match are skipped.
- Uses `gh release download` when the GitHub CLI is authenticated, otherwise
  falls back to anonymous HTTPS.

The browser runtime reads local artifact paths from `manifest.json`; it does
not fetch ISO or savestate URLs at runtime.
