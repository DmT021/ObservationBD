//
//  ContentView.swift
//  ObservationBDSwiftUISample
//
//  Created by Dmitry Galimzyanov on 03.07.2023.
//

import ObservationBD
import SwiftUI

@ObservableBD
final class ContentViewModel {
  var counter = 0
}

struct ContentView: View {
  var model: ContentViewModel

  var body: some View {
    AutoObservingView {
      VStack {
        Image(systemName: "globe")
          .imageScale(.large)
          .foregroundStyle(.tint)
        Text("Hello, world!")
        Text("Counter: \(model.counter)")
        Button {
          model.counter += 1
        } label: {
          Text("Increment")
        }

      }
      .padding()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(model: ContentViewModel())
  }
}
