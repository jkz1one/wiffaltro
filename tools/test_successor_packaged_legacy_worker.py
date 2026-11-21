#!/usr/bin/env python3
"""Run an actual Linux ELF worker and independently validate one original result."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
from test_successor_schedule_wiring import environment
from build_successor_engineering_linux import EDITOR_SHA, PACK_BROAD_SHA, USER_DIR

RELEASE_ELF = '2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0'
WORKER_MARKER = 'WIFFALTRO_PACKAGED_LEGACY_WORKER_ROUTE'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def native_transport(exe, empty, env, token, folder, log, limit):
    initial = time.monotonic()
    command = [str(exe),'--headless','--fixed-fps','60','--log-file',str(folder/'worker.log'),
               '--','--physical-job='+token]

    def heartbeat():
        temp = folder/'heartbeat.json.tmp'
        temp.write_text(json.dumps({'token':token},separators=(',',':')))
        os.replace(temp,folder/'heartbeat.json')

    heartbeat()
    with log.open('xb') as output, subprocess.Popen(command,cwd=empty,env=env,stdout=output,
                                                     stderr=subprocess.STDOUT) as child:
        try:
            while child.poll() is None:
                if time.monotonic()-initial >= limit:
                    raise TimeoutError('actual worker did not complete within the bounded test window')
                heartbeat()
                time.sleep(0.5)
        finally:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
    return child.returncode


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engineering-build',type=Path,required=True)
    parser.add_argument('--prepared-save-dir',type=Path,required=True,
                        help='Isolated native-generated legacy season and original job request, never a player save')
    parser.add_argument('--godot',type=Path,required=True)
    parser.add_argument('--stage-dir',type=Path,required=True)
    o=parser.parse_args()
    repo=Path(__file__).resolve().parents[1]
    build=o.engineering_build.resolve()
    exe=build/'package/Wiffaltro.x86_64'
    pack=build/'package/Wiffaltro.pck'
    meta=json.loads((build/'result.json').read_bytes())
    assert sha(exe.read_bytes()) == meta['elf'] == RELEASE_ELF
    assert sha(pack.read_bytes()) == meta['pck'] and meta['pack_broad_sha256'] == PACK_BROAD_SHA
    editor=o.godot.resolve()
    assert sha(editor.read_bytes()) == EDITOR_SHA
    initial=o.prepared_save_dir.resolve()
    generated=json.loads((initial/'generated.json').read_bytes())
    token=generated['token']
    assert re.fullmatch('[0-9a-f]{32}',token)
    original=(initial/'season-v1.json').read_bytes()
    backup=(initial/'season-v1.json.bak').read_bytes()
    request=(initial/'physical-jobs'/token/'request.json').read_bytes()
    assert sha(original) == generated['source_sha256'] and sha(request) == generated['request_sha256']
    packet=json.loads(request)
    assert packet['token']==token and packet['fixture']==generated['fixture']
    root=o.stage_dir.resolve()
    root.mkdir(mode=0o700)
    empty=root/'empty'; empty.mkdir()
    positive=environment(root/'positive')
    negative=environment(root/'negative')
    slot=Path(positive['XDG_DATA_HOME'])/USER_DIR
    (slot/'physical-jobs'/token).mkdir(parents=True)
    folder=slot/'physical-jobs'/token
    (slot/'season-v1.json').write_bytes(original)
    (slot/'season-v1.json.bak').write_bytes(backup)
    (folder/'request.json').write_bytes(request)
    neg_token='a'*32 if token != 'a'*32 else 'b'*32
    empty_job=Path(negative['XDG_DATA_HOME'])/USER_DIR/'physical-jobs'/neg_token
    empty_job.mkdir(parents=True)
    no_gate=negative.copy(); no_gate.pop('WIFFALTRO_DYNASTY_ENGINEERING',None)
    assert native_transport(exe,empty,no_gate,neg_token,empty_job,root/'ungated.log',25)==2
    assert not (empty_job/'response.json').exists()
    assert native_transport(exe,empty,negative,neg_token,empty_job,root/'missing-request.log',25)==1
    assert WORKER_MARKER in (root/'missing-request.log').read_text()
    assert json.loads((empty_job/'response.json').read_text()) == {'error':'Physical job checkpoint is invalid.'}
    if native_transport(exe,empty,positive,token,folder,root/'actual-worker.log',360) != 0:
        raise RuntimeError('actual ELF did not return a successful worker transport; retain request and diagnostics')
    assert WORKER_MARKER in (root/'actual-worker.log').read_text()
    reply=folder/'response.json'
    data=json.loads(reply.read_bytes())
    assert set(data)=={'version','token','request','fixture','report'}
    assert data['version']==1 and data['token']==token and data['request']==packet['request'] and data['fixture']==packet['fixture']
    status=json.loads((folder/'status.json').read_bytes())
    assert status['token']==token and 'inning' in status
    external=root/'audit.gd'
    external.write_bytes((repo/'tests/successor_packaged_legacy_worker_audit.gd.txt').read_bytes())
    with (root/'validate.log').open('xb') as output:
        result=subprocess.run([str(editor),'--headless','--audio-driver','Dummy','--path',str(empty),
            '--main-pack',str(pack),'--script',str(external),'--',str(folder/'request.json'),str(reply)],
            cwd=empty,env=positive,stdout=output,stderr=subprocess.STDOUT,timeout=240)
    valid=(root/'validate.log').read_text()
    assert result.returncode==0 and 'SCRIPT ERROR' not in valid and 'ACTUAL_ELF_LEGACY_REPORT_VALIDATED' in valid
    assert (slot/'season-v1.json').read_bytes()==original and (slot/'season-v1.json.bak').read_bytes()==backup
    assert (folder/'request.json').read_bytes()==request and (initial/'season-v1.json').read_bytes()==original
    print('PASS: exact real ELF legacy worker report, original native validator and unchanged source slots.')
    print('Report SHA-256',sha(reply.read_bytes()))


if __name__ == '__main__':
    main()
