//
//  AllocatedLock.swift
//  ObservationBD
//
//  Created by Dmitry Galimzyanov on 02.07.2023.
//

public typealias _AllocatedLock<T> = ManagedBuffer<T, _RawLock>
public typealias AllocatedLock<T> = CollectionOfOne<_AllocatedLock<T>>

extension CollectionOfOne {
  @inlinable
  init<T>(state: T) where Element == _AllocatedLock<T> {
    let lock = _AllocatedLock<T>.create(minimumCapacity: 1) { buffer in
      buffer.withUnsafeMutablePointerToElements { lock in
        raw_lock_init(lock)
      }
      return state
    }
    self.init(lock)
  }

  @inlinable
  func withLocked<T, R>(_ function: (inout T) throws -> R) rethrows -> R where Element == _AllocatedLock<T> {
    try element.withUnsafeMutablePointers { state, lock in
      raw_lock_lock(lock)
      defer { raw_lock_unlock(lock) }
      return try function(&state.pointee)
    }
  }
}

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
public typealias _RawLock = os_unfair_lock_s
@inlinable func raw_lock_init(_ lock: UnsafeMutablePointer<_RawLock>) {
  lock.initialize(to: os_unfair_lock_s())
}
@inlinable func raw_lock_lock(_ lock: UnsafeMutablePointer<_RawLock>) {
  os_unfair_lock_lock(lock)
}
@inlinable func raw_lock_unlock(_ lock: UnsafeMutablePointer<_RawLock>) {
  os_unfair_lock_unlock(lock)
}
#else
#error("Unsupported platform")
#endif
