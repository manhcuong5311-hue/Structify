//
//  StructifyWidgetBundle.swift
//  StructifyWidget
//
//  Created by Sam Manh Cuong on 18/3/26.
//

import WidgetKit
import SwiftUI

@main
struct StructifyWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextEventWidget()
        TimelineWidget()
        FullDayWidget()
        LockScreenInlineWidget()
        LockScreenCircularWidget()
        LockScreenRectangularWidget()
    }
}
