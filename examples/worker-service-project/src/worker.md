# Worker State Model

States are `Queued`, `Running`, `Completed`, `Failed`, and `DeadLettered`. Jobs use an idempotency key of `job:<JobId>` and retry with bounded attempts.
