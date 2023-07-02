//
//  AutoObservingView.swift
//  ObservationBDSwiftUISample
//
//  Created by Dmitry Galimzyanov on 03.07.2023.
//

import Combine
import ObservationBD
import SwiftUI

struct AutoObservingView<Content: View>: View {
  private let invalidator: Invalidator
  private let content: () -> Content

  init(@ViewBuilder content: @escaping () -> Content) {
    let invalidator = Invalidator()
    self.invalidator = invalidator
    self.content = content
  }

  var body: Content {
    withObservationTrackingBD {
      content()
    } onChange: { @MainActor in
      invalidator.invalidate()
    }
  }
}

struct Invalidator: DynamicProperty {
  final class Emitter: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()
  }

  @ObservedObject private var emitter = Emitter()

  func invalidate() {
    emitter.objectWillChange.send()
  }
}
