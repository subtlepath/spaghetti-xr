// Everything Swift may call in the shell and the engine.
//
// Wired up by XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER in the visionOS branch
// of the maintained SpaghettiKart CMake patch. Keep it to plain C declarations:
// the Swift side of the app imports nothing else from the C++ world.
#pragma once

#import "SpaghettiPadBridge.h"
