import Deadline
import Clocks
import XCTest

final class DeadlineTests: XCTestCase {
  
  func test_InTime() async {
    
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
  
  func test_Deadline() async {
    
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
  
  func test_Cancellation() async {
    
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
  
  func test_EarlyCancellation() async {
    
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
  
  func testAbc() async {
    let task = Task {
      do {
        _ = try await withDeadline(until: .now + .seconds(5)) {
          try await URLSession.shared.data(from: URL(string: "google.com")!)
        }
      } catch {
        print(error)
      }
    }
    
    task.cancel()
    await task.value
  }
}
