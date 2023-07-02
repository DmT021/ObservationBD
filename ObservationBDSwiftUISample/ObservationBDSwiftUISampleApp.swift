//
//  ObservationBDSwiftUISampleApp.swift
//  ObservationBDSwiftUISample
//
//  Created by Dmitry Galimzyanov on 03.07.2023.
//

import SwiftUI

@main
struct ObservationBDSwiftUISampleApp: App {
  @State var model = ContentViewModel()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
    }
  }
}
