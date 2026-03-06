//
//  Addhabit.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//
import SwiftUI

struct AddHabitButton: View {

    var body: some View {

        HStack {

            Spacer()

            HStack(spacing:8){

                Image(systemName:"repeat.circle.fill")

                Text("Thêm thói quen")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.green)
            .padding(.horizontal,18)
            .padding(.vertical,10)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )

            Spacer()
        }
    }
}
