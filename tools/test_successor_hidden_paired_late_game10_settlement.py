#!/usr/bin/env python3
"""Settle the retained exact cp141 complete pending, then verify sealed cold.

No runner or matches. --completed-stage reuses exact paid bytes after an
interruption. All files are isolated and retained locally for exact replay.
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
from test_successor_hidden_paired_late_game10_pending import RETAINED, TEST as PENDING_TEST
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_return_settlement import STORE
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_third_return_settlement import raw_rows
from test_successor_hidden_paired_visit6_sign import edit_span, span
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_late_game10_settlement'
UNPAID=RETAINED['npc29']
PAID=('f56a0fbb0eb015d087e0622f0aacbd01f55e9df9b6ae3b57485f5b803a76e8bd',UNPAID[0])
BUDGET={'startup':35,'cold':520,'candidate':530,'paid':460,'retry':65}


def run(project,home,mode,godot):
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=1630,
           stages=['cold','candidate','paid','retry'] if mode=='settle' else ['cold'])


def verify_added(source,durable):
    assert durable[1]==source[0]
    print('DURABLE GAME10 SETTLED',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    before,after=(item.decode() for item in (source[0],durable[0]))
    old,new=(json.loads(item) for item in (before,after))
    assert {k:v for k,v in old.items() if k!='ordinary'}=={k:v for k,v in new.items() if k!='ordinary'}
    a,b=(item['ordinary'] for item in (old,new))
    assert a['state']['round_index']==9 and b['state']['round_index']==10 and b['physical']['pending']=={}
    assert [row['id'] for row in b['state']['results']]==list(range(30))
    assert b['state']['playoff_seeds']==[0,4,1,3] and [row['id'] for row in b['state']['semifinals']]==[30,31]
    reports=['ordinary','physical','reports']
    assert raw_rows(after,reports)==raw_rows(before,reports)+raw_rows(before,['ordinary','physical','pending','reports'])
    for field in ('results','player_results'):
        path=['ordinary','state',field]
        earlier=raw_rows(before,path)
        assert raw_rows(after,path)[:len(earlier)]==earlier
    for club in range(6):
        path=['ordinary','build'] if club==0 else ['ordinary','opponents','clubs',str(club),'build']
        for section in ('build','book','bank'):
            earlier=raw_rows(before,path+[section,'_events'])
            assert raw_rows(after,path+[section,'_events'])[:len(earlier)]==earlier
    root=['ordinary','build','build']
    locked=[root+[part] for part in ('_contracts','_recruits','_roster')]
    locked.extend(root+['_game_rosters',key] for key in a['build']['build']['_game_rosters'])
    locked.extend([['ordinary','ownership'],['ordinary','build','book','_players']])
    for path in locked:
        lo,hi=span(before,path)
        x,y=span(after,path)
        assert before[lo:hi]==after[x:y]
    return new


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path,help='cp141 retained stage containing game10-npc29')
    parser.add_argument('--paid-stage',required=True,type=Path,help='cp121 stage containing Standard control')
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--only',nargs='+',choices=('paid','foreign-key','missing-terminal-physical','wrong-bracket','standard'),help='resume named checks only; requires exact retained paid stage')
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    if args.only and not args.completed_stage:
        parser.error('--only requires --completed-stage')
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'game10-npc29'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    source=verify_fixture(slot_pair(origin),UNPAID)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-late-game10-paid-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    store=project/STORE
    marker='\tpaired_candidate_ms=Time.get_ticks_msec()-started'
    line='\tvar result: bool = _write_data(_candidate_data,_expected)'
    prepared=once(store.read_text(),marker,marker+'\n\tif leg==9 and current!=null: print("CP127_STAGE paid")')
    store.write_text(once(prepared,line,'\tvar t:int=Time.get_ticks_usec()\n'+line+
                          '\n\tprint("G10_SETTLEMENT_WRITE_USEC=",Time.get_ticks_usec()-t," OK=",result)'))
    dependencies=(TEST,PENDING_TEST,'successor_hidden_paired_visit9_open','successor_hidden_paired_late_game9',
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
    home=root/'game10-settle'
    completed=args.completed_stage.resolve()/'game10-settle'/draft.SLOT if args.completed_stage else None
    primary=install(home,verify_fixture(slot_pair(completed),PAID) if completed else source)
    if not completed:
        run(project,home,'settle',godot)
    durable=slot_pair(primary)
    paid=verify_added(source,durable)
    if not args.only or 'paid' in args.only:
        cold=root/'paid-cold'
        cold_copy=install(cold,durable)
        run(project,cold,'paid',godot)
        assert slot_pair(cold_copy)==durable
    text=durable[0].decode()
    reports=['ordinary','physical','reports']
    rows=raw_rows(text,reports)
    archive=paid['ordinary']['physical']['reports']
    old_key=next(row['request'] for row in archive if row['fixture']==26)
    faults={
        'foreign-key':once(text,archive[-1]['request'],old_key),
        'missing-terminal-physical':edit_span(text,reports,'['+','.join(rows[:-1])+']'),
        'wrong-bracket':edit_span(text,['ordinary','state','semifinals'],
                                 '[{"id":30,"round":10,"away":1,"home":0},{"id":31,"round":10,"away":3,"home":4}]'),
    }
    for name,changed in faults.items():
        if args.only and name not in args.only:
            continue
        case=root/('tamper-'+name)
        pair=changed.encode(),durable[1]
        path=install(case,pair)
        run(project,case,'tamper-'+name,godot)
        assert slot_pair(path)==pair
    if not args.only or 'standard' in args.only:
        ordinary=root/'standard'
        control=install(ordinary,standard)
        out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                     '--','cold','standard'],environment(ordinary),180)
        assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(control)==standard and slot_pair(standard_path)==standard
    assert slot_pair(origin)==source and slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    if args.only:
        print('PASS: selected cold checks only:', ', '.join(args.only))
    else:
        print('PASS: private final regular settlement, historical paid replay, owned retry and sealed unplayed bracket only')


if __name__ == '__main__':
    main()
