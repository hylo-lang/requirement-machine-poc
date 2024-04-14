/// A set of properties of types used in a properties.
struct TypeProperties {

  /// A map from trait to its bases (i.e., the traits that it refines).
  var traitToBases: [String: [String]] = [:]

  /// Returns the traits which `t` refines.
  func bases(of t: String) -> Set<String> {
    traitToBases[t, default: []].reduce(into: Set()) { (partialResult, u) in
      if partialResult.insert(u).inserted {
        partialResult.formUnion(bases(of: u))
      }
    }
  }

  /// Returns the result of a three-way comparison between `u` and `v`.
  func compareOrder(_ u: Symbol, _ v: Symbol) -> StrictOrdering {
    switch (u, v) {
    case (.concrete(let n1), .concrete(let n2)):
      return .init(between: n1, and: n2)

    case (.trait(let n1), .trait(let n2)):
      let a = bases(of: n1)
      let b = bases(of: n2)
      if a.count < b.count {
        return .descending
      } else if a.count > b.count {
        return .ascending
      } else {
        return .init(between: n1, and: n2)
      }

    case (.associatedType(let t1, let n1), .associatedType(let t2, let n2)):
      if n1 == n2 {
        return compareOrder(.trait(t1), .trait(t2))
      } else {
        return .init(between: n1, and: n2)
      }

    case (.genericType(let n1), .genericType(let n2)):
      return .init(between: n1, and: n2)

    default:
      return .init(between: u.kind, and: v.kind)
    }
  }

  /// Returns the result of a three-way comparison between `u` and `v`.
  func compareOrder(_ u: Term, _ v: Term) -> StrictOrdering {
    switch StrictOrdering(between: u.count, and: v.count) {
    case .equal:
      break
    case let o:
      return o
    }

    var i = u.startIndex
    var j = v.startIndex
    while (i != u.endIndex) && (j != v.endIndex) {
      switch compareOrder(u[i], v[i]) {
      case .equal:
        i = u.index(after: i)
        j = u.index(after: j)

      case let o:
        return o
      }
    }

    if i == u.endIndex {
      return (j == v.endIndex) ? .equal : .ascending
    } else {
      return .descending
    }
  }

}

/// A type.
indirect enum Type {

  /// A concrete nominal type.
  case concrete(String)

  /// A trait.
  case trait(String)

  /// An associated type.
  case associatedType(qualification: Type, trait: String, name: String)

  /// A generic type parameter.
  case genericType(String)

  /// `true` if `self` is a generic type parameter or and associated type.
  var isAbstractParameter: Bool {
    switch self {
    case .associatedType, .genericType: return true
    default: return false
    }
  }

}

extension Type: Hashable {}

extension Type: CustomStringConvertible {

  var description: String {
    switch self {
      case .concrete(let name):
        return name
      case .trait(let name):
        return name
      case .associatedType(let qualification, let trait, let name):
        return "(\(qualification)::\(trait)).\(name)"
      case .genericType(let name):
        return name
    }
  }

}

/// The expression of a constraint in a generic signature.
enum Constraint {

  /// An equality constraint involving one or two skolems.
  case equality(lhs: Type, rhs: Type)

  /// A conformance or instance constraint on a skolem.
  case bound(lhs: Type, rhs: Type)

}

extension Constraint: CustomStringConvertible {

  var description: String {
    switch self {
    case .equality(let lhs, let rhs):
      return "\(lhs) == \(rhs)"
    case .bound(let lhs, let rhs):
      return "\(lhs): \(rhs)"
    }
  }

}
