//
//  ObservationRegistrar.swift
//  ObservationBD
//
//  Created by Dmitry Galimzyanov on 02.07.2023.
//

public typealias _ObservationRegistrarState = (
  id: Int,
  observations: [Int: _ObservationRegistrarStateObservation],
  lookups: [AnyKeyPath: Set<Int>]
)

@inlinable
func _makeObservationRegistrarState() -> _ObservationRegistrarState {
  (
    id: 0,
    observations: [:],
    lookups: [:]
  )
}

@inlinable
func _generateId(observationRegistrarState state: inout _ObservationRegistrarState) -> Int {
  defer { state.id += 1 }
  return state.id
}

@inlinable
func _registerTracking(
  observationRegistrarState state: inout _ObservationRegistrarState,
  for properties: Set<AnyKeyPath>,
  observer: @Sendable @escaping () -> Void
) -> Int {
  let id = _generateId(observationRegistrarState: &state)
  state.observations[id] = (properties: properties, observer: observer)
  for keyPath in properties {
    state.lookups[keyPath, default: []].insert(id)
  }
  return id
}

@inlinable
func _cancel(observationRegistrarState state: inout _ObservationRegistrarState, _ id: Int) {
  if let tracking = state.observations.removeValue(forKey: id) {
    for keyPath in tracking.properties {
      if var ids = state.lookups[keyPath] {
        ids.remove(id)
        if ids.count == 0 {
          state.lookups.removeValue(forKey: keyPath)
        } else {
          state.lookups[keyPath] = ids
        }
      }
    }
  }
}

@inlinable
func _willSet(
  observationRegistrarState state: inout _ObservationRegistrarState,
  keyPath: AnyKeyPath
) -> [@Sendable () -> Void] {
  var observers = [@Sendable () -> Void]()
  if let ids = state.lookups[keyPath] {
    for id in ids {
      if let observation = state.observations[id] {
        observers.append(observation.observer)
        _cancel(observationRegistrarState: &state, id)
      }
    }
  }
  return observers
}

public typealias _ObservationRegistrarStateObservation = (properties: Set<AnyKeyPath>, observer: @Sendable () -> Void)

public typealias _ObservationRegistrarContext = _AllocatedLock<_ObservationRegistrarState>

@inlinable
func _makeObservationRegistrarContext(state: _ObservationRegistrarState) -> _ObservationRegistrarContext {
  _makeAllocatedLock(state: state)
}

@inlinable
func _getId(observationRegistrarContext context: _ObservationRegistrarContext) -> ObjectIdentifier {
  ObjectIdentifier(context)
}

@inlinable
func _registerTracking(
  observationRegistrarContext context: _ObservationRegistrarContext,
  for properties: Set<AnyKeyPath>,
  observer: @Sendable @escaping () -> Void
) -> Int {
  _withLockedAllocatedLock(context) { state in
    _registerTracking(observationRegistrarState: &state, for: properties, observer: observer)
  }
}

@inlinable
func _cancel(observationRegistrarContext context: _ObservationRegistrarContext, _ id: Int) {
  _withLockedAllocatedLock(context) { _cancel(observationRegistrarState: &$0, id) }
}

@inlinable
func _willSet<Subject, Member>(
  observationRegistrarContext context: _ObservationRegistrarContext,
  keyPath: KeyPath<Subject, Member>
) {
  let actions = _withLockedAllocatedLock(context) { _willSet(observationRegistrarState: &$0, keyPath: keyPath) }
  for action in actions {
    action()
  }
}

public typealias _ObservationRegistrar = (context: _ObservationRegistrarContext, dummy: Void)

@inlinable
public func _makeObservationRegistrar() -> _ObservationRegistrar {
  (context: _makeObservationRegistrarContext(state: _makeObservationRegistrarState()), dummy: ())
}

@inlinable
public func _access<Subject, Member>(
  observationRegistrar: _ObservationRegistrar,
  keyPath: KeyPath<Subject, Member>
) {
  if let trackingPtr = _getObservationTLSValue() {
    if trackingPtr.pointee == nil {
      trackingPtr.pointee = _makeObservationTrackingAccessList()
    }
    _addAccessToObservationTrackingAccessList(
      &trackingPtr.pointee!,
      keyPath: keyPath,
      context: observationRegistrar.context
    )
  }
}

@inlinable
public func _willSet<Subject, Member>(
  observationRegistrar: _ObservationRegistrar,
  keyPath: KeyPath<Subject, Member>
) {
  _willSet(observationRegistrarContext: observationRegistrar.context, keyPath: keyPath)
}

@inlinable
public func _didSet<Subject, Member>(
  observationRegistrar: _ObservationRegistrar,
  keyPath: KeyPath<Subject, Member>
) {
}

@inlinable
public func _withMutation<Subject, Member, T>(
  observationRegistrar: _ObservationRegistrar,
  keyPath: KeyPath<Subject, Member>,
  _ mutation: () throws -> T
) rethrows -> T {
  _willSet(observationRegistrar: observationRegistrar, keyPath: keyPath)
  defer { _didSet(observationRegistrar: observationRegistrar, keyPath: keyPath) }
  return try mutation()
}
