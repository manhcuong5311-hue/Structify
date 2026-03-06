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

                // HEADER FIXED
                HeaderDateView()

                WeekStripView()

                // TIMELINE CARD
                TimelineView()
                                    .padding(.top, 20)
                
                
                
            }
        }
    }
}
