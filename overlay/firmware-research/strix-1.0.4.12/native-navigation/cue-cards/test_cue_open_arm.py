"""Check the first rendered frame of remote cue-card OPEN in the linked AP."""
from pathlib import Path
import sys

candidate = Path(sys.argv[1]).resolve()
fixture = candidate.parent / "official-addon/research/weread-v1/test_reader_arm.py"
original_file = __file__
__file__ = str(fixture)
exec(compile(fixture.read_text().split("seq=0\n")[0], str(fixture), "exec"))
__file__ = original_file

def cleanup():
    call("wr_slot_hidden", reader)
    put(0x18001000 + 24, 0)
    tick(100)
    assert not tokens and len(objects) == 1 and not timers

# Unsupported modes must not allocate or paint anything.
send(packet(1, 1, offset=1, sid=80), 1)
assert len(objects) == 1 and not tokens

# Check immediately after OPEN, before the first content or timer tick.
send(packet(1, 1, offset=3, sid=81))
assert "提词卡" in labels.values(), labels
assert not any("微信读书" in value for value in labels.values()), labels
assert call("wr_slot_visible", reader) and tokens
tick(100)
assert any("正在接收提词卡" in value for value in labels.values()), labels
assert not any(reply[5] == 1 for reply in replies), "cue OPEN requested a bookshelf"

# Replayed OPEN and another session cannot switch a live presentation's mode.
wakes = calls.count("wake")
send(packet(1, 1, offset=3, sid=81))
assert calls.count("wake") == wakes
send(packet(1, 2, offset=0, sid=81), 3)
send(packet(1, 1, offset=0, sid=82), 3)
assert "提词卡" in labels.values()

body = bytearray(384)
struct.pack_into("<IIIIIIII", body, 0, 3, 0, 2, 1, 0, 0, 0, 42)
body[64:71] = b"Opening"
body[160:164] = b"Demo"
body[256:269] = b"Hello glasses"
send(packet(2, 2, struct.pack("<II", len(body), zlib.crc32(body)), rev=1, sid=81))
send(packet(3, 3, bytes(body), rev=1, sid=81))
send(packet(4, 4, rev=1, sid=81))
tick(100)
assert "Opening" in labels.values() and "Hello glasses" in labels.values()
assert any("提词卡 1 / 2" in value for value in labels.values())
tick(91000)
assert call("wr_slot_visible", reader) and tokens, "cue page expired at the reader idle timeout"
linked = False
tick(100)
assert not call("wr_slot_visible", reader) and not tokens, "disconnected remote session retained ownership"
linked = True
cleanup()

# Legacy OPEN still has the normal WeRead waiting page and bookshelf request.
send(packet(1, 1, sid=83))
assert "微信读书" in labels.values()
tick(100)
assert any(reply[5] == 1 for reply in replies)
cleanup()

# Delayed renderer availability must also use the cue identity on first paint.
put(0x18001000 + 24, 1)
send(packet(1, 1, offset=3, sid=84))
assert not tokens and len(objects) == 1
put(0x18001000 + 24, 0)
tick(100)
assert "提词卡" in labels.values()
assert not any("微信读书" in value for value in labels.values())
cleanup()
call("wr_slot_destroy", reader)
put(slot + 28, 0)
call("tn_slot_destroy", slot)
tick(100)
assert alloc.keys() == freed and not timers and not tokens
result = {"passed": True, "AP": report["candidateAP"], "deviceIO": False,
          "cueFirstFrame": True, "noBookshelfRequest": True,
          "legacyReaderPreserved": True, "replayedOpenIdempotent": True,
          "foreignSessionAndModeRejected": True, "invalidModeNoUI": True,
          "cueBodyRendered": True, "busyRendererFirstFrame": True,
          "cueIdleHold": True, "disconnectReleasesRemoteSession": True,
          "noHeapLeaks": True, "physicalDisplayVerified": False}
(d / "cue-open-arm.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))
