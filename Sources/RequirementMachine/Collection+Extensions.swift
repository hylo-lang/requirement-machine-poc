extension Collection {

  /// The first element of `self` and its suffix after its first index or `nil` if `self` is empty.
  public var headAndTail: (head: Element, tail: SubSequence)? {
    if isEmpty { return nil }
    return (head: self[startIndex], tail: self[index(after: startIndex)...])
  }

}
