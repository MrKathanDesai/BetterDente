import Foundation

struct TopEnergyApp: Identifiable {
    let id = UUID()
    let name: String
    let cpuPercent: Double
}

class BatteryManager: ObservableObject {
    @Published var currentPercentage: Int = 0
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var isFullyCharged: Bool = false
    @Published var temperature: Double = 0.0
    @Published var voltage: Double = 0.0
    @Published var amperage: Double = 0.0
    @Published var wattage: Double = 0.0
    @Published var adapterWattage: Double = 0.0
    @Published var rawMaxCapacity: Int = 0
    @Published var designCapacity: Int = 0
    @Published var currentCapacity: Int = 0
    @Published var cycleCount: Int = 0
    @Published var timeRemaining: Int = -1
    @Published var serialNumber: String = ""
    
    // macOS-reported health (from system_profiler, matches System Settings)
    @Published var macOSHealthPercent: Int = 0
    @Published var macOSCondition: String = "Unknown"
    
    // Power consumption tracking
    @Published var todayEnergyWh: Double = 0.0
    @Published var averagePowerW: Double = 0.0
    @Published var peakPowerW: Double = 0.0
    @Published var sessionStartTime: Date = Date()
    
    // Top energy apps
    @Published var topEnergyApps: [TopEnergyApp] = []
    
    // Adapter info
    @Published var adapterName: String = ""
    @Published var adapterMaxWattage: Int = 0
    
    // Running averages
    private var powerSamples: [Double] = []
    private var energyAccumulator: Double = 0.0
    private var lastSampleTime: Date?
    private var topAppUpdateCounter: Int = 0
    
    var batteryHealthPercent: Double {
        if macOSHealthPercent > 0 { return Double(macOSHealthPercent) }
        guard designCapacity > 0 else { return 100.0 }
        return min(100.0, (Double(rawMaxCapacity) / Double(designCapacity)) * 100.0)
    }
    
    var batteryCondition: String {
        if !macOSCondition.isEmpty && macOSCondition != "Unknown" { return macOSCondition }
        let health = batteryHealthPercent
        if health >= 80 { return "Normal" }
        if health >= 60 { return "Service Recommended" }
        return "Service Battery"
    }
    
    var batteryConditionColor: String {
        let condition = batteryCondition
        if condition == "Normal" { return "green" }
        if condition == "Service Recommended" { return "yellow" }
        return "red"
    }
    
    // Power flow: how adapter power splits between battery and system
    var batteryChargingPowerW: Double {
        // When charging, wattage is positive (power flowing INTO battery)
        // When discharging, wattage is negative (power flowing FROM battery)
        return max(0, wattage) // Only positive = power going to battery
    }
    
    var systemPowerW: Double {
        // System consumption = adapter power - battery charging power
        // If not plugged in, system runs entirely from battery
        if !isPluggedIn { return abs(wattage) }
        return max(0, adapterWattage - batteryChargingPowerW)
    }
    
    var adapterTotalPowerW: Double {
        return isPluggedIn ? adapterWattage : 0
    }
    
    var timeRemainingFormatted: String {
        // 65535 (0xFFFF) means "calculating" in ioreg, -1 means unknown
        if isFullyCharged { return "Fully Charged" }
        
        // When plugged in but NOT charging (charge limiter active), show status only
        if isPluggedIn && !isCharging {
            return "Not Charging"
        }
        
        // Invalid or unknown time
        guard timeRemaining > 0, timeRemaining < 1440 else {
            return ""
        }
        
        let hours = timeRemaining / 60
        let mins = timeRemaining % 60
        
        if isPluggedIn && isCharging {
            return hours > 0 ? "\(hours)h \(mins)m to full" : "\(mins)m to full"
        }
        
        // On battery — show discharge time
        // Clarify label from "remaining" to "until empty" to avoid confusion with "time until charge"
        return hours > 0 ? "\(hours)h \(mins)m until empty" : "\(mins)m until empty"
    }
    
    var sessionDurationFormatted: String {
        let elapsed = Date().timeIntervalSince(sessionStartTime)
        let hours = Int(elapsed) / 3600
        let mins = (Int(elapsed) % 3600) / 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        return "\(mins)m"
    }
    
    var useHardwareBatteryPercentage: Bool {
        UserDefaults.standard.bool(forKey: "useHardwareBatteryPercentage")
    }
    
    private func executeCommand(_ launchPath: String, arguments: [String]) -> String? {
        let task = Process()
        let pipe = Pipe()
        task.launchPath = launchPath
        task.arguments = arguments
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            try pipe.fileHandleForReading.close()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    func updateStatus(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let pmsetOutput = self.executeCommand("/usr/bin/pmset", arguments: ["-g", "batt"])
            let ioregOutput = self.executeCommand("/usr/sbin/ioreg", arguments: ["-r", "-n", "AppleSmartBattery"])
            
            // Update top energy apps every 10 seconds (every 10th call at 1s polling)
            var topAppsOutput: String? = nil
            self.topAppUpdateCounter += 1
            if self.topAppUpdateCounter >= 20 {
                self.topAppUpdateCounter = 0
                topAppsOutput = self.executeCommand("/usr/bin/top", arguments: ["-l", "1", "-n", "5", "-o", "cpu", "-stats", "pid,command,cpu"])
            }
            
            DispatchQueue.main.async {
                if let pmset = pmsetOutput {
                    self.parse(output: pmset)
                }
                if let ioreg = ioregOutput {
                    self.parseHardwareStats(output: ioreg)
                }
                if let topApps = topAppsOutput {
                    self.parseTopApps(output: topApps)
                }
                self.updatePowerTracking()
                completion?()
            }
        }
    }
    
