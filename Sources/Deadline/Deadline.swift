enum DeadlineState<T> {
  case result(Result<T, any Error>)
  case sleepWasCancelled
  case deadlineExceeded
}

/// An error indicating that the deadline has passed and the operation did not complete.
public struct DeadlineExceededError: Error { }

/// Race the given operation against a deadline.
///
/// This is a helper that you can use for asynchronous APIs that do not support timeouts/deadlines natively.
/// It will start a `TaskGroup` with two child tasks: your operation and a `Task.sleep(until:tolerance:clock:)`. There are three possible outcomes:
/// 1. If your operation finishes first, it will simply return the result and cancel the sleeping.
/// 2. If the sleeping finishes first, it will throw a `DeadlineExceededError` and cancel your operation.
/// 3. If the parent task was cancelled, it will automatically cancel your operation and the sleeping. The cancellation handling will be inferred from your operation. `CancellationError`s from `Task.sleep(until:tolerance:clock:)` will be ignored.
/// - Important: The operation closure must support cooperative cancellation.
/// Otherwise, `withDeadline(until:tolerance:clock:operation:)` will suspend execution until the operation completes, making the deadline ineffective.
/// ## Example
/// This is just a demonstrative usage of this function. `CBCentralManager.connect(_:)` is a good example, in my opinion, since it does not support timeouts natively.
///
/// Again, if you try to make something like `CBCentralManager.connect(_:)` asynchronous and use it with `withDeadline(until:tolerance:clock:operation:)` be sure to use `withTaskCancellationHandler(operation:onCancel:)` at some point to opt into cooperative cancellation.
/// ```swift
/// try await withDeadline(until: .now + seconds(5), clock: .continous) {
///   try await cbCentralManager.connect(peripheral)
/// }
/// ```
public func withDeadline<C, T>(
  until instant: C.Instant,
  tolerance: C.Instant.Duration? = nil,
  clock: C,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T where C: Clock, T: Sendable {
  
  let result = await withTaskGroup(
    of: DeadlineState<T>.self,
    returning: Result<T, any Error>.self
  ) { taskGroup in
    
    taskGroup.addTask {
      do {
        return try await .result(.success(operation()))
      } catch {
        return .result(.failure(error))
      }
    }
    
    taskGroup.addTask {
      do {
        try await Task.sleep(until: instant, tolerance: tolerance, clock: clock)
        return .deadlineExceeded
      } catch {
        return .sleepWasCancelled
      }
    }
    
    // Make sure to cancel the remaining child task.
    defer {
      taskGroup.cancelAll()
    }
    
    for await next in taskGroup {
      switch next {
      // This indicates that the operation did complete. We can safely return the result.
      case let .result(result):
        return result
      // This indicates that the operation did not complete in time. We will throw `DeadlineExceededError`.
      case .deadlineExceeded:
        return .failure(DeadlineExceededError())
      // This indicates that the sleep child task was the first to return.
      // However we want to keep the cancellation handling of the operation. Therefore we will skip this iteration and wait for the operation child tasks result.
      case .sleepWasCancelled:
        continue
      }
    }
    
    preconditionFailure("Invalid state")
  }
  
  return try result.get()
}

/// Race the given operation against a deadline.
///
/// This is a helper that you can use for asynchronous APIs that do not support timeouts/deadlines natively.
/// It will start a `TaskGroup` with two child tasks: your operation and a `Task.sleep(until:tolerance:clock:)`. There are three possible outcomes:
/// 1. If your operation finishes first, it will simply return the result and cancel the sleeping.
/// 2. If the sleeping finishes first, it will throw a `DeadlineExceededError` and cancel your operation.
/// 3. If the parent task was cancelled, it will automatically cancel your operation and the sleeping. The cancellation handling will be inferred from your operation. `CancellationError`s from `Task.sleep(until:tolerance:clock:)` will be ignored.
/// - Important: The operation closure must support cooperative cancellation.
/// Otherwise, `withDeadline(until:tolerance:operation:)` will suspend execution until the operation completes, making the deadline ineffective.
/// ## Example
/// This is just a demonstrative usage of this function. `CBCentralManager.connect(_:)` is a good example, in my opinion, since it does not support timeouts natively.
///
/// Again, if you try to make something like `CBCentralManager.connect(_:)` asynchronous and use it with `withDeadline(until:tolerance:operation:)` be sure to use `withTaskCancellationHandler(operation:onCancel:)` at some point to opt into cooperative cancellation.
/// ```swift
/// try await withDeadline(until: .now + seconds(5), clock: .continous) {
///   try await cbCentralManager.connect(peripheral)
/// }
/// ```
public func withDeadline<T>(
  until instant: ContinuousClock.Instant,
  tolerance: ContinuousClock.Instant.Duration? = nil,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T where T: Sendable {
  try await withDeadline(until: instant, tolerance: tolerance, clock: ContinuousClock(), operation: operation)
}
