import WidgetKit
import SwiftUI

@main
struct DailyTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskListWidget()
        TaskCountWidget()
    }
}
