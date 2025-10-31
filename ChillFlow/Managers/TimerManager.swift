import Foundation
import Combine

class TimerManager: ObservableObject {
    @Published var currentState: TimerState = .idle
    @Published var remainingTime: TimeInterval = 0
    @Published var focusCount: Int = 0
    
    private var timer: Timer?
    private var startDate: Date?
    private var pausedRemainingTime: TimeInterval = 0
    
    // 番茄钟配置
    private let focusDuration: TimeInterval = 25 * 60 // 25分钟
    private let restDuration: TimeInterval = 5 * 60   // 5分钟
    private let longRestDuration: TimeInterval = 30 * 60 // 30分钟（需求1.5：最后1个专注后休息30分钟）
    private let maxFocusSessions = 3
    
    var isRunning: Bool {
        timer != nil
    }
    
    var currentCycle: String {
        switch currentState {
        case .focus(let count):
            return "\(count)/\(maxFocusSessions)"
        case .rest(let count):
            return "\(count)/\(maxFocusSessions)"
        default:
            return ""
        }
    }
    
    func start() {
        guard case .idle = currentState else { return }
        
        focusCount = 1
        startFocus()
    }
    
    func pause() {
        guard timer != nil else { return }
        
        // 保存剩余时间和已暂停时间
        if let startDate = startDate {
            let elapsed = Date().timeIntervalSince(startDate)
            let baseState = currentState.getBaseState()
            let totalDuration: TimeInterval = {
                switch baseState {
                case .focus:
                    return focusDuration
                case .rest:
                    return restDuration
                case .longRest:
                    return longRestDuration
                default:
                    return 0
                }
            }()
            pausedRemainingTime = max(0, totalDuration - elapsed)
        } else {
            pausedRemainingTime = remainingTime
        }
        
        let baseState = currentState.getBaseState()
        currentState = .paused(state: baseState)
        timer?.invalidate()
        timer = nil
        startDate = nil
    }
    
    func resume() {
        guard case .paused(let baseState) = currentState else { return }
        
        currentState = baseState
        // 从剩余时间继续
        let durationToResume = pausedRemainingTime > 0 ? pausedRemainingTime : remainingTime
        startTimer(with: durationToResume)
        pausedRemainingTime = 0
    }
    
    func skip() {
        timer?.invalidate()
        timer = nil
        
        switch currentState.getBaseState() {
        case .focus(let count):
            // 跳过专注：直接进入下一阶段
            if count < maxFocusSessions {
                // 前2个专注后进入短休息
                startRest(count: count)
            } else {
                // 第3个专注后进入长休息
                startLongRest()
            }
        case .rest(let count):
            // 跳过休息：进入下一个专注周期
            // 注意：count表示这是第count个专注后的休息，所以下一个专注是count+1
            focusCount = count + 1
            if focusCount <= maxFocusSessions {
                startFocus()
            } else {
                // 不应该出现这种情况，但为了安全
                startLongRest()
            }
        case .longRest:
            // 跳过长休息：重置为空闲状态
            reset()
        default:
            break
        }
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        currentState = .idle
        remainingTime = 0
        focusCount = 0
        startDate = nil
        pausedRemainingTime = 0
    }
    
    private func startFocus() {
        currentState = .focus(focusCount: focusCount)
        startTimer(with: focusDuration)
    }
    
    private func startRest(count: Int) {
        currentState = .rest(restCount: count)
        startTimer(with: restDuration)
    }
    
    private func startLongRest() {
        currentState = .longRest
        startTimer(with: longRestDuration)
    }
    
    private func startTimer(with duration: TimeInterval) {
        remainingTime = duration
        pausedRemainingTime = 0
        startDate = Date()
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        
        // 确保计时器在后台也能运行
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func tick() {
        guard let startDate = startDate else { return }
        
        let elapsed = Date().timeIntervalSince(startDate)
        let baseState = currentState.getBaseState()
        
        let totalDuration: TimeInterval = {
            switch baseState {
            case .focus:
                return focusDuration
            case .rest:
                return restDuration
            case .longRest:
                return longRestDuration
            default:
                return 0
            }
        }()
        
        remainingTime = max(0, totalDuration - elapsed)
        
        if remainingTime <= 0 {
            onTimerComplete()
        }
    }
    
    private func onTimerComplete() {
        timer?.invalidate()
        timer = nil
        
        switch currentState.getBaseState() {
        case .focus(let count):
            // 每个专注周期结束时记录统计数据
            StatsManager.shared.recordFocusSession(duration: focusDuration)
            
            if count < maxFocusSessions {
                startRest(count: count)
            } else {
                // 第3个专注结束后进入长休息
                startLongRest()
            }
        case .rest(let count):
            focusCount = count + 1
            if focusCount <= maxFocusSessions {
                startFocus()
            } else {
                startLongRest()
            }
        case .longRest:
            reset()
        default:
            break
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

