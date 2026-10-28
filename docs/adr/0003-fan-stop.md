# ADR-0003: Fan stop semantics and guardrails

Status: accepted (2026-10-28); scope of the 70 °C guardrail clarified by the
maintainer in this ADR.

## Decision

Two behaviours are modelled separately:

- `.off` — release the override and hand control back to Apple (`F0Md = 0`).
  This is the only "stop" behaviour in v1.
- `.forceZero` — write `F0Tg = 0` (and `F0Mn = 0` where required). Deferred to
  v1.1, gated behind an explicit acknowledgement in Settings → Advanced, and
  marked "requires verification on the target model".

The privacy of the fan-stop feature is protected by compile-time constants in
`FrostBarCore/HardwareGuardrails`:

| Constant | Value | Scope |
|---|---|---|
| `forceZeroAmbientLimit` | 50 °C | `.forceZero` only |
| `forceZeroForcedAuto` | 70 °C | `.forceZero` only |
| `emergencyAuto` | 95 °C | all manual control |
| `maxSlewRPMps` | 800 | all writes |
| `watchdogTimeout` | 10 s | helper |

### Why the 70 °C guardrail is scoped to `.forceZero`

Applying a global "automatic above 70 °C" rule would make every custom curve
inert in exactly the temperature range where the fan is useful, and would
silently override the user's chosen profile. The risk the guardrail addresses
is stopped or heavily throttled fans, not manual control in general. Manual
control therefore keeps the 95 °C emergency handoff, plus clamping, slew limits
and the watchdog.

## Consequences

- `.forceZero` is rejected in v1 by `ConfigurationValidator`,
  `DefaultModeEvaluator` and `FanWritePolicy`; three independent layers.
- The schema reserves `AdvancedSettings.forceZeroAcknowledgedAt` so v1.1 does not
  need a schema migration.
- Tests assert that guardrails cannot be supplied or weakened through JSON.
