import Foundation
import ServiceManagement
import os.log

let logger = Logger(subsystem: "com.betterdente.BetterDente", category: "ServiceManager")

class ServiceManager {
    static let shared = ServiceManager()
    
    private var connection: NSXPCConnection?
    
    private func getProxy() -> BetterDenteXPCProtocol? {
        if connection == nil {
            let conn = NSXPCConnection(machServiceName: "com.betterdente.BetterDenteHelper", options: .privileged)
            conn.remoteObjectInterface = NSXPCInterface(with: BetterDenteXPCProtocol.self)
            conn.invalidationHandler = { [weak self] in
                logger.warning("XPC connection invalidated. Will reconnect on next call.")
                self?.connection = nil
            }
            conn.interruptionHandler = { [weak self] in
                logger.warning("XPC connection interrupted. Will reconnect on next call.")
                self?.connection = nil
            }
            conn.resume()
            connection = conn
        }
        
        return connection?.remoteObjectProxyWithErrorHandler { error in
            logger.error("XPC Connection Error: \(error.localizedDescription, privacy: .public)")
        } as? BetterDenteXPCProtocol
    }
    
    func installDaemon() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.daemon(plistName: "com.betterdente.BetterDenteHelper.plist")
            do {
                if service.status == .requiresApproval {
                    logger.warning("Daemon requires user approval in Settings.")
                }
                try service.register()
                logger.notice("Successfully registered daemon.")
            } catch {
                logger.error("Failed to register daemon: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            logger.error("macOS 13.0 or later is required for SMAppService")
        }
    }
    
    func testDisableCharging() {
        getProxy()?.disableCharging { success in
            logger.notice("Disable Charging Response: \(success)")
        }
    }
    
    func testEnableCharging() {
        getProxy()?.enableCharging { success in
            logger.notice("Enable Charging Response: \(success)")
        }
    }
    
    func testForceDischarge() {
        getProxy()?.forceDischarge { success in
            logger.notice("Force Discharge Response: \(success)")
        }
    }
}
