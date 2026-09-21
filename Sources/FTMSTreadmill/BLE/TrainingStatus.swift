import Foundation 

enum TrainingStatus: UInt8, CaseIterable { 
    case idle = 0x01

    case preWorkout = 0x0E

    case manual = 0x0D

    case postWorkout = 0x0F

    var label: String { 
        switch self {
            case .idle: return "Ready"
            case .preWorkout: return "Counting"
            case .manual: return "Training"
            case .postWorkout: return "Slow down"
        }
    }
    var isRunning: Bool { self == .manual || self == .postWorkout }
    var isStopped: Bool { self == .idle }
}
