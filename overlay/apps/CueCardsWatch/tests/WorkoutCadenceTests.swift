import Foundation

@main struct WorkoutCadenceTests {
    static func main() {
        var window = WorkoutCadenceWindow()
        let base = Date(timeIntervalSince1970: 1000)
        func near(_ value: Double?, _ expected: Double) { precondition(value != nil && abs(value! - expected) < 0.001) }
        precondition(window.add(totalSteps: 100, date: base) == nil)
        precondition(window.add(totalSteps: 115, date: base.addingTimeInterval(5)) == nil)
        near(window.add(totalSteps: 130, date: base.addingTimeInterval(10)), 180)
        near(window.add(totalSteps: 169, date: base.addingTimeInterval(23)), 180)
        near(window.add(totalSteps: 220, date: base.addingTimeInterval(40)), 180)
        precondition(window.add(totalSteps: 300, date: base.addingTimeInterval(80)) == nil)
        precondition(window.add(totalSteps: 310, date: base.addingTimeInterval(80)) == nil)
        precondition(window.add(totalSteps: 2, date: base.addingTimeInterval(90)) == nil)
        near(window.add(totalSteps: 2, date: base.addingTimeInterval(100)), 0)
        window.reset()
        precondition(window.add(totalSteps: .nan, date: base) == nil)
        precondition(window.add(totalSteps: 500, date: base) == nil)
        precondition(window.add(totalSteps: 600, date: base.addingTimeInterval(10)) == nil)
        print("PASS HealthKit cadence: irregular windows, gap, pause/reset, duplicate, count reset, nonfinite and bounds")
    }
}
