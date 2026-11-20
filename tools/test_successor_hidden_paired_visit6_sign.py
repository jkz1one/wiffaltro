#!/usr/bin/env python3
"""Sign the exact private visit6 Dakota-for-Val quote on pinned cp130 input.

Use --fixture-stage from the cp130 visit-open reproducer and --paid-stage
from cp121 Standard. --completed-stage reuses the pinned signed output to
run only cold/negative checks. No games, original writes, or raw export.
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
from test_successor_hidden_paired_visit6_open import OPEN, span
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_visit6_sign'
SIGNED=('02fe146a28eeb41d806bc11e208882b1f95813c769eed19220e896e32e9cbe19', OPEN[0])
BUDGET={'startup':30,'cold':180,'candidate':60,'admission':180,'retry':30}


def run(project,home,mode,godot):
    stages=['cold','candidate','admission','retry'] if mode=='sign' else ['cold']
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=480,stages=stages)


def edit_span(text, keys, replacement):
    lo,hi=span(text,keys)
    return text[:lo]+replacement+text[hi:]


def old_human_roster_tamper(raw):
    for field,index in [('results',15),('player_results',5)]:
        path=['ordinary','state',field]
        row=raw_rows(raw,path)[index]
        lo,hi=span(row,['club_roster'])
        assert '"player.val_morgan"' in row[lo:hi] and '"player.dakota_wells"' not in row[lo:hi]
        moved=row[:lo]+once(row[lo:hi],'"player.val_morgan"','"player.dakota_wells"')+row[hi:]
        begin,end=span(raw,path)
        raw=raw[:begin]+once(raw[begin:end],row,moved)+raw[end:]
    return raw


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'visit6-open'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    start=verify_fixture(slot_pair(origin),OPEN)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-private-visit6-sign-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    store=project/STORE
    marker='\n\tpaired_shop_candidate_ms=Time.get_ticks_msec()-started'
    store.write_text(once(store.read_text(),marker,marker+'\n\tif sign_visit6: print("CP127_STAGE admission")'))
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
    home=root/'visit6-sign'
    completed=args.completed_stage.resolve()/'visit6-sign'/draft.SLOT if args.completed_stage else None
    primary=install(home,verify_fixture(slot_pair(completed),SIGNED) if completed else start)
    if not completed:
        run(project,home,'sign',godot)
    durable=slot_pair(primary)
    assert durable[1]==start[0]
    print('DURABLE VISIT6 SIGN',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    unsigned,signed=(json.loads(value) for value in (start[0],durable[0]))
    old,new=(value['ordinary'] for value in (unsigned,signed))
    old_raw,new_raw=(value.decode() for value in (start[0],durable[0]))
    def exact(keys):
        a,b=span(old_raw,keys)
        c,d=span(new_raw,keys)
        return old_raw[a:b]==new_raw[c:d]
    assert {k:v for k,v in unsigned.items() if k!='ordinary'}=={k:v for k,v in signed.items() if k!='ordinary'}
    for name in ('physical','opponents','ownership'):
        assert exact(['ordinary',name])
    for name in ('results','player_results'):
        assert exact(['ordinary','state',name])
    for name in ('build','book','bank'):
        path=['ordinary','build',name,'_events']
        assert raw_rows(new_raw,path)[:-1]==raw_rows(old_raw,path)
    assert exact(['ordinary','build','build','_game_rosters'])
    assert exact(['ordinary','build','build','_recruits'])
    for player in old['build']['book']['_players']:
        if player!='player.dakota_wells':
            assert exact(['ordinary','build','book','_players',player])
    assert new['build']['build']['_contracts']=={**old['build']['build']['_contracts'],'player.dakota_wells':32}
    assert new['build']['bank']['_state']['cash']==62 and old['build']['bank']['_state']['cash']==94
    assert new['build']['build']['_visit']['recruit']=={**old['build']['build']['_visit']['recruit'],'signed':True}
    cold=root/'cold'
    cold_path=install(cold,durable)
    run(project,cold,'cold',godot)
    assert slot_pair(cold_path)==durable
    faults={
       'quote':edit_span(new_raw,['ordinary','build','build','_visit','recruit','price'],'1'),
       'profile':edit_span(new_raw,['ordinary','build','book','_players','player.dakota_wells','stats','fielding'],'0'),
       'old-roster':old_human_roster_tamper(new_raw),
    }
    for name,corruption in faults.items():
        case=root/('tamper-'+name)
        pair=corruption.encode(),durable[1]
        path=install(case,pair)
        run(project,case,'tamper-'+name,godot)
        assert slot_pair(path)==pair
    ordinary=root/'standard'
    ordinary_path=install(ordinary,standard)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(ordinary_path)==standard
    assert slot_pair(origin)==start and slot_pair(standard_path)==standard and slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    print('PASS: real exact Dakota-for-Val at 32 Cash, single historical gate, cold exact, no later authority')


if __name__=='__main__':
    main()
