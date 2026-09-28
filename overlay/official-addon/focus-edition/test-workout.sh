#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/workout-tests
xcrun swiftc ../../apps/CueCardsWatch/WorkoutCadenceWindow.swift ../../apps/CueCardsWatch/tests/WorkoutCadenceTests.swift -o build/workout-tests/cadence
./build/workout-tests/cadence
xcrun clang -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined ../../firmware-research/strix-1.0.4.12/native-navigation/workout/workout_wire_test.c -o build/workout-tests/wire
./build/workout-tests/wire
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter -Wno-incompatible-pointer-types -fsanitize=address,undefined -framework Foundation NativeNavigation.m nav_runtime.c A2UIProtocol.m WorkoutTransportTests.m -o build/workout-tests/transport
./build/workout-tests/transport
