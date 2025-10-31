import Foundation

indirect enum TimerState {
    case idle
    case focus(focusCount: Int)
    case rest(restCount: Int)
    case longRest
    case paused(state: TimerState)
}

extension TimerState {
    var displayName: String {
        switch self {
        case .idle:
            return "空闲"
        case .focus:
            return "专注"
        case .rest:
            return "休息"
        case .longRest:
            return "长休息"
        case .paused:
            return "已暂停"
        }
    }
    
    var shouldPlayFocusAudio: Bool {
        switch self {
        case .focus, .paused(.focus):
            return true
        default:
            return false
        }
    }
    
    func getBaseState() -> TimerState {
        if case .paused(let baseState) = self {
            return baseState
        }
        return self
    }
}