    /// Fetch macOS health % (called less frequently — every 60 seconds)
    func fetchMacOSHealth() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let output = self.executeCommand("/usr/sbin/system_profiler", arguments: ["SPPowerDataType"])
            DispatchQueue.main.async {
                if let output = output {
                    self.parseMacOSHealth(output: output)
                }
            }
        }
    }
    
    private func parseMacOSHealth(output: String) {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Maximum Capacity:") {
                if let percentRange = line.range(of: "\\d+", options: .regularExpression) {
                    if let val = Int(line[percentRange]) {
                        macOSHealthPercent = val
                    }
                }
            }
            if line.contains("Condition:") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    macOSCondition = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
    }
    
    private func updatePowerTracking() {
        let now = Date()
        let absWattage = abs(wattage)
        
        // Track energy consumption
        if let lastTime = lastSampleTime {
            let dt = now.timeIntervalSince(lastTime) / 3600.0 // hours
            energyAccumulator += absWattage * dt
            todayEnergyWh = energyAccumulator
        }
        lastSampleTime = now
        
        // Running average & peak
        powerSamples.append(absWattage)
        if powerSamples.count > 300 { powerSamples.removeFirst() } // ~5 min window
        averagePowerW = powerSamples.reduce(0, +) / Double(max(1, powerSamples.count))
        peakPowerW = max(peakPowerW, absWattage)
    }
    
    private func parseTopApps(output: String) {
        let lines = output.components(separatedBy: .newlines)
        var apps: [TopEnergyApp] = []
        var foundHeader = false
        
        for line in lines {
            if line.contains("PID") && line.contains("COMMAND") {
                foundHeader = true
                continue
            }
            if foundHeader {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                // Parse: PID   COMMAND   %CPU
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 3 {
                    let name = parts[1]
                    let cpuStr = parts.last ?? "0"
                    let cpu = Double(cpuStr) ?? 0.0
                    if cpu > 0.1 {
                        apps.append(TopEnergyApp(name: name, cpuPercent: cpu))
                    }
                }
            }
        }
        topEnergyApps = apps
    }
    
    private func parseHardwareStats(output: String) {
        let lines = output.components(separatedBy: .newlines)
        
        if let tempLine = lines.first(where: { $0.contains("\"Temperature\" =") }) {
            if let valueString = tempLine.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines),
               let tempValue = Double(valueString) {
                self.temperature = tempValue / 100.0
            }
        }
        
        var rawCurrent: Double?
        var rawMax: Double?
        var parsedDesignCapacity: Int = 0
        var parsedCurrentCapacity: Int = 0
        var parsedCycleCount = 0
        var newVoltage = 0.0
        var newAmperage = 0.0
        var newAdapterWatts = 0.0
        var parsedTimeRemaining: Int = -1
        var parsedSerial = ""
        var parsedFullyCharged = false
        var parsedAdapterName = ""
        var parsedAdapterMaxWatts = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("\"AppleRawCurrentCapacity\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    rawCurrent = Double(valStr)
                }
            } else if trimmed.hasPrefix("\"AppleRawMaxCapacity\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    rawMax = Double(valStr)
                }
            } else if trimmed.hasPrefix("\"DesignCapacity\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    parsedDesignCapacity = Int(valStr) ?? 0
                }
            } else if trimmed.hasPrefix("\"CurrentCapacity\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    parsedCurrentCapacity = Int(valStr) ?? 0
                }
            } else if trimmed.hasPrefix("\"CycleCount\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    parsedCycleCount = Int(valStr) ?? 0
                }
            } else if trimmed.hasPrefix("\"Voltage\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines), let val = Double(valStr) {
                    newVoltage = val / 1000.0
                }
            } else if trimmed.hasPrefix("\"Amperage\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    if let uintVal = UInt64(valStr) {
                        let intVal = Int64(bitPattern: uintVal)
                        newAmperage = Double(intVal) / 1000.0
                    } else if let intVal = Int64(valStr) {
                        newAmperage = Double(intVal) / 1000.0
                    }
                }
            } else if trimmed.hasPrefix("\"TimeRemaining\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    // Check for hex values like 0xffff (calculating)
                    if valStr.hasPrefix("0x") {
                        parsedTimeRemaining = Int(valStr.dropFirst(2), radix: 16) ?? -1
                    } else {
                        parsedTimeRemaining = Int(valStr) ?? -1
                    }
                }
            } else if trimmed.hasPrefix("\"BatterySerialNumber\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    parsedSerial = valStr.replacingOccurrences(of: "\"", with: "")
                }
            } else if trimmed.hasPrefix("\"FullyCharged\" =") {
                if let valStr = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    parsedFullyCharged = (valStr == "Yes" || valStr == "1")
                }
            }
            
            // Parse adapter info from AppleRawAdapterDetails
            if trimmed.contains("\"Name\"=") && trimmed.contains("Adapter") {
                if let nameMatch = trimmed.range(of: "\"Name\"=\"([^\"]+)\"", options: .regularExpression) {
                    let matched = String(trimmed[nameMatch])
                    parsedAdapterName = matched.replacingOccurrences(of: "\"Name\"=\"", with: "").replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespaces)
                }
                if let wattsMatch = trimmed.range(of: "\"Watts\"=\\d+", options: .regularExpression) {
                    let matched = String(trimmed[wattsMatch])
                    parsedAdapterMaxWatts = Int(matched.replacingOccurrences(of: "\"Watts\"=", with: "")) ?? 0
                }
            }
        }
        
        let hwPercentage: Int? = {
            if let current = rawCurrent, let max = rawMax, max > 0 {
                return Int(round((current / max) * 100.0))
            }
            return nil
        }()
        
        self.rawMaxCapacity = Int(rawMax ?? 0)
        self.designCapacity = parsedDesignCapacity
        self.currentCapacity = parsedCurrentCapacity
        self.cycleCount = parsedCycleCount
        self.serialNumber = parsedSerial
        self.isFullyCharged = parsedFullyCharged
        // Only overwrite timeRemaining from ioreg if it's a valid value (> 0 and not "calculating")
        if parsedTimeRemaining > 0 && parsedTimeRemaining < 65535 {
            self.timeRemaining = parsedTimeRemaining
        }
        if !parsedAdapterName.isEmpty { self.adapterName = parsedAdapterName }
        if parsedAdapterMaxWatts > 0 { self.adapterMaxWattage = parsedAdapterMaxWatts }
        
        if self.useHardwareBatteryPercentage, let hwPct = hwPercentage {
            self.currentPercentage = min(100, hwPct)
        }
        
        self.voltage = newVoltage
        self.amperage = newAmperage
        self.wattage = newVoltage * newAmperage
        self.adapterWattage = self.isPluggedIn ? newAdapterWatts : 0.0
    }
    
    private func parse(output: String) {
        isPluggedIn = output.contains("AC Power")
        
        // Try to extract time estimate from pmset: "4:39 remaining" or "2:15 until full"
        // This is often more reliable than raw ioreg TimeRemaining
        if let timeRange = output.range(of: "\\d+:\\d+ (remaining|until full)", options: .regularExpression) {
            let timeStr = String(output[timeRange])
            let parts = timeStr.components(separatedBy: .whitespaces)
            if parts.count >= 2 {
                let timeParts = parts[0].components(separatedBy: ":")
                if timeParts.count == 2, let h = Int(timeParts[0]), let m = Int(timeParts[1]) {
                    self.timeRemaining = h * 60 + m
                }
            }
        }
        
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("InternalBattery") {
                if !useHardwareBatteryPercentage {
                    if let percentRange = line.range(of: "\\d+%", options: .regularExpression) {
                        let percentString = String(line[percentRange]).dropLast()
                        if let val = Int(percentString) {
                            self.currentPercentage = val
                        }
                    }
                }
                
                if line.contains("discharging") {
                    self.isCharging = false
                } else if line.contains("not charging") {
                    self.isCharging = false
                } else if line.contains("charging") || line.contains("charged") {
                    self.isCharging = true
                }
            }
        }
    }
}

