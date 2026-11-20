#!/usr/bin/env python3
"""Private NPC semifinal #31 only; source-stamped, independently resumable.

Use the same empty --stage-root for the first capture and subsequent
--only stages. Never use a real save slot. An interruption after a native
capture must resume from the original bytes with --resume-capture-sha.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_late_game10_pending import TEST as PENDING_TEST
from test_successor_hidden_paired_late_game10_settlement import PAID, TEST as SETTLED_TEST
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_visit6_sign import edit_span
from test_successor_hidden_paired_third_return_settlement import raw_rows
from test_successor_paired_resolver_context import once
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_semifinal_npc'
HUMAN_TEST='successor_hidden_paired_semifinal_human'
HUMAN=('77be0f3bf22ae002ded1aeeed74b4118e516940414d8d676910cccfc83aaa994',PAID[0])
CASES=('capture','admit','complete','request','wrong-game','standard')
BUDGET={'startup':35,'cold':420,'launch':420,'physics':240,'capture':120,'admission':460,'retry':70}
PATH=['ordinary','physical','pending','reports']


def digest(value):
    return hashlib.sha256(value).hexdigest()


def same_or_record(path,value):
    line=json.dumps(value,sort_keys=True)+'\n'
    if path.exists():
        assert path.read_text()==line, path.name
    else:
        tmp=path.with_suffix('.tmp')
        tmp.write_text(line)
        tmp.replace(path)


def run(project,home,mode,godot):
    markers={'capture':['cold','launch','physics','capture'],'admit':['cold','admission','retry']}
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=1450,
           stages=markers.get(mode,['cold']))


def source_stamp(repo):
    paths=(
        'drafts/successor-live-play-v1/DRAFT_MANIFEST.json',
        'drafts/successor-dynasty-owner-v1/DRAFT_MANIFEST.json',
        'drafts/successor-settled-workload-v1/DRAFT_MANIFEST.json',
        'drafts/successor-league-general-v2/DRAFT_MANIFEST.json',
        'drafts/successor-request-composition-v1/DRAFT_MANIFEST.json',
        'tests/'+TEST+'.gd.txt','tests/'+HUMAN_TEST+'.gd.txt','tests/'+PENDING_TEST+'.gd.txt','tests/'+SETTLED_TEST+'.gd.txt',
    )
    parent=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
    return {'base':parent,'files':{name:digest((repo/name).read_bytes()) for name in paths}}


def verify_pending(source,durable):
    assert durable[1]==source[0]
    text=durable[0].decode()
    ordinary=json.loads(text)['ordinary']
    pending=ordinary['physical']['pending']
    assert pending['human'][0]==30 and pending['human'][1:3]==[8,2]
    assert [row['fixture'] for row in pending['reports']]==[31]
    # Removing exactly the appended native report restores every earlier byte.
    assert edit_span(text,PATH,'[]').encode()==source[0]
    return pending['reports'][0],ordinary['physical']['reports']


def report_raw(text):
    return raw_rows(text,PATH)[0]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',type=Path,required=True)
    parser.add_argument('--paid-stage',type=Path,required=True)
    parser.add_argument('--stage-root',type=Path,required=True)
    parser.add_argument('--only',choices=CASES,nargs='+')
    parser.add_argument('--resume-capture-sha')
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    cases=args.only or CASES
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    repo=Path(__file__).resolve().parents[1]
    origin=args.fixture_stage.resolve()/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    source=verify_fixture(slot_pair(origin),HUMAN)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    root=args.stage_root.resolve()
    root.mkdir(parents=True,exist_ok=True)
    stamp=source_stamp(repo)
    same_or_record(root/'source.json',stamp)
    print('Exact retained stage:',root,flush=True)
    project=draft.stage(repo,Path(tempfile.mkdtemp(prefix='engine-',dir=root)),
                        (repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    physical=project/'src/gameplay/season/successor_live_play_v1/physical_fixtures.gd'
    marker='func resolve(season: SeasonState, fixture: Dictionary) -> Dictionary:'
    # Test-only tripwire: a correct run never executes this branch.
    physical.write_text(once(physical.read_text(),marker,marker+
        '\n\tif int(fixture.get("id",-1))==32: push_error("Unexpected native #32 resolver invocation")'))
    dependencies=(TEST,HUMAN_TEST,SETTLED_TEST,PENDING_TEST,'successor_hidden_paired_visit9_open','successor_hidden_paired_late_game9',
                  'successor_hidden_paired_visit8_open','successor_hidden_paired_late_game8','successor_hidden_paired_visit7_open',
                  'successor_hidden_paired_fourth_first_settlement','successor_hidden_paired_fourth_first_npcs',
                  'successor_hidden_paired_fourth_first','successor_hidden_paired_visit6_sign','successor_hidden_paired_visit6_open',
                  'successor_hidden_paired_third_return_settlement','successor_hidden_paired_third_return',
                  'successor_hidden_paired_third_first_settlement','successor_hidden_paired_third_first',
                  'successor_hidden_paired_next_return_settlement','successor_hidden_paired_next_return',
                  'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                  'successor_hidden_paired_return_settlement','successor_hidden_paired_return','successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')

    played=root/'capture'
    capture_path=played/draft.SLOT
    evidence=capture_path.parent/'fixture31-npc-report.local'
    if 'capture' in cases and not (root/'capture-pass.json').exists() and not evidence.exists():
        assert not capture_path.exists(), 'prior capture interrupted; inspect its isolated logs first'
        install(played,source)
        run(project,played,'capture',godot)
        assert slot_pair(capture_path)==source
        same_or_record(root/'capture-pass.json',{'sha256':digest(evidence.read_bytes())})
    assert slot_pair(capture_path)==source
    captured=evidence.read_bytes()
    capture_pin=digest(captured)
    if not (root/'capture-pass.json').exists():
        assert args.resume_capture_sha==capture_pin, 'exact interrupted after-capture SHA required'
    else:
        same_or_record(root/'capture-pass.json',{'sha256':capture_pin})
    print('NATIVE NPC31 CAPTURE',capture_pin,flush=True)
    if all(x=='capture' for x in cases):
        return
    # Each attempt gets a fresh immutable source copy; no capture is replayed.
    if 'admit' in cases and not (root/'admit-pass.json').exists():
        home=Path(tempfile.mkdtemp(prefix='admit-',dir=root))
        path=install(home,source)
        (path.parent/evidence.name).write_bytes(captured)
        os.environ['WIFFALTRO_FIXTURE31_CAPTURE']=capture_pin
        run(project,home,'admit',godot)
        assert (path.parent/evidence.name).read_bytes()==captured
        durable=slot_pair(path)
        verify_pending(source,durable)
        same_or_record(root/'admit-pass.json',{'directory':home.name,'sha256':list(map(digest,durable))})
    saved=json.loads((root/'admit-pass.json').read_text())
    durable=verify_fixture(slot_pair(root/saved['directory']/draft.SLOT),tuple(saved['sha256']))
    report,archive=verify_pending(source,durable)
    print('DURABLE NPC31 PENDING',digest(durable[0]),flush=True)
    text=durable[0].decode()
    # Replace only the real archived request digest, not the report body.
    borrowed=next(row['request'] for row in archive if row['fixture']==29)
    faults={'request':edit_span(text,PATH,'['+report_raw(text).replace(report['request'],borrowed,1)+']'),
            'wrong-game':edit_span(text,PATH,'['+edit_span(report_raw(text),['fixture'],'32')+']')}
    for mode in ('complete','request','wrong-game','standard'):
        if mode not in cases:
            continue
        record=root/(mode+'-pass.json')
        example=standard if mode=='standard' else (faults[mode].encode(),durable[1]) if mode in faults else durable
        outcome={'sha256':list(map(digest,example))}
        if not record.exists():
            home=Path(tempfile.mkdtemp(prefix=mode+'-',dir=root))
            path=install(home,example)
            if mode=='standard':
                out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                             '--','cold','standard'],environment(home),180)
                assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out
            else:
                run(project,home,mode if mode=='complete' else 'tamper-'+mode,godot)
            assert slot_pair(path)==example
        same_or_record(record,outcome)
    assert slot_pair(origin)==source and slot_pair(capture_path)==source and evidence.read_bytes()==captured
    assert slot_pair(standard_path)==standard
    print('PASS: selected #31 checks only:', ', '.join(cases))


if __name__=='__main__':
    main()
