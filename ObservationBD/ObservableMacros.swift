//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if $Macros && hasAttribute(attached)

@attached(member, names: named(_$observationRegistrar), named(access), named(withMutation), arbitrary)
@attached(memberAttribute)
public macro ObservableBD() =
  #externalMacro(module: "ObservationBDMacros", type: "ObservableBDMacro")

@attached(accessor, names: named(init), named(get), named(set))
public macro ObservationBDTracked() =
  #externalMacro(module: "ObservationBDMacros", type: "ObservationTrackedBDMacro")

@attached(accessor, names: named(willSet))
public macro ObservationBDIgnored() =
  #externalMacro(module: "ObservationBDMacros", type: "ObservationIgnoredBDMacro")

#endif
