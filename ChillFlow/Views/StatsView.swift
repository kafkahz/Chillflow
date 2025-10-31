import SwiftUI

struct StatsView: View {
    @EnvironmentObject var statsManager: StatsManager
    @State private var weekOffset = 0
    @State private var hoveredCell: (day: Int, slot: Int)? = nil
    
    var body: some View {
        VStack(spacing: 12) {
            // 周选择和日期范围
            HStack {
                Button(action: {
                    weekOffset -= 1
                }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                let statsForHeader = statsManager.getWeeklyStats(weekOffset: weekOffset)
                Text(statsForHeader.dateRange)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    weekOffset += 1
                }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // 总专注时长和热力图
            Group {
                let stats = statsManager.getWeeklyStats(weekOffset: weekOffset)
                
                let displayText: String = {
                    if let hovered = hoveredCell {
                        let calendar = Calendar.current
                        let now = Date()
                        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                        components.weekOfYear = (components.weekOfYear ?? 0) + weekOffset
                        if let weekStart = calendar.date(from: components) {
                            let targetDate = calendar.date(byAdding: .day, value: hovered.day, to: weekStart)!
                            let duration = statsManager.getHourlyStats(for: targetDate, hour: hovered.slot * 8, timeSlot: hovered.slot)
                            
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "M月d日"
                            let dateStr = dateFormatter.string(from: targetDate)
                            let timeRange = getTimeRange(for: hovered.slot)
                            return "\(dateStr) \(timeRange): \(formatDuration(duration))"
                        } else {
                            return "本周总专注时长: \(formatDuration(stats.totalDuration))"
                        }
                    } else {
                        return "本周总专注时长: \(formatDuration(stats.totalDuration))"
                    }
                }()
                
                Text(displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 热力图
                VStack(spacing: 4) {
                    // 星期标签
                    HStack(spacing: 4) {
                        ForEach(0..<7) { day in
                            Text(getDayLabel(day))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // 热力图网格
                    ForEach(0..<3) { slot in
                        HStack(spacing: 4) {
                            // 热力图单元格
                            ForEach(0..<7) { day in
                                HeatmapCell(
                                    value: stats.heatmap[day][slot],
                                    maxValue: getMaxValue(stats.heatmap),
                                    isHovered: hoveredCell?.day == day && hoveredCell?.slot == slot
                                )
                                .onHover { isHovering in
                                    if isHovering {
                                        hoveredCell = (day, slot)
                                    } else {
                                        hoveredCell = nil
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func getDayLabel(_ index: Int) -> String {
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return labels[index]
    }
    
    private func getTimeRange(for slot: Int) -> String {
        switch slot {
        case 0: return "0:00-7:00"
        case 1: return "8:00-15:00"
        case 2: return "16:00-24:00"
        default: return ""
        }
    }
    
    private func getMaxValue(_ heatmap: [[TimeInterval]]) -> TimeInterval {
        let maxValue = heatmap.flatMap { $0 }.max() ?? 1.0
        return max(maxValue, 3600) // 至少1小时作为基准
    }
}

struct HeatmapCell: View {
    let value: TimeInterval
    let maxValue: TimeInterval
    let isHovered: Bool
    
    var body: some View {
        let intensity = min(1.0, value / maxValue)
        let color = Color.blue.opacity(0.2 + intensity * 0.8)
        
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isHovered ? Color.blue : Color.clear, lineWidth: 2)
            )
    }
}
