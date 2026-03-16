//
//  ReviewManager.swift
//  Structify
//
//  Created by Sam Manh Cuong on 16/3/26.
//

import StoreKit
import UIKit

struct ReviewManager {

    private static let reviewCountKey    = "review_request_count"
    private static let lastReviewDateKey = "review_last_date"
    private static let eventCountKey     = "review_event_count"

    // Gọi sau mỗi lần tạo event thành công
    static func recordEventCreated() {
        let count = UserDefaults.standard.integer(forKey: eventCountKey) + 1
        UserDefaults.standard.set(count, forKey: eventCountKey)
        maybeRequestReview(eventCount: count)
    }

    private static func maybeRequestReview(eventCount: Int) {
        let reviewCount  = UserDefaults.standard.integer(forKey: reviewCountKey)
        let lastDate     = UserDefaults.standard.object(forKey: lastReviewDateKey) as? Date

        let shouldRequest: Bool = {
            switch reviewCount {
            case 0:
                // Lần 1 — sau khi tạo event thứ 3
                return eventCount >= 3

            case 1:
                // Lần 2 — sau 30 ngày kể từ lần 1
                guard let last = lastDate else { return false }
                return Date().timeIntervalSince(last) >= 30 * 86400

            case 2:
                // Lần 3 — sau 90 ngày kể từ lần 2
                guard let last = lastDate else { return false }
                return Date().timeIntervalSince(last) >= 90 * 86400

            default:
                // Đã dùng hết 3 lần
                return false
            }
        }()

        guard shouldRequest else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            requestReview()
            UserDefaults.standard.set(reviewCount + 1, forKey: reviewCountKey)
            UserDefaults.standard.set(Date(), forKey: lastReviewDateKey)
        }
    }

    private static func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        
        AppStore.requestReview(in: scene)
    }
}
