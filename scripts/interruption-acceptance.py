#!/usr/bin/env python3
"""Native pre-dispatch interruption acceptance; manual approval, no approval RPC."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import select
import subprocess
import time
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('mode', choices=['stop', 'user-input', 'environment', 'window-close', 'permission-revoke'])
parser.add_argument('--evidence', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
binary = root / 'build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse'
path = Path(args.evidence)
if path.exists():
    raise SystemExit('Refusing to overwrite existing acceptance evidence')
record = {'suite': 'native-pre-dispatch-interruption', 'mode': args.mode, 'status': 'running',
          'startedAt': datetime.now(timezone.utc).isoformat(),
          'companionSHA256': hashlib.sha256(binary.read_bytes()).hexdigest(),
          'scope': 'Captured target interrupted before dispatch; not interruption during native event delivery.',
          'checks': []}
log = path.with_suffix('.log').open('x')
child = subprocess.Popen([str(binary), '--mcp', '--diagnostics'], stdin=subprocess.PIPE,
                         stdout=subprocess.PIPE, stderr=log)
sequence = 0
buffer = b''
session = None

def rpc(method, params, notification=False):
    global sequence, buffer
    sequence += 1
    message = {'jsonrpc': '2.0', 'method': method, 'params': params}
    if not notification:
        message['id'] = sequence
    child.stdin.write(json.dumps(message).encode() + b'\n')
    child.stdin.flush()
    if notification:
        return None
    deadline = time.monotonic() + 15
    while b'\n' not in buffer:
        remaining = deadline - time.monotonic()
        if remaining <= 0 or not select.select([child.stdout], [], [], remaining)[0]:
            raise RuntimeError('RPC_TIMEOUT')
        chunk = os.read(child.stdout.fileno(), 65536)
        if not chunk:
            raise RuntimeError('RPC_EOF')
        buffer += chunk
    line, buffer = buffer.split(b'\n', 1)
    reply = json.loads(line)
    if reply.get('id') != sequence or 'error' in reply:
        raise RuntimeError('RPC_PROTOCOL')
    return reply['result']

def call(name, arguments=None):
    response = rpc('tools/call', {'name': name, 'arguments': arguments or {}})
    return response.get('isError', False), json.loads(response['content'][0]['text'])

def success(name, arguments=None):
    failed, value = call(name, arguments)
    if failed:
        raise RuntimeError(value.get('error', 'TOOL_FAILED'))
    return value

try:
    rpc('initialize', {'protocolVersion': '2025-11-25', 'capabilities': {},
                      'clientInfo': {'name': 'interruption-acceptance', 'version': '1'}})
    rpc('notifications/initialized', {}, True)
    session = success('session_open')
    print('AWAITING_NATIVE_APPROVAL', flush=True)
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        current = success('session_status')
        if current['state'] == 'ready':
            session = current
            break
        if current['state'] in ['cancelled', 'expired', 'paused']:
            raise RuntimeError('SESSION_ENDED_BEFORE_CAPTURE')
        time.sleep(.25)
    else:
        raise RuntimeError('APPROVAL_TIMEOUT')
    for attempt in range(20):
        failed, observation = call('desktop_observe', {'sessionId': session['id']})
        if not failed:
            break
        if observation.get('error') != 'FOCUS_CHANGED':
            raise RuntimeError(observation.get('error', 'OBSERVATION_FAILED'))
        time.sleep(.1)
    else:
        raise RuntimeError('FOCUS_CHANGED')
    targets = [e for e in observation['elements'] if e.get('identifier') == 'fixture.input']
    if len(targets) != 1:
        raise RuntimeError('TARGET_AMBIGUOUS')
    request = {'requestId': str(uuid.uuid4()), 'idempotencyKey': str(uuid.uuid4()),
               'sessionId': session['id'], 'generation': session['generation'],
               'observationId': observation['id'], 'elementId': targets[0]['id'],
               'kind': 'setValue', 'text': 'This interrupted request must be refused'}
    captured_at = time.monotonic()
    last_observation_attempt = captured_at
    print('TARGET_CAPTURED: perform ' + args.mode + ' interruption now.', flush=True)
    deadline = time.monotonic() + 120
    heartbeat = time.monotonic()
    while time.monotonic() < deadline:
        current = success('session_status')
        if args.mode == 'permission-revoke':
            permissions = success('system_capabilities')['permissions']
            if permissions.get('accessibility') is False:
                record['accessibilityGranted'] = False
                break
            if current['state'] != 'ready':
                time.sleep(.25)
                continue
        if args.mode == 'window-close':
            try:
                os.kill(observation['pid'], 0)
            except ProcessLookupError:
                record['fixtureProcessGone'] = True
                record['snapshotAgeSecondsAtClose'] = time.monotonic() - captured_at
                if record['snapshotAgeSecondsAtClose'] >= 8:
                    raise RuntimeError('SNAPSHOT_TOO_OLD_TO_ISOLATE_CLOSE')
                break
            if current['state'] != 'ready':
                time.sleep(.1)
                continue
            if time.monotonic() - last_observation_attempt >= 1:
                last_observation_attempt = time.monotonic()
                rejected, latest = call('desktop_observe', {'sessionId': session['id']})
                if not rejected:
                    latest_targets = [e for e in latest['elements'] if e.get('identifier') == 'fixture.input']
                    if latest['pid'] != observation['pid'] or len(latest_targets) != 1:
                        raise RuntimeError('FIXTURE_IDENTITY_CHANGED')
                    request['observationId'] = latest['id']
                    request['elementId'] = latest_targets[0]['id']
                    captured_at = time.monotonic()
        if current['state'] != 'ready':
            if args.mode == 'stop' and current['state'] == 'paused':
                record['intermediatePauseReason'] = current.get('pauseReason')
                time.sleep(.1)
                continue
            break
        if time.monotonic() - heartbeat >= 3:
            success('session_heartbeat', {'sessionId': session['id'], 'generation': session['generation']})
            heartbeat = time.monotonic()
        time.sleep(.1)
    else:
        raise RuntimeError('INTERRUPTION_TIMEOUT')
    record['observedState'] = current['state']
    record['pauseReason'] = current.get('pauseReason')
    expected = {'stop': ('cancelled', None), 'user-input': ('paused', 'userInput'),
                'environment': ('paused', 'environmentChanged'),
                'window-close': (current['state'], current.get('pauseReason')),
                'permission-revoke': (current['state'], current.get('pauseReason'))}[args.mode]
    if (current['state'], current.get('pauseReason')) != expected:
        raise RuntimeError('UNEXPECTED_INTERRUPTION_STATE')
    record['checks'].append('Expected native interruption state observed')
    if args.mode not in ['window-close', 'permission-revoke']:
        if current['generation'] <= session['generation']:
            raise RuntimeError('GENERATION_NOT_INVALIDATED')
        record['checks'].append('Captured generation invalidated')
    elif args.mode == 'window-close':
        record['checks'].append('Originally observed fixture process exited')
    else:
        record['checks'].append('Companion reports Accessibility permission revoked')
    failed, refusal = call('desktop_action', request)
    record['actionRefusal'] = refusal.get('error')
    if not failed or refusal.get('error') not in (['UNAUTHORIZED', 'STALE_OBSERVATION', 'CANCELLED', 'TARGET_NOT_FOUND', 'TARGET_AMBIGUOUS', 'FOCUS_CHANGED', 'PERMISSION_REQUIRED'] if args.mode in ['window-close', 'permission-revoke'] else ['UNAUTHORIZED', 'STALE_OBSERVATION', 'CANCELLED']):
        raise RuntimeError('INTERRUPTED_ACTION_NOT_REFUSED')
    record['checks'].append('Captured action refused after interruption')
    failed, refusal = call('desktop_observe', {'sessionId': session['id']})
    if not failed:
        raise RuntimeError('INTERRUPTED_OBSERVATION_NOT_REFUSED')
    record['checks'].append('Observation refused until new native authorization')
    record['status'] = 'passed'
except Exception as error:
    record['status'] = 'failed'
    record['error'] = str(error)[:160]
finally:
    if session and child.poll() is None:
        try:
            success('session_cancel', {'sessionId': session['id']})
        except Exception:
            record['cleanupCancelFailed'] = True
    child.stdin.close()
    try:
        child.wait(timeout=5)
    except subprocess.TimeoutExpired:
        child.terminate()
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
    log.close()
    record['finishedAt'] = datetime.now(timezone.utc).isoformat()
    record['childExitCode'] = child.returncode
    path.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record), flush=True)
raise SystemExit(0 if record['status'] == 'passed' else 1)
