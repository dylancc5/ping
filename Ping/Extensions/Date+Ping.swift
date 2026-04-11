import Foundation

extension Date {
    /// Short relative label: "2d ago", "3w ago", "5mo ago", "Never" for nil.
    var relativeLabel: String {
        let seconds = Date.now.timeIntervalSince(self)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = days / 30.44

        switch days {
        case ..<1:   return hours < 1 ? "Just now" : "\(Int(hours))h ago"
        case ..<7:   return "\(Int(days))d ago"
        case ..<30:  return "\(Int(weeks))w ago"
        case ..<365: return "\(Int(months))mo ago"
        default:     return "\(Int(months / 12))y ago"
        }
    }

    /// Medium date: "Apr 5, 2024"
    var shortFormatted: String {
        formatted(date: .abbreviated, time: .omitted)
    }
}

extension Optional where Wrapped == Date {
    var relativeLabel: String {
        self?.relativeLabel ?? "Never"
    }
}
