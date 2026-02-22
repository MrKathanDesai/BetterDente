import Foundation
import Combine
import SwiftUI
import IOKit.pwr_mgt

class ChargingController: ObservableObject {
    @AppStorage("chargeLimit") var chargeLimit: Int = 80 {
        didSet { evaluateState() }
    }
    @AppStorage("isLimiterEnabled") var isLimiterEnabled: Bool = true {
        didSet { evaluateState() }
    }
    @AppStorage("isDischargeEnabled") var isDischargeEnabled: Bool = false {
        didSet { evaluateState() }
    }
    @AppStorage("isSailingModeEnabled") var isSailingModeEnabled: Bool = false {
        didSet { evaluateState() }
    }
    @AppStorage("sailingDrop") var sailingDrop: Int = 5 {
        didSet { evaluateState() }
    }
    @AppStorage("isHeatProtectionEnabled") var isHeatProtectionEnabled: Bool = false {
        didSet { evaluateState() }
    }
    @AppStorage("heatProtectionThreshold") var heatProtectionThreshold: Int = 35 {
        didSet { evaluateState() }
    }
    @AppStorage("isTopUpActive") var isTopUpActive: Bool = false {
        didSet { evaluateState() }
    }
    @AppStorage("isStopChargingWhenSleepingEnabled") var isStopChargingWhenSleepingEnabled: Bool = true
    @AppStorage("isDisableSleepEnabled") var isDisableSleepEnabled: Bool = false
    @AppStorage("useHardwareBatteryPercentage") var useHardwareBatteryPercentage: Bool = false {
        didSet { batteryManager.updateStatus() }
    }
    
    enum CalibrationState: String {
        case inactive = "Inactive"
        case chargingTo100 = "Charging to 100%"
        case dischargingTo15 = "Discharging to 15%"
        case chargingTo100Again = "Recharging to 100%"
        case holding100 = "Holding at 100%"
    }
    @AppStorage("calibrationState") var calibrationState: CalibrationState = .inactive
    @AppStorage("calibrationHoldStartTime") var calibrationHoldStartTime: Double = 0.0
    
    // Scheduling State
    @AppStorage("isScheduledTopUpEnabled") var isScheduledTopUpEnabled: Bool = false
    @AppStorage("scheduledTopUpInterval") var scheduledTopUpInterval: Int = 14 // days
    @AppStorage("lastScheduledTopUp") var lastScheduledTopUp: Double = 0.0 // timeIntervalSince1970
    
    @AppStorage("isScheduledCalibrationEnabled") var isScheduledCalibrationEnabled: Bool = false
    @AppStorage("scheduledCalibrationInterval") var scheduledCalibrationInterval: Int = 30 // days
    @AppStorage("lastScheduledCalibration") var lastScheduledCalibration: Double = 0.0 // timeIntervalSince1970
    
    @AppStorage("isScheduledDischargeEnabled") var isScheduledDischargeEnabled: Bool = false
    @AppStorage("scheduledDischargeInterval") var scheduledDischargeInterval: Int = 14 // days
    @AppStorage("lastScheduledDischarge") var lastScheduledDischarge: Double = 0.0 // timeIntervalSince1970
    
    enum MenuBarDisplayMode: String, CaseIterable {
        case iconOnly = "Icon Only"
        case appLogo = "App Logo"
        case batteryNative = "Native Battery"
        case wattage = "Wattage"
        case temperature = "Temperature"
        case percentage = "Percentage"
    }
    @AppStorage("menuBarDisplayMode") var menuBarDisplayMode: MenuBarDisplayMode = .iconOnly
    
    // App Exceptions
    @AppStorage("appExceptionsList") var appExceptionsList: String = "" // Comma-separated app names
    @Published var isExceptionAppActive: Bool = false
    
    var exceptions: [String] {
        appExceptionsList.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    
    @Published var activeState: LimitEnforcementState? = nil
    @Published var batteryManager = BatteryManager()
    @Published var healthLogManager = HealthLogManager()
    @Published var powerHistory = PowerHistoryStore()
    @Published var lastUpdated: Date = Date()
    
    private var timer: AnyCancellable?
    private var childCancellables = Set<AnyCancellable>()
    private var sleepAssertionID: IOPMAssertionID = 0
    private var lastOverheatTime: Date?
    
    enum LimitEnforcementState: String {
        case charging = "Charging"
        case disabled = "Bypassing Battery (AC Only)"
        case discharging = "Discharging to Limit"
        case overheating = "Paused: Battery Hot"
        case topUp = "Topping Up to 100%"
        case calibrating = "Calibrating"
    }
    init() {
        // Forward objectWillChange from nested observable objects so SwiftUI redraws immediately
        batteryManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &childCancellables)
        
        healthLogManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &childCancellables)
        
