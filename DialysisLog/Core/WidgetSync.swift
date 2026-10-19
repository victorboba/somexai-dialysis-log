import Foundation
import WidgetKit

enum WidgetSync {
    /// The Home Screen answers the only question between exchanges: how many so far today,
    /// and how much has come off.
    static func update(with days: [DayRecord], prescription: Prescription?) {
        let today = days.first { Calendar.current.isDateInToday($0.date) }
        var snapshot = WidgetSnapshot()
        snapshot.totalEntries = days.reduce(0) { $0 + $1.sortedTreatments.count }
        snapshot.todayCount = today?.sortedTreatments.count ?? 0
        snapshot.prescribedCount = prescription?.modality.isPeritoneal == true
            ? (prescription?.exchangesPerDay ?? 0) : 0
        if let uf = today?.totalUF {
            snapshot.todayUF = Int(uf)
            snapshot.hasTodayUF = true
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
