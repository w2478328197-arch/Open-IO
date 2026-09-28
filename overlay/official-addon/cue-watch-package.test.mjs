import test from 'node:test';
import assert from 'node:assert/strict';
import {validateCueWatchMetadata,verifyCueWatchCode} from './cue-watch-package.mjs';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const companion='io.example.turbo';
const info={CFBundleIdentifier:companion+'.cuecards.watchkitapp',WKCompanionAppBundleIdentifier:companion,WKApplication:true};
const entitlements={'com.apple.developer.team-identifier':'TEAM','application-identifier':'TEAM.'+info.CFBundleIdentifier};
test('signed companion must belong to this phone application and signing team',()=>{
  assert.doesNotThrow(()=>validateCueWatchMetadata(info,entitlements,companion,'TEAM'));
  assert.throws(()=>validateCueWatchMetadata({...info,WKCompanionAppBundleIdentifier:'another.app'},entitlements,companion,'TEAM'));
  assert.throws(()=>validateCueWatchMetadata({...info,CFBundleIdentifier:'another.watch'},entitlements,companion,'TEAM'));
  assert.throws(()=>validateCueWatchMetadata(info,entitlements,companion,'OTHER'));
  assert.throws(()=>validateCueWatchMetadata(info,{...entitlements,'application-identifier':'TEAM.wrong'},companion,'TEAM'));
});
test('embedded watch version must match its phone container',()=>{
  const version={CFBundleVersion:'201',CFBundleShortVersionString:'1.0.5'};
  assert.doesNotThrow(()=>validateCueWatchMetadata({...info,...version},entitlements,companion,'TEAM',version));
  assert.throws(()=>validateCueWatchMetadata({...info,...version,CFBundleVersion:'1'},entitlements,companion,'TEAM',version),/watch_companion_version_mismatch/);
  assert.throws(()=>validateCueWatchMetadata({...info,...version,CFBundleShortVersionString:'1.0'},entitlements,companion,'TEAM',version),/watch_companion_version_mismatch/);
});
test('combined companion uses an existing health-enabled identity without accepting unrelated apps',()=>{
  const combined={...info,CFBundleIdentifier:companion+'.watchkitapp',NSHealthShareUsageDescription:'Current heart rate'};
  const health={...entitlements,'application-identifier':'TEAM.'+combined.CFBundleIdentifier,'com.apple.developer.healthkit':true};
  assert.doesNotThrow(()=>validateCueWatchMetadata(combined,health,companion,'TEAM'));
  assert.throws(()=>validateCueWatchMetadata(combined,{...health,'com.apple.developer.healthkit':false},companion,'TEAM'));
  assert.throws(()=>validateCueWatchMetadata({...combined,CFBundleIdentifier:companion+'.unknown.watchkitapp'},health,companion,'TEAM'));
  assert.throws(()=>validateCueWatchMetadata({...info,NSHealthShareUsageDescription:'Current heart rate'},entitlements,companion,'TEAM'),/watch_healthkit_entitlement_required/);
});
test('root-level Debug dylibs require individual signature and team verification',()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'turbo-watch-sign-'));
  try {
    for(const name of ['CueCardsWatch','CueCardsWatch.debug.dylib','__preview.dylib'])fs.writeFileSync(path.join(dir,name),Buffer.from('cffaedfe00000000','hex'));
    fs.writeFileSync(path.join(dir,'Info.plist'),'not executable');
    const calls=[];
    assert.equal(verifyCueWatchCode(dir,'TEAM',(program,args)=>calls.push({program,args})).length,3);
    assert.ok(calls.every(c=>c.program==='codesign'&&c.args.includes('=anchor apple generic and certificate leaf[subject.OU] = "TEAM"')));
    assert.throws(()=>verifyCueWatchCode(dir,'TEAM',(_program,args)=>{if(args.at(-1).endsWith('.debug.dylib'))throw Error('missing code signature');}),/missing code signature/);
  } finally { fs.rmSync(dir,{recursive:true,force:true}); }
});
