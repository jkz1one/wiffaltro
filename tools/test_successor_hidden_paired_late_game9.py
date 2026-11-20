#!/usr/bin/env python3
"""Play the authored private Game9 in separate owned cold stages, then settle.

--fixture-stage is cp138 visit8-open; --paid-stage supplies cp121 Standard.
No prior games are replayed. Each match emits local primitive evidence
before admission. --resume-stage with --through reuses retained exact
successful stages and runs only the remaining gates.
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
from test_successor_hidden_paired_next_return_settlement import STORE
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_third_return_settlement import raw_rows
from test_successor_hidden_paired_visit6_sign import edit_span, span
from test_successor_hidden_paired_visit8_open import VISIT8
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_late_game9'
STEPS=('human','npc25','npc26','settle')
RETAINED={
    'human': ('75352b9458d46e03f3091202862f66e6e22468ca39ce55753ce882541dd2aa23',VISIT8[0]),
    'npc25': ('abddc7845f4599879f9e4ededde297fe278a8e4d2c3edbca3b1f041a4aeee377',
              '75352b9458d46e03f3091202862f66e6e22468ca39ce55753ce882541dd2aa23'),
    'npc26': ('1146b4920e9383acbe11b89fa0f760f091f5ece6c306b1a0844f8a985e0c8dbe',
              'abddc7845f4599879f9e4ededde297fe278a8e4d2c3edbca3b1f041a4aeee377'),
    'settle': ('039e5fbf11d23b9d927537bea8bad52a165a7bb64083b7ab6097399a6b61c5aa',
               '1146b4920e9383acbe11b89fa0f760f091f5ece6c306b1a0844f8a985e0c8dbe'),
}
NATIVE={
    'human': 'c2cbe3db380cbe3ececa531ab0cd5f473a917cc302ebed763d338f084297b936',
    'npc25': '3420e0c34dc5e2a3ad450ccabe152ea518f2a05af2cadccad0be860ffef15340',
    'npc26': 'eb4d1209aecaff87ce02f3c1cf7343ffecd1413b3b4b60083f08f8f3a2c00f5c',
}
BUDGET={'startup':30,'cold':345,'launch':395,'physics':240,'capture':115,
        'admission':395,'candidate':395,'paid':285,'retry':45}
MARKERS={'human':['cold','launch','physics','capture','admission','retry'],
         'npc25':['cold','launch','physics','admission','retry'],
         'npc26':['cold','launch','physics','admission','retry'],
         'settle':['cold','candidate','paid','retry']}


def run(project,home,mode,godot):
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=1350,
           stages=MARKERS.get(mode,['cold']))


def verify_added(earlier,later,step):
    assert later[1]==earlier[0]
    print('DURABLE GAME9',step,hashlib.sha256(later[0]).hexdigest(),flush=True)
    before,after=(data.decode() for data in (earlier[0],later[0]))
    earlier,later=(json.loads(data) for data in (before,after))
    assert {k:v for k,v in earlier.items() if k!='ordinary'}=={k:v for k,v in later.items() if k!='ordinary'}
    a,b=(data['ordinary'] for data in (earlier,later))
    pending=['ordinary','physical','pending']
    if step=='human':
        human=b['physical']['pending']['human']
        assert human[0]==24 and human[3]['player.dakota_wells']['pa']>0 and 'player.val_morgan' not in human[3]
        assert b['physical']['pending']['reports']==[]
        assert edit_span(after,pending,'{}')==before
    elif step.startswith('npc'):
        job=int(step[3:])
        path=pending+['reports']
        assert [row['fixture'] for row in b['physical']['pending']['reports']]==list(range(25,job+1))
        older=raw_rows(before,path)
        assert raw_rows(after,path)[:-1]==older
        assert edit_span(after,path,'['+','.join(older)+']')==before
    else:
        assert a['state']['round_index']==8 and b['state']['round_index']==9
        assert b['physical']['pending']=={} and b['build']['build']['_visit']['number']==9
        assert b['build']['build']['_visit']['open'] is False and 'recruit' not in b['build']['build']['_visit']
        assert a['physical']['pending']['human'][3]==b['state']['player_results'][-1]['performance']
        path=['ordinary','physical','reports']
        assert raw_rows(after,path)==raw_rows(before,path)+raw_rows(before,pending+['reports'])
        for name in ('results','player_results'):
            path=['ordinary','state',name]
            old=raw_rows(before,path)
            assert raw_rows(after,path)[:len(old)]==old
        for club in range(6):
            path=['ordinary','build'] if club==0 else ['ordinary','opponents','clubs',str(club),'build']
            for section in ('build','book','bank'):
                old=raw_rows(before,path+[section,'_events'])
                assert raw_rows(after,path+[section,'_events'])[:len(old)]==old
        paths=[['ordinary','build','book','_players'],['ordinary','build','build','_contracts'],
               ['ordinary','build','build','_recruits'],['ordinary','build','build','_roster']]
        paths.extend(['ordinary','build','build','_game_rosters',key] for key in a['build']['build']['_game_rosters'])
        for path in paths:
            lo,hi=span(before,path)
            start,end=span(after,path)
            assert before[lo:hi]==after[start:end]
    return b


def evidence_file(path,step):
    if step=='human':
        return path.parent/'fixture24-human-capture.local'
    if step.startswith('npc'):
        return path.parent/f'{step}-runner-report.local'
    return None


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--resume-stage',type=Path)
    parser.add_argument('--through',choices=STEPS)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    if bool(args.resume_stage)!=bool(args.through):
        parser.error('resume requires both --resume-stage and --through')
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'visit8-open'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    source=verify_fixture(slot_pair(origin),VISIT8)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-late-game9-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    store=project/STORE
    marker='\tpaired_candidate_ms=Time.get_ticks_msec()-started'
    store.write_text(once(store.read_text(),marker,marker+
        '\n\tif leg==8 and current!=null: print("CP127_STAGE paid")'))
    dependencies=(TEST,'successor_hidden_paired_visit8_open','successor_hidden_paired_late_game8','successor_hidden_paired_visit7_open','successor_hidden_paired_fourth_first_settlement',
                  'successor_hidden_paired_fourth_first_npcs','successor_hidden_paired_fourth_first',
                  'successor_hidden_paired_visit6_sign','successor_hidden_paired_visit6_open',
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
    current=source
    evidence=[]
    for i,step in enumerate(STEPS):
        folder='game9-'+step
        reused=args.resume_stage.resolve()/folder/draft.SLOT if args.through and i<=STEPS.index(args.through) else None
        home=root/folder
        path=install(home,verify_fixture(slot_pair(reused),RETAINED[step]) if reused else current)
        if not reused:
            run(project,home,step,godot)
        durable=slot_pair(path)
        settled=verify_added(current,durable,step)
        artifact=evidence_file(reused or path,step)
        artifact_sha=hashlib.sha256(artifact.read_bytes()).hexdigest() if artifact else None
        if artifact:
            if reused:
                assert artifact_sha==NATIVE[step]
            print('G9_NATIVE_EVIDENCE',step,artifact_sha,flush=True)
        evidence.append((path,durable,reused,artifact,artifact_sha))
        current=durable
    cold=root/'paid-cold'
    cold_copy=install(cold,current)
    run(project,cold,'paid',godot)
    assert slot_pair(cold_copy)==current and not any(cold_copy.parent.glob('*.local'))
    text=current[0].decode()
    archive=['ordinary','physical','reports']
    rows=raw_rows(text,archive)
    # A real prior return key is still foreign to the new opener geometry.
    old_key=next(row['request'] for row in settled['physical']['reports'] if row['fixture']==23)
    faults={'mixed-source':once(text,settled['physical']['reports'][-1]['request'],old_key),
            'noninteger-fixture':edit_span(text,archive,'['+','.join(rows[:-1]+[edit_span(rows[-1],['fixture'],'26.5')])+']'),
            'dropped-report':edit_span(text,archive,'['+','.join(rows[:-1])+']')}
    for name,changed in faults.items():
        case=root/('tamper-'+name)
        pair=changed.encode(),current[1]
        path=install(case,pair)
        run(project,case,'tamper-'+name,godot)
        assert slot_pair(path)==pair
    ordinary=root/'standard'
    control=install(ordinary,standard)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(control)==standard
    for path,durable,reused,artifact,pin in evidence:
        assert slot_pair(path)==durable and (not reused or slot_pair(reused)==durable)
        if artifact:
            assert hashlib.sha256(artifact.read_bytes()).hexdigest()==pin
    assert slot_pair(origin)==source and slot_pair(standard_path)==standard
    print('PASS: genuine private Game9 only; historical proofs and exact paid/partial cold; next game closed')


if __name__ == '__main__':
    main()
