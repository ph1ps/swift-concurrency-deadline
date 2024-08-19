enum DeadlineState<T>: Sendable where T: Sendable {
  case result(Result<T, any Error>)
  case sleepWasCancelled
  case deadlineExceeded
}

/// An error indicating that the deadline has passed and the operation did not complete.
public struct DeadlineExceededError: Error { }

/// Race the given operation against a deadline.
///
/// This function provides a mechanism for enforcing timeouts on asynchronous operations that lack native deadline support. It creates a `TaskGroup` with two concurrent tasks: the provided operation and a sleep task.
///
/// - Parameters:
///   - until: The absolute deadline for the operation to complete.
///   - tolerance: The allowed tolerance for the deadline.
///   - clock: The clock used for timing the operation.
///   - operation: The asynchronous operation to be executed.
///
/// - Returns: The result of the operation if it completes before the deadline.
/// - Throws: `DeadlineExceededError`, if the operation fails to complete before the deadline and errors thrown by the operation itself.
///
/// ## Examples
/// To fully understand this, let's illustrate the 3 outcomes of this function:
///
/// ### Outcome 1
/// The operation finishes in time:
/// ```swift
/// let result = try await withDeadline(until: .now + .seconds(5)) {
///   // Simulate long running task
///   try await Task.sleep(for: .seconds(1))
///   return "success"
/// }
/// ```
/// As you'd expect, result will be "success". The same applies when your operation fails in time:
/// ```swift
/// let result = try await withDeadline(until: .now + .seconds(5)) {
///   // Simulate long running task
///   try await Task.sleep(for: .seconds(1))
///   throw CustomError()
/// }
/// ```
/// This will throw `CustomError`.
///
/// ## Outcome 2
/// The operation does not finish in time:
/// ```swift
/// let result = try await withDeadline(until: .now + .seconds(1)) {
///   // Simulate even longer running task
///   try await Task.sleep(for: .seconds(5))
///   return "success"
/// }
/// ```
/// This will throw `DeadlineExceededError` because the operation will not finish in time.
///
/// ## Outcome 3
/// The parent task was cancelled:
/// ```swift
/// let task = Task {
///   do {
///     try await withDeadline(until: .now + .seconds(5)) {
///       try await URLSession.shared.data(from: url)
///     }
///   } catch {
///     print(error)
///   }
/// }
///
/// task.cancel()
/// ```
/// The print is guaranteed to print `URLError(.cancelled)`.
/// - Important: The operation closure must support cooperative cancellation. Otherwise, the deadline will not be respected.
public func withDeadline<C, R>(
  until instant: C.Instant,
  tolerance: C.Instant.Duration? = nil,
  clock: C,
  operation: @Sendable () async throws -> R
) async throws -> R where C: Clock, R: Sendable {
  
  // NB: This is safe to use, because the closure will not escape the context of this function.
  let result = await withoutActuallyEscaping(operation) { operation in
    await withTaskGroup(
      of: DeadlineState<R>.self,
      returning: Result<R, any Error>.self
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
      
      defer {
        taskGroup.cancelAll()
      }
      
      for await next in taskGroup {
        switch next {
        case let .result(result):
          return result
        case .deadlineExceeded:
          return .failure(DeadlineExceededError())
        case .sleepWasCancelled:
          continue
        }
      }
      
      preconditionFailure("Invalid state")
    }
  }
  
  return try result.get()
}

/// Race the given operation against a deadline.
///
/// This function provides a mechanism for enforcing timeouts on asynchronous operations that lack native deadline support. It creates a `TaskGroup` with two concurrent tasks: the provided operation and a sleep task.
/// `ContinuousClock` will be used as the default clock.
///
/// - Parameters:
///   - until: The absolute deadline for the operation to complete.
///   - tolerance: The allowed tolerance for the deadline.
///   - operation: The asynchronous operation to be executed.
///
/// - Returns: The result of the operation if it completes before the deadline.
/// - Throws: `DeadlineExceededError`, if the operation fails to complete before the deadline and errors thrown by the operation itself.
///
/// ## Examples
/// To fully understand this, let's illustrate the 3 outcomes of this function:
///
/// ### Outcome 1
/// The operation finishes in time:
/// ```swift
/// let result = try await withDeadline(until: .now + .seconds(5)) {
///   // Simulate long running task
///   try await Task.sleep(for: .seconds(1))
///   return "success"
/// }
/// ```
/// As you'd expect, result will be "success". The same applies when your operation fails in time:
/// ```swift
/// let result = try await withDeadline(until: .now + .seconds(5)) {
///   // Simulate long running task
///   try await Task.sleep(for: .seconds(1))
///   throw CustomError()
/// }
/// ```
/// This will throw `CustomError`.
///
/// ## Outcome 2
/// The operation does not finish in time:
/// ```swift
/// let result = try await withDeadline(until: .now + .seconds(1)) {
///   // Simulate even longer running task
///   try await Task.sleep(for: .seconds(5))
///   return "success"
/// }
/// ```
/// This will throw `DeadlineExceededError` because the operation will not finish in time.
///
/// ## Outcome 3
/// The parent task was cancelled:
/// ```swift
/// let task = Task {
///   do {
///     try await withDeadline(until: .now + .seconds(5)) {
///       try await URLSession.shared.data(from: url)
///     }
///   } catch {
///     print(error)
///   }
/// }
///
/// task.cancel()
/// ```
/// The print is guaranteed to print `URLError(.cancelled)`.
/// - Important: The operation closure must support cooperative cancellation. Otherwise, the deadline will not be respected.
public func withDeadline<R>(
  until instant: ContinuousClock.Instant,
  tolerance: ContinuousClock.Instant.Duration? = nil,
  operation: @Sendable () async throws -> R
) async throws -> R where R: Sendable {
  try await withDeadline(until: instant, tolerance: tolerance, clock: ContinuousClock(), operation: operation)
}
