import Foundation

/// A single snapshot of all battery metrics at a point in time
struct PowerSnapshot: Codable, Identifiable {
    var id: Date { timestamp }
    let timestamp: Date
    let wattage: Double
    let voltage: Double
    let amperage: Double
    let temperature: Double
    let percentage: Int
    let isPluggedIn: Bool
    let isCharging: Bool
}

/// Time range options for chart display
enum HistoryTimeRange: String, CaseIterable, Identifiable {
    case fiveMinutes = "5m"
    case thirtyMinutes = "30m"
    case oneHour = "1h"
    case sixHours = "6h"
    case twelveHours = "12h"
    case twentyFourHours = "24h"
    
    var id: String { rawValue }
    
    var seconds: TimeInterval {
        switch self {
        case .fiveMinutes: return 300
        case .thirtyMinutes: return 1800
        case .oneHour: return 3600
        case .sixHours: return 21600
        case .twelveHours: return 43200
        case .twentyFourHours: return 86400
        }
    }
    
    var label: String { rawValue }
}

/// Persistent store for power history data. Saves to disk periodically and auto-prunes old entries.
class PowerHistoryStore: ObservableObject {
    @Published var snapshots: [PowerSnapshot] = []
    
    private let fileURL: URL
    private var saveCounter: Int = 0
    private let saveInterval: Int = 30 // Save every 30 recordings (~30s at 1s polling)
    private let maxAge: TimeInterval = 48 * 3600 // 48 hours
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDirectory = appSupport.appendingPathComponent("BetterDente")
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        fileURL = appDirectory.appendingPathComponent("PowerHistory.json")
        loadFromDisk()
    }
    
    /// Add a new snapshot and periodically persist to disk
    func record(snapshot: PowerSnapshot) {
        snapshots.append(snapshot)
        saveCounter += 1
        
        if saveCounter >= saveInterval {
            pruneAndSave()
            saveCounter = 0
        }
    }
    
    /// Get snapshots filtered for a given time range
    func snapshots(for range: HistoryTimeRange) -> [PowerSnapshot] {
        let cutoff = Date().addingTimeInterval(-range.seconds)
        return snapshots.filter { $0.timestamp >= cutoff }
    }
    
    /// Downsample snapshots for long time ranges to keep charts performant
    func downsampledSnapshots(for range: HistoryTimeRange, maxPoints: Int = 200) -> [PowerSnapshot] {
        let filtered = snapshots(for: range)
        guard filtered.count > maxPoints else { return filtered }
        
        let stride = Double(filtered.count) / Double(maxPoints)
        var result: [PowerSnapshot] = []
        var index: Double = 0
        while Int(index) < filtered.count {
            result.append(filtered[Int(index)])
            index += stride
        }
        // Always include the last point
        if let last = filtered.last, result.last?.timestamp != last.timestamp {
            result.append(last)
        }
        return result
    }
    
    // MARK: - Persistence
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let loaded = try decoder.decode([PowerSnapshot].self, from: data)
            
            // Only keep data within maxAge
            let cutoff = Date().addingTimeInterval(-maxAge)
            self.snapshots = loaded.filter { $0.timestamp >= cutoff }
            print("Loaded \(self.snapshots.count) power history snapshots from disk.")
        } catch {
            print("Failed to load power history: \(error)")
        }
    }
    
    func pruneAndSave() {
        // Remove entries older than 48 hours
        let cutoff = Date().addingTimeInterval(-maxAge)
        snapshots = snapshots.filter { $0.timestamp >= cutoff }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(snapshots)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save power history: \(error)")
        }
    }
    
    /// Force save (called on app termination)
    func forceSave() {
        pruneAndSave()
    }
}
