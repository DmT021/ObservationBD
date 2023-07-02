//
//  ObservationTLS.swift
//  ObservationBD
//
//  Created by Dmitry Galimzyanov on 02.07.2023.
//


#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
@inlinable
func _getObservationTLSValue() -> UnsafeMutablePointer<_ObservationTrackingAccessList?>? {
  if let value = Thread.current.threadDictionary[_observationTLSKey] as? UnsafeMutablePointer<_ObservationTrackingAccessList?>? {
    return value
  }
  return nil
}

@inlinable
func _setObservationTLSValue(_ value: UnsafeMutablePointer<_ObservationTrackingAccessList?>?) {
  Thread.current.threadDictionary[_observationTLSKey] = value
}

@inlinable
var _observationTLSKey: Int {
  11238947208947
}
#else
#error("Unsupported platform")
#endif
