//
//  AppSheet.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

// TÌM AppSheet enum (file riêng hoặc cùng file):
enum AppSheet: Identifiable {
    case createItem
    case eventDetail(EventItem)
    // 👈 thêm:
    case habitDetail(EventItem)

    var id: String {
        switch self {
        case .createItem:        return "createItem"
        case .eventDetail(let e): return "event-\(e.id)"
        case .habitDetail(let e): return "habit-\(e.id)"
        }
    }
}



enum AppAlert: Identifiable {
    case deleteEvent(EventItem)
    case systemEventChange(EventItem, Int)
    case recurringTimeChange(EventItem, Int)      // 👈 thêm — drag
    case recurringDurationChange(EventItem, Int)  // 👈 thêm — resize

    var id: String {
        switch self {
        case .deleteEvent(let e):           return "delete_\(e.id)"
        case .systemEventChange(let e, _):  return "system_\(e.id)"
        case .recurringTimeChange(let e, _):     return "time_\(e.id)"
        case .recurringDurationChange(let e, _): return "dur_\(e.id)"
        }
    }
}
