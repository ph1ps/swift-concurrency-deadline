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
    do {
      try await task.value
    } catch {
      XCTFail()
    }
  }
  
  func testDeadline() async {
    
    let testClock = TestClock()
    let task = Task {
      try await withDeadline(until: .init(offset: .milliseconds(100)), clock: testClock) {
        try await testClock.sleep(until: .init(offset: .milliseconds(200)))
      }
    }
    
    await testClock.advance(by: .milliseconds(200))
    do {
      try await task.value
      XCTFail()
    } catch is DeadlineExceededError {
      // expected
    } catch {
      XCTFail()
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
    
    do {
      try await task.value
      XCTFail()
    } catch is CustomError {
      // expected
    } catch {
      XCTFail()
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
    
    do {
      try await task.value
      XCTFail()
    } catch is CustomError {
      // expected
    } catch {
      XCTFail()
    }
  }
}
