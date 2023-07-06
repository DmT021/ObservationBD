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
public typealias ObservationRegistrarState = CollectionOfOne<_ObservationRegistrarState>

extension ObservationRegistrarState {
  @inlinable
  public init() {
    self.init((
      id: 0,
      observations: [:],
      lookups: [:]
    ))
  }

  @inlinable
  mutating func generateId() -> Int {
    defer { element.id += 1}
    return element.id
  }

  @inlinable
  mutating func registerTracking(
    for properties: Set<AnyKeyPath>,
    observer: @Sendable @escaping () -> Void
  ) -> Int {
    let id = generateId()
    element.observations[id] = (properties: properties, observer: observer)
    for keyPath in properties {
      element.lookups[keyPath, default: []].insert(id)
    }
    return id
  }

  @inlinable
  mutating func cancel(id: Int) {
    guard let tracking = element.observations.removeValue(forKey: id) else {
      return
    }
    for keyPath in tracking.properties {
      guard var ids = element.lookups[keyPath] else {
        continue
      }
      ids.remove(id)
      element.lookups[keyPath] = ids.isEmpty ? nil : ids
    }
  }

  @inlinable
  mutating func willSet(keyPath: AnyKeyPath) -> [@Sendable () -> Void] {
    var observers = [@Sendable () -> Void]()
    if let ids = element.lookups[keyPath] {
      for id in ids {
        if let observation = element.observations[id] {
          observers.append(observation.observer)
          cancel(id: id)
        }
      }
    }
    return observers
  }
}

public typealias _ObservationRegistrarStateObservation = (properties: Set<AnyKeyPath>, observer: @Sendable () -> Void)

public typealias _ObservationRegistrarContext = _AllocatedLock<_ObservationRegistrarState>
public typealias ObservationRegistrarContext = CollectionOfOne<AllocatedLock<ObservationRegistrarState>>

extension ObservationRegistrarContext {
  @inlinable
  init(state: ObservationRegistrarState) {
    self.init(AllocatedLock(state: state))
  }

  @inlinable
  var id: ObjectIdentifier {
    ObjectIdentifier(element.element)
  }

  @inlinable
  func registerTracking(
    for properties: Set<AnyKeyPath>,
    observer: @Sendable @escaping () -> Void
  ) -> Int {
    element.withLocked { state in
      state.registerTracking(for: properties, observer: observer)
    }
  }

  @inlinable
  func cancel(id: Int) {
    element.withLocked { $0.cancel(id: id) }
  }

  @inlinable
  func willSet<Subject, Member>(keyPath: KeyPath<Subject, Member>) {
    let actions = element.withLocked { $0.willSet(keyPath: keyPath) }
    for action in actions {
      action()
    }
  }
}

public typealias ObservationRegistrar = CollectionOfOne<ObservationRegistrarContext>

extension ObservationRegistrar {
  @inlinable
  public init() where Element == ObservationRegistrarContext {
    self.init(ObservationRegistrarContext(state: ObservationRegistrarState()))
  }

  @inlinable
  public func access<Subject, Member>(keyPath: KeyPath<Subject, Member>) {
    guard let trackingPtr = _getObservationTLSValue() else {
      return
    }
    if trackingPtr.pointee == nil {
      trackingPtr.pointee = ObservationTrackingAccessList()
    }
    trackingPtr.pointee!.addAccess(
      keyPath: keyPath,
      context: element
    )
  }

  @inlinable
  public func willSet<Subject, Member>(keyPath: KeyPath<Subject, Member>) {
    element.willSet(keyPath: keyPath)
  }

  @inlinable
  public func didSet<Subject, Member>(keyPath: KeyPath<Subject, Member>) {
  }

  @inlinable
  public func withMutation<Subject, Member, T>(
    keyPath: KeyPath<Subject, Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    willSet(keyPath: keyPath)
    defer { didSet(keyPath: keyPath) }
    return try mutation()
  }
}
