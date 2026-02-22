import Foundation

@objc protocol BetterDenteXPCProtocol {
    func disableCharging(withReply reply: @escaping (Bool) -> Void)
    func enableCharging(withReply reply: @escaping (Bool) -> Void)
    func forceDischarge(withReply reply: @escaping (Bool) -> Void)
}
