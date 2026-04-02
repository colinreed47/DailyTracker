import WidgetKit
import SwiftUI

@main
struct DailyHabitsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TaskListWidget()
        TaskCountWidget()
        LockScreenTaskWidget()
    }
}
