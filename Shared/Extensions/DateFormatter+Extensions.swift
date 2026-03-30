import Foundation

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

extension Date {
    var dayString: String {
        DateFormatter.dayFormatter.string(from: self)
    }
}
