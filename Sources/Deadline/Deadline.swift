enum DeadlineState<T>: Sendable where T: Sendable {
  case operationResult(Result<T, Error>)
  case sleepResult(Result<Bool, Error>)
}

/// An error indicating that the deadline has passed and the operation did not complete.
public struct DeadlineExceededError: Error { }

/// Race the given operation against a deadline.
///
/// This function provides a mechanism for enforcing timeouts on asynchronous operations that lack native deadline support. It creates a `TaskGroup` with two concurrent tasks: the provided operation and a sleep task.
///
/// - Parameters:
///   - instant: The absolute deadline for the operation to complete.
///   - tolerance: The allowed tolerance for the deadline.
///   - clock: The clock used for timing the operation.
///   - isolation: The isolation passed on to the task group.
///   - operation: The asynchronous operation to be executed.
///
/// - Returns: The result of the operation if it completes before the deadline.
/// - Throws: `DeadlineExceededError`, if the operation fails to complete before the deadline and errors thrown by the operation or clock.
///
/// ## Examples
/// To fully understand this, let's illustrate the 3 outcomes of this function:
///
/// ### Outcome 1
/// The operation finishes in time:
/// ```swift
/// let result = try await deadline(until: .now + .seconds(5)) {
///   // Simulate long running task
///   try await Task.sleep(for: .seconds(1))
///   return "success"
/// }
/// ```
/// As you'd expect, result will be "success". The same applies when your operation fails in time:
/// ```swift
/// let result = try await deadline(until: .now + .seconds(5)) {
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
/// let result = try await deadline(until: .now + .seconds(1)) {
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
///     try await deadline(until: .now + .seconds(5)) {
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
public func deadline<C, R>(
  until instant: C.Instant,
  tolerance: C.Instant.Duration? = nil,
  clock: C,
  isolation: isolated (any Actor)? = #isolation,
  operation: @Sendable () async throws -> R
) async throws -> R where C: Clock, R: Sendable {
  
  // NB: This is safe to use, because the closure will not escape the context of this function.
  let result = await withoutActuallyEscaping(operation) { operation in
    await withTaskGroup(
      of: DeadlineState<R>.self,
      returning: Result<R, any Error>.self,
      isolation: isolation
    ) { taskGroup in
      
      taskGroup.addTask {
        do {
          let result = try await operation()
          return .operationResult(.success(result))
        } catch {
          return .operationResult(.failure(error))
        }
      }
      
      taskGroup.addTask {
        do {
          try await Task.sleep(until: instant, tolerance: tolerance, clock: clock)
          return .sleepResult(.success(false))
        } catch where Task.isCancelled {
          return .sleepResult(.success(true))
        } catch {
          return .sleepResult(.failure(error))
        }
      }
      
      defer {
        taskGroup.cancelAll()
      }
      
      for await next in taskGroup {
        switch next {
        case .operationResult(let result):
          return result
        case .sleepResult(.success(false)):
          return .failure(DeadlineExceededError())
        case .sleepResult(.success(true)):
          continue
        case .sleepResult(.failure(let error)):
          return .failure(error)
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
///   - instant: The absolute deadline for the operation to complete.
///   - tolerance: The allowed tolerance for the deadline.
///   - isolation: The isolation passed on to the task group.
///   - operation: The asynchronous operation to be executed.
///
/// - Returns: The result of the operation if it completes before the deadline.
/// - Throws: `DeadlineExceededError`, if the operation fails to complete before the deadline and errors thrown by the operation or clock.
///
/// ## Examples
/// To fully understand this, let's illustrate the 3 outcomes of this function:
///
/// ### Outcome 1
/// The operation finishes in time:
/// ```swift
/// let result = try await deadline(until: .now + .seconds(5)) {
///   // Simulate long running task
///   try await Task.sleep(for: .seconds(1))
///   return "success"
/// }
/// ```
/// As you'd expect, result will be "success". The same applies when your operation fails in time:
/// ```swift
/// let result = try await deadline(until: .now + .seconds(5)) {
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
/// let result = try await deadline(until: .now + .seconds(1)) {
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
///     try await deadline(until: .now + .seconds(5)) {
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
public func deadline<R>(
  until instant: ContinuousClock.Instant,
  tolerance: ContinuousClock.Instant.Duration? = nil,
  isolation: isolated (any Actor)? = #isolation,
  operation: @Sendable () async throws -> R
) async throws -> R where R: Sendable {
  try await deadline(until: instant, tolerance: tolerance, clock: ContinuousClock(), isolation: isolation, operation: operation)
}
