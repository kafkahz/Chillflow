import SwiftUI
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    private var previousState: TimerState = .idle
    private var cancellables = Set<AnyCancellable>()
    
    let timerManager = TimerManager()
    let audioManager = AudioManager()
    let statsManager = StatsManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupStateObserver()
    }
    
    private func setupMenuBar() {
        // 使用固定长度，避免倒计时时左右移动
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "ChillFlow")
            image?.size = NSSize(width: 26, height: 26) // 调整图标大小
            button.image = image
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            
            // 设置等宽字体，确保数字宽度一致
            button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 300)
        popover?.behavior = .transient
        popover?.appearance = NSAppearance(named: .darkAqua) // 设置外观确保不透明
        
        let hostingController = NSHostingController(rootView: MainView()
            .environmentObject(timerManager)
            .environmentObject(audioManager)
            .environmentObject(statsManager))
        
        // 确保视图控制器的视图不透明
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        popover?.contentViewController = hostingController
    }
    
    private func setupStateObserver() {
        // 监听计时器状态变化，更新菜单栏图标和音频
        timerManager.$currentState
            .combineLatest(timerManager.$remainingTime)
            .sink { [weak self] state, _ in
                guard let self = self else { return }
                
                self.updateStatusBarIcon()
                
                // 处理音频同步
                let previousBaseState = self.previousState.getBaseState()
                let currentBaseState = state.getBaseState()
                
                print("AppDelegate: 状态变化 - 从 \(previousBaseState) 到 \(currentBaseState)")
                
                // 状态转换时自动控制音频
                switch (previousBaseState, currentBaseState) {
                case (.idle, .focus):
                    print("AppDelegate: 触发播放音频 - Idle -> Focus")
                    self.audioManager.playFocusAudio()
                case (.focus, .rest), (.focus, .longRest):
                    print("AppDelegate: 触发停止音频 - Focus -> Rest/LongRest")
                    self.audioManager.stopAudio()
                case (.rest, .focus):
                    print("AppDelegate: 触发播放音频 - Rest -> Focus")
                    self.audioManager.playFocusAudio()
                case (.longRest, .idle):
                    // Long Rest结束时不需要播放音频
                    print("AppDelegate: Long Rest结束 -> Idle，不播放音频")
                    break
                default:
                    print("AppDelegate: 其他状态转换，不处理音频")
                    break
                }
                
                self.previousState = state
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let baseImage = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "ChillFlow")
        baseImage?.size = NSSize(width: 26, height: 26) // 调整图标大小
        
        // 确保使用等宽字体，避免数字变化时宽度变化
        if button.font == nil {
            button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        }
        
        switch timerManager.currentState.getBaseState() {
        case .rest, .longRest:
            // 休息状态：显示图标和剩余时间
            let timeString = formatTime(timerManager.remainingTime)
            button.image = baseImage
            button.image?.isTemplate = true
            button.title = " \(timeString)"
            
            // 固定按钮长度，使用足够的宽度容纳时间文本
            statusItem?.length = 80 // 固定宽度，足够容纳图标和 " 05:00"
        default:
            // 空闲和专注状态：只显示图标
            button.title = ""
            button.image = baseImage
            button.image?.isTemplate = true
            
            // 只显示图标时使用较小的固定宽度
            statusItem?.length = NSStatusItem.squareLength
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // 激活应用窗口，确保popover正确显示并获得焦点
                NSApplication.shared.activate(ignoringOtherApps: true)
                
                // 显示popover
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // 确保popover窗口激活并获得焦点
                if let popoverWindow = popover.contentViewController?.view.window {
                    popoverWindow.makeKey()
                    popoverWindow.orderFrontRegardless()
                }
            }
        }
    }
}

@main
struct ChillFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