// MARK: - Health Logging

struct DailyHealthLog: Identifiable, Codable {
    var id: UUID = UUID()
    let date: Date
    let rawMaxCapacity: Int
    let cycleCount: Int
}

class HealthLogManager: ObservableObject {
    @Published var logs: [DailyHealthLog] = []
    
    private let fileURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDirectory = appSupport.appendingPathComponent("BetterDente")
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        fileURL = appDirectory.appendingPathComponent("HealthLogs.json")
        loadLogs()
    }
    
    func loadLogs() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([DailyHealthLog].self, from: data) else {
            generateMockDataIfNeeded()
            return
        }
        self.logs = decoded
        generateMockDataIfNeeded()
    }
    
    private func saveLogs() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        try? data.write(to: fileURL)
    }
    
    func logDailyStats(rawMaxCapacity: Int, cycleCount: Int) {
        guard rawMaxCapacity > 0, cycleCount > 0 else { return }
        let now = Date()
        let calendar = Calendar.current
        if let lastLog = logs.last, calendar.isDate(lastLog.date, inSameDayAs: now) { return }
        
        let newLog = DailyHealthLog(date: now, rawMaxCapacity: rawMaxCapacity, cycleCount: cycleCount)
        DispatchQueue.main.async {
            self.logs.append(newLog)
            self.saveLogs()
        }
    }
    
    private func generateMockDataIfNeeded() {
        // Don't generate mock data — only use real logged data
        // Historical charts will show "Collecting history..." until we have 2+ daily logs
    }
}
