#!/usr/bin/env python3
"""Assemble and build Open IO sources locally. Never uploads apps or flashes devices."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
UPSTREAM = "https://github.com/Turbo1123/Turbo-IO.git"
COMMIT = "ca7bc09fbbf036eaf32e90797302d1c798d9e5a4"


def run(*args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def features(value):
    parts = value.split(',')
    if not parts or len(set(parts)) != len(parts) or not set(parts) <= {'todo', 'cue', 'run'}:
        raise ValueError('Features must be todo, cue, run, or a comma-separated combination')
    return [name for name in ('todo', 'cue', 'run') if name in parts]


def read_workspace(root):
    state = json.loads((root / '.openio.json').read_text())
    if state['upstreamCommit'] != COMMIT:
        raise ValueError('This workspace uses a different upstream revision')
    features(','.join(state['features']))
    return state


def environment(selected):
    result = {k: v for k, v in os.environ.items() if not k.startswith(('TIO_', 'OPENIO_'))}
    result['OPENIO_FEATURES'] = ','.join(selected)
    return result


def prepare(args):
    selected = features(args.features)
    manifest = json.loads((ROOT / 'SOURCE_MANIFEST.json').read_text())
    paths = set()
    for entry in manifest['files']:
        rel = Path(entry['path'])
        if rel.is_absolute() or '..' in rel.parts or entry['path'] in paths:
            raise ValueError('Unsafe or duplicate overlay path')
        paths.add(entry['path'])
        source = ROOT / 'overlay' / rel
        if source.is_symlink() or sha(source) != entry['sha256']:
            raise ValueError('Overlay integrity check failed: ' + str(rel))
    output = args.out.resolve()
    if output.exists():
        raise ValueError('Use a new output directory; existing workspaces are preserved')
    output.mkdir(parents=True)
    run('git', 'init', '-q', output)
    run('git', '-C', output, 'remote', 'add', 'origin', args.upstream or UPSTREAM)
    run('git', '-C', output, 'fetch', '--depth', '1', 'origin', COMMIT)
    run('git', '-C', output, 'checkout', '-q', '--detach', 'FETCH_HEAD')
    revision = subprocess.check_output(['git', '-C', str(output), 'rev-parse', 'HEAD'], text=True).strip()
    if revision != COMMIT:
        raise ValueError('Upstream commit mismatch')
    for entry in manifest['files']:
        target = output / entry['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / 'overlay' / entry['path'], target)
    (output / '.openio.json').write_text(json.dumps({
        'features': selected, 'upstreamCommit': COMMIT,
        'manifestSHA256': sha(ROOT / 'SOURCE_MANIFEST.json')
    }, indent=2) + '\n')
    print('Prepared Open IO source workspace:', output)


def build(args):
    root = args.workspace.resolve()
    state = read_workspace(root)
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]+\.[A-Za-z0-9.-]+', args.bundle) or args.bundle == 'com.rayneo.venus.pub':
        raise ValueError('Choose your own separate bundle identifier')
    env = environment(state['features'])
    env.update(TIO_IMAGE_RX_LAB='1', TIO_IMAGE_RX_WIDE='1', TIO_DISPLAY_PHONE='1')
    glasses = bool({'cue', 'run'} & set(state['features']))
    if glasses:
        env.update(TIO_OTA_FLASH_ENABLED='1', TIO_DISPLAY_FLASH='1', TIO_PRIVATE_OTA_TARGET='1', TIO_CUE_CARDS_OTA='1', TIO_WORKOUT_OTA='1')
    else:
        env['TIO_PHONE_ONLY_FOCUS'] = '1'
    run('bash', root / 'official-addon/focus-edition/build.sh', 'embedded', args.bundle, env=env)
    flavor = 'cue-cards-ota' if glasses else 'image-rx-lab'
    artifact = root / 'official-addon/focus-edition/build' / flavor / 'TurboIOPrivateAddon.dylib'
    output = root / 'build/openio'
    output.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(artifact, output / 'TurboIOPrivateAddon.dylib')
    state.update(bundle=args.bundle, addonSHA256=sha(artifact))
    if glasses:
        run('bash', root / 'apps/CueCardsWatch/build.sh', args.bundle, env=env)
    (root / '.openio-build.json').write_text(json.dumps(state, indent=2) + '\n')
    print('Build passed. Watch output is unsigned until sign-watch is run.')


def sign_watch(args):
    root = args.workspace.resolve()
    state = json.loads((root / '.openio-build.json').read_text())
    if not {'cue', 'run'} & set(state['features']):
        raise ValueError('The todo profile has no Watch companion')
    if not re.fullmatch(r'[A-Z0-9]{10}', args.team):
        raise ValueError('Invalid Apple development team')
    env = environment(state['features'])
    env['OPENIO_DEVELOPMENT_TEAM'] = args.team
    env['OPENIO_WATCH_DESTINATION'] = 'id=' + args.watch
    run('bash', root / 'apps/CueCardsWatch/build.sh', state['bundle'], env=env)
    print('Watch signed locally. Use build/Build/Products/Debug-watchos/CueCardsWatch.app under apps/CueCardsWatch.')


def package(args):
    root = args.workspace.resolve()
    state = json.loads((root / '.openio-build.json').read_text())
    addon = root / 'build/openio/TurboIOPrivateAddon.dylib'
    if sha(addon) != state['addonSHA256']:
        raise ValueError('Built addon changed; rebuild before packaging')
    symbols = subprocess.check_output(['nm', '-g', str(addon)], text=True)
    actual = {name for name in ('todo', 'cue', 'run') if '_OpenIOProfile' + name.title() in symbols}
    if actual != set(state['features']):
        raise ValueError('Addon features do not match this workspace')
    command = ['node', root / 'official-addon/package.mjs', '--app', args.app.resolve(),
               '--addon', addon, '--profile', args.profile.resolve(), '--identity', args.identity,
               '--device', args.device, '--out', args.out.resolve(), '--bundle', state['bundle']]
    if {'cue', 'run'} & actual:
        if not args.firmware:
            raise ValueError('Cue/run require the exact locally rebuilt TWK1 firmware')
        command += ['--experimental-ota', 'TWK1', '--private-ota-target', '1', '--firmware', args.firmware.resolve()]
        if 'run' in actual and not args.watch_app:
            raise ValueError('Run requires a signed Watch companion')
    else:
        if args.firmware or args.watch_app:
            raise ValueError('Todo profile accepts neither firmware nor Watch companion')
        command += ['--phone-only-focus', '1']
    if args.watch_app:
        watch_info = plistlib.loads((args.watch_app / 'Info.plist').read_bytes())
        validate_watch_profile(watch_info, actual)
        command += ['--watch-app', args.watch_app.resolve()]
    if args.product:
        command += ['--product', args.product]
    run(*command)


def validate_watch_profile(info, selected):
    expected = set(selected) & {'cue', 'run'}
    if set(info.get('OpenIOFeatures', '').split(',')) != expected:
        raise ValueError('Watch features do not match the phone; rebuild and sign the matching Watch profile')
    if 'run' in expected and not info.get('NSHealthShareUsageDescription'):
        raise ValueError('Running Watch profile is missing its HealthKit purpose description')


def firmware(args):
    root = args.workspace.resolve()
    read_workspace(root)
    run(sys.executable, root / 'firmware-research/strix-1.0.4.12/native-navigation/cue-cards/build.py',
        '--workout', '--stock', args.stock.resolve(), '--llvm', args.llvm.resolve(), '--out', args.out.resolve())


def main():
    default = (ROOT / '.openio-profile').read_text().strip() if (ROOT / '.openio-profile').exists() else 'todo,cue,run'
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest='action', required=True)
    p = subs.add_parser('prepare')
    p.add_argument('--features', default=default)
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--upstream', help='Optional local Git repository, read at the pinned commit only')
    p.set_defaults(handler=prepare)
    for name, handler in [('build', build), ('sign-watch', sign_watch), ('package', package), ('firmware', firmware)]:
        p = subs.add_parser(name)
        p.add_argument('--workspace', type=Path, required=True)
        p.set_defaults(handler=handler)
        if name == 'build':
            p.add_argument('--bundle', required=True)
        elif name == 'sign-watch':
            p.add_argument('--team', required=True)
            p.add_argument('--watch', required=True, help='Your paired Watch device identifier from Xcode')
        elif name == 'firmware':
            for key in ['stock', 'llvm', 'out']:
                p.add_argument('--' + key, type=Path, required=True)
        else:
            for key in ['app', 'profile', 'out']:
                p.add_argument('--' + key, type=Path, required=True)
            for key in ['identity', 'device']:
                p.add_argument('--' + key, required=True)
            p.add_argument('--firmware', type=Path)
            p.add_argument('--watch-app', type=Path)
            p.add_argument('--product')
    args = parser.parse_args()
    args.handler(args)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print('Open IO stopped:', error, file=sys.stderr)
        sys.exit(1)
