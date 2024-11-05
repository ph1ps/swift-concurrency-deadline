import Clocks
import Deadline
import Testing

@Test func testInTime() async {
  
  let testClock = TestClock()
  let task = Task {
    try await deadline(until: .init(offset: .milliseconds(200)), clock: testClock) {
      try await testClock.sleep(until: .init(offset: .milliseconds(100)))
    }
  }
  
  await testClock.advance(by: .milliseconds(200))
  await #expect(throws: Never.self) {
    try await task.value
  }
}

@Test func testDeadline() async {
  
  let testClock = TestClock()
  let task = Task {
    try await deadline(until: .init(offset: .milliseconds(100)), clock: testClock) {
      try await testClock.sleep(until: .init(offset: .milliseconds(200)))
    }
  }
  
  await testClock.advance(by: .milliseconds(200))
  await #expect(throws: DeadlineExceededError.self) {
    try await task.value
  }
}

@Test func testCancellation() async {
  
  struct CustomError: Error { }
  
  let testClock = TestClock()
  let task = Task {
    try await deadline(until: .init(offset: .milliseconds(100)), clock: testClock) {
      do {
        try await testClock.sleep(until: .init(offset: .milliseconds(200)))
      } catch {
        throw CustomError()
      }
    }
  }
  
  await testClock.advance(by: .milliseconds(50))
  task.cancel()
  
  await #expect(throws: CustomError.self) {
    try await task.value
  }
}

@Test func testEarlyCancellation() async {
  
  struct CustomError: Error { }
  
  let testClock = TestClock()
  let task = Task {
    try await deadline(until: .init(offset: .milliseconds(100)), clock: testClock) {
      do {
        try await testClock.sleep(until: .init(offset: .milliseconds(200)))
      } catch {
        throw CustomError()
      }
    }
  }
  
  task.cancel()
  
  await #expect(throws: CustomError.self) {
    try await task.value
  }
}

@Test func testFailingClock() async {
  
  struct CustomError: Error { }
  struct CustomClock: Clock {
    let _internal = TestClock()
    var now: TestClock<Duration>.Instant { _internal.now }
    var minimumResolution: TestClock<Duration>.Duration { _internal.minimumResolution }
    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws { throw CustomError() }
  }
  
  let customClock = CustomClock()
  let task = Task {
    try await deadline(until: .init(offset: .milliseconds(200)), clock: customClock) {
      try await customClock.sleep(until: .init(offset: .milliseconds(100)))
    }
  }
  
  await #expect(throws: CustomError.self) {
    try await task.value
  }
}
