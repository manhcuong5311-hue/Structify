//
//  AlldayeventRow.swift
//  Structify
//
//  Created by Sam Manh Cuong on 14/3/26.
//
import SwiftUI

struct AllDayEventsRow: View {

    let events: [EventItem]
    var onTap: (EventItem) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(events) { event in
                    Button {
                        onTap(event)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(event.color)
                                .frame(width: 40, height: 40)

                            Image(systemName: event.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .shadow(
                            color: event.color.opacity(0.3),
                            radius: 6,
                            y: 3
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}
