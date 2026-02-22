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
                Image(systemName: "battery.100.bolt")
                switch controller.menuBarDisplayMode {
                case .iconOnly:
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
}
