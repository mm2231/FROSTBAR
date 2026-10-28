# ADR-0006: The helper owns every SMC write

Status: accepted (2026-10-28)

## Decision

`FrostBar.app` never writes to the SMC. Reads happen in-process through
`FrostBarSMC` when the AppleSMC user client allows it; if the probe fails with
`kIOReturnNotPrivileged`, `FallbackSensorProvider` switches to reads through the
helper.

Writes are only possible through `FrostBarHelper`, a launchd daemon registered
with `SMAppService.daemon`, reachable over Mach XPC. The app never sends raw SMC
keys: the wire protocol accepts `FanCommand` values only.

The helper:

- verifies the client's code signature (team id + bundle id) and audit token;
- validates the command with `FanWritePolicy` (whitelist, clamp, slew, TTL);
- keeps a journal so an interrupted override is restored to automatic mode;
- exits after an idle period, leaving the fans under Apple control.

## Consequences

- A compromised app process cannot write arbitrary SMC keys.
- The helper is the only component that needs the `root` user, and it has no
  network or UI.
- Helper and app must be signed with the same team, otherwise the XPC
  requirement rejects the connection.
