import SwiftUI

struct ControlView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 0) {
            // 中间内容组
            VStack(spacing: 10) {
                // 状态显示
                Text(timerManager.currentState.displayName)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 15)
                
                // 时间显示
                Text(formatTimeForDisplay())
                    .font(.system(size: 45, weight: .light, design: .rounded))
                    .monospacedDigit()
                
                // 周期显示
                if !timerManager.currentCycle.isEmpty {
                    Text("第 \(timerManager.currentCycle) 个周期")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 控制按钮
                VStack(spacing: 6) {
                    // 开始按钮（仅在空闲状态显示）
                    if case .idle = timerManager.currentState {
                        Button(action: {
                            timerManager.start()
                            // 音频会在AppDelegate的状态监听中自动触发
                        }) {
                            Text("开始专注")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    } else {
                        // 暂停/继续、跳过、重置按钮
                        HStack(spacing: 8) {
                            // 暂停/继续
                            if case .paused = timerManager.currentState {
                                Button(action: {
                                    timerManager.resume()
                                    audioManager.resumeAudio()
                                }) {
                                    Image(systemName: "play.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button(action: {
                                    timerManager.pause()
                                    audioManager.pauseAudio()
                                }) {
                                    Image(systemName: "pause.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // 跳过
                            Button(action: {
                                timerManager.skip()
                                // 音频会在AppDelegate的状态监听中自动触发
                            }) {
                                Image(systemName: "forward.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.bordered)
                            
                            // 重置
                            Button(action: {
                                timerManager.reset()
                                // 重置时停止音频
                                audioManager.stopAudio()
                            }) {
                                Image(systemName: "stop.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            
            // 按钮和音量控制之间的间距
            Spacer()
                .frame(height: 30)
            
            // 音量控制（固定在底部）
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Slider(value: $audioManager.volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
            .padding(.top, 0)
        }
    }
    
    private func formatTimeForDisplay() -> String {
        // 空闲状态时显示"25:00"
        if case .idle = timerManager.currentState {
            return "25:00"
        }
        return formatTime(timerManager.remainingTime)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

