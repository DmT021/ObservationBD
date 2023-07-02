//
//  main.swift
//  ObservationBDSample
//
//  Created by Dmitry Galimzyanov on 02.07.2023.
//

import ObservationBD

@ObservableBD
final class MyCounter {
  var count = 0

  func increment() {
    count += 1
  }
}

let myCounter = MyCounter()

func test() {
  withObservationTrackingBD {
    print(myCounter.count)
  } onChange: {
    DispatchQueue.main.async { test() }
  }
  DispatchQueue.main.asyncAfter(deadline: .now()+1) {
    myCounter.increment()
  }
}

test()

RunLoop.main.run()
