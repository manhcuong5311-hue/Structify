//
//  AddItemButton.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

struct AddItemButton: View {

    var action: () -> Void

    var body: some View {

        Button(action: action) {

            HStack(spacing:6) {

                Image(systemName: "plus.circle.fill")

                Text(String(localized:"add"))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal,12)
            .padding(.vertical,6)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
    }
}
