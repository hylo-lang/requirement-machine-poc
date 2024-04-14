/// The result type of a three-way comparison implementing a strict total order.
public enum StrictOrdering: Int, Hashable {

  /// The LHS is ordered before thr RHS.
  case ascending = -1

  /// The LHS is neither ordered before nor ordered after the RHS.
  case equal = 0

  /// The LHS is ordered after the RHS.
  case descending = 1

  /// Creates the comparison of `a` with `b`.
  public init<T: Comparable>(between a: T, and b: T) {
    self = (a < b) ? .ascending : ((b < a) ? .descending : .equal)
  }

}

/// Returns the result of calling `action` with a mutable projection of `value`.
public func modify<T, U>(_ value: inout T, _ action: (inout T) throws -> U) rethrows -> U {
  try action(&value)
}
