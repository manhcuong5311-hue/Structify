//
//  ScheduleView.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//
import SwiftUI

struct ScheduleView: View {

    var body: some View {

        ZStack(alignment: .bottom) {

            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                HeaderDateView()
                WeekStripView()

                Spacer()
            }

            FloatingCard {

                TimelineView()

            }
        }
    }
}

import SwiftUI

struct FloatingCard<Content: View>: View {

    let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var lastOffset: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {

        GeometryReader { geo in

            let maxDrag = geo.size.height * 0.65

            content
                .background(.white)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 28,
                        style: .continuous
                    )
                )
                .shadow(color: .black.opacity(0.08),
                        radius: 12,
                        y: 4)

                .overlay(alignment: .top) {

                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundStyle(.gray.opacity(0.4))
                        .padding(.top, -15)

                        // tăng vùng chạm
                        .padding(.vertical, 20)
                        .contentShape(Rectangle())

                        // gesture ưu tiên
                        .highPriorityGesture(
                            DragGesture()
                                .onChanged { value in

                                    let newOffset =
                                    lastOffset + value.translation.height

                                    dragOffset =
                                    min(max(newOffset, 0), maxDrag)
                                }

                                .onEnded { _ in

                                    if dragOffset > maxDrag * 0.5 {
                                        dragOffset = maxDrag
                                    } else {
                                        dragOffset = 0
                                    }

                                    lastOffset = dragOffset
                                }
                        )
                }

                .offset(y: 145 + dragOffset)
                .animation(.spring(response: 0.35,
                                   dampingFraction: 0.85),
                           value: dragOffset)
        }
    }
}
