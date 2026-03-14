//
//  AppSheet.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

enum AppSheet: Identifiable {

    case createItem
    case eventDetail(EventItem)

    var id: String {

        switch self {

        case .createItem:
            return "createItem"

        case .eventDetail(let event):
            return event.id.uuidString
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
