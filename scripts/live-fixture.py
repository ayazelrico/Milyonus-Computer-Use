#!/usr/bin/env python3
"""Live AX acceptance slice. Requires native approval; never grants itself access."""
import json
import os
from pathlib import Path
import select
import subprocess
import time
import uuid
import sys
import argparse
import hashlib
from datetime import datetime, timezone

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--native-text',action='store_true')
parser.add_argument('--native-click',action='store_true')
parser.add_argument('--heartbeat-expiry',action='store_true')
parser.add_argument('--iterations',type=int,choices=range(1,31),default=10)
options=parser.parse_args()
root = Path(__file__).resolve().parent.parent
binary = root/'build/MilyonusComputerUse.app/Contents/MacOS/MilyonusComputerUse'
diagnostics = (root/'docs/evidence/live-diagnostics.log').open('w')
process = subprocess.Popen([str(binary),'--mcp','--diagnostics'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=diagnostics)
evidence_path=root/'docs/evidence/live-fixture.json'
mode='pointer' if '--native-click' in sys.argv else 'semantic'
if '--native-text' in sys.argv: mode+='-keyboard'
if '--heartbeat-expiry' in sys.argv: mode+='-heartbeat'
mode_evidence=root/f'docs/evidence/live-fixture-{mode}.json'
def write_evidence(value):
    encoded=json.dumps(value,indent=2)+'\n'
    evidence_path.write_text(encoded)
    mode_evidence.write_text(encoded)
started=datetime.now(timezone.utc).isoformat()
binary_hash=hashlib.sha256(binary.read_bytes()).hexdigest()
write_evidence({'status':'running','startedAt':started,'binarySHA256':binary_hash})
sequence=0
buffer=b''
checks=[]
timings=[]

def rpc(method,params=None,notification=False):
    global sequence,buffer
    sequence+=1
    request={'jsonrpc':'2.0','method':method,'params':params or {}}
    if not notification: request['id']=sequence
    process.stdin.write(json.dumps(request).encode()+b'\n');process.stdin.flush()
    if notification:return
    deadline=time.monotonic()+15
    while b'\n' not in buffer:
        remaining=deadline-time.monotonic()
        if remaining<=0 or not select.select([process.stdout],[],[],remaining)[0]:raise RuntimeError('Response timeout')
        chunk=os.read(process.stdout.fileno(),65536)
        if not chunk:raise RuntimeError('Unexpected EOF')
        buffer+=chunk
    line,buffer=buffer.split(b'\n',1)
    response=json.loads(line)
    assert response['id']==sequence,response
    assert 'error' not in response,response
    return response['result']

def call(name,args=None,expected_error=None):
    result=rpc('tools/call',{'name':name,'arguments':args or {}})
    value=json.loads(result['content'][0]['text'])
    if expected_error:
        assert result['isError'] and value['error']==expected_error,(name,value)
    else:assert not result['isError'],(name,value)
    return value

def check(name,condition):
    assert condition,name
    checks.append({'name':name,'passed':True})

def target(observation,identifier):
    matches=[e for e in observation['elements'] if e.get('identifier')==identifier]
    assert len(matches)==1,(identifier,observation)
    return matches[0]

def action(observation,identifier,kind,text=None):
    value={'requestId':str(uuid.uuid4()),'sessionId':session['id'],'idempotencyKey':str(uuid.uuid4()),
           'observationId':observation['id'],'generation':session['generation'],
           'elementId':target(observation,identifier)['id'],'kind':kind}
    if text is not None:value['text']=text
    return value

try:
    rpc('initialize',{'protocolVersion':'2025-11-25','capabilities':{},'clientInfo':{'name':'live-fixture','version':'1'}})
    rpc('notifications/initialized',notification=True)
    capabilities=call('system_capabilities')
    check('AX permission granted',capabilities['permissions']['accessibility'])
    session=call('session_open')
    print('WAITING: Approve the fixture-only session in the native companion.',flush=True)
    deadline=time.monotonic()+240
    while time.monotonic()<deadline:
        session=call('session_status')
        if session['state']=='ready':break
        if session['state'] in ['cancelled','expired']:raise RuntimeError('Session ended before approval')
        time.sleep(.4)
    else:raise RuntimeError('Native approval was not received')
    # Activation is asynchronous. Retry only this read, never a mutating action.
    for attempt in range(20):
        try:
            initial_observation=call('desktop_observe',{'sessionId':session['id']})
            break
        except AssertionError as error:
            if 'FOCUS_CHANGED' not in str(error): raise
            time.sleep(.1)
    else: raise RuntimeError('Fixture did not become active after native approval')
    for iteration in range(options.iterations):
        call("session_heartbeat", {"sessionId":session["id"], "generation":session["generation"]})
        observation=call('desktop_observe',{'sessionId':session['id']})
        check(f'{iteration}: secure field excluded',not any(e.get('identifier')=='fixture.secure' for e in observation['elements']))
        check(f'{iteration}: secret absent','synthetic-secret-never-export' not in json.dumps(observation))
        text=f'Fixture {iteration}: İstanbul ıİ şğü 👩🏽‍💻 e\u0301'
        request=action(observation,'fixture.input','setValue',text)
        start=time.monotonic();result=call('desktop_action',request);timings.append((time.monotonic()-start)*1000)
        check(f'{iteration}: value independently verified',result['effect']=='applied' and result['verification']=='passed')
        duplicate=call('desktop_action',request)
        check(f'{iteration}: duplicate returns same action',duplicate['actionId']==result['actionId'])
        stale=dict(request,idempotencyKey=str(uuid.uuid4()),requestId=str(uuid.uuid4()))
        call('desktop_action',stale,expected_error='STALE_OBSERVATION')
        check(f'{iteration}: stale observation rejected',True)
        if '--native-text' in sys.argv:
            observation=call('desktop_observe',{'sessionId':session['id']})
            text = f'Native {iteration}: İstanbul şğü 👩🏽‍💻'
            native_request=action(observation,'fixture.input','setValue',text)
            native_result=call('desktop_type_text',native_request)
            check(f'{iteration}: native keyboard independently verified',native_result['effect']=='applied' and native_result['verification']=='passed')
            duplicate=call('desktop_type_text',native_request)
            check(f'{iteration}: native duplicate suppressed',duplicate['actionId']==native_result['actionId'])
            call('desktop_action',native_request,expected_error='IDEMPOTENCY_CONFLICT')
            check(f'{iteration}: execution method conflict rejected',True)
        observation=call('desktop_observe',{'sessionId':session['id']})
        request=action(observation,'fixture.save','press')
        save_tool='desktop_click' if '--native-click' in sys.argv else 'desktop_action'
        result=call(save_tool,request)
        if result['effect']!='applied' or result['verification']!='passed': print('Save result metadata:',json.dumps(result),flush=True)
        check(f'{iteration}: save independently verified',result['effect']=='applied' and result['verification']=='passed')
        duplicate=call(save_tool,request)
        check(f'{iteration}: duplicate save suppressed',duplicate['actionId']==result['actionId'])
        observation=call('desktop_observe',{'sessionId':session['id']})
        check(f'{iteration}: saved value visible',target(observation,'fixture.status')['value'].endswith(text))
    if '--heartbeat-expiry' in sys.argv:
        print('Checking silent-client lease expiry (16 seconds).', flush=True)
        call('session_heartbeat',{'sessionId':session['id'],'generation':session['generation']})
        silence_start=time.monotonic()
        while True:
            expired=call('session_status')
            elapsed=time.monotonic()-silence_start
            if expired['state']!='ready':
                check('lease did not pause early',elapsed>=14.5)
                break
            if elapsed>17:raise RuntimeError('Heartbeat lease did not expire')
            time.sleep(.25)
        check('silent client paused',expired['state']=='paused')
        check('pause caused by heartbeat expiry',expired.get('pauseReason')=='heartbeatLost')
        check('lease loss fences generation',expired['generation']==session['generation']+1)
        call('session_heartbeat',{'sessionId':session['id'],'generation':session['generation']},expected_error='UNAUTHORIZED')
        check('late heartbeat cannot revive authority',True)
    call('session_pause',{'sessionId':session['id']})
    call('desktop_observe',{'sessionId':session['id']},expected_error='UNAUTHORIZED')
    check('paused session cannot observe',True)
    call('session_cancel',{'sessionId':session['id']})
    check('cancelled terminal state',call('session_status')['state']=='cancelled')
    result={'suite':'live-fixture-native-text' if '--native-text' in sys.argv else 'live-fixture-AX-slice',
            'heartbeatExpiry':'--heartbeat-expiry' in sys.argv,'nativeClick':'--native-click' in sys.argv,'nativeText':'--native-text' in sys.argv,
            'status':'passed','startedAt':started,'completedAt':datetime.now(timezone.utc).isoformat(),
            'binarySHA256':binary_hash,'approvalSource':'external native UI; test controller may automate the authorized approval','passed':len(checks),'failed':0,'iterations':options.iterations,
            'checks':checks,'setValueRoundTripMs':timings,
            'limits':'Fixture only; native approval supplied externally. Not the full G3 matrix.'}
    write_evidence(result)
    print(f'PASS: {len(checks)} live fixture checks across {options.iterations} iterations.',flush=True)
except BaseException as error:
    write_evidence({'status':'failed','startedAt':started,
        'binarySHA256':binary_hash,'passed':len(checks),'errorType':type(error).__name__})
    raise
finally:
    process.terminate()
    try:process.wait(timeout=5)
    except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
