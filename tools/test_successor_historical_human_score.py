#!/usr/bin/env python3
"""Verify the inactive historical-human flow guard without enabling signing.

--fixture-stage is the exact cp130 native visit6 open stage; --paid-stage
supplies the cp121 Standard control. Original input is read-only. Signing is
invoked only on detached test Builds and neither written nor adopted by App.
No gameplay, no raw transfers, and no signed save files are produced.
"""
import argparse
from pathlib import Path
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_visit6_open import OPEN
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_historical_human_score'
STAGES=['cold','unsigned','signed','score','occupancy','row-roster','receipt','missing']
BUDGET={'startup':30, **dict.fromkeys(STAGES,180)}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--performance-gate',action='store_true',help='focused absent-performance negative')
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'visit6-open'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    opened=verify_fixture(slot_pair(origin),OPEN)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-historical-human-score-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    dependencies=(TEST,'successor_hidden_paired_visit6_open','successor_hidden_paired_third_return_settlement',
                  'successor_hidden_paired_third_return','successor_hidden_paired_third_first_settlement',
                  'successor_hidden_paired_third_first','successor_hidden_paired_next_return_settlement',
                  'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                  'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                  'successor_hidden_paired_return','successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home=root/'proof'
    primary=install(home,opened)
    if args.performance_gate:
        native(project,home,'performance-gate',godot,scene=TEST,
               budgets={**BUDGET,'missing-performance':30},stages=['cold','missing-performance'],outer=240)
    else:
        native(project,home,'proof',godot,scene=TEST,budgets=BUDGET,stages=STAGES,outer=1200)
    assert slot_pair(primary)==opened and slot_pair(origin)==opened
    assert len(list(home.rglob('wiffaltro-common-career-v4.json*')))==2
    ordinary=root/'standard'
    ordinary_copy=install(ordinary,standard)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(ordinary_copy)==standard
    assert slot_pair(standard_path)==standard
    print('PASS: authenticated historical human rosters validate unchanged native score/flow, new path stays inactive')


if __name__=='__main__':
    main()
