//
//  Header.swift
//  Structify
//
//  Created by Sam Manh Cuong on 6/3/26.
//
import SwiftUI

struct HeaderView: View {
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text("6 thg 3,")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("2026")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                WeekDay(day: "2", selected: false)
                WeekDay(day: "3", selected: false)
                WeekDay(day: "4", selected: false)
                WeekDay(day: "5", selected: false)
                WeekDay(day: "6", selected: true)
                WeekDay(day: "7", selected: false)
                WeekDay(day: "8", selected: false)
            }
            
        }
        .padding()
    }
}

struct WeekDay: View {
    
    var day: String
    var selected: Bool
    
    var body: some View {
        
        Text(day)
            .font(.headline)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(selected ? Color.orange : Color.clear)
            )
            .foregroundColor(selected ? .white : .black)
    }
}
