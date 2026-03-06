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

import SwiftUI

enum AppAlert: Identifiable {

    case deleteEvent(EventItem)

    var id: String {

        switch self {
        case .deleteEvent(let event):
            return event.id.uuidString
        }
    }
}
