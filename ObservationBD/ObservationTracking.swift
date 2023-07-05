//
//  ObservationTracking.swift
//  ObservationBD
//
//  Created by Dmitry Galimzyanov on 02.07.2023.
//

@usableFromInline
typealias _ObservationTrackingEntry = (
  registerTracking: @Sendable (Set<AnyKeyPath>, @Sendable @escaping () -> Void) -> Int,
  cancel: @Sendable (Int) -> Void,
  properties: Set<AnyKeyPath>
)
@usableFromInline
typealias ObservationTrackingEntry = CollectionOfOne<_ObservationTrackingEntry>

extension ObservationTrackingEntry {
  @inlinable
  init(context: ObservationRegistrarContext) {
    self.init((
      registerTracking: { properties, observer in
        context.registerTracking(for: properties, observer: observer)
      },
      cancel: { id in
        context.cancel(id: id)
      },
      properties: Set<AnyKeyPath>()
    ))
  }

  @inlinable
  func addObserver(_ function: @Sendable @escaping () -> Void) -> Int {
    element.registerTracking(element.properties, function)
  }
}

@usableFromInline
typealias _ObservationTrackingAccessList = [ObjectIdentifier: ObservationTrackingEntry]

@usableFromInline
typealias ObservationTrackingAccessList = CollectionOfOne<_ObservationTrackingAccessList>

extension ObservationTrackingAccessList {
  @inlinable
  init() {
    self.init([:])
  }

  @inlinable
  mutating func addAccess<Subject>(
    keyPath: PartialKeyPath<Subject>,
    context: ObservationRegistrarContext
  ) {
    element[context.id, default: ObservationTrackingEntry(context: context)].element
      .properties.insert(keyPath)
  }

  @inlinable
  mutating func merge(_ other: ObservationTrackingAccessList) {
    for (identifier, entry) in other.element {
      element[identifier, default: entry].element
        .properties.formUnion(entry.element.properties)
    }
  }
}

public func withObservationTrackingBD<T>(
  _ apply: () -> T,
  onChange: @autoclosure () -> @Sendable () -> Void
) -> T {
  var accessList: ObservationTrackingAccessList?
  let result = withUnsafeMutablePointer(to: &accessList) { ptr in
    let previous = _getObservationTLSValue()
    _setObservationTLSValue(ptr)
    defer {
      if let scoped = ptr.pointee, let previous {
        if var prevList = previous.pointee {
          prevList.merge(scoped)
          previous.pointee = prevList
        } else {
          previous.pointee = scoped
        }
      }
      _setObservationTLSValue(previous)
    }
    return apply()
  }
  if let list = accessList {
    let state = AllocatedLock(state: [ObjectIdentifier: Int]())
    let onChange = onChange()
    let values = list.element.mapValues {
      $0.addObserver {
        onChange()
        let values = state.withLocked { $0 }
        for (id, token) in values {
          list.element[id]?.element.cancel(token)
        }
      }
    }
    state.withLocked { $0 = values }
  }
  return result
}
