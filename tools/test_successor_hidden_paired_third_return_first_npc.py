#!/usr/bin/env python3
"""Play NPC16 only from the exact human15 output of the cp126 reproducer.

Supply that --fixture-stage and the cp121 --paid-stage for Standard.
One launch, independent cold after its write, two targeted negatives.
A stage timeout is fatal and never relaunches. --completed-stage runs
only cold checks on the exact pinned durable output already played. The callback saves the native
report/request/owner binding in disposable local scratch before admission.
"""
import argparse
import hashlib
from pathlib import Path
import os
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_first_npcs import raw_value
from test_successor_hidden_paired_third_return import HUMAN15
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_third_return_first_npc'
BUDGET = {'startup':30, 'cold':180, 'launch':210, 'physics':180, 'admission':210, 'retry':30}
OUTER = 800
NPC16 = ('a9eac8d14d29f5e89444b46c4714e1f0e87883d6568707f6f717e32e746e15d9', HUMAN15[0])
RUNNER_EVIDENCE = '30215c9a2ca00893476bf3900c864ab43769e9fcca06975e629eee6e9e07c337'


def native(project, home, mode, godot):
    command = [godot,'--headless','--fixed-fps','60','--path',str(project),
               'res://tests/'+TEST+'.tscn','--',mode]
    process = subprocess.Popen(command, env=environment(home), stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout,selectors.EVENT_READ)
    begun = stage_started = time.monotonic()
    phase = 'startup'
    phases = []
    parts = []
    pending = b''
    try:
        while True:
            remaining = min(stage_started+BUDGET[phase],begun+OUTER)-time.monotonic()
            if remaining <= 0:
                raise RuntimeError(f'{mode}: stage {phase} timed out, completed markers {phases}; not rerunning')
            if not selector.select(remaining):
                continue
            chunk = os.read(process.stdout.fileno(),65536)
            if not chunk:
                break
            pending += chunk
            while b'\n' in pending:
                line,pending=pending.split(b'\n',1)
                value=line.decode(errors='replace')
                print(value,flush=True)
                parts.append(value)
                if value.startswith('CP127_STAGE '):
                    _, phase, *_ = value.split()
                    assert phase in BUDGET and phase not in phases
                    phases.append(phase)
                    stage_started=time.monotonic()
        assert process.wait(timeout=5)==0 and 'CP127_PASS' in parts
        assert not any('ERROR:' in row or row.startswith('CP127_RUNNER_FAILED') for row in parts)
        expected=['cold','launch','physics','admission','retry'] if mode=='play' else ['cold']
        assert phases==expected
    finally:
        selector.close()
        if process.poll() is None:
            os.killpg(process.pid,signal.SIGTERM)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL)
                process.wait()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    godot=shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'third-return'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    starter=verify_fixture(slot_pair(origin),HUMAN15)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-third-return-npc16-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    dependencies=(TEST,'successor_hidden_paired_third_return','successor_hidden_paired_third_first_settlement',
                  'successor_hidden_paired_third_first','successor_hidden_paired_next_return_settlement',
                  'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                  'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                  'successor_hidden_paired_return','successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home=root/'third-return-npc16'
    completed=args.completed_stage.resolve()/'third-return-npc16'/draft.SLOT if args.completed_stage else None
    primary=install(home,verify_fixture(slot_pair(completed),NPC16) if completed else starter)
    if not completed:
        native(project,home,'play',godot)
    durable=slot_pair(primary)
    assert durable[1]==starter[0]
    print('DURABLE NPC16',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    report_path=(completed or primary).parent/'npc16-runner-report.local'
    assert report_path.is_file()
    report_hash=hashlib.sha256(report_path.read_bytes()).hexdigest()
    if completed:
        assert report_hash==RUNNER_EVIDENCE
    text=durable[0].decode()
    marker='"pending":'
    value,raw=raw_value(text,marker)
    _, reports=raw_value(raw,'"reports":')
    assert [row['fixture'] for row in value['reports']]==[16]
    assert once(text,marker+raw,marker+once(raw,'"reports":'+reports,'"reports":[]')).encode()==starter[0]
    cold=root/'cold'
    cold_path=install(cold,durable)
    native(project,cold,'cold',godot)
    assert slot_pair(cold_path)==durable and not (cold_path.parent/report_path.name).exists()
    faults={
        'request':once(text,value['reports'][0]['request'],'0'*64),
        'fixture17':once(text,marker+raw,marker+once(raw,reports,reports.replace('"fixture":16','"fixture":17',1))),
    }
    for name, changed in faults.items():
        target=root/('tamper-'+name)
        corrupt=changed.encode(),durable[1]
        path=install(target,corrupt)
        native(project,target,'tamper-'+name,godot)
        assert slot_pair(path)==corrupt
    ordinary=root/'standard'
    ordinary_path=install(ordinary,standard)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(ordinary_path)==standard
    assert slot_pair(origin)==starter and slot_pair(standard_path)==standard and slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    assert hashlib.sha256(report_path.read_bytes()).hexdigest()==report_hash
    print('PASS: real private NPC16 only, own carried debt, held retry, independent cold, no payout, Standard exact')


if __name__=='__main__':
    main()
