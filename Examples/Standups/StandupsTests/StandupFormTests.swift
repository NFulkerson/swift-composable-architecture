import ComposableArchitecture
import XCTest

@testable import Standups

@MainActor
final class StandupFormTests: XCTestCase {
  func testAddAttendee() async {
    let store = TestStore(
      initialState: StandupForm.State(
        standup: Standup(
          id: Standup.ID(),
          attendees: [],
          title: "Engineering"
        )
      ),
      reducer: StandupForm()
    ) {
      $0.uuid = .incrementing
    }

    XCTAssertNoDifference(
      store.state.standup.attendees,
      [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
      ]
    )

    await store.send(.addAttendeeButtonTapped) {
      $0.focus = .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!)
      $0.standup.attendees = [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!),
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000001")!),
      ]
    }
  }

  func testFocus_RemoveAttendee() async {
    let store = TestStore(
      initialState: StandupForm.State(
        standup: Standup(
          id: Standup.ID(),
          attendees: [
            Attendee(id: Attendee.ID()),
            Attendee(id: Attendee.ID()),
            Attendee(id: Attendee.ID()),
            Attendee(id: Attendee.ID()),
          ],
          title: "Engineering"
        )
      ),
      reducer: StandupForm()
    )

    store.dependencies.uuid = .incrementing

    await store.send(.deleteAttendees(atOffsets: [0])) {
      $0.focus = .attendee($0.standup.attendees[1].id)
      $0.standup.attendees = [
        $0.standup.attendees[1],
        $0.standup.attendees[2],
        $0.standup.attendees[3],
      ]
    }

    await store.send(.deleteAttendees(atOffsets: [1])) {
      $0.focus = .attendee($0.standup.attendees[2].id)
      $0.standup.attendees = [
        $0.standup.attendees[0],
        $0.standup.attendees[2],
      ]
    }

    await store.send(.deleteAttendees(atOffsets: [1])) {
      $0.focus = .attendee($0.standup.attendees[0].id)
      $0.standup.attendees = [
        $0.standup.attendees[0]
      ]
    }

    await store.send(.deleteAttendees(atOffsets: [0])) {
      $0.focus = .attendee(Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
      $0.standup.attendees = [
        Attendee(id: Attendee.ID(uuidString: "00000000-0000-0000-0000-000000000000")!)
      ]
    }
  }
}
