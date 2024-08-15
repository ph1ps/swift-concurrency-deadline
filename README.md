# Deadline
A deadline algorithm for Swift Concurrency.

## Rationale
As I've previously stated on the [Swift forums](https://forums.swift.org/t/my-experience-with-concurrency/73197): in my opinion deadlines or timeouts are a missing piece in Swift's Concurrency system. 

Since this algorithm is not easy to get right and the implementation in [swift-async-algorithms](https://github.com/apple/swift-async-algorithms/pull/215) has been laying around without getting merged for quite some time now, I decided to open-source my implementation.

## Details

The library comes with two free functions, one with a generic clock. And another one which uses the `ContinuousClock` as default.
```swift
public func withDeadline<C, T>(
  until instant: C.Instant,
  tolerance: C.Instant.Duration? = nil,
  clock: C,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T where C: Clock, T: Sendable { ... }

public func withDeadline<T>(
  until instant: ContinuousClock.Instant,
  tolerance: ContinuousClock.Instant.Duration? = nil,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T where T: Sendable { ... }
```

This function provides a mechanism for enforcing timeouts on asynchronous operations that lack native deadline support. It creates a `TaskGroup` with two concurrent tasks: the provided operation and a sleep task.

- Parameters:
  - `until`: The absolute deadline for the operation to complete.
  - `tolerance`: The allowed tolerance for the deadline.
  - `clock`: The clock used for timing the operation.
  - `operation`: The asynchronous operation to be executed.

- Returns: The result of the operation if it completes before the deadline.
- Throws: `DeadlineExceededError`, if the operation fails to complete before the deadline and errors thrown by the operation itself.

> [!CAUTION]
> The operation closure must support cooperative cancellation. Otherwise, the deadline will not be respected.

### Examples
To fully understand this, let's illustrate the 3 outcomes of this function:

#### Outcome 1
The operation finishes in time:
```swift
let result = try await withDeadline(until: .now + .seconds(5)) {
  // Simulate long running task
  try await Task.sleep(for: .seconds(1))
  return "success"
}
```
As you'd expect, result will be "success". The same applies when your operation fails in time:
```swift
let result = try await withDeadline(until: .now + .seconds(5)) {
  // Simulate long running task
  try await Task.sleep(for: .seconds(1))
  throw CustomError()
}
```
This will throw `CustomError`.

#### Outcome 2
The operation does not finish in time:
```swift
let result = try await withDeadline(until: .now + .seconds(1)) {
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
    try await withDeadline(until: .now + .seconds(5)) {
      try await URLSession.shared.data(from: url)
    }
  } catch {
    print(error)
  }
}

task.cancel()
```
The print is guaranteed to print `URLError(.cancelled)`.
