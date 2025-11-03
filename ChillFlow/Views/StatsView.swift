import SwiftUI
import AppKit

struct StatsView: View {
    @EnvironmentObject var statsManager: StatsManager
    @State private var weekOffset = 0
    @State private var hoveredCell: (day: Int, slot: Int)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 中间内容组
            VStack(spacing: 10) {
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
                .padding(.top, 15)
                
                // 总专注时长和热力图
                Group {
                    let stats = statsManager.getWeeklyStats(weekOffset: weekOffset)
                
                let displayText: String = {
                    if let hovered = hoveredCell {
                        let calendar = Calendar.current
                        let now = Date()
                        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                        components.weekOfYear = (components.weekOfYear ?? 0) + weekOffset
                        if let weekStartDate = calendar.date(from: components) {
                            // 确保是周一
                            let weekday = calendar.component(.weekday, from: weekStartDate)
                            let daysFromMonday = weekday == 1 ? 1 : weekday - 2
                            if let weekStart = calendar.date(byAdding: .day, value: daysFromMonday, to: weekStartDate) {
                                let targetDate = calendar.date(byAdding: .day, value: hovered.day, to: weekStart)!
                                let duration = statsManager.getHourlyStats(for: targetDate, hour: hovered.slot * 8, timeSlot: hovered.slot)
                                
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "M月d日"
                                let dateStr = dateFormatter.string(from: targetDate)
                                let timeRange = getTimeRange(for: hovered.slot)
                                return "\(dateStr) \(timeRange): \(formatDuration(duration))"
                            }
                        }
                        return "本周总专注时长: \(formatDuration(stats.totalDuration))"
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
                                let cellValue = stats.heatmap[day][slot]
                                HeatmapCell(
                                    value: cellValue,
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
            
            Spacer()
                .frame(height: 30)
            
            // GitHub链接按钮
            Button(action: {
                if let url = URL(string: "https://github.com/kafkahz/Chillflow") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("ChillFlow")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 8)
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
        let maxValue = heatmap.flatMap { $0 }.max() ?? 0.0
        // 如果有数据，使用实际最大值；如果没有数据，返回一个基准值用于计算
        if maxValue > 0 {
            return maxValue
        } else {
            return 3600 // 至少1小时作为基准，但只在没有数据时使用
        }
    }
}

struct HeatmapCell: View {
    let value: TimeInterval
    let maxValue: TimeInterval
    let isHovered: Bool
    
    var body: some View {
        // 有数据就显示明显颜色，无数据显示淡色
        let hasData = value > 0
        
        let backgroundColor: Color = {
            if hasData {
                // 计算强度比例：当前值相对于最大值的比例
                let intensity = maxValue > 0 ? min(1.0, value / maxValue) : 1.0
                
                // 扩大不透明度范围：从0.3到1.0，让颜色深浅差异更明显
                // 使用平方根函数让渐变更平滑自然
                let normalizedIntensity = sqrt(intensity) // 平方根使低值更明显
                let opacity = 0.3 + normalizedIntensity * 0.7 // 范围：0.3 - 1.0
                
                // 根据强度调整颜色：低强度用较淡的蓝色，高强度用较深的蓝色
                return Color(NSColor.systemBlue).opacity(opacity)
            } else {
                // 无数据时使用很淡的背景色
                return Color(NSColor.separatorColor).opacity(0.15)
            }
        }()
        
        RoundedRectangle(cornerRadius: 4)
            .fill(backgroundColor)
            .frame(height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isHovered ? Color.accentColor : Color.clear, lineWidth: 2)
            )
    }
}
