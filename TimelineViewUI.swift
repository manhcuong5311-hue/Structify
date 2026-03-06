//
//  Untitled.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//

import SwiftUI

struct TimelineViewUI: View {
    
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
                    
                    VStack(spacing: 30) {
                        
                        TimelineItem(
                            time: "06:00",
                            title: "Rise and Shine",
                            icon: "alarm.fill",
                            color: .orange,
                            done: true
                        )
                        
                        TimelineGap(text: "Nhiệm vụ sắp tới. Có 8g 34ph để lên kế hoạch.")
                        
                        TimelineItem(
                            time: "21:10–22:40",
                            title: "Xem phim",
                            icon: "tv.fill",
                            color: .blue,
                            done: false
                        )
                        
                        TimelineGap(text: "Nghỉ nhanh 50ph để thêm sáng tạo.")
                        
                        TimelineItem(
                            time: "23:30",
                            title: "Wind Down",
                            icon: "moon.fill",
                            color: .blue,
                            done: false
                        )
                    }
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
    }
}






struct TimelineItem: View {
    
    var time: String
    var title: String
    var icon: String
    var color: Color
    var done: Bool
    
    var body: some View {
        
        HStack(alignment: .top, spacing: 16) {
            
            Text(time)
                .font(.caption)
                .frame(width: 70, alignment: .leading)
            
            ZStack {
                
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 60, height: 120)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading) {
                
                Text(title)
                    .font(.headline)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 28, height: 28)
                .overlay(
                    done ?
                    Image(systemName: "checkmark")
                        .foregroundColor(.orange)
                    : nil
                )
        }
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


