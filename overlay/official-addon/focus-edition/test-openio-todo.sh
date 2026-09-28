#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/openio-todo-tests
for unit in TodoProtocol TodoCompletionLedger TodoMirrorLedger; do
  extra=()
  [[ "$unit" != TodoMirrorLedger ]] || extra+=(TodoProtocol.m)
  xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-incompatible-pointer-types -framework Foundation \
    "$unit.m" "${unit}Tests.m" ${extra[@]+"${extra[@]}"} -o "build/openio-todo-tests/$unit"
  if [[ "$unit" == TodoCompletionLedger ]]; then
    suite="io.turboio.todo.ledger-tests.openio.$(uuidgen)"
    trap 'build/openio-todo-tests/TodoCompletionLedger cleanup "$suite"' EXIT
    for mode in write read verify; do "build/openio-todo-tests/$unit" "$mode" "$suite"; done
    "build/openio-todo-tests/$unit" cleanup "$suite"
    trap - EXIT
  else
    "build/openio-todo-tests/$unit"
  fi
done
for unit in AppleTodoList AppleTodoMirror; do
  xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter -Wno-incompatible-pointer-types \
    -framework Foundation -framework EventKit AppleCalendarSync.m "${unit}Tests.m" -o "build/openio-todo-tests/$unit"
  "build/openio-todo-tests/$unit"
done
