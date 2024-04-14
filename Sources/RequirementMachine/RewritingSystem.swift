/// A set of rewriting rules.
struct RewritingSystem {

  /// The rules in the system.
  private(set) var rules: [Rule]

  /// A map from terms to the rule of which they are the left-hand side.
  private var termToRule: Trie<Term, Rule.Identifier>

  /// Creates an empty system.
  init() {
    self.rules = []
    self.termToRule = Trie()
  }

  /// The indices of the active rules in the system.
  var indices: [Rule.Identifier] {
    rules.indices.filter({ (r) in !rules[r].isSimplified })
  }

  /// Inserts the given rule.
  ///
  /// A rule *u => v* is notionally contained in a rewriting system if that system contains a set
  /// of rules capable of rewriting *u* to *v*. This set may not contain *u => v* itself.
  ///
  /// The return value is `(true, new)` if `r` is not already notionally contained in the system,
  /// where `new` is the identifier of a newly inserted rule that is encoding `r`. Otherwise, the
  /// return value is `(false, old)` where `old` is the identifier of a rule encoding `r`.
  ///
  /// - Precondition: The source of the rule is ordered after its target.
  @discardableResult
  mutating func insert(
    _ r: Rule, orderingTermsWith compareOrder: (Term, Term) -> StrictOrdering
  ) -> (inserted: Bool, ruleAfterInsertion: Rule.Identifier) {
    precondition(compareOrder(r.source, r.target) == .descending, "invalid rewriting rule")

    // If the source of the rule isn't associated with any other rule yet, inserts the rule and
    // return `(true, i)` where `i` is the position of the rule in `rules`. Otherwise, return
    // `(false, j)` where `j` is the position of a rule sharing the same source.
    let result = modify(&termToRule[r.source]) { (q) in
      if let old = q {
        return (inserted: false, ruleAfterInsertion: old)
      } else {
        q = rules.count
        rules.append(r)
        return (inserted: true, ruleAfterInsertion: q!)
      }
    }

    // Nothing more to do if the rule was inserted.
    if result.inserted {
      return result
    }

    // Otherwise, update the system to notionally contain the rule.
    switch compareOrder(r.target, rules[result.ruleAfterInsertion].target) {
    case .equal:
      return result

    case .descending:
      return insert(
        .init(from: r.target, to: rules[result.ruleAfterInsertion].target),
        orderingTermsWith: compareOrder)

    case .ascending:
      // Let the u1 => v1 and u2 => v2 be the old and new rules, respectively. Remove u1 => v1 from
      // the system and add v1 => v2.
      rules[result.ruleAfterInsertion].flags.insert(.isRightSimplified)
      insert(
        .init(from: rules[result.ruleAfterInsertion].target, to: r.target),
        orderingTermsWith: compareOrder)

      // Add u2 => v2.
      let q = rules.count
      termToRule[r.source] = q
      rules.append(r)
      return (inserted: true, ruleAfterInsertion: q)
    }
  }

  /// Rewrites `u` with the rules in `self` until a normal form is reached.
  ///
  /// The rewriting process is notionally nondeterministic unless `self` is confluent.
  func reduce(_ u: Term) -> Term {
    for p in u.indices {
      let (n, q) = termToRule.longestPrefix(startingWith: u[p...])
      if p != q, let r = n[[]] {
        let x = Term(u[..<p])
        let v = rules[r].target
        let z = u[(p + rules[r].source.count)...]
        return reduce(x + v + z)
      }
    }
    return u
  }

  /// Calls `action` with each identifier in `terms` denoting a rule having an overlap between its
  /// left-hand side and `suffix`.
  ///
  /// If the key/value pair `(t, i)` is contained in `terms`, then `t` is the suffix of some term
  /// `l` and `i` identifies a rewriting rule `l => r`.
  private func forEachOverlap(
    of suffix: Term.SubSequence, in terms: SubTrie<Term, Rule.Identifier>,
    do action: (Rule.Identifier) -> Void
  ) {
    var t = suffix
    var n = terms

    while let (head, tail) = t.headAndTail {
      if let m = n[prefix: [head]] {
        if let i = m[[]] { action(i) }
        t = tail
        n = m
      } else {
        return
      }
    }

    for e in n.elements {
      action(e.value)
    }
  }

  func forEachOverlap(
    involving i: Rule.Identifier, do action: (Rule.Identifier, Term.Index) -> Void
  ) {
    let u = rules[i].source
    for p in u.indices {
      forEachOverlap(of: u[p...], in: termToRule[prefix: []]!) { (j) in
        // Ignore the overlap of a rule with itself at position 0.
        if (i == j) && (p == u.startIndex) { return }
        action(j, p)
      }
    }
  }

