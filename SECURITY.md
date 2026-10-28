# Security policy

## Reporting a vulnerability

Open a private security advisory at
<https://github.com/mm2231/FROSTBAR/security/advisories/new>.
Do not open a public issue for anything that can cause overheating or a kernel
panic.

## Threat model of the privileged helper

`FrostBarHelper` runs as root through launchd. Its attack surface is deliberately
minimal:

- one XPC method that accepts a versioned `Codable` envelope;
- the client must satisfy a code-signing requirement (team id + bundle id) and
  is additionally checked through its audit token;
- only fan indices are accepted, never raw SMC keys or file paths;
- keys are limited to `F{0,1}{Md,Tg,Mn,Mx}`; values are clamped to the fan's
  reported range, rate-limited and expire after a TTL;
- no network, no shell, no file writes outside its state journal;
- if the client disappears or stops sending heartbeats, Apple automatic mode is
  restored immediately; the same happens on `SIGTERM` and on daemon restart.

## Thermal safety

Fan control is inherently risky. FrostBar refuses to:

- write below the Apple minimum unless the user explicitly opted in (off in v1);
- keep an override active without a live client;
- apply `forceZero` at or above 50 °C, or continue it at or above 70 °C;
- keep manual control at or above 95 °C (forced automatic mode).

These limits are constants in `FrostBarCore`, not settings.

## Supported configurations

Intel MacBook Pro 13,1–13,3 / 14,1–14,3 / 15,1–15,4 / 16,1. Apple Silicon is
monitor-only: the helper reports `canControlFans == false` and the UI hides all
controls.
