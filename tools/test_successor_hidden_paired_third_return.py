#!/usr/bin/env python3
"""Play or verify only private third-pair return human15. NPCs remain barred.

Obtain --fixture-stage at cp125 with the third-first settlement reproducer.
Provide cp121 --paid-stage for its pinned admitted Standard cold control.
--completed-stage reopens the exact previously played fixture15 without
a game rerun. All synthetic files and logs are kept in disposable local
directories; source inputs are never changed.
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
from test_successor_hidden_paired_next_first_npcs import raw_value
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_third_return'
START = ('c84a3048d200278193a781968212e2a55e8489058dc401b4c5b309991412dd6f',
         '08ce00cf4ba915c62bbfbba90c3838663dc7035bc1cfd54b2c174cc0e90de204')
HUMAN15 = ('13b1493cfd048d512ba13b3534c6531c90d678248dae679a5a7688a1d0a6e1a4', START[0])


def run(project,home,mode,godot):
    out = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                   'res://tests/'+TEST+'.tscn','--',mode],environment(home),600)
    assert 'HIDDEN_PAIRED_THIRD_RETURN_PASS' in out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    origin = args.fixture_stage.resolve()/'third-first-settlement'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    start = verify_fixture(slot_pair(origin),START)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-third-return-human-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    for name in (TEST,'successor_hidden_paired_third_first_settlement','successor_hidden_paired_third_first',
                 'successor_hidden_paired_next_return_settlement','successor_hidden_paired_next_return',
                 'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                 'successor_hidden_paired_return_settlement','successor_hidden_paired_return',
                 'successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'third-return'
    completed = args.completed_stage.resolve()/'third-return'/draft.SLOT if args.completed_stage else None
    primary = install(home,verify_fixture(slot_pair(completed),HUMAN15) if completed else start)
    if not completed:
        run(project,home,'human',godot)
    durable = slot_pair(primary)
    assert durable[1]==start[0]
    print('DURABLE HUMAN15',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    marker = '"pending":'
    text = durable[0].decode()
    value, raw = raw_value(text,marker)
    assert value['human'][0]==15 and value['reports']==[]
    assert once(text,marker+raw,marker+'{}').encode()==start[0]
    run(project,home,'cold',godot)
    assert slot_pair(primary)==durable
    foreign = json.loads(start[0])['ordinary']['physical']['reports'][-1]
    foreign['fixture']=16
    faults = {
        'human-start':once(text,value['binding']['request'],'0'*64),
        'unqualified-npc':once(text,marker+raw,marker+once(raw,'"reports":[]',
                            '"reports":['+json.dumps(foreign,separators=(',',':'))+']')),
    }
    for fault, corruption in faults.items():
        target=root/('tamper-'+fault)
        pair=corruption.encode(),durable[1]
        path=install(target,pair)
        run(project,target,'tamper-'+fault,godot)
        assert slot_pair(path)==pair
    ordinary = root/'standard'
    ordinary_path = install(ordinary,standard)
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                   '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(ordinary_path)==standard
    assert slot_pair(origin)==start and slot_pair(standard_path)==standard
    if completed:
        assert slot_pair(completed)==durable
    print('PASS: real fixture15 exact own debt and Mika, unchanged paid history, NPC/payout closed, Standard exact')


if __name__ == '__main__':
    main()
