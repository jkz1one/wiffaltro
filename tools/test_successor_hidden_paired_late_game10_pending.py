#!/usr/bin/env python3
"""Play only private regular fixtures 27–29 from the exact cp140 visit9 owner.

Each native process starts from the previous durable checkpoint; no earlier
matches replay. A successful terminal projection may stage the bracket only on
its detached verification fork. No phase10 owner or settlement can be written.
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
from test_successor_hidden_paired_third_return_settlement import raw_rows
from test_successor_hidden_paired_visit6_sign import edit_span
from test_successor_hidden_paired_visit9_open import VISIT9
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_late_game10_pending'
STEPS=('human','npc28','npc29')
# Latest proof stage pins allow a cacheless recheck without replaying matches.
RETAINED={
    'human': ('fad1ecd050c3176ad947e013219d7e333fa3f3e0e3304fadae603c9c10699c0c',VISIT9[0]),
    'npc28': ('b4315e9d6fea8a58636da4c5c5c05f3c4a7e80092a96bf01ca713c49bb4fe4e7',
              'fad1ecd050c3176ad947e013219d7e333fa3f3e0e3304fadae603c9c10699c0c'),
    'npc29': ('66e1b7dc55c7a3ba6a44f8aeae664e3f80115cf3ad99c27c343909d529b56806',
              'b4315e9d6fea8a58636da4c5c5c05f3c4a7e80092a96bf01ca713c49bb4fe4e7'),
}
NATIVE={
    'human': '07632308749e39403fc7206c26cc0c290c795ad81a711f1cc871014c6ad672da',
    'npc28': '0e7679810a134490904af7776e15d568d9742f99225803c5ddd59ba2bb9304eb',
    'npc29': '333e9fa94437d20433c1935b5596e609dd23d39371d04adb6a7224ceeefd9f48',
}
BUDGET={'startup':30,'cold':430,'launch':490,'physics':240,'capture':115,
        'admission':490,'retry':50}
MARKERS={'recover-human':['cold','admission','retry'],
         'human':['cold','launch','physics','capture','admission','retry'],
         'npc28':['cold','launch','physics','admission','retry'],
         'npc29':['cold','launch','physics','admission','retry']}


def run(project,home,mode,godot):
    return native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=1700,
                  stages=MARKERS.get(mode,['cold']))


def verify_added(earlier,later,step):
    assert later[1]==earlier[0]
    print('DURABLE GAME10',step,hashlib.sha256(later[0]).hexdigest(),flush=True)
    before,after=(data.decode() for data in (earlier[0],later[0]))
    outer=['ordinary','physical','pending']
    pending=json.loads(after)['ordinary']['physical']['pending']
    human=pending['human']
    assert human[0]==27 and human[3]['player.dakota_wells']['pa']>0 and 'player.val_morgan' not in human[3]
    if step=='human':
        assert pending['reports']==[]
        assert edit_span(after,outer,'{}')==before
    else:
        path=outer+['reports']
        assert [row['fixture'] for row in pending['reports']]==list(range(28,int(step[3:])+1))
        older=raw_rows(before,path)
        assert raw_rows(after,path)[:-1]==older
        assert edit_span(after,path,'['+','.join(older)+']')==before
    return pending


def evidence_file(path,step):
    return path.parent/('fixture27-human-capture.local' if step=='human' else f'{step}-runner-report.local')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path,help='cp140 stage containing visit9-open')
    parser.add_argument('--paid-stage',required=True,type=Path,help='cp121 stage containing Standard control')
    parser.add_argument('--resume-stage',type=Path)
    parser.add_argument('--captured-human-stage',type=Path,help='reuse exact interrupted native fixture27 capture; no resimulation')
    parser.add_argument('--through',choices=STEPS)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    if bool(args.resume_stage)!=bool(args.through):
        parser.error('resume requires both --resume-stage and --through')
    if args.resume_stage and args.captured_human_stage:
        parser.error('choose saved boundary or interrupted capture, not both')
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'visit9-open'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    source=verify_fixture(slot_pair(origin),VISIT9)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-late-game10-pending-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    projection=project/'src/gameplay/season/successor_live_play_v1/paired_first_projection.gd'
    marker='\treturn Live.same(candidate.semifinals,games)'
    # Print only after all bracket checks have passed; no change to the decision.
    projection.write_text(once(projection.read_text(),marker,
        '\tif Live.same(candidate.semifinals,games):\n'
        '\t\tprint("G10_DETACHED_UNPLAYED ",candidate.results.size(),":",candidate.physical.reports.size(),'
        '":", JSON.stringify(candidate.playoff_seeds),":",JSON.stringify(candidate.semifinals))\n'+marker))
    dependencies=(TEST,'successor_hidden_paired_visit9_open','successor_hidden_paired_late_game9',
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
    current=source
    evidence=[]
    for i,step in enumerate(STEPS):
        folder='game10-'+step
        reused=args.resume_stage.resolve()/folder/draft.SLOT if args.through and i<=STEPS.index(args.through) else None
        home=root/folder
        path=install(home,verify_fixture(slot_pair(reused),RETAINED[step]) if reused else current)
        if step=='human' and args.captured_human_stage:
            interrupted=args.captured_human_stage.resolve()/folder/draft.SLOT
            assert slot_pair(interrupted)==source
            primitive=evidence_file(interrupted,step).read_bytes()
            assert hashlib.sha256(primitive).hexdigest()==NATIVE['human']
            evidence_file(path,step).write_bytes(primitive)
            run(project,home,'recover-human',godot)
            assert slot_pair(interrupted)==source and evidence_file(interrupted,step).read_bytes()==primitive
        elif not reused:
            run(project,home,step,godot)
        durable=slot_pair(path)
        pending=verify_added(current,durable,step)
        artifact=evidence_file(reused or path,step)
        pin=hashlib.sha256(artifact.read_bytes()).hexdigest()
        if reused:
            assert pin==NATIVE[step]
        print('G10_NATIVE_EVIDENCE',step,pin,flush=True)
        evidence.append((path,durable,reused,artifact,pin))
        current=durable
    cold=root/'complete-cold'
    cold_copy=install(cold,current)
    run(project,cold,'complete',godot)
    assert slot_pair(cold_copy)==current and not any(cold_copy.parent.glob('*.local'))
    text=current[0].decode()
    report_path=['ordinary','physical','pending','reports']
    rows=raw_rows(text,report_path)
    archive=json.loads(text)['ordinary']['physical']['reports']
    old_key=next(row['request'] for row in archive if row['fixture']==26)
    terminal=pending['reports'][-1]['request']
    faults={'mixed-source':once(text,terminal,old_key),
            'noninteger-fixture':edit_span(text,report_path,'['+','.join(rows[:-1]+[edit_span(rows[-1],['fixture'],'29.5')])+']'),
            'reordered':edit_span(text,report_path,'['+','.join(reversed(rows))+']')}
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
        assert hashlib.sha256(artifact.read_bytes()).hexdigest()==pin
    assert slot_pair(origin)==source and slot_pair(standard_path)==standard
    print('PASS: genuine private Game10 pending; exact historical bytes, detached unplayed bracket only, no settlement')


if __name__ == '__main__':
    main()
