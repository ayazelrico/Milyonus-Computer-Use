#!/usr/bin/env python3
"""Record reproducible source identifiers without reading credentials or user data."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
paths = [root/'Package.swift']
for directory in ['Sources', 'Tests', 'Schemas', 'scripts', 'Integrations', 'Experiments']:
    paths.extend(path for path in (root/directory).rglob('*')
                 if path.is_file() and '__pycache__' not in path.parts)
files = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
         for path in sorted(paths)}
manifest = {'recordedAt': datetime.now(timezone.utc).isoformat(), 'algorithm': 'SHA-256',
            'files': files,
            'scope': 'Source snapshot only; individual test logs and native binary hash determine acceptance.'}
for name, relative in [('debugCompanion', 'build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse'),
                       ('releaseCompanion', '.build/release/MilyonusComputerUse')]:
    path = root/relative
    if path.is_file(): manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest()
print(json.dumps(manifest, indent=2))
