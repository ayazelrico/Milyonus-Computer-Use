# Example native-host integration

`ComputerUseIntegration.ComputerUseSessionCoordinator` is a generic integration
boundary. Keep it disabled by default and supply a dedicated managed client and
a selection-suspension hook. Only the explicit `computerUse` entry mode may
start a fixture session. Other host modes must remain unprivileged.

The coordinator cannot grant native approval. Preserve session ownership,
foreground, cancellation and target checks. Shut down the dedicated connection
when its native owner closes. A successful unit test is not host acceptance.

`XPCFactoryExample.swift` illustrates trusted local factory wiring. The service
must already be registered and its signing policy supplied locally. Production
identity and lifecycle validation remain the integrating application's responsibility.
