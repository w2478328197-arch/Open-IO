#!/usr/bin/env python3
"""Create source archives locally from the committed distribution file list."""
import hashlib
from pathlib import Path
import subprocess
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
from verify_source import verify

ROOT = Path(__file__).resolve().parents[1]
VERSION = 'v0.1.0'


def main():
    verify(ROOT)
    names = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-z']).decode().split('\0')
    names = sorted(n for n in names if n)
    if not names or any(not (ROOT / n).is_file() for n in names):
        raise ValueError('Missing tracked release files')
    output = ROOT / 'build/releases'
    output.mkdir(parents=True, exist_ok=True)
    checksums = []
    for feature in ['todo', 'cue', 'run']:
        stem = f'OpenIO-{feature}-source-{VERSION}'
        archive = output / (stem + '.zip')
        with ZipFile(archive, 'w') as target:
            def write(name, data):
                entry = ZipInfo(stem + '/' + name, (2026, 9, 28, 0, 0, 0))
                entry.compress_type = ZIP_DEFLATED
                entry.external_attr = 0o100644 << 16
                target.writestr(entry, data, compresslevel=9)
            for name in names:
                write(name, (ROOT / name).read_bytes())
            write('.openio-profile', (feature + '\n').encode())
        with ZipFile(archive) as check:
            assert check.testzip() is None
            assert check.read(stem + '/.openio-profile').decode().strip() == feature
            assert not any(n.endswith(('.ipa', '.mobileprovision', '.p12', '.dylib', '.bin')) for n in check.namelist())
        checksums.append(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name)
    (output / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')
    print('\n'.join(checksums))


if __name__ == '__main__':
    main()
