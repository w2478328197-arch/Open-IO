#!/usr/bin/env python3
"""Check only the files distributed by Open IO; do not read device data."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def verify(root=ROOT):
    manifest = json.loads((root / 'SOURCE_MANIFEST.json').read_text())
    expected = {item['path']: item for item in manifest['files']}
    actual = {p.relative_to(root / 'overlay').as_posix() for p in (root / 'overlay').rglob('*') if p.is_file()}
    if len(expected) != len(manifest['files']) or expected.keys() != actual:
        raise ValueError('Overlay file list mismatch')
    for name, entry in expected.items():
        p = root / 'overlay' / name
        if p.is_symlink():
            raise ValueError('Symlink in source overlay')
        data = p.read_bytes()
        if len(data) != entry['bytes'] or hashlib.sha256(data).hexdigest() != entry['sha256']:
            raise ValueError('Overlay hash mismatch: ' + name)
        if b'\x00' in data:
            raise ValueError('Binary data in source overlay')
        text = data.decode('utf-8')
        for pattern in [r'/Users' + r'/(?!YOUR_|example)[^/\s]+/', r'sk-[A-Za-z0-9_.-]{12,}', r'-----BEGIN (?:[A-Z ]+)?PRIVATE KEY-----']:
            if re.search(pattern, text):
                raise ValueError('Private data pattern in ' + name)
    return len(expected)


if __name__ == '__main__':
    print('Source manifest verified:', verify(), 'text files')
