import Foundation

// Heuristic icon/color suggestion based on what the user typed in the title
// field. Used by the create-event sheet to "magic" the icon while the user
// types so common events (Meeting, Gym, Lunch...) don't need a manual pick.
//
// Lookup is case-insensitive substring match against a lowercased title.
// Keywords cover both English and Vietnamese for the most common verbs/nouns.
// Order matters: earlier matchers win, so put the more specific ones first
// (e.g. "tập gym" before generic "tập").

struct KeywordMatcher {
    let keywords: [String]
    let icon: String
    let colorHex: String
}

enum KeywordIconMap {

    static let matchers: [KeywordMatcher] = [

        // ─── Work / meetings ───
        KeywordMatcher(keywords: ["standup", "stand-up", "daily"],
                       icon: "figure.stand", colorHex: "#6A7AE0"),
        KeywordMatcher(keywords: ["interview", "phỏng vấn", "phong van"],
                       icon: "person.text.rectangle.fill", colorHex: "#3F4D7A"),
        KeywordMatcher(keywords: ["presentation", "thuyết trình", "thuyet trinh", "demo"],
                       icon: "chart.bar.fill", colorHex: "#E07A4B"),
        KeywordMatcher(keywords: ["meeting", "họp", "hop", "zoom", "team sync", "sync"],
                       icon: "person.2.fill", colorHex: "#5B82F0"),
        KeywordMatcher(keywords: ["call", "gọi", "goi", "phone"],
                       icon: "phone.fill", colorHex: "#3DB5B0"),
        KeywordMatcher(keywords: ["focus", "deep work", "tập trung", "tap trung"],
                       icon: "laptopcomputer", colorHex: "#7059D6"),
        KeywordMatcher(keywords: ["email", "inbox", "mail"],
                       icon: "envelope.fill", colorHex: "#4FA8D0"),
        KeywordMatcher(keywords: ["review", "đánh giá", "danh gia"],
                       icon: "checklist", colorHex: "#4B82C0"),

        // ─── Meals ───
        KeywordMatcher(keywords: ["breakfast", "sáng", "ăn sáng", "an sang"],
                       icon: "sun.and.horizon.fill", colorHex: "#F5A65B"),
        KeywordMatcher(keywords: ["lunch", "ăn trưa", "an trua", "trưa", "trua"],
                       icon: "fork.knife", colorHex: "#7BC15B"),
        KeywordMatcher(keywords: ["dinner", "ăn tối", "an toi", "tối", "toi"],
                       icon: "fork.knife.circle.fill", colorHex: "#4FA86F"),
        KeywordMatcher(keywords: ["coffee", "cà phê", "ca phe", "cafe"],
                       icon: "cup.and.saucer.fill", colorHex: "#A86B3F"),

        // ─── Fitness ───
        KeywordMatcher(keywords: ["yoga"],
                       icon: "figure.yoga", colorHex: "#E07AAE"),
        KeywordMatcher(keywords: ["gym", "tập gym", "tap gym"],
                       icon: "dumbbell.fill", colorHex: "#EA5757"),
        KeywordMatcher(keywords: ["run", "chạy", "chay bo", "chạy bộ", "jog"],
                       icon: "figure.run", colorHex: "#FF8A3A"),
        KeywordMatcher(keywords: ["workout", "exercise", "tập luyện", "tap luyen", "tập"],
                       icon: "figure.strengthtraining.traditional", colorHex: "#FF8A3A"),
        KeywordMatcher(keywords: ["swim", "bơi", "boi"],
                       icon: "figure.pool.swim", colorHex: "#4FA8D0"),
        KeywordMatcher(keywords: ["walk", "đi bộ", "di bo"],
                       icon: "figure.walk", colorHex: "#4CD980"),

        // ─── Health ───
        KeywordMatcher(keywords: ["doctor", "bác sĩ", "bac si", "khám", "kham"],
                       icon: "cross.case.fill", colorHex: "#D8645B"),
        KeywordMatcher(keywords: ["therapy", "trị liệu", "tri lieu", "tâm lý", "tam ly"],
                       icon: "brain.head.profile", colorHex: "#2EB7A7"),
        KeywordMatcher(keywords: ["dentist", "nha sĩ", "nha si", "răng", "rang"],
                       icon: "mouth.fill", colorHex: "#E26B8E"),

        // ─── Learning ───
        KeywordMatcher(keywords: ["class", "lớp học", "lop hoc", "lớp", "lop"],
                       icon: "graduationcap.fill", colorHex: "#4B82C0"),
        KeywordMatcher(keywords: ["study", "học bài", "hoc bai", "ôn tập", "on tap"],
                       icon: "book.fill", colorHex: "#9C6CDC"),
        KeywordMatcher(keywords: ["read", "đọc sách", "doc sach", "reading"],
                       icon: "book.closed.fill", colorHex: "#6A7AB0"),
        KeywordMatcher(keywords: ["course", "khoá học", "khoa hoc"],
                       icon: "laptopcomputer", colorHex: "#A36AE0"),

        // ─── Personal ───
        KeywordMatcher(keywords: ["date", "hẹn hò", "hen ho"],
                       icon: "heart.fill", colorHex: "#E26B8E"),
        KeywordMatcher(keywords: ["shopping", "mua sắm", "mua sam"],
                       icon: "cart.fill", colorHex: "#EC6C8A"),
        KeywordMatcher(keywords: ["errand", "việc vặt", "viec vat"],
                       icon: "bag.fill", colorHex: "#E5A23A"),
        KeywordMatcher(keywords: ["appointment", "lịch hẹn", "lich hen", "cuộc hẹn", "cuoc hen"],
                       icon: "calendar.badge.clock", colorHex: "#D85B82"),
        KeywordMatcher(keywords: ["family", "gia đình", "gia dinh"],
                       icon: "house.fill", colorHex: "#7BC15B"),
        KeywordMatcher(keywords: ["birthday", "sinh nhật", "sinh nhat"],
                       icon: "gift.fill", colorHex: "#E26B8E"),
        KeywordMatcher(keywords: ["party", "tiệc", "tiec"],
                       icon: "party.popper.fill", colorHex: "#E2A23E"),

        // ─── Lifestyle / transit ───
        KeywordMatcher(keywords: ["flight", "bay", "máy bay", "may bay", "fly"],
                       icon: "airplane", colorHex: "#5BA8D6"),
        KeywordMatcher(keywords: ["travel", "du lịch", "du lich", "trip"],
                       icon: "airplane.departure", colorHex: "#5BA8D6"),
        KeywordMatcher(keywords: ["commute", "đi làm", "di lam", "drive"],
                       icon: "car.fill", colorHex: "#7B8794"),
        KeywordMatcher(keywords: ["break", "nghỉ", "nghi", "rest"],
                       icon: "pause.circle.fill", colorHex: "#9CD0E5"),
        KeywordMatcher(keywords: ["sleep", "ngủ", "ngu", "đi ngủ", "di ngu"],
                       icon: "moon.zzz.fill", colorHex: "#6C7AA6"),
        KeywordMatcher(keywords: ["movie", "phim", "cinema"],
                       icon: "film.fill", colorHex: "#C75BAF"),
        KeywordMatcher(keywords: ["music", "nhạc", "nhac", "concert"],
                       icon: "music.note", colorHex: "#E25A8E")
    ]

    /// Returns the first matcher whose keywords appear in `title` (case-insensitive
    /// substring). Returns nil if no keyword matches.
    static func match(_ title: String) -> KeywordMatcher? {
        let lower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return nil }
        for matcher in matchers {
            if matcher.keywords.contains(where: { lower.contains($0) }) {
                return matcher
            }
        }
        return nil
    }
}
