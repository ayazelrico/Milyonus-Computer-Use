#!/usr/bin/env python3
"""Black-box MCP tests. Never approve a native session or mutate the desktop."""
import json
import os
from pathlib import Path
import select
import subprocess
import time

root = Path(__file__).resolve().parent.parent
binary = root / 'build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse'
process = subprocess.Popen([str(binary), '--mcp'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
sequence = 0
buffer = b''
checks = []

def send(value):
    process.stdin.write(json.dumps(value).encode() + b'\n')
    process.stdin.flush()

def receive():
    global buffer
    deadline = time.monotonic() + 15
    while b'\n' not in buffer:
        remaining = deadline-time.monotonic()
        if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
            raise RuntimeError('Protocol response timeout')
        chunk = os.read(process.stdout.fileno(), 65536)
        if not chunk:
            raise RuntimeError('Unexpected EOF')
        buffer += chunk
    line, buffer = buffer.split(b'\n', 1)
    return json.loads(line)

def rpc(method, params=None):
    global sequence
    sequence += 1
    send({'jsonrpc':'2.0','id':sequence,'method':method,'params':params or {}})
    response = receive()
    assert response['id'] == sequence, response
    return response

def call(name, args=None):
    result = rpc('tools/call', {'name':name,'arguments':args or {}})['result']
    return result.get('isError',False), json.loads(result['content'][0]['text'])

def check(name, condition):
    assert condition, name
    checks.append({'name':name,'passed':True})

try:
    check('requires initialization', 'error' in rpc('tools/list'))
    initialized = rpc('initialize', {'protocolVersion':'2025-11-25','capabilities':{},'clientInfo':{'name':'smoke','version':'1'}})
    check('protocol negotiation', initialized['result']['protocolVersion'] == '2025-11-25')
    check('requires initialized notification', 'error' in rpc('tools/list'))
    send({'jsonrpc':'2.0','method':'notifications/initialized'})
    tools = rpc('tools/list')['result']['tools']
    check('no approval tool', not any('approve' in t['name'] or 'allow' in t['name'] for t in tools))
    error, capabilities = call('system_capabilities')
    check('no image egress', not error and capabilities['imageEgress'] is False)
    error, session = call('session_open')
    check('session awaits native approval', not error and session['state'] == 'awaitingApproval')
    check('heartbeat contract advertised', capabilities['heartbeatTimeoutSeconds']==15 and capabilities['heartbeatIntervalSeconds']==5)
    error, result = call('session_heartbeat', {'sessionId':session['id'],'generation':1})
    check('heartbeat cannot approve', error and result['error']=='UNAUTHORIZED')
    error, result = call('session_heartbeat', {'sessionId':session['id'],'generation':True})
    check('boolean generation rejected', error and result['error']=='INVALID_REQUEST')
    error, result = call('desktop_observe', {'sessionId':session['id']})
    check('unapproved observation rejected', error and result['error']=='UNAUTHORIZED')
    error, result = call('session_open')
    check('second session rejected', error and result['error']=='LEASE_BUSY')
    error, result = call('session_cancel', {'sessionId':'forged'})
    check('foreign session rejected', error and result['error']=='UNAUTHORIZED')
    error, result = call('session_status', {'grant':True})
    check('unexpected fields rejected', error and result['error']=='INVALID_REQUEST')
    error, result = call('session_approve')
    assert error and result['error']=='UNSUPPORTED_CAPABILITY', result
    check('invented approval tool rejected', True)
    error, result = call('session_cancel', {'sessionId':session['id']})
    check('cancellation terminal state', not error and result['state']=='cancelled')
    malformed = rpc('tools/call', {'name':'session_open','arguments':[]})
    check('array arguments rejected', malformed['result']['isError'])
    check('array params rejected', 'error' in rpc('tools/list', ['invalid']))
    check('unknown method', rpc('execute_shell')['error']['code']==-32601)
    print(json.dumps({'suite':'mcp-black-box','passed':len(checks),'failed':0,'checks':checks,'permissions':capabilities['permissions']}, indent=2))
finally:
    process.terminate()
    try: process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill(); process.wait(timeout=5)
