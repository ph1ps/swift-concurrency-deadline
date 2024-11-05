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
    var now: ContinuousClock.Instant { fatalError() }
    var minimumResolution: ContinuousClock.Duration { fatalError() }
    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws { throw CustomError() }
  }
  
  let customClock = CustomClock()
  let testClock = TestClock()
  let task = Task {
    try await deadline(until: .now.advanced(by: .milliseconds(200)), clock: customClock) {
      try await testClock.sleep(until: .init(offset: .milliseconds(100)))
    }
  }
  
  await #expect(throws: CustomError.self) {
    try await task.value
  }
}