        powerHistory.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &childCancellables)
        
        setupSleepObservers()
        startMonitoring()
    }
    
    private func setupSleepObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    private func manageSleepAssertion() {
        // Only prevent sleep if our settings allow it AND we are trying to actively change the battery level
        let needsToStayAwake = isDisableSleepEnabled && isLimiterEnabled && batteryManager.isPluggedIn && (activeState == .charging || activeState == .discharging || activeState == .topUp || activeState == .calibrating)
        
        if needsToStayAwake && sleepAssertionID == 0 {
            print("Creating PreventUserIdleSystemSleep assertion.")
            _ = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "BetterDente actively managing battery level" as CFString,
                &sleepAssertionID
            )
        } else if !needsToStayAwake && sleepAssertionID != 0 {
            print("Releasing PreventUserIdleSystemSleep assertion.")
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }
    
    @objc private func handleSleep() {
        print("Mac is going to sleep.")
        timer?.cancel() // Pause periodic monitoring
        
        // Before letting the Mac sleep, release any active assertions and force AC Bypass if enabled
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
        
        if isStopChargingWhenSleepingEnabled && isLimiterEnabled {
            print("Stop Charging When Sleeping enabled. Forcing AC Bypass before sleep.")
            ServiceManager.shared.testDisableCharging()
            DispatchQueue.main.async { self.activeState = .disabled }
        }
    }
    
    @objc private func handleWake() {
        print("Mac woke from sleep. Resuming monitoring.")
        startMonitoring()
    }
    
    private var healthFetchCounter: Int = 0
    
    func startMonitoring() {
        // Initial fetch
        batteryManager.fetchMacOSHealth() // Get macOS health on startup
        batteryManager.updateStatus { [weak self] in
            guard let self = self else { return }
            self.lastUpdated = Date()
            self.recordSnapshot()
            self.evaluateState()
        }
        
        timer?.cancel()
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // Fetch macOS health every 60 seconds (system_profiler is slow)
                // At 0.5s polling, 120 ticks = 60 seconds
                self.healthFetchCounter += 1
                if self.healthFetchCounter >= 120 {
                    self.healthFetchCounter = 0
                    self.batteryManager.fetchMacOSHealth()
                }
                
                self.batteryManager.updateStatus {
                    self.lastUpdated = Date()
                    self.recordSnapshot()
                    self.healthLogManager.logDailyStats(rawMaxCapacity: self.batteryManager.rawMaxCapacity, cycleCount: self.batteryManager.cycleCount)
                    self.checkAppExceptions()
                    self.evaluateState()
                    self.checkSchedules()
                }
            }
    }
    
    private func recordSnapshot() {
        let snapshot = PowerSnapshot(
            timestamp: Date(),
            wattage: batteryManager.wattage,
            voltage: batteryManager.voltage,
            amperage: batteryManager.amperage,
            temperature: batteryManager.temperature,
            percentage: batteryManager.currentPercentage,
            isPluggedIn: batteryManager.isPluggedIn,
            isCharging: batteryManager.isCharging
        )
        powerHistory.record(snapshot: snapshot)
    }
    
    private func checkAppExceptions() {
        let currentExceptions = exceptions
        guard !currentExceptions.isEmpty else {
            if isExceptionAppActive {
                DispatchQueue.main.async { self.isExceptionAppActive = false }
            }
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }
        
        let isMatch = runningApps.contains { appName in
            currentExceptions.contains(where: { exception in
                appName.caseInsensitiveCompare(exception) == .orderedSame
            })
        }
        
        if isMatch != isExceptionAppActive {
            DispatchQueue.main.async {
                print(isMatch ? "Exception App Launched: Overriding Limit." : "Exception App Quit: Restoring Limit.")
                self.isExceptionAppActive = isMatch
            }
        }
    }
    
    private func evaluateState() {
        guard isLimiterEnabled else {
            // Unconditionally enable charging if the limiter is turned off
            if activeState != .charging {
                ServiceManager.shared.testEnableCharging()
                DispatchQueue.main.async { self.activeState = .charging }
            }
            return
        }
        
        // Deactivate Top Up automatically if the charger is unplugged
        if isTopUpActive && !batteryManager.isPluggedIn {
            DispatchQueue.main.async { self.isTopUpActive = false }
        }
        
        // Handle unplugged state gracefully by returning early and resetting state
        if !batteryManager.isPluggedIn && calibrationState == .inactive {
            if activeState != nil {
                print("Charger unplugged. Resetting active state.")
                DispatchQueue.main.async { self.activeState = nil }
            }
            manageSleepAssertion()
            return
        }
        
        // Handle overheating (only when plugged in based on the above guard)
        let currentLevel = batteryManager.currentPercentage
        let currentTemp = batteryManager.temperature
        
        if isHeatProtectionEnabled {
            if currentTemp >= Double(heatProtectionThreshold) {
                // Overheating -> Force stop charging (AC Bypass) to cool down
                lastOverheatTime = Date()
                if activeState != .overheating {
                    print("Battery is hot (\(currentTemp)°C >= \(heatProtectionThreshold)°C). Pausing charge.")
                    ServiceManager.shared.testDisableCharging()
                    DispatchQueue.main.async { self.activeState = .overheating }
                }
                manageSleepAssertion()
                return
            } else if let lastTime = lastOverheatTime, Date().timeIntervalSince(lastTime) < 300 {
                // Temperature is safe, but we are within the 5-minute cooldown window
                if activeState != .overheating {
                    print("Battery cool, but waiting for 5-minute hysteresis to elapse.")
                    ServiceManager.shared.testDisableCharging()
                    DispatchQueue.main.async { self.activeState = .overheating }
                }
                manageSleepAssertion()
                return
            } else {
                // Cooldown elapsed, clear the timer
                lastOverheatTime = nil
            }
        }
        
        // Top Up mode overrides all limits and forces charge to 100%
        let isOverrideActive = isTopUpActive || isExceptionAppActive
        if isOverrideActive && batteryManager.isPluggedIn {
            if currentLevel < 100 {
                if activeState != .topUp {
                    print("Override active. Forcing charge to 100%.")
                    ServiceManager.shared.testEnableCharging()
                    DispatchQueue.main.async { self.activeState = .topUp }
                }
            } else {
                if activeState != .disabled {
                    print("Override reached 100%. Bypassing.")
                    ServiceManager.shared.testDisableCharging()
                    DispatchQueue.main.async { self.activeState = .disabled }
                }
            }
            return
        }
        
        // Calibration Mode bypasses standard limits
        if calibrationState != .inactive {
            switch calibrationState {
            case .inactive:
                break // handled by if condition
                
            case .chargingTo100:
                if currentLevel < 100 {
                    if activeState != .calibrating {
                        print("Calibration: Charging to 100%...")
                        ServiceManager.shared.testEnableCharging()
                        DispatchQueue.main.async { self.activeState = .calibrating }
                    }
                } else {
                    // Reached 100%, transition to discharging
                    print("Calibration: Reached 100%. Transitioning to discharging to 15%.")
                    DispatchQueue.main.async { self.calibrationState = .dischargingTo15 }
                    ServiceManager.shared.testForceDischarge() // We want to force discharge to 15%
                    DispatchQueue.main.async { self.activeState = .calibrating }
                }
                
            case .dischargingTo15:
                if currentLevel > 15 {
                    if activeState != .calibrating {
                        print("Calibration: Discharging to 15%...")
                        ServiceManager.shared.testForceDischarge()
                        DispatchQueue.main.async { self.activeState = .calibrating }
                    }
                } else {
                    // Reached 15%, transition back to charging
                    print("Calibration: Reached 15%. Transitioning to recharging to 100%.")
                    DispatchQueue.main.async { self.calibrationState = .chargingTo100Again }
                    ServiceManager.shared.testEnableCharging()
                    DispatchQueue.main.async { self.activeState = .calibrating }
                }
                
            case .chargingTo100Again:
                if currentLevel < 100 {
                    if activeState != .calibrating {
                        print("Calibration: Recharging to 100%...")
                        ServiceManager.shared.testEnableCharging()
                        DispatchQueue.main.async { self.activeState = .calibrating }
                    }
                } else {
                    // Reached 100% again, start holding
                    print("Calibration: Reached 100% again. Starting 1-hour hold.")
                    DispatchQueue.main.async {
                        self.calibrationHoldStartTime = Date().timeIntervalSince1970
                        self.calibrationState = .holding100
                        self.activeState = .calibrating
                    }
                    ServiceManager.shared.testDisableCharging()
                }
                
            case .holding100:
                let elapsed = Date().timeIntervalSince1970 - calibrationHoldStartTime
                if elapsed < 3600 {
                    if activeState != .calibrating {
                        print("Calibration: Holding at 100%. (\(Int(elapsed))/3600 seconds elapsed)")
                        ServiceManager.shared.testDisableCharging()
                        DispatchQueue.main.async { self.activeState = .calibrating }
                    }
                } else {
                    print("Calibration: 1-hour hold complete. Calibration finished.")
                    DispatchQueue.main.async {
                        self.calibrationState = .inactive
                        self.activeState = nil
                        self.startMonitoring() // Re-evaluate normal state
                    }
                }
            }
            
            manageSleepAssertion()
            return
        }
        
        if currentLevel > chargeLimit && isDischargeEnabled {
            // Over limit and discharge is enabled -> force discharge
            if activeState != .discharging {
                print("Charge over limit (\(currentLevel)% > \(chargeLimit)%). Forcing discharge.")
                ServiceManager.shared.testForceDischarge()
                DispatchQueue.main.async { self.activeState = .discharging }
            }
        } else if currentLevel >= chargeLimit {
            // Over or at limit, but discharge NOT needed -> stop charging (AC Bypass)
            if activeState != .disabled {
                print("Charge limit reached (\(currentLevel)% >= \(chargeLimit)%). Enforcing limit (AC Bypass).")
                ServiceManager.shared.testDisableCharging()
                DispatchQueue.main.async { self.activeState = .disabled }
            }
        } else {
            // Under limit -> determine lower bound
            let lowerBound = isSailingModeEnabled ? max(0, chargeLimit - sailingDrop) : chargeLimit
            
            if currentLevel < lowerBound || (currentLevel <= lowerBound && !isSailingModeEnabled) {
                // Below the lower bound -> allow charging
                if activeState != .charging {
                    print("Below charge bound (\(currentLevel)% < \(lowerBound)%). Permitting charge.")
                    ServiceManager.shared.testEnableCharging()
                    DispatchQueue.main.async { self.activeState = .charging }
                }
            } else {
                // Between lowerBound and chargeLimit
                if activeState == .charging {
                    // Keep charging until we reach chargeLimit
                } else if activeState != .disabled {
                    // Switch to AC Bypass (stop discharging or initialize state)
                    print("In sailing zone (\(currentLevel)%). Enforcing AC Bypass.")
                    ServiceManager.shared.testDisableCharging()
                    DispatchQueue.main.async { self.activeState = .disabled }
                }
            }
        }
        
        // Post evaluation check for sleep assertions
        manageSleepAssertion()
    }
    
    func forceCharge100() {
        print("Top Up clicked.")
        isLimiterEnabled = true
        isTopUpActive = true
        calibrationState = .inactive // Cancel calibration if any
        evaluateState()
    }
    
    func startCalibration() {
        print("Calibration started.")
        isLimiterEnabled = true
        isTopUpActive = false
        calibrationState = .chargingTo100
        evaluateState()
    }
    
    func stopCalibration() {
        print("Calibration stopped.")
        calibrationState = .inactive
        evaluateState()
    }
    
    private func checkSchedules() {
        guard isLimiterEnabled else { return }
        
        let now = Date().timeIntervalSince1970
        let secondsInDay: Double = 86400
        
        // Check Top Up Schedule
        if isScheduledTopUpEnabled && !isTopUpActive {
            // If never run, set to now to start the clock, rather than triggering immediately
            if lastScheduledTopUp == 0 {
                lastScheduledTopUp = now
            } else {
                let daysSince = (now - lastScheduledTopUp) / secondsInDay
                if daysSince >= Double(scheduledTopUpInterval) {
                    print("Scheduled Top Up triggered (\(daysSince) days elapsed).")
                    lastScheduledTopUp = now
                    forceCharge100()
                }
            }
        }
        
        // Check Calibration Schedule
        if isScheduledCalibrationEnabled && calibrationState == .inactive {
            if lastScheduledCalibration == 0 {
                lastScheduledCalibration = now
            } else {
                let daysSince = (now - lastScheduledCalibration) / secondsInDay
                if daysSince >= Double(scheduledCalibrationInterval) {
                    print("Scheduled Calibration triggered (\(daysSince) days elapsed).")
                    lastScheduledCalibration = now
                    startCalibration()
                }
            }
        }
        
        // Check Discharge Schedule
        if isScheduledDischargeEnabled && activeState != .discharging && activeState != .calibrating && !isTopUpActive {
            if lastScheduledDischarge == 0 {
                lastScheduledDischarge = now
            } else {
                let daysSince = (now - lastScheduledDischarge) / secondsInDay
                if daysSince >= Double(scheduledDischargeInterval) {
                    print("Scheduled Discharge triggered (\(daysSince) days elapsed).")
                    lastScheduledDischarge = now
                    // We simulate a scheduled discharge by forcing a discharge event.
                    // This relies on the AC Bypass continuing until the limit is reached.
                    // Because we don't have a formal "ScheduledDischargeState", we just manually trigger it.
                    ServiceManager.shared.testForceDischarge()
                    DispatchQueue.main.async { self.activeState = .discharging }
                }
            }
        }
    }
}
