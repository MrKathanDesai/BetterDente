import SwiftUI

struct ContentView: View {
    @EnvironmentObject var controller: ChargingController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Charge Limiter")
                    .font(.headline)
                Spacer()
                
                // Pulse indicator showing the app is alive
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .opacity(pulseOpacity)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseOpacity)
                    .onAppear { pulseOpacity = 0.3 }
                
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider()
            
            // Battery Status
            HStack {
                VStack(alignment: .leading) {
                    Text("Battery Level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(controller.batteryManager.currentPercentage)%")
                            .font(.system(size: 32, weight: .bold))
                        
                        statusBadge
                    }
                }
                Spacer()
                
                HStack(spacing: 8) {
                    if controller.activeState == .disabled {
                        Image(systemName: "powerplug.fill").foregroundColor(.blue).font(.system(size: 16))
                    } else if controller.activeState == .overheating {
                        Image(systemName: "thermometer.sun.fill").foregroundColor(.red).font(.system(size: 16))
                    } else if controller.activeState == .discharging {
                        Image(systemName: "arrow.down.circle.fill").foregroundColor(.orange).font(.system(size: 16))
                    }
                    
                    LiquidBatteryView(
                        percentage: Double(controller.batteryManager.currentPercentage) / 100.0,
                        fillColor: batteryFillColor,
                        isChargingState: isActivelyCharging
                    )
                    .frame(height: 54)
                }
            }
            .padding(.vertical, 4)
            
            // Mini Power Dashboard
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    // Power
                    let batteryWatts = controller.batteryManager.wattage
                    let isDraining = batteryWatts < 0
                    miniStat(
                        icon: "bolt.fill",
                        value: String(format: "%.1fW", abs(batteryWatts)),
                        color: isDraining ? .orange : .green
                    )
                    
                    // Temperature
                    let tempHot = controller.batteryManager.temperature >= Double(controller.heatProtectionThreshold) && controller.isHeatProtectionEnabled
                    miniStat(
                        icon: "thermometer",
                        value: String(format: "%.1f°C", controller.batteryManager.temperature),
                        color: tempHot ? .red : .secondary
                    )
                    
                    // Health
                    let health = controller.batteryManager.batteryHealthPercent
                    miniStat(
                        icon: "heart.fill",
                        value: String(format: "%.0f%%", health),
                        color: health >= 80 ? .green : (health >= 60 ? .yellow : .red)
                    )
                    
                    // Cycles
                    miniStat(
                        icon: "arrow.triangle.2.circlepath",
                        value: "\(controller.batteryManager.cycleCount)",
                        color: .secondary
                    )
                }
                
                // Time remaining / adapter info
                let timeStr = controller.batteryManager.timeRemainingFormatted
                if !timeStr.isEmpty {
                    Text(timeStr)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Color(.separatorColor).opacity(0.2))
            .cornerRadius(6)
            
            Divider()
            
            // Controls
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable Charge Limiter", isOn: $controller.isLimiterEnabled)
                    .toggleStyle(SwitchToggleStyle())
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Charge Limit")
                        Spacer()
                        Text("\(controller.chargeLimit)%")
                            .bold()
                    }
                    Slider(value: Binding(
                        get: { Double(controller.chargeLimit) },
                        set: { controller.chargeLimit = Int($0) }
                    ), in: 40...100, step: 1)
                    .disabled(!controller.isLimiterEnabled)
                }
                
                Toggle("Top Up to 100%", isOn: Binding(
                    get: { controller.isTopUpActive },
                    set: { newValue in
                        if newValue {
                            controller.forceCharge100()
                        } else {
                            controller.isTopUpActive = false
                        }
                    }
                ))
                .toggleStyle(.button)
                .buttonStyle(.borderedProminent)
                .tint(controller.isTopUpActive ? .green : .blue)
                .frame(maxWidth: .infinity)
                .disabled(!controller.isLimiterEnabled)
            }
            
            // Debug actions
            Divider()
            DisclosureGroup("Advanced Debug") {
                VStack(spacing: 8) {
                    Button("Manual Disable SMC Charge") {
                        ServiceManager.shared.testDisableCharging()
                    }
                    Button("Manual Enable SMC Charge") {
                        ServiceManager.shared.testEnableCharging()
                    }
                    Button("Fix Helper Tool Installation") {
                        ServiceManager.shared.installDaemon()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Computed Helpers
    
    @State private var pulseOpacity: Double = 1.0
    
    private var isActivelyCharging: Bool {
        let state = controller.activeState
        return state == .charging || state == .topUp || state == .calibrating
    }
    
    private func miniStat(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var batteryFillColor: Color {
        let state = controller.activeState
        if state == .discharging { return .orange }
        if state == .disabled { return .blue }
        if state == .overheating { return .red }
        if isActivelyCharging { return .green }
        return Color.primary
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if let state = controller.activeState {
            let stateColor: Color = {
                switch state {
                case .charging: return .green
                case .disabled: return .blue
                case .topUp: return .green
                case .discharging: return .orange
                case .overheating: return .red
                case .calibrating: return .purple
                }
            }()
            
            Text(state.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(stateColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(stateColor.opacity(0.15))
                .cornerRadius(4)
        } else if !controller.batteryManager.isPluggedIn {
            Text("On Battery")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
    }
}

// MARK: - Animated Battery View

struct LiquidBatteryView: View {
    var percentage: Double // 0.0 to 1.0
    var fillColor: Color
    var isChargingState: Bool
    
    @State private var phase: Double = 0
    @State private var isAnimating: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background outline of the battery
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(.windowBackgroundColor)))
                
                // The liquid fill
                LiquidWave(phase: phase, fillLevel: percentage)
                    .fill(fillColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                
                // Reflection/Glass effect overlay
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.0)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Percentage text centered
                Text("\(Int(percentage * 100))")
                    .font(.system(size: geometry.size.height * 0.4, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.2)
                    .lineLimit(1)
                    .foregroundColor(percentage > 0.4 ? .white : .primary)
                    .shadow(color: .black.opacity(percentage > 0.4 ? 0.3 : 0.0), radius: 1, x: 0, y: 1)
            }
            .onAppear {
                startAnimation()
            }
            .onChange(of: isChargingState) { _ in
                // Only restart when charging state actually changes
                startAnimation()
            }
        }
        .aspectRatio(0.45, contentMode: .fit) // Tall battery shape
        // Add the top nub
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 8, height: 4)
                .offset(y: -2),
            alignment: .top
        )
    }
    
    private func startAnimation() {
        phase = 0
        withAnimation(.linear(duration: isChargingState ? 1.5 : 4.0).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }
    }
}

// Sine wave path generator
struct LiquidWave: Shape {
    var phase: Double
    var fillLevel: Double // 0.0 to 1.0
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = Double(rect.width)
        let height = Double(rect.height)
        
        let waveHeight = height * 0.05 // Amplitude
        // Map fillY so that at 0.0 the highest wave peak is below the battery, and at 1.0 the lowest wave valley is above the battery.
        let fillY = height + waveHeight - (fillLevel * (height + 2 * waveHeight))
        
        path.move(to: CGPoint(x: 0, y: height))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * .pi * 2 + phase)
            let y = fillY + waveHeight * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}
