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
    private let hasLaunchedKey = "chillflow_has_launched"
    
    private init() {
        // 检查是否是首次启动
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if !hasLaunched {
            // 首次启动，清除所有数据
            records = []
            saveRecords()
            // 标记应用已启动过
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            print("首次启动，已清除所有专注时长数据")
        } else {
            // 非首次启动，正常加载数据
            loadRecords()
            // 清除之前可能添加的测试数据（向后兼容）
            clearTestData()
        }
    }
    
    // 清除测试数据（周一上午0-7时的数据）- 向后兼容旧版本
    private func clearTestData() {
        let calendar = Calendar.current
        let now = Date()
        
        // 计算本周一的日期
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStartDate = calendar.date(from: components) else { return }
        
        // 确保是周一（weekday = 2）
        let weekday = calendar.component(.weekday, from: weekStartDate)
        let daysFromMonday = weekday == 1 ? 1 : weekday - 2
        guard let weekStart = calendar.date(byAdding: .day, value: daysFromMonday, to: weekStartDate) else { return }
        
        // 移除本周一上午（0-7时）的测试数据
        let beforeCount = records.count
        records.removeAll { record in
            let recordDate = calendar.startOfDay(for: record.date)
            let mondayStart = calendar.startOfDay(for: weekStart)
            return recordDate == mondayStart && record.hour >= 0 && record.hour <= 7
        }
        
        // 如果有数据被移除，保存更改
        if records.count < beforeCount {
            saveRecords()
            print("已清除测试数据")
        }
    }
    
    // 添加测试数据：周一上午75分钟
    private func addTestDataIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        // 计算本周一的日期
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStartDate = calendar.date(from: components) else { return }
        
        // 确保是周一（weekday = 2）
        let weekday = calendar.component(.weekday, from: weekStartDate)
        let daysFromMonday = weekday == 1 ? 1 : weekday - 2
        guard let weekStart = calendar.date(byAdding: .day, value: daysFromMonday, to: weekStartDate) else { return }
        
        // 移除本周一上午（0-7时）的旧测试数据（如果有）
        records.removeAll { record in
            let recordDate = calendar.startOfDay(for: record.date)
            let mondayStart = calendar.startOfDay(for: weekStart)
            return recordDate == mondayStart && record.hour >= 0 && record.hour <= 7
        }
        
        // 添加新的测试数据：周一上午75分钟
        let testRecord = FocusRecord(
            id: UUID(),
            date: calendar.date(byAdding: .hour, value: 6, to: weekStart)!, // 周一上午6时
            duration: 75 * 60, // 75分钟转换为秒
            hour: 6 // 6时，属于0-7时时间段（timeSlot=0）
        )
        
        records.append(testRecord)
        saveRecords()
        print("已添加测试数据：周一上午专注时长75分钟")
        print("测试数据详情：日期=\(weekStart)，hour=6，duration=\(75*60)秒")
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
        guard let weekStartDate = calendar.date(from: components) else {
            return ("", 0, Array(repeating: Array(repeating: 0, count: 3), count: 7))
        }
        
        // 确保weekStart是周一（weekday = 2）
        // date(from:) 可能返回周日（weekday = 1），需要调整为周一
        let weekday = calendar.component(.weekday, from: weekStartDate)
        let daysFromMonday = weekday == 1 ? 1 : weekday - 2 // 周日需要+1天，其他-2
        guard let weekStart = calendar.date(byAdding: .day, value: daysFromMonday, to: weekStartDate) else {
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
            // weekday: 1=周日, 2=周一, ..., 7=周六
            // 需要转为：0=周一, 1=周二, ..., 6=周日
            let weekday = calendar.component(.weekday, from: record.date)
            var dayIndex: Int
            if weekday == 1 {
                // 周日，放在最后（索引6）
                dayIndex = 6
            } else {
                // 周一到周六：2->0, 3->1, ..., 7->5
                dayIndex = weekday - 2
            }
            
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

