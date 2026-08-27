import QtQuick

// Guarded wrapper around the Phase 8I NETWORK surface.
// The base dashboard owns rendering and backend process execution. This wrapper
// enforces request/result interface coherence so a completed scan from a
// previously selected adapter can never be rendered as the current adapter.
NetworkDashboard {
    id: root

    property bool coherenceCheckScheduled: false

    function scheduleScanCoherenceCheck() {
        if (coherenceCheckScheduled) return
        coherenceCheckScheduled = true

        Qt.callLater(function() {
            root.coherenceCheckScheduled = false

            var scanObject = root.wifiScan || {}
            var resultIface = ((scanObject.interface || {}).name || "")
            var selectedIface = root.selectedWifiIface || ""

            if (resultIface.length === 0 || selectedIface.length === 0 || resultIface === selectedIface)
                return

            var staleIface = resultIface

            // Clear the stale result only. No backend mutation is performed.
            root.wifiScan = ({
                scan: {
                    ready: false,
                    blocked_reasons: [],
                    access_point_count: 0
                },
                access_points: [],
                interface: {}
            })
            root.selectedApIndex = -1
            root.scanBusy = false
            root.scanMessage = "Discarded stale " + staleIface + " scan; refreshing " + selectedIface + "…"

            if (root.backend && typeof root.backend.log === "function")
                root.backend.log("Discarded stale NETWORK scan for " + staleIface + "; selected adapter is " + selectedIface)

            // The prior Process has exited by the time this deferred check runs,
            // so it is now safe to launch the scan for the current selection.
            if (root.visible) {
                Qt.callLater(function() {
                    if (root.visible && root.selectedWifiIface === selectedIface)
                        root.refreshScan()
                })
            }
        })
    }

    onWifiScanChanged: scheduleScanCoherenceCheck()
    onSelectedWifiIfaceChanged: scheduleScanCoherenceCheck()
}
