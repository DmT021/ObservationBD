//
//  CollectionOfOneExtensions.swift
//  ObservationBD
//
//  Created by Dmitry Galimzyanov on 05.07.2023.
//

extension CollectionOfOne {
  @inlinable
  var element: Element {
    _read {
      yield self[0] // should be just `_element`
    }
    _modify {
      yield &self[0]
    }
  }
}
