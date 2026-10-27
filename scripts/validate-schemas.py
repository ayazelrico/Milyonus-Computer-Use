#!/usr/bin/env python3
"""Validate actual Swift wire output with an independent Draft 2020-12 validator."""
import copy
import json
from pathlib import Path
import subprocess
from jsonschema import Draft202012Validator, FormatChecker

root = Path(__file__).resolve().parent.parent
fixtures = json.loads(subprocess.check_output([str(root/'.build/debug/milyonus-cu'), 'contract-fixtures']))
checker = FormatChecker()
assert 'date-time' in checker.checkers, 'Install jsonschema[format] to validate timestamps'
checks = []
validators = {}
for name, fixture in fixtures.items():
    schema = json.loads((root/'Schemas/v1'/f'{name}.schema.json').read_text())
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema, format_checker=checker)
    validators[name] = validator
    validator.validate(fixture)
    checks.append({'name': f'{name}: actual Swift encoding accepted', 'passed': True})

def reject(name, label, mutate):
    value = copy.deepcopy(fixtures[name])
    mutate(value)
    assert not validators[name].is_valid(value), label
    checks.append({'name': label, 'passed': True})

for name in fixtures:
    reject(name, f'{name}: unknown field rejected', lambda value: value.update(grant=True))
reject('action', 'boolean generation rejected', lambda value: value.update(generation=True))
reject('action', 'generation overflow rejected', lambda value: value.update(generation=2**63))
reject('action', 'unknown action rejected', lambda value: value.update(kind='executeShell'))
reject('action', 'NUL text rejected', lambda value: value.update(text='a\0b'))
reject('action', 'press with text rejected', lambda value: value.update(kind='press'))
reject('action', 'missing setValue text rejected', lambda value: value.pop('text'))
reject('heartbeat', 'heartbeat zero generation rejected', lambda value: value.update(generation=0))
reject('session', 'ready state cannot carry pause reason', lambda value: value.update(state='ready', pauseReason='heartbeatLost'))
reject('session', 'oversized bundle rejected', lambda value: value.update(bundleId='a'*256))
reject('session', 'invalid expiry rejected', lambda value: value.update(expiresAt='not-a-date'))
reject('session', 'invented pause reason rejected', lambda value: value.update(pauseReason='approvedByModel'))
reject('result', 'invalid effect rejected', lambda value: value.update(effect='maybe'))
reject('result', 'unknown effect cannot pass verification', lambda value: value.update(effect='unknown', verification='passed'))
reject('result', 'unapplied effect cannot fail verification', lambda value: value.update(effect='notApplied', verification='failed'))
reject('result', 'passed verification cannot carry error', lambda value: value.update(effect='applied', verification='passed', error='CANCELLED'))
reject('result', 'unknown error rejected', lambda value: value.update(error='UNRECOGNIZED'))
reject('observation', 'invalid PID rejected', lambda value: value.update(pid=-1))
reject('observation', 'oversized element tree rejected', lambda value: value.update(elements=value['elements']*301))
reject('observation', 'invalid bounds rejected', lambda value: value['elements'][0]['bounds'].update(width=0))
reject('observation', 'duplicate element objects rejected', lambda value: value.update(elements=[value['elements'][0], value['elements'][0]]))
reject('observation', 'duplicate actions rejected', lambda value: value['elements'][0].update(actions=['press', 'press']))
reject('observation', 'empty role rejected', lambda value: value['elements'][0].update(role=''))
reject('observation', 'unrecognized source rejected', lambda value: value.update(source='shell'))
for pixels in [0, 2001, -2001, True, 1.5]:
    reject('scroll', f'invalid scroll delta {pixels!r} rejected', lambda value, pixels=pixels: value.update(scrollPixels=pixels))
reject('scroll', 'missing scroll delta rejected', lambda value: value.pop('scrollPixels'))
reject('scroll', 'scroll text rejected', lambda value: value.update(text='unrelated'))
reject('scroll', 'scroll coordinates rejected', lambda value: value.update(x=42))
reject('action', 'text action with scroll delta rejected', lambda value: value.update(scrollPixels=20))
reject('drag', 'drag text rejected', lambda value: value.update(text='unexpected'))
reject('drag', 'drag scroll pixels rejected', lambda value: value.update(scrollPixels=20))
reject('drag', 'drag coordinates rejected', lambda value: value.update(x=42))
reject('drag', 'drag duration override rejected', lambda value: value.update(durationMilliseconds=10000))
reject('capabilities', 'native approval removal rejected', lambda value: value.update(requiresNativeApproval=False))
reject('capabilities', 'expanded mutation scope rejected', lambda value: value.update(mutationApps=['other.app']))
reject('capabilities', 'experimental action promoted to semantic rejected', lambda value: value.update(supportedActions=['drag']))
reject('capabilities', 'incompatible heartbeat rejected', lambda value: value.update(heartbeatIntervalSeconds=15))
reject('capabilities', 'numeric feature flag rejected', lambda value: value.update(experimentalNativeFixtureDrag=1))
reject('capabilities', 'duplicate advertised action rejected', lambda value: value.update(supportedActions=['press','press']))
reject('capabilities', 'oversized scroll capability rejected', lambda value: value.update(maximumScrollPixels=2001))
print(json.dumps({'suite':'swift-json-schema-conformance','passed':len(checks),'failed':0,'checks':checks,
                  'limits':'Runtime UTF-8/UTF-16 byte limits and native policy are additionally enforced in Swift.'},indent=2))
