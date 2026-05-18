# Incident Catalog

This directory contains public incident modules for Agent Gate Incident Replay.

Each incident module is self-contained and follows the contract in
`specs/incident-module.md`.

The first canonical incident type should be:

```text
credential-boundary-escape
```

It demonstrates an agent attempting to read another agent's credential, producing
a blocking runtime event and an Agent Gate `VERDICT: FAIL`, followed by a
permitted path that produces `VERDICT: PASS`.
