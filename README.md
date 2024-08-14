# Deadline
A deadline algorithm for Swift Concurrency.

## Rationale
As I've previously stated on the [Swift forums](https://forums.swift.org/t/my-experience-with-concurrency/73197): in my opinion deadlines or timeouts are a missing piece in Swift's Concurrency system. 

Since this algorithm is not easy to get right and the implementation in [swift-async-algorithms](https://github.com/apple/swift-async-algorithms/pull/215) has been laying around without getting merged for quite some time now, I decided to open-source my implementation.

## Details
It will start a `TaskGroup` with two child tasks: your operation and a `Task.sleep(until:tolerance:clock:)`. There are three possible outcomes:
1. If your operation finishes first, it will simply return the result and cancel the sleeping.
2. If the sleeping finishes first, it will throw a `DeadlineExceededError` and cancel your operation.
3. If the parent task was cancelled, it will automatically cancel your operation and the sleeping. The cancellation handling will be inferred from your operation. `CancellationError`s from `Task.sleep(until:tolerance:clock:)` will be ignored.

> [!CAUTION]
> The operation closure must support cooperative cancellation.
> Otherwise, `withDeadline(until:tolerance:clock:operation:)` will suspend execution until the operation completes, making the deadline ineffective.

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

## Example
This is just a demonstrative usage of this function. `CBCentralManager.connect(_:)` is a good example, in my opinion, since it does not support timeouts natively.

Again, if you try to make something like `CBCentralManager.connect(_:)` asynchronous and use it with `withDeadline(until:tolerance:clock:operation:)` be sure to use `withTaskCancellationHandler(operation:onCancel:)` at some point to opt into cooperative cancellation.
```swift
try await withDeadline(until: .now + seconds(5), clock: .continous) {
  try await cbCentralManager.connect(peripheral)
}
```
