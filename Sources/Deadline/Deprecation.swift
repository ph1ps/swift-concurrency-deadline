@available(*, deprecated, renamed: "deadline")
public func withDeadline<C, R>(
  until instant: C.Instant,
  tolerance: C.Instant.Duration? = nil,
  clock: C,
  operation: @Sendable () async throws -> R
) async throws -> R where C: Clock, R: Sendable {
  try await deadline(until: instant, tolerance: tolerance, clock: clock, operation: operation)
}

@available(*, deprecated, renamed: "deadline")
public func withDeadline<R>(
  until instant: ContinuousClock.Instant,
  tolerance: ContinuousClock.Instant.Duration? = nil,
  operation: @Sendable () async throws -> R
) async throws -> R where R: Sendable {
  try await deadline(until: instant, tolerance: tolerance, operation: operation)
}
