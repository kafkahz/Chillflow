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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "ChillFlow")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 300)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MainView()
            .environmentObject(timerManager)
            .environmentObject(audioManager)
            .environmentObject(statsManager))
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
                
                // 状态转换时自动控制音频
                switch (previousBaseState, currentBaseState) {
                case (.idle, .focus):
                    self.audioManager.playFocusAudio()
                case (.focus, .rest), (.focus, .longRest):
                    self.audioManager.stopAudio()
                case (.rest, .focus):
                    self.audioManager.playFocusAudio()
                case (.longRest, .idle):
                    // Long Rest结束时不需要播放音频
                    break
                default:
                    break
                }
                
                self.previousState = state
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }
        
        let baseImage = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "ChillFlow")
        
        switch timerManager.currentState.getBaseState() {
        case .rest, .longRest:
            // 休息状态：显示图标和剩余时间
            let timeString = formatTime(timerManager.remainingTime)
            button.image = baseImage
            button.image?.isTemplate = true
            button.title = " \(timeString)"
        default:
            // 空闲和专注状态：只显示图标
            button.title = ""
            button.image = baseImage
            button.image?.isTemplate = true
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
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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

