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
                // Main Icon logic
                if controller.menuBarDisplayMode == .batteryNative {
                    Image(systemName: getBatterySystemName())
                } else if controller.menuBarDisplayMode == .appLogo {
                    Image(systemName: "bolt.shield.fill")
                } else {
                    Image(systemName: "bolt.battery.block.fill")
                }
                
                // Optional Text logic
                switch controller.menuBarDisplayMode {
                case .iconOnly, .appLogo, .batteryNative:
                    EmptyView()
                case .wattage:
                    Text("\(String(format: "%.1f", abs(controller.batteryManager.wattage)))W")
                case .temperature:
                    Text("\(String(format: "%.1f", controller.batteryManager.temperature))°C")
                case .percentage:
                    Text("\(controller.batteryManager.currentPercentage)%")
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
        
        if isCharging {
            if level >= 95 { return "battery.100.bolt" }
            if level >= 75 { return "battery.75.bolt" }
            if level >= 50 { return "battery.50.bolt" }
            return "battery.25.bolt"
        } else {
            if level >= 95 { return "battery.100" }
            if level >= 75 { return "battery.75" }
            if level >= 50 { return "battery.50" }
            if level >= 25 { return "battery.25" }
            return "battery.0"
        }
    }
}
