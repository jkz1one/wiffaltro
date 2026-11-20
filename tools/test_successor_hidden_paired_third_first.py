#!/usr/bin/env python3
"""Play only the private third-pair opening human from a pinned paid round4.

Use the cp121 paid settlement stage (with its Standard control) and the
retained complete pending stages from cp113, cp118, cp120. These older
boundaries are reopened but no earlier match is replayed. All data stays local.
--completed-stage checks the exact recorded fixture12 output without another game.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_first_npcs import COMPLETE as LEGACY2
from test_successor_hidden_paired_next_return_settlement import PENDING as LEGACY3
from test_successor_hidden_paired_return_npcs import COMPLETE, PARTIAL
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_third_first'
PAID = ('1d411717213a736f101dad5b28a06da9151a7dfaaeff16144484ff6032706acc', LEGACY3[0])
COMPLETE12 = ('771073bd0837eff84a5f9126d46a3d6fea50c51e71915d0f224747c54ac9a5f9', PAID[0])


def run(project,home,mode,godot):
    out = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                   'res://tests/'+TEST+'.tscn','--',mode],environment(home),480)
    assert 'HIDDEN_PAIRED_THIRD_FIRST_PASS' in out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--legacy-return-stage',required=True,type=Path)
    parser.add_argument('--legacy-next-first-stage',required=True,type=Path)
    parser.add_argument('--legacy-next-return-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    versions = (
        (1,args.legacy_return_stage.resolve()/'return-npcs'/draft.SLOT,(COMPLETE,PARTIAL)),
        (2,args.legacy_next_first_stage.resolve()/'next-first-npcs'/draft.SLOT,LEGACY2),
        (3,args.legacy_next_return_stage.resolve()/'next-return'/draft.SLOT,LEGACY3),
    )
    fixtures = [(str(rank),path,verify_fixture(slot_pair(path),digest)) for rank,path,digest in versions]
    origin = args.paid_stage.resolve()/'next-return-settlement'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    starter = verify_fixture(slot_pair(origin),PAID)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-third-first-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    for name in (TEST,'successor_hidden_paired_next_return_settlement','successor_hidden_paired_next_return',
                 'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                 'successor_hidden_paired_return_settlement','successor_hidden_paired_return',
                 'successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'third-human'
    completed = args.completed_stage.resolve()/'third-human'/draft.SLOT if args.completed_stage else None
    if completed is None:
        for rank,original,pair in fixtures:
            legacy = root/('legacy'+rank)
            path = install(legacy,pair)
            run(project,legacy,'legacy'+rank,godot)
            assert slot_pair(path)==slot_pair(original)==pair
        primary = install(home,starter)
        run(project,home,'play',godot)
        durable = slot_pair(primary)
    else:
        durable = verify_fixture(slot_pair(completed),COMPLETE12)
        primary = install(home,durable)
    assert durable[1]==starter[0]
    print('DURABLE UNPAID FIXTURE12 SHA256=',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    frame = json.loads(durable[0])['ordinary']['physical']['pending']
    assert frame['human'][0]==12 and frame['reports']==[] and frame['binding']['version']==1
    text = durable[0].decode()
    marker = '"pending":'
    at = text.index(marker+'{"binding":')+len(marker)
    _, end = json.JSONDecoder().raw_decode(text,at)
    assert (text[:at]+'{}'+text[end:]).encode()==starter[0]
    run(project,home,'cold',godot)
    assert slot_pair(primary)==durable
    for fault, key in [('new-start',frame['binding']['request']),
                       ('old-archive',json.loads(starter[0])['ordinary']['physical']['reports'][-1]['request'])]:
        case = root/('tamper-'+fault)
        pair = once(text,'"request":"'+key+'"','"request":"'+'0'*64+'"').encode(),durable[1]
        path = install(case,pair)
        run(project,case,'tamper-'+fault,godot)
        assert slot_pair(path)==pair
    ordinary = root/'standard'
    path = install(ordinary,standard)
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                   '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(path)==standard
    assert slot_pair(origin)==starter and slot_pair(standard_path)==standard
    assert all(slot_pair(original)==pair for _,original,pair in fixtures)
    if completed is not None:
        assert slot_pair(completed)==durable
    print('PASS: authored older requests, actual fixture12 fresh stamina + exact Mika, byte-exact held/cold and Standard')


if __name__ == '__main__':
    main()