  /// Returns the critical pair formed by the rules `lhs` and `rhs`, which overlap at the `i`-th
  /// position of `lhs`'s source.
  func formCriticalPair(
    _ lhs: Rule.Identifier, _ rhs: Rule.Identifier, overlappingAt i: Int
  ) -> CriticalPair {
    // Let `lhs` and `rhs` denote rewriting rules u1 => v1 and u2 => v2, respectively.
    let (u1, v1) = rules[lhs].deconstructed
    let (u2, v2) = rules[rhs].deconstructed

    // If i + |u2| ≤ |u1|, then u1 = x·u2·z for some x and z.
    if i + u2.count <= u1.count {
      let x = u1[..<i]
      let z = u1[(i + u2.count)...]
      return CriticalPair(v1, x + v2 + z)
    }

    // Otherwise, u1 = xy and u2 = yz for some x, y, and z.
    else {
      let x = u1[..<i]
      let z = u2[(u1.count - i)...]
      return CriticalPair(v1 + z, x + v2)
    }
  }

  mutating func resolveCriticalPair(
    _ p: CriticalPair, orderingTermsWith compareOrder: (Term, Term) -> StrictOrdering
  ) -> Rule.Identifier? {
    // Fast path: critical pair is trivial without any reduction.
    if p.first == p.second { return nil }

    // Reduce both sides of the pair.
    let b1 = reduce(p.first)
    let b2 = reduce(p.second)

    // There are only three cases to consider because we assume a total order on the terms. That is
    // unlike traditional implementations of Knuth-Bendix, which must fail on incomparable terms.
    switch compareOrder(b1, b2) {
    case .equal:
      // b1 = b2: the pair is trivial and there's nothing more to do.
      return nil

    case .ascending:
      // b1 < b2: insert a new rule b2 => b1.
      let (inserted, i) = insert(.init(from: b2, to: b1), orderingTermsWith: compareOrder)
      return inserted ? i : nil

    case .descending:
      // b2 < b1: insert a new rule b1 => b2.
      let (inserted, i) = insert(.init(from: b1, to: b2), orderingTermsWith: compareOrder)
      return inserted ? i : nil
    }
  }

}

extension RewritingSystem: CustomStringConvertible {

  var description: String {
    "[" + indices.map({ (r) in rules[r].description }).joined(separator: ", ") + "]"
  }

}

/// A rewriting rule, from a source to a target.
struct Rule {

  /// The identifier of a rule in a rewriting system.
  typealias Identifier = Int

  /// The left-hand side of the rule.
  let source: Term

  /// The right-hand side of the rule.
  let target: Term

  /// The flags of the rule.
  var flags: Flags

  /// Creates an instance from `u` to `v`.
  init(from u: Term, to v: Term) {
    self.source = u
    self.target = v
    self.flags = []
  }

  /// `self` as a pair `(source, target)`.
  var deconstructed: (Term, Term) { (source, target) }

  /// `true` if `self` has been simplified.
  var isSimplified: Bool { flags.contains(.isRightSimplified) }

  /// A set of flags associated with a rewriting rule.
  struct Flags: OptionSet {

    typealias RawValue = UInt8

    var rawValue: UInt8

    /// Indicates that the rule has been removed by right-simplification.
    static let isRightSimplified = Flags(rawValue: 1)

  }

}

extension Rule: CustomStringConvertible {

  var description: String {
    "\(source) => \(target)"
  }

}

/// The rewritings of a term by two different rules or the same rule at two different positions.
struct CriticalPair {

  /// The first term of the pair.
  let first: Term

  /// The first term of the pair.
  let second: Term

  /// Creates an instance with the given terms.
  init(_ u: Term, _ v: Term) {
    self.first = u
    self.second = v
  }

}

/// The identifier of an overlap between rewriting rules.
struct OverlapIdentifier: Hashable {

  /// The raw value of this identifier.
  private let rawValue: UInt64

  /// Creates an instance identifying an overlap between `lhs` and `rhs` at the `i`-th position of
  /// `lhs`'s source.
  init(_ lhs: Rule.Identifier, _ rhs: Rule.Identifier, at i: Term.Index) {
    precondition((i | lhs | rhs) & ~((1 << 16) - 1) == 0)
    self.rawValue = UInt64(truncatingIfNeeded: i | (lhs << 16) | (rhs << 32))
  }

}
