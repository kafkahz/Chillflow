import SwiftUI

struct MainView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var statsManager: StatsManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部Tab栏和退出按钮（固定位置）
            ZStack {
                // Tab选择器居中
                HStack {
                    Spacer()
                    Picker("", selection: $selectedTab) {
                        Text("控制").tag(0)
                        Text("统计").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 150)
                    Spacer()
                }
                
                // 退出按钮在右侧
                HStack {
                    Spacer()
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Image(systemName: "power")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 12)
                }
            }
            .padding(.top, 30)
            .padding(.bottom, 4)
            .frame(height: 30) // 固定Tab栏高度
            
            // Tab内容（带滑动动画）
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // 控制视图
                    ControlView()
                        .environmentObject(timerManager)
                        .environmentObject(audioManager)
                        .frame(width: geometry.size.width)
                    
                    // 统计视图
                    StatsView()
                        .environmentObject(statsManager)
                        .frame(width: geometry.size.width)
                }
                .offset(x: -CGFloat(selectedTab) * geometry.size.width)
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // 占据剩余空间
            .clipped() // 裁剪超出边界的内容
        }
        .frame(width: 320, height: 300)
        .background(Color(NSColor.windowBackgroundColor)) // 设置明确背景色，确保不透明
    }
}

