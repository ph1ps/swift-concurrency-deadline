# Deadline
A deadline algorithm for Swift Concurrency.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fph1ps%2Fswift-concurrency-deadline%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ph1ps/swift-concurrency-deadline)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fph1ps%2Fswift-concurrency-deadline%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ph1ps/swift-concurrency-deadline)

## Rationale
As I've previously stated on the [Swift forums](https://forums.swift.org/t/my-experience-with-concurrency/73197): in my opinion deadlines or timeouts are a missing piece in Swift's Concurrency system. Since this algorithm is not easy to get right I decided to open-source my implementation.

## Details

The library comes with two free functions, one with a generic clock and another one which uses the `ContinuousClock` as default.
```swift
public func deadline<C, R>(
  until instant: C.Instant,
  tolerance: C.Instant.Duration? = nil,
  clock: C,
  isolation: isolated (any Actor)? = #isolation,
  operation: @Sendable () async throws -> R
) async throws -> R where C: Clock, R: Sendable { ... }

public func deadline<R>(
  until instant: ContinuousClock.Instant,
  tolerance: ContinuousClock.Instant.Duration? = nil,
  isolation: isolated (any Actor)? = #isolation,
  operation: @Sendable () async throws -> R
) async throws -> R where R: Sendable { ... }
```

This function provides a mechanism for enforcing timeouts on asynchronous operations that lack native deadline support. It creates a `TaskGroup` with two concurrent tasks: the provided operation and a sleep task.

- Parameters:
  - `instant`: The absolute deadline for the operation to complete.
  - `tolerance`: The allowed tolerance for the deadline.
  - `clock`: The clock used for timing the operation.
  - `isolation`: The isolation passed on to the task group.
  - `operation`: The asynchronous operation to be executed.

- Returns: The result of the operation if it completes before the deadline.
- Throws: `DeadlineExceededError`, if the operation fails to complete before the deadline and errors thrown by the operation or clock.

> [!CAUTION]
> The operation closure must support cooperative cancellation. Otherwise, the deadline will not be respected.

### Examples
To fully understand this, let's illustrate the 3 outcomes of this function:

#### Outcome 1
The operation finishes in time:
```swift
let result = try await deadline(until: .now + .seconds(5)) {
  // Simulate long running task
  try await Task.sleep(for: .seconds(1))
  return "success"
}
```
As you'd expect, result will be "success". The same applies when your operation fails in time:
```swift
let result = try await deadline(until: .now + .seconds(5)) {
  // Simulate long running task
  try await Task.sleep(for: .seconds(1))
  throw CustomError()
}
```
This will throw `CustomError`.

#### Outcome 2
The operation does not finish in time:
```swift
let result = try await deadline(until: .now + .seconds(1)) {
  // Simulate even longer running task
  try await Task.sleep(for: .seconds(5))
  return "success"
}
```
This will throw `DeadlineExceededError` because the operation will not finish in time.

#### Outcome 3
The parent task was cancelled:
```swift
let task = Task {
  do {
    try await deadline(until: .now + .seconds(5)) {
      try await URLSession.shared.data(from: url)
    }
  } catch {
    print(error)
  }
}

task.cancel()
```
The print is guaranteed to print `URLError(.cancelled)`.

## Improvements
- Only have one free function with a default expression of `ContinuousClock` for the `clock` parameter.
  - Blocked by: https://github.com/swiftlang/swift/issues/72199
- Use `@isolated(any)` for synchronous task enqueueing support.
  - Blocked by: https://github.com/swiftlang/swift/issues/76604
