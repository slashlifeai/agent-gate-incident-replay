# Credential Boundary Escape

This incident demonstrates an agent attempting to read another agent's runtime
credential.

The expected replay shows:

1. a blocked credential access event;
2. normalized policy evidence;
3. `VERDICT: FAIL` for the blocked path;
4. `VERDICT: PASS` for the corrected path.

The full replay entrypoint and expected transcript will be added once the VM
mount mechanism is implemented.
