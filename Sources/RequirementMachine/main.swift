func main() {

  // 1. Generate a set of constraints

  // trait Z2 {
  //   type X: Z2 where Self == ((Self::Z2).X::Z2).X
  // }

  // let constraints: [Constraint] = [
  //   .bound(
  //     lhs: .genericType("Self"), rhs: .trait("Z2")),
  //   .equality(
  //     lhs: .genericType("Self"),
  //     rhs: .associatedType(
  //       qualification: .associatedType(
  //         qualification: .genericType("Self"), trait: "Z2", name: "X"),
  //       trait: "Z2", name: "X"))
  // ]

  let this = Type.genericType("Self")

  let constraints: [Constraint] = [
    // Self: Collection
    .bound(
      lhs: this,
      rhs: .trait("Collection")),

    // Self: Self.Index: Regular
    .bound(
      lhs: .associatedType(qualification: this, trait: "Collection", name: "Index"),
      rhs: .trait("Regular")),

    // Self: Self.Slice: Collection
    .bound(
      lhs: .associatedType(
        qualification: this, trait: "Collection", name: "Slice"),
      rhs: .trait("Collection")),

    // Self: Self.Slice.Index == Self.Index
    .equality(
      lhs: .associatedType(
        qualification: .associatedType(
          qualification: this, trait: "Collection", name: "Slice"),
        trait: "Slice", name: "Index"),
      rhs: .associatedType(
        qualification: this, trait: "Collection", name: "Index")),

    // Self: Self.Slice.Element == Self.Element
    .equality(
      lhs: .associatedType(
        qualification: .associatedType(
          qualification: this, trait: "Collection", name: "Slice"),
        trait: "Slice", name: "Index"),
      rhs: .associatedType(
        qualification: this, trait: "Collection", name: "Index")),

    // Self: Self.Slice.Slice == Self.Slice
    .equality(
      lhs: .associatedType(
        qualification: .associatedType(
          qualification: this, trait: "Collection", name: "Slice"),
        trait: "Slice", name: "Index"),
      rhs: .associatedType(
        qualification: this, trait: "Collection", name: "Slice")),
  ]

  let types = TypeProperties()

  // 2. Translate the constraints to a rewriting system

  var system = RewritingSystem()
  for c in constraints {
    switch c {
    case .bound(let lhs, let rhs):
      let v = Term(lhs)
      let u = v + Term(rhs)
      system.insert(.init(from: u, to: v), orderingTermsWith: types.compareOrder)

    case .equality(let lhs, let rhs):
      assert(lhs.isAbstractParameter, "left operand of equality constraint must be abstract")
      var v = Term(lhs)
      var u = rhs.isAbstractParameter ? Term(rhs) : v + Term(rhs)
      if types.compareOrder(u, v) == .ascending { swap(&v, &u) }
      system.insert(.init(from: u, to: v), orderingTermsWith: types.compareOrder)
    }
  }

  var pairs: [CriticalPair] = []
  var visitedOverlaps: Set<OverlapIdentifier> = []

  // 3. Apply Knuth-Bendix completion.

  for i in system.indices {
    system.forEachOverlap(involving: i) { (j, p) in
      pairs.append(system.formCriticalPair(i, j, overlappingAt: p))
      visitedOverlaps.insert(.init(i, j, at: p))
    }
  }

  while let p = pairs.popLast() {
    if system.resolveCriticalPair(p, orderingTermsWith: types.compareOrder) == nil { continue }
    for i in system.indices {
      system.forEachOverlap(involving: i) { (j, p) in
        if visitedOverlaps.insert(.init(i, j, at: p)).inserted {
          pairs.append(system.formCriticalPair(i, j, overlappingAt: p))
        }
      }
    }
  }

  print(system)

  // 4. Query the rewriting system.

  // let t1 = Type.associatedType(qualification: .genericType("Self"), trait: "Z2", name: "X")
  // let t2 = Type.associatedType(qualification: t1, trait: "Z2", name: "X")
  // let t3 = Type.associatedType(qualification: t2, trait: "Z2", name: "X")
  // print(system.reduce(Term(t3)))

  // Self.Slice.Element
  let t = Type.associatedType(
    qualification: .associatedType(
      qualification: this, trait: "Collection", name: "Slice"),
    trait: "Collection", name: "Element")

  print(system.reduce(Term(t)))
}

main()
