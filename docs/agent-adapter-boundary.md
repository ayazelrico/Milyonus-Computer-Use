# Agent runner validation across adapters

`AgentRunner` accepts any `HarnessClient`, so it cannot assume the stdio implementation already validated incoming values. It now validates the supplied ready session, each current/authorized session reply, both pre-planning and fresh observations, and each returned action result using the shared contract checks. Initial status application scope must also match the host-supplied session before an observation can reach the planner.

Truncated observations are rejected as stale before planning and again before action/completion. Capture timestamps must be less than ten seconds old and no more than one second ahead of the local clock at admission. The fresh post-planning observation must have a different observation ID from the one given to the planner. Freshness is checked again after the authorization-status await, which may itself consume the observation window. Existing session/generation, PID, target continuity, step/time budgets and independent completion checks remain in force.

The timestamp check is a conservative metadata admission rule, not proof of capture freshness. Clock jumps can cause safe refusals, and a dishonest adapter can forge timestamps or IDs. Native target identity and monotonic freshness/lease checks remain authoritative; no model output gains permission from passing these checks.

Invalid runtime data stops the run and invokes its existing session cancellation cleanup. A malformed action result is not retried even if an effect may already have occurred. Invalid host-supplied session metadata is rejected before a run is registered. The runner does not attempt to repair observations, strip invalid elements or fabricate missing values.

This increment closes a concrete gap: the general runner previously lacked a truncated-observation check even though native action targeting and the gesture acceptance runner already rejected incomplete observations. Earlier documentation suggesting all runners already enforced that boundary was too broad; only the new synthetic runner tests establish it here.

Synthetic custom-adapter tests verify zero planner calls for malformed/truncated/stale/future observations and invalid status metadata/scope; zero mutations for reused or truncated fresh observations on both action and completion paths; and cancellation without retry after a malformed post-effect result. These are in-process adapters and scripted planners, with no network/provider/native interaction. Real model/native acceptance remains open.
