import Foundation
import Combine

struct FocusRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let duration: TimeInterval // 秒
    let hour: Int // 0-23
}

class StatsManager: ObservableObject {
    static let shared = StatsManager()
    
    @Published var records: [FocusRecord] = []
    
    private let storageKey = "chillflow_focus_records"
    
    private init() {
        loadRecords()
    }
    
    func recordFocusSession(duration: TimeInterval) {
        let record = FocusRecord(
            id: UUID(),
            date: Date(),
            duration: duration,
            hour: Calendar.current.component(.hour, from: Date())
        )
        
        records.append(record)
        saveRecords()
    }
    
    func getWeeklyStats(weekOffset: Int = 0) -> (dateRange: String, totalDuration: TimeInterval, heatmap: [[TimeInterval]]) {
        let calendar = Calendar.current
        let now = Date()
        
        // 计算指定周的周一
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekOfYear = (components.weekOfYear ?? 0) + weekOffset
        guard let weekStart = calendar.date(from: components) else {
            return ("", 0, Array(repeating: Array(repeating: 0, count: 3), count: 7))
        }
        
        // 计算周一到周日
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M月d日"
        let startStr = dateFormatter.string(from: weekStart)
        let endStr = dateFormatter.string(from: weekEnd)
        let dateRange = "\(startStr) - \(endStr)"
        
        // 筛选该周的数据
        let weekRecords = records.filter { record in
            record.date >= weekStart && record.date <= weekEnd
        }
        
        // 计算总时长
        let totalDuration = weekRecords.reduce(0) { $0 + $1.duration }
        
        // 构建热力图：7天 x 3个时间段（每8小时一段）
        var heatmap = Array(repeating: Array(repeating: 0.0, count: 3), count: 7)
        
        for record in weekRecords {
            let dayIndex = calendar.component(.weekday, from: record.date) - 2 // 转为0-6（周一到周日）
            if dayIndex >= 0 && dayIndex < 7 {
                let timeSlot = record.hour / 8 // 0-2: 0-7, 8-15, 16-23
                if timeSlot >= 0 && timeSlot < 3 {
                    heatmap[dayIndex][timeSlot] += record.duration
                }
            }
        }
        
        return (dateRange, totalDuration, heatmap)
    }
    
    func getHourlyStats(for date: Date, hour: Int, timeSlot: Int) -> TimeInterval {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        
        let recordsInDay = records.filter { record in
            let recordDate = calendar.startOfDay(for: record.date)
            return recordDate >= dayStart && recordDate < dayEnd
        }
        
        let hourStart = timeSlot * 8
        let hourEnd = hourStart + 7
        
        return recordsInDay.filter { record in
            record.hour >= hourStart && record.hour <= hourEnd
        }.reduce(0) { $0 + $1.duration }
    }
    
    private func saveRecords() {
        if let encoded = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([FocusRecord].self, from: data) {
            records = decoded
        }
    }
}

