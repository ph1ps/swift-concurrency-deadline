import Deadline
import Clocks
import XCTest

final class DeadlineTests: XCTestCase {
  
  func testInTime() async {
    
    let testClock = TestClock()
    let task = Task {
      try await withDeadline(until: .init(offset: .milliseconds(200)), clock: testClock) {
        try await testClock.sleep(until: .init(offset: .milliseconds(100)))
      }
    }
    
    await testClock.advance(by: .milliseconds(200))
    
    let result = await task.result
    XCTAssertNoThrow(try result.get())
  }
  
  func testDeadline() async {
    
    let testClock = TestClock()
    let task = Task {
      try await withDeadline(until: .init(offset: .milliseconds(100)), clock: testClock) {
        try await testClock.sleep(until: .init(offset: .milliseconds(200)))
      }
    }
    
    await testClock.advance(by: .milliseconds(200))
    
    let result = await task.result
    XCTAssertThrowsError(try result.get()) { error in
      XCTAssertTrue(error is DeadlineExceededError)
    }
  }
  
  func testCancellation() async {
    
    struct CustomError: Error { }
    
    let testClock = TestClock()
    let task = Task {
      try await withDeadline(until: .init(offset: .milliseconds(100)), clock: testClock) {
        do {
          try await testClock.sleep(until: .init(offset: .milliseconds(200)))
        } catch {
          throw CustomError()
        }
      }
    }
    
    await testClock.advance(by: .milliseconds(50))
    task.cancel()
    
    let result = await task.result
    XCTAssertThrowsError(try result.get()) { error in
      XCTAssertTrue(error is CustomError)
    }
  }
  
  func testEarlyCancellation() async {
    
    struct CustomError: Error { }
    
    let testClock = TestClock()
    let task = Task {
      try await withDeadline(until: .init(offset: .milliseconds(100)), clock: testClock) {
        do {
          try await testClock.sleep(until: .init(offset: .milliseconds(200)))
        } catch {
          throw CustomError()
        }
      }
    }
    
    task.cancel()
    
    let result = await task.result
    XCTAssertThrowsError(try result.get()) { error in
      XCTAssertTrue(error is CustomError)
    }
  }
  
  func testFailingClock() async {
    
    struct CustomError: Error { }
    struct CustomClock: Clock {
      let _internal = TestClock()
      var now: TestClock<Duration>.Instant { _internal.now }
      var minimumResolution: TestClock<Duration>.Duration { _internal.minimumResolution }
      func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws { throw CustomError() }
    }
    
    let customClock = CustomClock()
    let task = Task {
      try await withDeadline(until: .init(offset: .milliseconds(200)), clock: customClock) {
        try await customClock.sleep(until: .init(offset: .milliseconds(100)))
      }
    }
    
    let result = await task.result
    XCTAssertThrowsError(try result.get()) { error in
      XCTAssertTrue(error is CustomError)
    }
  }
}
