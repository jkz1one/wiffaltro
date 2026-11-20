#!/usr/bin/env python3
"""Play exactly private human fixture18 from cp132's signed visit6 stage.

Use --fixture-stage from the signed visit6 reproducer and --paid-stage from
cp121 for the Standard control. --completed-stage skips all game simulation
and checks exact previously retained output. No evidence is exported.
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
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_visit6_sign import OPEN, SIGNED, edit_span, old_human_roster_tamper, span
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_fourth_first'
COMPLETE18=('e4358977d6a12a7551f7657e71fc8646376ed6f4fd14d3db18a95a48d32d5b2c',SIGNED[0])
BUDGET={'startup':30,'cold':240,'launch':60,'physics':210,'capture':90,'admission':260,'retry':30}


def run(project,home,mode,godot):
    stages=['cold','launch','physics','capture','admission','retry'] if mode=='play' else ['cold']
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=875,stages=stages)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--unsigned-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'visit6-sign'/draft.SLOT
    unsigned_path=args.unsigned_stage.resolve()/'visit6-open'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    starter=verify_fixture(slot_pair(origin),SIGNED)
    unsigned=verify_fixture(slot_pair(unsigned_path),OPEN)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-fourth-pair-human-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    dependencies=(TEST,'successor_hidden_paired_visit6_sign','successor_hidden_paired_visit6_open',
                  'successor_hidden_paired_third_return_settlement','successor_hidden_paired_third_return',
                  'successor_hidden_paired_third_first_settlement','successor_hidden_paired_third_first',
                  'successor_hidden_paired_next_return_settlement','successor_hidden_paired_next_return',
                  'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                  'successor_hidden_paired_return_settlement','successor_hidden_paired_return',
                  'successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    completed=args.completed_stage.resolve()/'fourth-human'/draft.SLOT if args.completed_stage else None
    home=root/'fourth-human'
    primary=install(home,verify_fixture(slot_pair(completed),COMPLETE18) if completed else starter)
    if not completed:
        run(project,home,'play',godot)
    durable=slot_pair(primary)
    assert durable[1]==starter[0]
    print('DURABLE FIXTURE18',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    text=durable[0].decode()
    data=json.loads(text)
    frame=data['ordinary']['physical']['pending']
    assert frame['human'][0]==18 and frame['reports']==[] and frame['binding']['version']==1
    performance=frame['human'][3]
    assert 'player.val_morgan' not in performance and performance['player.dakota_wells']['pa']>0
    path=['ordinary','physical','pending']
    assert edit_span(text,path,'{}').encode()==starter[0]
    cold=root/'cold'
    cold_path=install(cold,durable)
    run(project,cold,'cold',godot)
    assert slot_pair(cold_path)==durable and not (cold_path.parent/'fixture18-human-capture.local').exists()
    lo,hi=span(text,[*path,'human'])
    human=text[lo:hi]
    decoder=json.JSONDecoder()
    pos=1
    for _ in range(9):
        _,end=decoder.raw_decode(human,pos)
        assert human[end]==','
        pos=end+1
    _,end=decoder.raw_decode(human,pos)
    proof=edit_span(human[pos:end],['version'],'1')
    faults={
        'start':once(text,'"request":"'+frame['binding']['request']+'"','"request":"'+'0'*64+'"'),
        'old-roster':old_human_roster_tamper(text),
        'proof':text[:lo]+human[:pos]+proof+human[end:]+text[hi:],
    }
    for name,corrupt in faults.items():
        case=root/('tamper-'+name)
        pair=corrupt.encode(),durable[1]
        cold_corrupt=install(case,pair)
        run(project,case,'tamper-'+name,godot)
        assert slot_pair(cold_corrupt)==pair
    still_unsigned=root/'unsigned'
    unsigned_cold=install(still_unsigned,unsigned)
    run(project,still_unsigned,'unsigned',godot)
    assert slot_pair(unsigned_cold)==unsigned
    ordinary=root/'standard'
    control=install(ordinary,standard)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(control)==standard
    assert slot_pair(origin)==starter and slot_pair(unsigned_path)==unsigned and slot_pair(standard_path)==standard
    assert slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    print('PASS: actual fixture18, exact Dakota/Mika and both resets, cacheless cold and sealed later routes')


if __name__ == '__main__':
    main()
