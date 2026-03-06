import SwiftUI

struct EventItem: Identifiable, Equatable {

    let id = UUID()

    var time: String
    var title: String
    var icon: String
    var color: Color

    var minutes: Int {
        let parts = time.split(separator: ":")
        let h = Int(parts[0]) ?? 0
        let m = Int(parts[1]) ?? 0
        return h * 60 + m
    }

    mutating func update(minutes: Int) {

        let h = minutes / 60
        let m = minutes % 60

        time = String(format: "%02d:%02d", h, m)
    }
}
