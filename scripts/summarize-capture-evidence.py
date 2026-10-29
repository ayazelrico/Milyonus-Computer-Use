#!/usr/bin/env python3
"""Validate explicit capture records and summarize their narrow acceptance boundaries."""
import argparse
import json
import math
from pathlib import Path

EXPECTED = {
    'absent': ('passed-absent-fixture', 'TARGET_NOT_FOUND'),
    'ambiguous': ('passed-ambiguous-fixture', 'TARGET_AMBIGUOUS'),
    'marker': ('passed-fixture-marker', None),
    'move': ('passed-move-before-publication', 'STALE_OBSERVATION'),
    'close': ('passed-close-before-publication', 'STALE_OBSERVATION'),
    'cancel': ('passed-cancel-before-publication', 'CancellationError'),
    'deadline': ('passed-deadline-before-publication', 'TIMEOUT'),
}


def validate(path):
    record = json.loads(path.read_text())
    case = record['case']
    status, refusal = EXPECTED[case]
    result = record['result']
    if record.get('status') != status or result.get('status') != status:
        raise ValueError('Record does not establish its declared case: ' + str(path))
    if result.get('imageWrittenToDisk') is not False or result.get('imageSentToProvider') is not False:
        raise ValueError('Missing local-only evidence')
    if case != 'absent' and record.get('ownedFixtureExited') is not True:
        raise ValueError('Missing owned fixture cleanup')
    if refusal and result.get('refusal') != refusal:
        raise ValueError('Unexpected refusal')
    boundary = 'selection-or-local-marker'
    if case in ['move', 'close', 'cancel', 'deadline']:
        boundary = 'after-framework-image-before-final-revalidation'
        times = [result.get(key) for key in ['imageReturnedBeforeTransitionUptime',
                 'transitionObservedUptime', 'refusalObservedUptime']]
        if not all(type(value) in [int, float] and math.isfinite(value) and value > 0 for value in times):
            raise ValueError('Missing monotonic event times')
        if not times[0] <= times[1] <= times[2]:
            raise ValueError('Invalid event ordering')
        if (result.get('boundary') != boundary or result.get('framePublished') is not False
                or result.get('transitionObserved') is not True):
            raise ValueError('Missing publication-refusal evidence')
        if case == 'deadline' and times[1] - times[0] < 10:
            raise ValueError('Delay did not exceed the unchanged ten-second deadline')
        if case == 'move':
            before, after = result['expectedBounds'], result['observedBounds']
            if after['id'] != str(result['targetWindowID']) or after['pid'] != str(result['targetPID']):
                raise ValueError('Movement identity mismatch')
            if abs(float(after['x']) - before['x']) < 40 and abs(float(after['y']) - before['y']) < 20:
                raise ValueError('No measured movement')
    if case == 'marker' and result.get('colorFidelityAccepted') is not False:
        raise ValueError('Marker identity is not color-fidelity acceptance')
    return {'case': case, 'evidence': str(path), 'status': status, 'boundary': boundary,
            'clientSourceSHA256': record['clientSourceSHA256'],
            'fixtureSHA256': record.get('fixtureSHA256')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True)
    parser.add_argument('records', nargs='+', type=Path)
    args = parser.parse_args()
    output = Path(args.output)
    if output.exists():
        raise SystemExit('Summary already exists')
    cases = [validate(path) for path in args.records]
    if len({entry['case'] for entry in cases}) != len(cases):
        raise SystemExit('Supply exactly one selected record per case')
    result = {'suite': 'capture-evidence-audit', 'status': 'passed-record-validation', 'cases': cases,
              'limitations': 'Validates recorded assertions and timing, not an independent replay. Records may represent different source snapshots. No full H4, framework-call preemption, color-fidelity, publisher authentication, installed-companion or hardware-matrix claim.'}
    output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'status': result['status'], 'validatedCases': len(cases)}))


if __name__ == '__main__':
    main()
