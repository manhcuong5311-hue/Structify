//
//  Global.swift
//  Structify
//
//  Created by Sam Manh Cuong on 9/3/26.
//
import SwiftUI

struct IPadSheetModifier: ViewModifier {

    func body(content: Content) -> some View {

        if UIDevice.current.userInterfaceIdiom == .pad {

            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)

        } else {

            content
        }
    }
}
