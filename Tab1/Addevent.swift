//
//  Addevent.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//
import SwiftUI

struct AddEventButton: View {

    var body: some View {

        HStack {

            Spacer()

            HStack(spacing:8){

                Image(systemName:"plus.circle.fill")

                Text("Thêm việc")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal,18)
            .padding(.vertical,10)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )

            Spacer()
        }
    }
}
