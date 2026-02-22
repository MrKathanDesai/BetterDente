import SwiftUI
import Charts
struct SettingsView: View {
    @EnvironmentObject var controller: ChargingController
    @State private var selectedTimeRange: HistoryTimeRange = .fiveMinutes
    
    var body: some View {
        TabView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Discharge Behavior
                    GroupBox(label: Text("Discharge Behavior").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Automatic Discharge", isOn: $controller.isDischargeEnabled)
                                .disabled(!controller.isLimiterEnabled)
                            Text("If enabled, the Mac will force a discharge event when the battery is above the charge limit.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                            if !controller.isDischargeEnabled {
                                Button("Discharge to Limit Now") {
                                    ServiceManager.shared.testForceDischarge()
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Sailing Mode
                    GroupBox(label: Text("Sailing Mode").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Enable Sailing Mode", isOn: $controller.isSailingModeEnabled)
                                .disabled(!controller.isLimiterEnabled)
                            
                            if controller.isSailingModeEnabled {
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Sailing Drop")
                                        Spacer()
                                        Text("\(controller.sailingDrop)%")
                                    }
                                    Slider(value: Binding(
                                        get: { Double(controller.sailingDrop) },
                                        set: { controller.sailingDrop = Int($0) }
                                    ), in: 2...20, step: 1)
                                    .disabled(!controller.isLimiterEnabled)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Text("Allows the battery to naturally drop by this amount before resuming charge.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Heat Protection
                    GroupBox(label: Text("Heat Protection").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Enable Heat Protection", isOn: $controller.isHeatProtectionEnabled)
                                .disabled(!controller.isLimiterEnabled)
                            
                            if controller.isHeatProtectionEnabled {
                                VStack(spacing: 4) {
                                    HStack {
                                        Text("Max Temperature")
                                        Spacer()
                                        Text("\(controller.heatProtectionThreshold)°C")
                                    }
                                    Slider(value: Binding(
                                        get: { Double(controller.heatProtectionThreshold) },
                                        set: { controller.heatProtectionThreshold = Int($0) }
                                    ), in: 25...45, step: 1)
                                    .disabled(!controller.isLimiterEnabled)
                                }
                                .padding(.vertical, 4)
                            }
                            Text("Pauses charging if the battery exceeds this temperature.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Sleep Management
                    GroupBox(label: Text("Sleep Management").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Stop Charging When Sleeping", isOn: $controller.isStopChargingWhenSleepingEnabled)
                                .disabled(!controller.isLimiterEnabled)
                            
                            Text("When enabled, your MacBook will pause charging right before it goes to sleep to prevent it from bypassing the charge limit while asleep.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                            Divider().padding(.vertical, 4)
                            
                            Toggle("Disable Sleep until Target Reached", isOn: $controller.isDisableSleepEnabled)
                                .disabled(!controller.isLimiterEnabled)
                                
                            Text("If the MacBook needs to actively charge or discharge to reach your target percentage, it will automatically prevent sleep until the target is reached.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Menu Bar Customization
                    GroupBox(label: Text("Menu Bar Display").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Customize what appears next to the battery icon in your Mac's menu bar.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker("Display Mode", selection: $controller.menuBarDisplayMode) {
                                ForEach(ChargingController.MenuBarDisplayMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // App Exceptions
                    GroupBox(label: Text("Smart App Exceptions").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("App Names (e.g. Final Cut Pro, Xcode)", text: $controller.appExceptionsList)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .disabled(!controller.isLimiterEnabled)
                            
                            Text("If any of these applications are currently running, the charge limit is temporarily ignored and the Mac is allowed to charge to 100% for maximum performance. Separate exact names by commas.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Advanced
                    GroupBox(label: Text("Advanced").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Use Hardware Battery Percentage", isOn: $controller.useHardwareBatteryPercentage)
                            
                            Text("Displays the raw hardware battery capacity instead of macOS's rounded percentage. This is often more accurate but may occasionally jump.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                }
                .padding(20)
            }
            .tabItem {
                Label("Advanced", systemImage: "gearshape.2")
            }
            
            // Calibration Tab
            ScrollView {
                VStack(spacing: 20) {
                    GroupBox(label: Text("Battery Calibration").font(.headline)) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calibration ensures your Mac's Battery Management System accurately reports capacity.")
                                .font(.subheadline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("The automated process will:")
                                    .fontWeight(.semibold)
                                Text("1. Charge your battery to 100%.")
                                Text("2. Enforce a discharge down to 15%.")
                                Text("3. Recharge back to 100%.")
                                Text("4. Hold at 100% for 1 hour.")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Current Status:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(controller.calibrationState.rawValue)
                                        .font(.headline)
                                        .foregroundColor(controller.calibrationState == .inactive ? .primary : .purple)
                                }
                                Spacer()
                                
                                if controller.calibrationState == .inactive {
                                    Button("Start Calibration") {
                                        controller.startCalibration()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.purple)
                                    .disabled(!controller.isLimiterEnabled)
                                } else {
                                    Button("Stop Calibration") {
                                        controller.stopCalibration()
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .tabItem {
                Label("Calibration", systemImage: "arrow.triangle.2.circlepath")
            }
            // Power Insights Tab — AlDente-style Dashboard
            ScrollView {
                VStack(spacing: 14) {
                    
                    // ═══ ROW 1: Three Info Cards ═══
                    HStack(spacing: 10) {
                        // ⚡ Battery Specs
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Battery Specs", systemImage: "bolt.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.primary)
                                Divider()
                                specRow("Current:", String(format: "%.2f A", controller.batteryManager.amperage))
                                specRow("Voltage:", String(format: "%.2f V", controller.batteryManager.voltage))
                                specRow("Power:", String(format: "%.1f W", abs(controller.batteryManager.wattage)))
                                specRow("System Load:", String(format: "%.1f W", controller.batteryManager.averagePowerW))
                            }
                        }
                        
                        // ♥ Battery Health
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Battery Health", systemImage: "heart.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.pink)
                                Divider()
                                specRow("Design Capacity:", "\(controller.batteryManager.designCapacity) mAh")
                                specRow("Max Capacity:", "\(controller.batteryManager.rawMaxCapacity) mAh")
                                specRow("macOS Condition:", controller.batteryManager.batteryCondition)
                                specRow("Cycle Count:", "\(controller.batteryManager.cycleCount)")
                            }
                        }
                        
                        // 🔌 Adapter Specs
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Power Adapter", systemImage: "powerplug.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                                Divider()
                                let adapterName = controller.batteryManager.adapterName.isEmpty ? "—" : controller.batteryManager.adapterName
                                specRow("Name:", adapterName)
                                specRow("Power:", controller.batteryManager.isPluggedIn ? String(format: "%.1f W", controller.batteryManager.adapterWattage) : "0 W")
                                specRow("Max:", controller.batteryManager.adapterMaxWattage > 0 ? "\(controller.batteryManager.adapterMaxWattage) W" : "—")
                                specRow("Status:", controller.batteryManager.isPluggedIn ? "Connected" : "Disconnected")
                            }
                        }
                    }
                    
                    // ═══ POWER FLOW VISUAL ═══
                    dashboardCard {
                        let bm = controller.batteryManager
                        let adapterW = bm.adapterTotalPowerW
                        let batteryW = bm.batteryChargingPowerW
                        let systemW = bm.systemPowerW
                        let totalW = max(1, batteryW + systemW)
                        
                        if bm.isPluggedIn && adapterW > 0 {
                            HStack(spacing: 0) {
                                // Left: Adapter
                                VStack(spacing: 2) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.0fW", adapterW))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .frame(width: 50)
                                
                                // Divider bar
                                Rectangle()
                                    .fill(Color(.separatorColor).opacity(0.5))
                                    .frame(width: 2, height: 55)
                                    .padding(.horizontal, 4)
                                
                                // Right: Split bars
                                VStack(spacing: 6) {
                                    // Battery charging bar
                                    HStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(colors: [Color.green.opacity(0.6), Color.green.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .frame(width: max(20, CGFloat(batteryW / totalW) * 300), height: 22)
                                            .overlay(
                                                HStack {
                                                    Text(String(format: "%.1f W", batteryW))
                                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                    Image(systemName: "battery.100.bolt")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.white.opacity(0.8))
                                                }
                                                .padding(.horizontal, 6)
                                            )
                                        Spacer(minLength: 0)
                                    }
                                    
                                    // System power bar
                                    HStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .frame(width: max(20, CGFloat(systemW / totalW) * 300), height: 22)
                                            .overlay(
                                                HStack {
                                                    Text(String(format: "%.1f W", systemW))
                                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(.white)
                                                    Spacer()
                                                    Image(systemName: "laptopcomputer")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.white.opacity(0.8))
                                                }
                                                .padding(.horizontal, 6)
                                            )
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                        } else {
                            // Not plugged in — show battery draining
                            HStack(spacing: 8) {
                                Image(systemName: "battery.50")
                                    .font(.system(size: 20))
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Running on Battery")
                                        .font(.system(size: 11, weight: .medium))
                                    Text(String(format: "%.1f W system drain", abs(bm.wattage)))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    // ═══ ROW 2: Battery Level + Temperature Charts ═══
                    HStack(spacing: 10) {
                        // Battery Level Chart
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Battery Level")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("\(controller.batteryManager.currentPercentage) %")
                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 0) {
                                        let timeStr = controller.batteryManager.timeRemainingFormatted
                                        if !timeStr.isEmpty {
                                            Text(timeStr)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                        }
                                        Image(systemName: controller.batteryManager.isPluggedIn ? "battery.100.bolt" : "battery.75")
                                            .font(.system(size: 20))
                                            .foregroundColor(controller.batteryManager.isCharging ? .green : .primary)
                                    }
                                }
                                
                                let data = controller.powerHistory.downsampledSnapshots(for: selectedTimeRange)
                                if data.count < 2 {
                                    chartPlaceholder
                                } else {
                                    Chart(data) { item in
                                        AreaMark(x: .value("T", item.timestamp), y: .value("%", item.percentage))
                                            .foregroundStyle(
                                                LinearGradient(colors: [Color.green.opacity(0.4), Color.green.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                                            )
                                            .interpolationMethod(.monotone)
                                        LineMark(x: .value("T", item.timestamp), y: .value("%", item.percentage))
                                            .foregroundStyle(Color.green)
                                            .interpolationMethod(.monotone)
                                            .lineStyle(StrokeStyle(lineWidth: 2))
                                        RuleMark(y: .value("Limit", controller.chargeLimit))
                                            .foregroundStyle(Color.red.opacity(0.4))
                                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                    }
                                    .chartYScale(domain: 0...100)
                                    .chartYAxis {
                                        AxisMarks(position: .trailing, values: [0, 25, 50, 75, 100]) { value in
                                            AxisValueLabel {
                                                Text("\(value.as(Int.self) ?? 0)")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                            }
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(date, format: .dateTime.hour().minute())
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 100)
                                }
                            }
                        }
                        
                        // Temperature Chart
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Battery Temperature")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f °C", controller.batteryManager.temperature))
                                            .font(.system(size: 26, weight: .bold, design: .rounded))
                                            .foregroundColor(controller.batteryManager.temperature > 35 ? .orange : .primary)
                                    }
                                    Spacer()
                                    Image(systemName: "thermometer.medium")
                                        .font(.system(size: 20))
                                        .foregroundColor(controller.batteryManager.temperature > 35 ? .orange : .secondary)
                                }
                                
                                let data = controller.powerHistory.downsampledSnapshots(for: selectedTimeRange)
                                if data.count < 2 {
                                    chartPlaceholder
                                } else {
                                    Chart {
                                        ForEach(data) { item in
                                            AreaMark(x: .value("T", item.timestamp), y: .value("°C", item.temperature))
                                                .foregroundStyle(
                                                    LinearGradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                                )
                                                .interpolationMethod(.catmullRom)
                                            LineMark(x: .value("T", item.timestamp), y: .value("°C", item.temperature))
                                                .foregroundStyle(Color.blue)
                                                .interpolationMethod(.catmullRom)
                                                .lineStyle(StrokeStyle(lineWidth: 2))
                                        }
                                        if controller.isHeatProtectionEnabled {
                                            RuleMark(y: .value("Max", controller.heatProtectionThreshold))
                                                .foregroundStyle(Color.red.opacity(0.5))
                                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(position: .trailing) { value in
                                            AxisValueLabel {
                                                Text("\(value.as(Int.self) ?? 0)")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.secondary)
                                            }
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(date, format: .dateTime.hour().minute())
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 100)
                                }
                            }
                        }
                    }
                    
                    // ═══ ROW 3: Power Draw + Power Stats ═══
                    dashboardCard {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("Power Draw")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    let w = controller.batteryManager.wattage
                                    Text(String(format: "%.1f W", abs(w)))
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(w < 0 ? .orange : (w == 0 ? .primary : .green))
                                }
                                Spacer()
                                // Stat pills
                                HStack(spacing: 12) {
                                    statPill(label: "Avg", value: String(format: "%.1fW", controller.batteryManager.averagePowerW))
                                    statPill(label: "Peak", value: String(format: "%.1fW", controller.batteryManager.peakPowerW))
                                    statPill(label: "Energy", value: String(format: "%.1fWh", controller.batteryManager.todayEnergyWh))
                                    statPill(label: "Session", value: controller.batteryManager.sessionDurationFormatted)
                                }
                            }
                            
                            let data = controller.powerHistory.downsampledSnapshots(for: selectedTimeRange)
                            if data.count < 2 {
                                chartPlaceholder
                            } else {
                                Chart(data) { item in
                                    AreaMark(x: .value("T", item.timestamp), y: .value("W", item.wattage))
                                        .foregroundStyle(
                                            LinearGradient(colors: [
                                                (item.wattage < 0 ? Color.orange : Color.green).opacity(0.35),
                                                .clear
                                            ], startPoint: .top, endPoint: .bottom)
                                        )
                                        .interpolationMethod(.catmullRom)
                                    LineMark(x: .value("T", item.timestamp), y: .value("W", item.wattage))
                                        .foregroundStyle(item.wattage < 0 ? Color.orange : Color.green)
                                        .interpolationMethod(.catmullRom)
                                        .lineStyle(StrokeStyle(lineWidth: 2))
                                }
                                .chartYAxis {
                                    AxisMarks(position: .trailing) { value in
                                        AxisValueLabel {
                                            Text("\(value.as(Int.self) ?? 0)")
                                                .font(.system(size: 9)).foregroundColor(.secondary)
                                        }
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                            .foregroundStyle(Color.secondary.opacity(0.3))
                                    }
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                                        AxisValueLabel {
                                            if let date = value.as(Date.self) {
                                                Text(date, format: .dateTime.hour().minute())
                                                    .font(.system(size: 9)).foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 100)
                            }
                        }
                    }
                    
                    // ═══ ROW 4: Apps Using Energy + Time Range ═══
                    HStack(spacing: 10) {
                        // Apps Using Energy
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Apps Using Significant Energy", systemImage: "flame.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.orange)
                                Divider()
                                if controller.batteryManager.topEnergyApps.isEmpty {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
                                        Text("No Apps Using Significant Energy")
                                            .font(.system(size: 11)).foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 6)
                                } else {
                                    ForEach(controller.batteryManager.topEnergyApps) { app in
                                        HStack {
                                            Image(systemName: "app.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                            Text(app.name)
                                                .font(.system(size: 11))
                                                .lineLimit(1)
                                            Spacer()
                                            Text(String(format: "%.1f%%", app.cpuPercent))
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .foregroundColor(app.cpuPercent > 50 ? .red : (app.cpuPercent > 10 ? .orange : .secondary))
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Time Range + Session Info
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Time Range")
                                    .font(.system(size: 11, weight: .bold))
                                Picker("", selection: $selectedTimeRange) {
                                    ForEach(HistoryTimeRange.allCases) { range in
                                        Text(range.label).tag(range)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .labelsHidden()
                                
                                Divider()
                                specRow("Session Time:", controller.batteryManager.sessionDurationFormatted)
                                specRow("Data Points:", "\(controller.powerHistory.snapshots.count)")
                            }
                        }
                    }
                    
                    // ═══ ROW 5: Cycle Count + Max Capacity ═══
                    HStack(spacing: 10) {
                        // Cycle Count
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Battery Cycles")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Text("\(controller.batteryManager.cycleCount) Cycles")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                
                                let logs = controller.healthLogManager.logs
                                if logs.count >= 2 {
                                    Chart(logs) { log in
                                        AreaMark(x: .value("Date", log.date), y: .value("Cycles", log.cycleCount))
                                            .foregroundStyle(
                                                LinearGradient(colors: [Color.red.opacity(0.3), Color.red.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                            )
                                            .interpolationMethod(.monotone)
                                        LineMark(x: .value("Date", log.date), y: .value("Cycles", log.cycleCount))
                                            .foregroundStyle(Color.red)
                                            .interpolationMethod(.monotone)
                                            .lineStyle(StrokeStyle(lineWidth: 2))
                                    }
                                    .chartXAxis(.hidden)
                                    .chartYAxis {
                                        AxisMarks(position: .trailing) { _ in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                        }
                                    }
                                    .frame(height: 60)
                                } else {
                                    chartPlaceholderSmall
                                }
                            }
                        }
                        
                        // Maximum Capacity
                        dashboardCard {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Maximum Capacity")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.pink)
                                }
                                Text(String(format: "%.0f %%", controller.batteryManager.batteryHealthPercent))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(healthColor)
                                
                                let logs = controller.healthLogManager.logs
                                if logs.count >= 2 {
                                    Chart(logs) { log in
                                        AreaMark(x: .value("Date", log.date), y: .value("mAh", log.rawMaxCapacity))
                                            .foregroundStyle(
                                                LinearGradient(colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                                            )
                                            .interpolationMethod(.monotone)
                                        LineMark(x: .value("Date", log.date), y: .value("mAh", log.rawMaxCapacity))
                                            .foregroundStyle(Color.orange)
                                            .interpolationMethod(.monotone)
                                            .lineStyle(StrokeStyle(lineWidth: 2))
                                    }
                                    .chartXAxis(.hidden)
                                    .chartYAxis {
                                        AxisMarks(position: .trailing) { _ in
                                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                                                .foregroundStyle(Color.secondary.opacity(0.3))
                                        }
                                    }
                                    .frame(height: 60)
                                } else {
                                    chartPlaceholderSmall
                                }
                            }
                        }
                    }
                    
                }
                .padding(14)
            }
            .tabItem {
                Label("Insights", systemImage: "bolt.circle")
            }
            
            // Schedule Tab
            ScrollView {
                VStack(spacing: 20) {
                    Text("Schedules only run while BetterDente is open.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    GroupBox(label: Text("Scheduled Top Up").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Top Up to 100%", isOn: $controller.isScheduledTopUpEnabled)
                                .disabled(!controller.isLimiterEnabled)
                            
                            if controller.isScheduledTopUpEnabled {
                                HStack {
                                    Stepper("Every \(controller.scheduledTopUpInterval) days", value: $controller.scheduledTopUpInterval, in: 1...90)
                                    Spacer()
                                    Text("(Recommended: 14)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                let daysSince = controller.lastScheduledTopUp == 0 ? "Never" : String(format: "%.1f", (Date().timeIntervalSince1970 - controller.lastScheduledTopUp) / 86400)
                                Text("Last run: \(daysSince) days ago")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    GroupBox(label: Text("Scheduled Calibration").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Run Full Calibration", isOn: $controller.isScheduledCalibrationEnabled)
                                .disabled(!controller.isLimiterEnabled)
                            
                            if controller.isScheduledCalibrationEnabled {
                                HStack {
                                    Stepper("Every \(controller.scheduledCalibrationInterval) days", value: $controller.scheduledCalibrationInterval, in: 7...180)
                                    Spacer()
                                    Text("(Recommended: 30)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                let daysSince = controller.lastScheduledCalibration == 0 ? "Never" : String(format: "%.1f", (Date().timeIntervalSince1970 - controller.lastScheduledCalibration) / 86400)
                                Text("Last run: \(daysSince) days ago")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    GroupBox(label: Text("Scheduled Discharge").font(.headline)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Discharge to Limit", isOn: $controller.isScheduledDischargeEnabled)
                                .disabled(!controller.isLimiterEnabled)
                            
                            if controller.isScheduledDischargeEnabled {
                                HStack {
                                    Stepper("Every \(controller.scheduledDischargeInterval) days", value: $controller.scheduledDischargeInterval, in: 1...90)
                                    Spacer()
                                    Text("(Recommended: 14)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                let daysSince = controller.lastScheduledDischarge == 0 ? "Never" : String(format: "%.1f", (Date().timeIntervalSince1970 - controller.lastScheduledDischarge) / 86400)
                                Text("Last run: \(daysSince) days ago")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .tabItem {
                Label("Schedule", systemImage: "calendar.badge.clock")
            }
            
            // Health Tab
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Battery Health History")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Maximum Capacity")
                                .font(.headline)
                            Text("\(controller.batteryManager.rawMaxCapacity) mAh")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Cycle Count")
                                .font(.headline)
                            Text("\(controller.batteryManager.cycleCount)")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    if controller.healthLogManager.logs.isEmpty {
                        Text("Collecting initial data...\nThis will populate over the coming days.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        // Max Capacity Chart
                        GroupBox(label: Text("Maximum Capacity Degradation").font(.headline)) {
                            Chart(controller.healthLogManager.logs) { log in
                                LineMark(
                                    x: .value("Date", log.date),
                                    y: .value("Capacity (mAh)", log.rawMaxCapacity)
                                )
                                .foregroundStyle(Color.green)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Date", log.date),
                                    yStart: .value("Capacity (mAh)", 0),
                                    yEnd: .value("Capacity (mAh)", log.rawMaxCapacity)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.green.opacity(0.3), Color.clear]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 180)
                            .padding(.top, 8)
                        }
                        
                        // Cycle Count Chart
                        GroupBox(label: Text("Cycle Count Progression").font(.headline)) {
                            Chart(controller.healthLogManager.logs) { log in
                                 LineMark(
                                     x: .value("Date", log.date),
                                     y: .value("Cycles", log.cycleCount)
                                 )
                                 .foregroundStyle(Color.blue)
                                 .interpolationMethod(.stepCenter)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 120)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(20)
            }
            .tabItem {
                Label("Health", systemImage: "heart.text.square")
            }
        }
        .frame(width: 520, height: 650)
    }
    
    // MARK: - Helper Views
    
    private var healthColor: Color {
        let health = controller.batteryManager.batteryHealthPercent
        if health >= 80 { return .green }
        if health >= 60 { return .yellow }
        return .red
    }
    
    // MARK: - Dashboard Card Container
    
    private func dashboardCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(.windowBackgroundColor).opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(8)
    }
    
    // MARK: - Spec Row (label: value)
    
    private func specRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Stat Pill
    
    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
    
    // MARK: - Chart Placeholders
    
    private var chartPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3)
                .foregroundColor(.secondary.opacity(0.5))
            Text("Collecting data...")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
    
    private var chartPlaceholderSmall: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
            Text("Collecting history...")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
    }
    
    private func batteryInfoRow(_ label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}
