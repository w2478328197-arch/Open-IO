"""Execute the linked TWK1 file receiver, UI and timeout code with mocked OS."""
from pathlib import Path
import sys
candidate=Path(sys.argv[1]).resolve()
base=candidate.parent/'official-addon/research/navigation-runtime-v1/test_service_arm.py'
source=base.read_text().split("slot=call('tn_slot_create',APP)")[0]
source=source.replace("assert r(2)==r(3)==128", "assert (r(2),r(3))==(224,144)")
source=source.replace("r(0) in (16,18,20,32)", "r(0) in (14,16,18,20,32)")
source=source.replace("j['cmd']=='turbo_nav_v1'", "j['cmd']=='turbo_wrk_v1'")
source=source.replace("b'TNA1\\1'", "b'TWA1\\1'")
source=source.replace('replies=[];labels={}', 'replies=[];menu_events=[];labels={}')
source=source.replace("j=json.loads(b[6:]);assert j['cmd']=='turbo_wrk_v1';", "j=json.loads(b[6:])\n  if j['cmd']=='turbo_wrk_menu':\n   raw=bytes.fromhex(j['payload']['data']);assert len(raw)==20 and raw[:5]==b'TWM1\\1' and raw[5] in (0,1) and raw[6:8]==bytes(2) and zlib.crc32(raw[:16])==struct.unpack_from('<I',raw,16)[0];menu_events.append((raw[5],*struct.unpack_from('<II',raw,8)));ret();return\n  assert j['cmd']=='turbo_wrk_v1';")
source=source.replace("for n in ['memcpy'", "for n in ['menu_text_align','memcpy'")
source=source.replace("elif n=='menu_font':", "elif n=='menu_text_align':assert r(1)==3;ret()\n elif n=='menu_font':")
source+=r'''
slot=call('tn_slot_create',APP);assert slot;put(APP+0xdc+28,slot)
call('stream_register_shim');callback=word(0x19750d2c+0x18)
def send_workout(op,sid,seq,expected=0,nonce=0):
 global now
 now+=150
 payload=struct.pack('<HHHHIII4B32s',146,360,176,105,342000,2120,1800,3,5,0,0,b'140.25-<155.75') if op in (1,2) else b''
 b=bytearray(b'TWK1'+bytes([2,op,0,0])+struct.pack('<IIIIII',sid,seq,len(payload),0,nonce,0)+payload)
 struct.pack_into('<I',b,20,zlib.crc32(b));u.mem_write(WIRE,bytes(b));f=bytearray(336);struct.pack_into('<II',f,0,WIRE,len(b))
 name=b'turbo-workout.twk\0';f[8:8+len(name)]=name;f[329]=1;struct.pack_into('<I',f,332,len(b));u.mem_write(FILE,bytes(f))
 before=queued;call(callback,FILE);assert queued==before+1;u.mem_write(WIRE,bytes(len(b)));before=len(replies)
 call(0x106eba90,0,QUEUE);assert len(replies)==before+1
 ack=replies[-1];assert ack[5]==expected and struct.unpack_from('<II',ack,8)==(sid,seq),(ack,expected)
# Start from home, render all fields and confirm the actual linked native ACK.
send_workout(1,500,1)
assert tokens=={7} and len(objects)==23 and '6′00″' in labels.values() and '212' in labels.values(),labels
assert '140.25-<155.75' in labels.values() and 'Z3 / 5' in labels.values()
beforealloc=len(alloc)
for seq in range(2,12):send_workout(2,500,seq)
assert len(alloc)==beforealloc
# Stale heart/pace cannot survive a still-connected phone heartbeat.
tick(16000);assert '连接中' in labels.values() and '—' in labels.values()
send_workout(3,500,12);assert '—' in labels.values()
send_workout(2,500,13);assert '6′00″' in labels.values()
send_workout(2,500,12,4)
send_workout(4,500,14);tick(200);assert not tokens and len(objects)==1
send_workout(1,501,1);put(EVENT,0x3b);call('m8_hook_vm_event',EVENT);tick(200);assert not tokens and len(objects)==1
# Local menu opens even offline, with all unavailable metrics visibly missing.
linked=False;before=len(menu_events);assert call('tw_slot_open',slot)
assert '请在手表开始跑步' in labels.values() and '运动看板' in labels.values()
assert '6′00″' not in labels.values() and '00:00' not in labels.values() and '—' in labels.values()
tick(61000);assert not tokens and len(menu_events)==before
put(EVENT,0x3a);call('m8_hook_vm_event',EVENT);assert tokens=={7}
put(EVENT,0x3b);call('m8_hook_vm_event',EVENT);tick(200);assert not tokens and len(objects)==1
linked=True;assert call('tw_slot_open',slot);opened,nonce,seq=menu_events[-1];assert opened and nonce and seq==1
tick(2100);assert menu_events[-1]==(1,nonce,2)
send_workout(1,600,1,4,nonce+1);assert '请在手表开始跑步' in labels.values()
beforealloc=len(alloc);send_workout(1,600,1,nonce=nonce)
assert len(alloc)==beforealloc and '6′00″' in labels.values() and '请在手表开始跑步' not in labels.values()
send_workout(1,600,1,nonce=nonce) # Duplicate accepted without reallocation.
put(EVENT,0x3b);call('m8_hook_vm_event',EVENT);tick(200);assert menu_events[-1][0]==0 and not tokens and len(objects)==1
send_workout(1,601,1,4,nonce);assert len(objects)==1 # Delayed START cannot reopen after Back.
assert call('tw_slot_open',slot);newnonce=menu_events[-1][1];assert newnonce!=nonce
send_workout(1,602,1,4,nonce);send_workout(1,602,1,nonce=newnonce);send_workout(4,602,2);tick(200)
assert not tokens and len(objects)==1 and menu_events[-1][0]==0
# Repeated entry and back releases view, canvas, power, and preserves the home slot.
for _ in range(10):
 assert call('tw_slot_open',slot);put(EVENT,0x3b);call('m8_hook_vm_event',EVENT);tick(200);assert not tokens and len(objects)==1
call('tn_slot_destroy',slot);tick(200);assert not timers and len(freed)==len(alloc)
result={'passed':True,'AP':report['candidateAP'],'syntheticOnly':True,'fileReceiver':True,'twoColumns':True,'nativeReply':True,'stale15Seconds':True,'heartbeatsDoNotRefreshMetrics':True,'physicalBack':True,'noHeapLeaks':True,'deviceVerified':False}
result.update(localMenu=True,offlineWaiting=True,noFakeWaitingMetrics=True,menuPulseCRC=True,nonceBoundStart=True,backRejectsDelayedStart=True,tenReentryCycles=True)
(d/'workout-service-arm.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
'''
exec(compile(source,str(base),'exec'),{'__file__':str(base),'__name__':'__main__'})
