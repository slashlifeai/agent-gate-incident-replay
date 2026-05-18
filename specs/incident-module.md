# Incident Module Contract

## Purpose

An incident module is a self-contained replay package mounted into the Agent Gate Incident Replay VM. It provides the entrypoint, metadata, and expected evidence needed to replay one AI-agent incident type.

## Layout

```text
incidents/<incident-id>/
  incident.json
  replay.sh
  events.jsonl
  expected-verdicts.json
  README.md
```

Optional files:

```text
transcript.expected.txt
evidence.expected.json
assets/
```

## `incident.json`

```json
{
  "schema_version": "agent.gate.incident.v0",
  "id": "credential-boundary-escape",
  "title": "Agent attempts to read another agent credential",
  "category": "credential-boundary",
  "entrypoint": "replay.sh",
  "expected_verdicts": ["FAIL", "PASS"],
  "requires": {
    "agent_gate_core": ">=0.1.0",
    "runtime": ">=0.1.0"
  }
}
```

## Runtime Contract

The browser runtime restores a blackbox savestate, mounts the selected module inside the VM, and invokes the module entrypoint through the VM-local replay command.

The VM should expose the selected module at:

```text
/mnt/incident
```

The default VM command should be:

```bash
agent-gate-replay /mnt/incident
```

## Module Responsibilities

The module owns the incident narrative, local replay entrypoint, expected policy events, expected verdict sequence, and any fixtures specific to the incident.

The module does not own Agent Gate reducer behavior, runtime credential broker semantics, browser loading behavior, or the base VM image.
