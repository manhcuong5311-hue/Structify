//
//  CreateItemSheetModifier.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

struct CreateItemSheetModifier: ViewModifier {

    @Binding var isPresented: Bool
    var onCreate: ((EventKind, String, String) -> Void)?

    func body(content: Content) -> some View {

        content
            .sheet(isPresented: $isPresented) {

                CreateItemSheet(onCreate: onCreate)
                    .presentationDetents([.medium]) 
                    .presentationDragIndicator(.visible)
            }
        
    }
}

extension View {

    func createItemSheet(
        isPresented: Binding<Bool>,
        onCreate: ((EventKind, String, String) -> Void)? = nil
    ) -> some View {

        modifier(CreateItemSheetModifier(
            isPresented: isPresented,
            onCreate: onCreate
        ))
    }
}
