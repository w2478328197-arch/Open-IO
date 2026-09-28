#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/cue-cards-tests
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter \
  -fsanitize=address,undefined -framework Foundation \
  CueCardsCore.m CueCardsTests.m reader.c -o build/cue-cards-tests/core
build/cue-cards-tests/core
baseline=../../firmware-research/strix-1.0.4.12/native-navigation/focus/src/official-addon/research/weread-v1
candidate=../../firmware-research/strix-1.0.4.12/native-navigation/cue-cards
test_headers=build/cue-cards-tests/headers
mkdir -p "$test_headers"
cp "$baseline/reader.h" "$test_headers/reader.h"
for test in reader_test reader_view_test reader_input_test; do
  cp "$baseline/$test.c" "$test_headers/$test.c"
done
cp "$baseline/reader_view.h" "$test_headers/reader_view.h"
python3 - "$test_headers/reader.h" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
old = "uint8_t front;bool active,valid,receiving,pending,automatic,dirty,returning;"
new = "uint8_t front;bool active,valid,receiving,pending,automatic,dirty,returning,cue_home;"
if source.count(old) != 1:
    raise SystemExit("Unexpected FOCUS reader.h layout; refusing to build cue-card tests")
source = source.replace(old, new)
old_api = "void wr_tick(WRReader *,uint32_t);"
if source.count(old_api) != 1:
    raise SystemExit("Unexpected FOCUS reader.h API; refusing to build idle-hold tests")
path.write_text(source.replace(old_api, "bool wr_should_close_for_idle(bool,uint32_t);\n" + old_api))
PY
cmp reader.c "$candidate/reader.c"
for test in reader_test reader_view_test reader_input_test; do
  test_source="$test_headers/$test.c"
  units=(reader.c "$test_source")
  if [[ "$test" == reader_view_test ]]; then units+=("$candidate/reader_view.c"); fi
  xcrun clang -std=c11 -Wall -Wextra -Wno-unused-parameter -fsanitize=address,undefined \
    -I "$test_headers" -I "$baseline" "${units[@]}" -o "build/cue-cards-tests/$test"
  "build/cue-cards-tests/$test"
done
xcrun clang -std=c11 -Wall -Wextra -Wno-unused-parameter -fsanitize=address,undefined \
  -I "$test_headers" -I "$baseline" reader.c "$candidate/reader_view.c" "$candidate/cue_view_test.c" \
  -o build/cue-cards-tests/cue-view
build/cue-cards-tests/cue-view
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter -Wno-incompatible-pointer-types \
  -fsanitize=address,undefined -framework Foundation \
  ReaderBridge.m ReaderBridgeTest.m ReadingContent.m reader.c -lz -o build/cue-cards-tests/reader-bridge
build/cue-cards-tests/reader-bridge
