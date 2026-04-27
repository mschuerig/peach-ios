import Testing
import Foundation
import SwiftUI
@testable import Peach

/// AC 6 of Story 77.2: every registered discipline that overrides
/// ``TrainingDisciplineUI/profileCard`` must surface a non-default view, and
/// disciplines that do not override must inherit the default
/// ``ProgressChartView``. The aggregating ``ProfileScreen`` renders whatever
/// ``profileCard`` returns; this test pins that contract end-to-end against
/// the production bootstrap list.
@Suite("TrainingDisciplineUI — profileCard")
struct ProfileCardConformanceTests {

    private let registry = TrainingDisciplineRegistry(disciplines: DisciplineBootstrap.allDisciplines)

    /// Disciplines that ship an explicit profile card. Other registered
    /// disciplines must inherit the default ``ProgressChartView``.
    private static let disciplinesWithCustomProfileCard: Set<TrainingDisciplineID> = [
        .timingOffsetDetection,
        .continuousRhythmMatching,
    ]

    @Test("disciplines without an override inherit the default ProgressChartView")
    func defaultProfileCardIsProgressChartView() async {
        for discipline in registry.allUI
        where !Self.disciplinesWithCustomProfileCard.contains(discipline.id) {
            let signature = Self.viewTypeSignature(of: discipline.profileCard)
            #expect(
                signature.contains("ProgressChartView"),
                "\(discipline.id) should inherit the default ProgressChartView but rendered \(signature)"
            )
        }
    }

    @Test("disciplines with an override do not return the default ProgressChartView")
    func overriddenProfileCardIsNotDefault() async {
        for discipline in registry.allUI
        where Self.disciplinesWithCustomProfileCard.contains(discipline.id) {
            let signature = Self.viewTypeSignature(of: discipline.profileCard)
            #expect(
                !signature.contains("ProgressChartView"),
                "\(discipline.id) overrides profileCard but still resolves to ProgressChartView (\(signature))"
            )
            #expect(
                !signature.contains("EmptyView"),
                "\(discipline.id) profileCard collapsed to EmptyView (\(signature))"
            )
        }
    }

    /// Returns a string that includes the dynamic type of the view inside an
    /// ``AnyView``. ``AnyView`` hides its wrapped type at the type level,
    /// but ``Mirror`` reveals the storage type through `subjectType`; the
    /// type's name is descriptive enough for a contract assertion.
    private static func viewTypeSignature<V: View>(of view: V) -> String {
        var description = String(reflecting: Mirror(reflecting: view).subjectType)
        var children = Array(Mirror(reflecting: view).children)
        while let child = children.first {
            description += " > " + String(reflecting: Mirror(reflecting: child.value).subjectType)
            children = Array(Mirror(reflecting: child.value).children)
        }
        return description
    }
}
