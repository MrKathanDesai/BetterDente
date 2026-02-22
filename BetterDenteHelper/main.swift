import Foundation

class BetterDenteHelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: BetterDenteXPCProtocol.self)
        newConnection.exportedObject = BetterDenteHelper()
        newConnection.resume()
        return true
    }
}

class BetterDenteHelper: NSObject, BetterDenteXPCProtocol {
    override init() {
        super.init()
        do {
            try SMCKit.open()
            print("SMCKit Connection Opened Successfully in Helper")
        } catch {
            print("Failed to open SMCKit: \(error)")
        }
    }
    
    func disableCharging(withReply reply: @escaping (Bool) -> Void) {
        do {
            let chteCode = FourCharCode(fromString: "CHTE")
            let chteInfo = DataType(type: FourCharCode(fromStaticString: "ui32"), size: 4)
            let chteKey = SMCKey(code: chteCode, info: chteInfo)
            var chteBytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            chteBytes.0 = 0x01
            try SMCKit.writeData(chteKey, data: chteBytes)
            
            // Explicitly enable adapter power in case we were discharging
            let chieCode = FourCharCode(fromString: "CHIE")
            let chieInfo = DataType(type: FourCharCode(fromStaticString: "hex_"), size: 1)
            let chieKey = SMCKey(code: chieCode, info: chieInfo)
            let chieBytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            try? SMCKit.writeData(chieKey, data: chieBytes)
            
            reply(true)
        } catch {
            print("Failed to disable charging: \(error)")
            reply(false)
        }
    }
    
    func enableCharging(withReply reply: @escaping (Bool) -> Void) {
        do {
            let chteCode = FourCharCode(fromString: "CHTE")
            let chteInfo = DataType(type: FourCharCode(fromStaticString: "ui32"), size: 4)
            let chteKey = SMCKey(code: chteCode, info: chteInfo)
            let chteBytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            try SMCKit.writeData(chteKey, data: chteBytes)
            
            // Explicitly enable adapter power
            let chieCode = FourCharCode(fromString: "CHIE")
            let chieInfo = DataType(type: FourCharCode(fromStaticString: "hex_"), size: 1)
            let chieKey = SMCKey(code: chieCode, info: chieInfo)
            let chieBytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            try? SMCKit.writeData(chieKey, data: chieBytes)
            
            reply(true)
        } catch {
            print("Failed to enable charging: \(error)")
            reply(false)
        }
    }
    
    func forceDischarge(withReply reply: @escaping (Bool) -> Void) {
        do {
            // First stop charging
            let chteCode = FourCharCode(fromString: "CHTE")
            let chteInfo = DataType(type: FourCharCode(fromStaticString: "ui32"), size: 4)
            let chteKey = SMCKey(code: chteCode, info: chteInfo)
            var chteBytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            chteBytes.0 = 0x01
            try SMCKit.writeData(chteKey, data: chteBytes)
            
            // Then disable AC adapter power
            let chieCode = FourCharCode(fromString: "CHIE")
            let chieInfo = DataType(type: FourCharCode(fromStaticString: "hex_"), size: 1)
            let chieKey = SMCKey(code: chieCode, info: chieInfo)
            var chieBytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
            chieBytes.0 = 0x08
            try SMCKit.writeData(chieKey, data: chieBytes)
            
            reply(true)
        } catch {
            print("Failed to force discharge: \(error)")
            reply(false)
        }
    }
}

let delegate = BetterDenteHelperDelegate()
let listener = NSXPCListener(machServiceName: "com.kathandesai.BetterDenteHelper")
listener.delegate = delegate
listener.resume()

// Keep the daemon running
RunLoop.main.run()
