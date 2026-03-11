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

    var id: String {

        switch self {

        case .deleteEvent(let event):
            return "delete-\(event.id)"

        case .systemEventChange(let event, _):
            return "system-\(event.id)"
        }
    }
}
