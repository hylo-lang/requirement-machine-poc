/// A part of a term in a requirement rewriting system.
enum Symbol: Hashable {

  /// A concrete nominal type.
  case concrete(String)

  /// A trait.
  case trait(String)

  /// An associated type.
  case associatedType(trait: String, name: String)

  /// A generic type parameter.
  case genericType(String)

  /// The kind of this symbol, which can be used as a comparable discriminator.
  var kind: Int {
    switch self {
      case .concrete: return 0
      case .trait: return 1
      case .associatedType: return 2
      case .genericType: return 3
    }
  }

}

/// A composition of symbols, forming a term.
struct Term {

  /// The symbols composing the term.
  private(set) var symbols: [Symbol]

  /// Creates an instance encoding `t`.
  init(_ t: Type) {
    switch t {
    case .concrete(let n):
      self = Term([.concrete(n)])
    case .trait(let n):
      self = Term([.trait(n)])
    case .associatedType(let q, let t, let n):
      self = Term(q) + Term([.associatedType(trait: t, name: n)])
    case .genericType(let n):
      self = Term([.genericType(n)])
    }
  }

  /// Creates an instance with the symbols in `s`.
  init<S: Sequence>(_ s: S) where S.Element == Symbol {
    self.symbols = Array(s)
  }

  /// Returns `u` concatenated with `v`.
  static func + (u: Self, v: Self) -> Self {
    var w = u
    w += v
    return w
  }

  /// Appends `v` at the end of `u`.
  static func += (u: inout Self, v: Self) {
    u.symbols.append(contentsOf: v.symbols)
  }

  /// Returns `u` concatenated with `v`.
  static func + (u: Self, v: Slice<Term>) -> Self {
    var w = u
    w += v
    return w
  }

  /// Appends `v` at the end of `u`.
  static func += (u: inout Self, v: Slice<Term>) {
    u.symbols.append(contentsOf: v)
  }

}

extension Term: Hashable {}

extension Term: Collection {

  typealias Index = Int

  typealias Element = Symbol

  var startIndex: Int {
    0
  }

  var endIndex: Int {
    symbols.count
  }

  func index(after position: Int) -> Int {
    position + 1
  }

  subscript(position: Int) -> Symbol {
    symbols[position]
  }

}

extension Term: CustomStringConvertible {

  var description: String {
    var result: [String] = []
    for s in symbols {
      switch s {
      case .concrete(let n):
        result.append("[concrete: \(n)]")
      case .trait(let n):
        result.append("[\(n)]")
      case .associatedType(let t, let n):
        result.append("[::\(t).\(n)]")
      case .genericType(let n):
        result.append(n)
      }
    }
    return result.joined(separator: ".")
  }

}

extension Slice<Term> {

  /// Returns `u` concatenated with `v`.
  static func + (u: Self, v: Self) -> Term {
    Term(u) + v
  }

  /// Returns `u` concatenated with `v`.
  static func + (u: Self, v: Term) -> Term {
    Term(u) + v
  }

}
