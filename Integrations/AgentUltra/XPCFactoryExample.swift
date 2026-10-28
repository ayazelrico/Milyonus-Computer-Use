import ComputerUseClient
import ComputerUseIntegration
import ComputerUseIPC

/// Trusted native-host configuration only. Keep the feature disabled by default.
/// The service must already be independently registered and its signing policy supplied locally.
@MainActor
func makeXPCComputerUseCoordinator(
    enabled: Bool = false,
    serviceName: String,
    peer: BrokerPeerIdentity,
    suspendSelection: @escaping @MainActor (Bool) -> Void
) -> ComputerUseSessionCoordinator {
    ComputerUseSessionCoordinator(enabled: enabled, clientFactory: {
        XPCSessionClient(serviceName: serviceName, peer: peer, allowFixtureActions: true)
    }, selectionSuspension: suspendSelection)
}
