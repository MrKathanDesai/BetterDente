import SwiftUI

@main
struct BetterDenteApp: App {
    @StateObject private var controller = ChargingController()
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(controller)
        } label: {
            HStack(spacing: 4) {
                // 1. Icon
                if controller.menuBarIconStyle == .nativeBattery {
                    Image(systemName: getBatterySystemName())
                }
                
                // 2. Stats String (Flattened for stability)
                let statsString = [
                    controller.showMenuBarPercentage ? "\(controller.batteryManager.currentPercentage)%" : nil,
                    controller.showMenuBarWattage ? "\(String(format: "%.1f", abs(controller.batteryManager.wattage)))W" : nil,
                    controller.showMenuBarTemperature ? "\(String(format: "%.1f", controller.batteryManager.temperature))°C" : nil
                ].compactMap { $0 }.joined(separator: " ")
                
                if !statsString.isEmpty {
                    Text(statsString)
                }
            }
        }
        .menuBarExtraStyle(.window)
        
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(controller)
        }
    }
    
    private func getBatterySystemName() -> String {
        let level = controller.batteryManager.currentPercentage
        let isCharging = controller.batteryManager.isCharging
        
        // Match macOS native battery segments
        if isCharging {
            if level >= 100 { return "battery.100.bolt" }
            if level >= 75 { return "battery.75.bolt" }
            if level >= 50 { return "battery.50.bolt" }
            if level >= 25 { return "battery.25.bolt" }
            return "battery.0.bolt"
        } else {
            if level >= 100 { return "battery.100" }
            if level >= 75 { return "battery.75" }
            if level >= 50 { return "battery.50" }
            if level >= 25 { return "battery.25" }
            if level >= 10 { return "battery.0" }
            return "battery.0" // low battery matches empty
        }
    }
}
