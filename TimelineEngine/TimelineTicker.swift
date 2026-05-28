import Combine
import Foundation

@MainActor
final class TimelineTicker: ObservableObject {

    @Published var now: Int = TimelineEngine.currentMinutes()

    private var cancellable: AnyCancellable?

    init(interval: TimeInterval = 30) {
        cancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.now = TimelineEngine.currentMinutes()
            }
    }
}
