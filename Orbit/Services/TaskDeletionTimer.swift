import Foundation
import Combine

final class TaskDeletionTimer: ObservableObject {
    static let shared = TaskDeletionTimer()
    
    @Published var activeTimers: [UUID: Int] = [:]
    private var cancellables: [UUID: AnyCancellable] = [:]
    private var completionHandlers: [UUID: () -> Void] = [:]
    
    private init() {}

    func startTimer(for taskId: UUID, onComplete: @escaping () -> Void) {
        cancelTimer(for: taskId)
        
        activeTimers[taskId] = 5
        completionHandlers[taskId] = onComplete

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            guard let current = self.activeTimers[taskId] else {
                timer.invalidate()
                return
            }
            
            if current <= 1 {
                timer.invalidate()
                self.cancelTimer(for: taskId)
                if let handler = self.completionHandlers[taskId] {
                    handler()
                    self.completionHandlers.removeValue(forKey: taskId)
                }
            } else {
                self.activeTimers[taskId] = current - 1
            }
        }

        let cancellable = AnyCancellable {
            timer.invalidate()
        }
        cancellables[taskId] = cancellable
    }

    func cancelTimer(for taskId: UUID) {
        cancellables[taskId]?.cancel()
        cancellables.removeValue(forKey: taskId)
        activeTimers.removeValue(forKey: taskId)
        completionHandlers.removeValue(forKey: taskId)
    }

    func isTimerActive(for taskId: UUID) -> Bool {
        return activeTimers[taskId] != nil
    }

    func remainingTime(for taskId: UUID) -> Int? {
        return activeTimers[taskId]
    }
}

