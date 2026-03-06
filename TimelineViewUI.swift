//
//  Untitled.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI
import Combine

struct TimelineViewUI: View {
    
    @State private var previewTime: String = ""
    @StateObject private var engine = TimelineEngine()
    
    
    func todayAt(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        )!
    }
    
    
    var body: some View {
        
        ZStack(alignment: .top) {
            
            // LAYER 0 — HEADER BACKGROUND
            VStack {
                HeaderView()
                    .padding(.top, 35)   // 👈 đẩy header xuống
                Spacer()
            }
            .background(Color(.systemGray6))
            
            // LAYER 1 — CARD CONTAINING TIMELINE
            VStack(spacing: 0) {
                
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                
                ScrollView {

                    TimelineContainer(
                        engine: engine,
                        startOfDay: Calendar.current.startOfDay(for: Date())
                    )
                    .padding()
                }
                
                BottomBar()
            }
            
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
            )
            .offset(y: 180)   // đẩy card xuống để header lộ phía sau
        }
        
        .ignoresSafeArea(edges: .top)
        .onAppear {

            engine.events = [

                TimelineEvent(
                    id: UUID(),
                    title: "Rise and Shine",
                    start: todayAt(6,0),
                    end: todayAt(7,0),
                    color: "orange"
                ),

                TimelineEvent(
                    id: UUID(),
                    title: "Xem phim",
                    start: todayAt(21,10),
                    end: todayAt(22,40),
                    color: "blue"
                ),

                TimelineEvent(
                    id: UUID(),
                    title: "Wind Down",
                    start: todayAt(23,30),
                    end: todayAt(23,50),
                    color: "blue"
                )
            ]
        }
    }
}






struct TimelineItem: View {

    let event: TimelineEvent
    
    
    @State private var dragOffset: CGFloat = 0
    private let engine = TimelineEngine()
    @State private var previewTime: String = ""
    
    
    var eventColor: Color {
        event.color == "orange" ? .orange : .blue
    }
    
    func timeFromString(_ time: String) -> Int {
        let parts = time.split(separator: ":")
        guard parts.count == 2 else { return 0 }
        
        let hour = Int(parts[0]) ?? 0
        let minute = Int(parts[1]) ?? 0
        
        return hour * 60 + minute
    }
    
    var timeString: String {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        return formatter.string(from: event.start)
    }
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 16) {
            
            Text(timeString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            
            Image(systemName: "alarm.fill")
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(eventColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                
                Text(event.title)
                    .font(.headline)
                
                Text(timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 28, height: 28)
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    
                    dragOffset = value.translation.height
                    
                    let baseMinutes = Calendar.current.dateComponents(
                        [.minute],
                        from: Calendar.current.startOfDay(for: event.start),
                        to: event.start
                    ).minute ?? 0

                    let deltaMinutes = Int(dragOffset / engine.pixelPerMinute)

                    let newMinutes = baseMinutes + deltaMinutes

                    let hour = newMinutes / 60
                    let minute = newMinutes % 60

                    previewTime = String(format: "%02d:%02d", hour, minute)
                }
                .onEnded { value in
                    
                    dragOffset = 0
                    previewTime = ""
                }
        )
        .overlay(
            Group {
                if !previewTime.isEmpty {
                    Text(previewTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .offset(x: -90)
                }
            },
            alignment: .leading
        )
        .animation(.spring(), value: dragOffset)
    }
}

struct TimelineGap: View {
    
    var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "clock")
            
            Text(text)
                .font(.caption)
            
            Spacer()
        }
        .foregroundColor(.gray)
    }
}


struct BottomBar: View {
    
    var body: some View {
        
        HStack {
            
            TabItem(icon: "tray", title: "Hộp thư")
            TabItem(icon: "list.bullet", title: "Lịch trình", selected: true)
            TabItem(icon: "sparkles", title: "AI")
            TabItem(icon: "gear", title: "Cài đặt")
            
            Spacer()
            
            Button {
                
            } label: {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                    )
            }
        }
        .padding()
        .background(Color.white)
    }
}

struct TabItem: View {
    
    var icon: String
    var title: String
    var selected: Bool = false
    
    var body: some View {
        
        VStack {
            Image(systemName: icon)
            Text(title)
                .font(.caption)
        }
        .foregroundColor(selected ? .orange : .black)
        .frame(maxWidth: .infinity)
    }
}


