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

@inlinable
func _makeObservationTrackingEntry(_ context: _ObservationRegistrarContext) -> _ObservationTrackingEntry {
  (
    registerTracking: { properties, observer in
      _registerTracking(observationRegistrarContext: context, for: properties, observer: observer)
    },
    cancel: { id in
      _cancel(observationRegistrarContext: context, id)
    },
    properties: Set<AnyKeyPath>()
  )
}

@inlinable
func _addObserver(
  observationTrackingEntry entry: _ObservationTrackingEntry,
  _ function: @Sendable @escaping () -> Void
) -> Int {
  entry.registerTracking(entry.properties, function)
}

@usableFromInline
typealias _ObservationTrackingAccessList = [ObjectIdentifier: _ObservationTrackingEntry]

@inlinable
func _makeObservationTrackingAccessList() -> _ObservationTrackingAccessList {
  [:]
}

@inlinable
func _addAccessToObservationTrackingAccessList<Subject>(
  _ list: inout _ObservationTrackingAccessList,
  keyPath: PartialKeyPath<Subject>,
  context: _ObservationRegistrarContext
) {
  list[_getId(observationRegistrarContext: context), default: _makeObservationTrackingEntry(context)]
    .properties.insert(keyPath)
}

@inlinable
func _mergeObservationTrackingAccessList(
  _ list: inout _ObservationTrackingAccessList,
  _ other: _ObservationTrackingAccessList
) {
  for (identifier, entry) in other {
    list[identifier, default: entry].properties.formUnion(entry.properties)
  }
}

public func withObservationTrackingBD<T>(
  _ apply: () -> T,
  onChange: @escaping @Sendable () -> Void
) -> T {
  var accessList: _ObservationTrackingAccessList?
  let result = withUnsafeMutablePointer(to: &accessList) { ptr in
    let previous = _getObservationTLSValue()
    _setObservationTLSValue(ptr)
    defer {
      if let scoped = ptr.pointee, let previous {
        if var prevList = previous.pointee {
          _mergeObservationTrackingAccessList(&prevList, scoped)
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
    let state = _makeAllocatedLock(state: [ObjectIdentifier: Int]())
//    let onChange = onChange()
    let values = list.mapValues {
      _addObserver(observationTrackingEntry: $0) {
        onChange()
        let values = _withLockedAllocatedLock(state) { $0 }
        for (id, token) in values {
          list[id]?.cancel(token)
        }
      }
    }
    _withLockedAllocatedLock(state) { $0 = values }
  }
  return result
}
