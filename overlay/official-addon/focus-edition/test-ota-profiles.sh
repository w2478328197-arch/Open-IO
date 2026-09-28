#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
work="$PWD/build/ota-profile-tests"
mkdir -p "$work/fixture" "$work/imported"
python3 - "$work" <<'PY'
from pathlib import Path
import os,sys,shutil,zipfile
work=Path(sys.argv[1])
files={code:Path(os.environ['OPENIO_TEST_'+code+'_ZIP']) for code in ('TFP1','TCC1','TWK1')}
for code,source in files.items():
 target=work/'fixture'/f'{code}.zip';shutil.copy2(source,target)
 with zipfile.ZipFile(target) as z:z.extractall(work/'fixture'/code)
PY
xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations \
 -DTIO_WORKOUT_OTA=1 -DTIO_CUE_CARDS_OTA=1 -DTIO_DISPLAY_FLASH=1 -DTIO_OTA_FEED_ARMING_ENABLED=1 \
 -DTIO_IMAGE_RX_LAB=1 -DTIO_DISPLAY_PHONE=1 -framework Foundation ExperimentalOTA.m ExperimentalOTAFeed.m ExperimentalOTAFlash.m \
 ExperimentalOTAGuard.m ResearchCatalog.m ExperimentalOTAProfilesTests.m -o "$work/profiles"
"$work/profiles" "$work/fixture" "$work/imported"
