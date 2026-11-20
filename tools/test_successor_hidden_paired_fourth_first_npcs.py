#!/usr/bin/env python3
"""Stage exactly NPC19 then NPC20 on the retained cp133 signed human game.

Each job has its own bounded authentic runner and fresh App/Store. Evidence
remains local before admission. --partial-stage reuses the unpaid NPC19 report and
simulates only NPC20; --completed-stage runs cold and negatives only.
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
from test_successor_hidden_paired_fourth_first import COMPLETE18, TEST as HUMAN_TEST, run as human_run
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_visit6_sign import OPEN, span
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_fourth_first_npcs'
NPC19=('c935c65fffaef157f9cb9d9d1505a4ca7c220ca44070a4f143642f7ffb62ecc0',COMPLETE18[0])
NPC20=('69dc2b55ce9ab5bbf986440a4a04ab94c040e5598c8fe662fa6aaaa61fa98edb',NPC19[0])
REPORT19='c038cd2d40e6a5251880a5de419d35a4d639a3ae866079ba20691a3b39b8a726'
REPORT20='312cbf8f3ee5a7d40ee98d9cd07365c7597c3e1a487720d77e41b07d10160d06'
BUDGET={'startup':30,'cold':230,'launch':250,'physics':180,'admission':260,'retry':30}


def run(project,home,mode,godot):
    stages=['cold','launch','physics','admission','retry'] if mode.startswith('play') else ['cold']
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=930,stages=stages)


def report_span(text):
    return span(text,['ordinary','physical','pending','reports'])


def verify_added(starter,durable,job):
    assert durable[1]==starter[0]
    print(f'DURABLE NPC{job}',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    text=durable[0].decode()
    previous=starter[0].decode()
    begin,end=report_span(text)
    lo,hi=report_span(previous)
    reports=text[begin:end]
    prior=previous[lo:hi]
    rows=json.loads(reports)
    assert [row['fixture'] for row in rows]==list(range(19,job+1))
    if job==20:
        _, edge=json.JSONDecoder().raw_decode(reports,1)
        assert reports[1:edge]==prior[1:-1]
    assert (text[:begin]+prior+text[end:]).encode()==starter[0]
    return rows


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--unsigned-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--partial-stage',type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'fourth-human'/draft.SLOT
    control_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    unsigned_path=args.unsigned_stage.resolve()/'visit6-open'/draft.SLOT
    source=verify_fixture(slot_pair(origin),COMPLETE18)
    control=verify_fixture(slot_pair(control_path),STANDARD)
    unsigned=verify_fixture(slot_pair(unsigned_path),OPEN)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-fourth-first-npcs-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    dependencies=(TEST,HUMAN_TEST,'successor_hidden_paired_visit6_sign','successor_hidden_paired_visit6_open',
                  'successor_hidden_paired_third_return_settlement','successor_hidden_paired_third_return',
                  'successor_hidden_paired_third_first_settlement','successor_hidden_paired_third_first',
                  'successor_hidden_paired_next_return_settlement','successor_hidden_paired_next_return',
                  'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                  'successor_hidden_paired_return_settlement','successor_hidden_paired_return',
                  'successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    for name in (TEST,HUMAN_TEST):
        (project/'tests'/(name+'.tscn')).write_text(
            '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
            + name + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    first='fourth-first-npc19'
    second='fourth-first-npc20'
    if args.completed_stage and not args.partial_stage:
        args.partial_stage=args.completed_stage
    external=[None if item is None else item.resolve()/phase/draft.SLOT
              for item,phase in ((args.partial_stage,first),(args.completed_stage,second))]
    evidence=[]
    current=source
    for job,phase,provided in zip((19,20),(first,second),external):
        home=root/phase
        expected=NPC19 if job==19 else NPC20
        path=install(home,verify_fixture(slot_pair(provided),expected) if provided else current)
        if not provided:
            run(project,home,f'play{job}',godot)
        durable=slot_pair(path)
        rows=verify_added(current,durable,job)
        report=(provided or path).parent/f'npc{job}-runner-report.local'
        digest=hashlib.sha256(report.read_bytes()).hexdigest()
        if provided:
            assert digest==(REPORT19 if job==19 else REPORT20)
        evidence.append((path,durable,report,digest,provided))
        print(f'NPC{job} LOCAL NATIVE DIGEST',digest,flush=True)
        current=durable
    assert evidence[1][1][1]==evidence[0][1][0]
    cold=root/'cold-complete'
    path=install(cold,current)
    run(project,cold,'cold20',godot)
    assert slot_pair(path)==current and not any(path.parent.glob('npc*-runner-report.local'))
    text=current[0].decode()
    begin,end=report_span(text)
    reports=text[begin:end]
    _, edge=json.JSONDecoder().raw_decode(reports,1)
    faults={
        'request':once(text,rows[-1]['request'],'0'*64),
        'reordered':text[:begin]+'['+reports[edge+1:-1]+','+reports[1:edge]+']'+text[end:],
    }
    for name,changed in faults.items():
        case=root/('tamper-'+name)
        pair=changed.encode(),current[1]
        corrupt=install(case,pair)
        run(project,case,'tamper-'+name,godot)
        assert slot_pair(corrupt)==pair
    ordinary=root/'standard'
    standard=install(ordinary,control)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(standard)==control
    case=root/'unsigned'
    unsigned_copy=install(case,unsigned)
    human_run(project,case,'unsigned',godot)
    assert slot_pair(unsigned_copy)==unsigned
    for path,data,report,digest,provided in evidence:
        assert slot_pair(path)==data and hashlib.sha256(report.read_bytes()).hexdigest()==digest
        if provided:
            assert slot_pair(provided)==data
    assert slot_pair(origin)==source and slot_pair(control_path)==control and slot_pair(unsigned_path)==unsigned
    print('PASS: actual authored NPC19 and NPC20, original signed owner, no payouts, exact unpaid cold')


if __name__ == '__main__':
    main()
