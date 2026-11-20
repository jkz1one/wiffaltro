#!/usr/bin/env python3
"""Play the authored private Game8 in separate owned cold stages, then settle.

--fixture-stage is cp136 visit7-open; --paid-stage supplies cp121 Standard.
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
from test_successor_hidden_paired_visit7_open import VISIT7
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_late_game8'
STEPS=('human','npc22','npc23','settle')
RETAINED={
    'human': ('20b6e9b0491b26daeed714e393644812afb4ba37abba19fbc6dd4163b8740ba2',VISIT7[0]),
    'npc22': ('8e682a92865cd7ac44d5e6d22e755ce1f02766d79b061d2e02988d0b7d330bed',
              '20b6e9b0491b26daeed714e393644812afb4ba37abba19fbc6dd4163b8740ba2'),
    'npc23': ('b501def4b70530d4ebbaa3c232e040fc99ab96e7d63965314659de267bcfe85d',
              '8e682a92865cd7ac44d5e6d22e755ce1f02766d79b061d2e02988d0b7d330bed'),
    'settle': ('ab179707fd6cca105bb190c804fc798fb86aff81b63788777184c2c6c3895655',
               'b501def4b70530d4ebbaa3c232e040fc99ab96e7d63965314659de267bcfe85d'),
}
NATIVE={
    'human': '266b83b2c236687162433dc8aa4c8f3ff0102055f0d6024c35fd0a7a07b337e1',
    'npc22': '54cf66b6761056563eb7e0ce878d8baed390cfc60c8d43a827511ddb429eced9',
    'npc23': 'e074af8d801b711c5b1661c2b0219c0933b4fbcd9078ae8ed1ba753c25cb7769',
}
BUDGET={'startup':30,'cold':270,'launch':280,'physics':220,'capture':100,
        'admission':280,'candidate':280,'paid':245,'retry':45}
MARKERS={'human':['cold','launch','physics','capture','admission','retry'],
         'npc22':['cold','launch','physics','admission','retry'],
         'npc23':['cold','launch','physics','admission','retry'],
         'settle':['cold','candidate','paid','retry']}


def run(project,home,mode,godot):
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=1050,
           stages=MARKERS.get(mode,['cold']))


def verify_added(earlier,later,step):
    assert later[1]==earlier[0]
    print('DURABLE GAME8',step,hashlib.sha256(later[0]).hexdigest(),flush=True)
    before,after=(data.decode() for data in (earlier[0],later[0]))
    earlier,later=(json.loads(data) for data in (before,after))
    assert {k:v for k,v in earlier.items() if k!='ordinary'}=={k:v for k,v in later.items() if k!='ordinary'}
    a,b=(data['ordinary'] for data in (earlier,later))
    pending=['ordinary','physical','pending']
    if step=='human':
        human=b['physical']['pending']['human']
        assert human[0]==21 and human[3]['player.dakota_wells']['pa']>0 and 'player.val_morgan' not in human[3]
        assert b['physical']['pending']['reports']==[]
        assert edit_span(after,pending,'{}')==before
    elif step.startswith('npc'):
        job=int(step[3:])
        path=pending+['reports']
        assert [row['fixture'] for row in b['physical']['pending']['reports']]==list(range(22,job+1))
        older=raw_rows(before,path)
        assert raw_rows(after,path)[:-1]==older
        assert edit_span(after,path,'['+','.join(older)+']')==before
    else:
        assert a['state']['round_index']==7 and b['state']['round_index']==8
        assert b['physical']['pending']=={} and b['build']['build']['_visit']['number']==8
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
        return path.parent/'fixture21-human-capture.local'
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
    origin=args.fixture_stage.resolve()/'visit7-open'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    source=verify_fixture(slot_pair(origin),VISIT7)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-late-game8-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    store=project/STORE
    marker='\tpaired_candidate_ms=Time.get_ticks_msec()-started'
    store.write_text(once(store.read_text(),marker,marker+
        '\n\tif leg==7 and current!=null: print("CP127_STAGE paid")'))
    dependencies=(TEST,'successor_hidden_paired_visit7_open','successor_hidden_paired_fourth_first_settlement',
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
        folder='game8-'+step
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
            print('G8_NATIVE_EVIDENCE',step,artifact_sha,flush=True)
        evidence.append((path,durable,reused,artifact,artifact_sha))
        current=durable
    cold=root/'paid-cold'
    cold_copy=install(cold,current)
    run(project,cold,'paid',godot)
    assert slot_pair(cold_copy)==current and not any(cold_copy.parent.glob('*.local'))
    text=current[0].decode()
    archive=['ordinary','physical','reports']
    rows=raw_rows(text,archive)
    faults={'return-key':once(text,settled['physical']['reports'][-1]['request'],'0'*64),
            'dropped-return':edit_span(text,archive,'['+','.join(rows[:-1])+']')}
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
    print('PASS: genuine private Game8 only; historical proofs and exact paid/partial cold; next game closed')


if __name__ == '__main__':
    main()
