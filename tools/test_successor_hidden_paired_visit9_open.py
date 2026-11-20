#!/usr/bin/env python3
"""Open only the authentic ninth visit on the exact paid cp139 owner.

Use --fixture-stage from cp139 and --paid-stage from cp121 for Standard. --completed-stage repeats only exact cold/corruption
checks, never the open transaction or any games. No raw evidence is exported.
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
from test_successor_hidden_paired_fourth_first import TEST as HUMAN_TEST
from test_successor_hidden_paired_fourth_first_npcs import TEST as NPC_TEST
from test_successor_hidden_paired_fourth_first_settlement import TEST as SETTLED_TEST
from test_successor_hidden_paired_late_game8 import TEST as GAME8_TEST
from test_successor_hidden_paired_late_game9 import RETAINED, TEST as GAME9_TEST
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_return_settlement import STORE
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_third_return_settlement import raw_rows
from test_successor_hidden_paired_visit6_sign import edit_span, span
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_visit9_open'
PAID9=RETAINED['settle']
VISIT9=('00ae224983bef14b1559c8aa78d302e8c6c641991f4b382a1f9a4d7b0d10a17a',PAID9[0])
BUDGET={'startup':30,'cold':260,'candidate':65,'paid':250,'retry':45}


def run(project,home,mode,godot):
    stages=['cold','candidate','paid','retry'] if mode=='open' else ['cold']
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=675,stages=stages)


def verify_preserved(paid,durable):
    assert durable[1]==paid[0]
    print('DURABLE VISIT9 OPEN',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    old,new=(frame.decode() for frame in (paid[0],durable[0]))
    old_data,new_data=(json.loads(frame) for frame in (old,new))
    assert {k:v for k,v in old_data.items() if k!='ordinary'}=={k:v for k,v in new_data.items() if k!='ordinary'}
    for nested in (['state'],['physical'],['opponents'],['ownership'],['build','book'],['build','bank'],
                   ['build','build','_contracts'],['build','build','_roster'],['build','build','_game_rosters']):
        path=['ordinary',*nested]
        lo,hi=span(old,path)
        begin,end=span(new,path)
        assert old[lo:hi]==new[begin:end]
    for name in ('_events','_recruits'):
        key=['ordinary','build','build',name]
        assert raw_rows(new,key)[:-1]==raw_rows(old,key)
    b=new_data['ordinary']['build']['build']
    assert b['_events'][-1]=={'id':'visit9-open:25','rev':25,'op':'open'}
    assert b['_recruits'][-1]=={'visit':9,'chance':0,'offer':{}}
    assert b['_visit']['number']==9 and b['_visit']['open'] is True and b['_visit']['recruit']=={}
    assert b['_visit']['offers'] and b['_visit']['cards']
    assert new_data['ordinary']['build']['bank']['_state']['cash']==122
    return old_data,new_data


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
    origin=args.fixture_stage.resolve()/'game9-settle'/draft.SLOT
    control_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    paid=verify_fixture(slot_pair(origin),PAID9)
    control=verify_fixture(slot_pair(control_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-private-visit9-cutoff-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    store=project/STORE
    marker='\tpaired_shop_candidate_ms=Time.get_ticks_msec()-started'
    line='\tvar result: bool = _write_data(_candidate_data,_expected)'
    prepared=once(store.read_text(),marker,marker+'\n\tif visit==9: print("CP127_STAGE paid")')
    store.write_text(once(prepared,line,'\tvar t:int=Time.get_ticks_usec()\n'+line+
                         '\n\tprint("VISIT9_WRITE_USEC=",Time.get_ticks_usec()-t," OK=",result)'))
    dependencies=(TEST,'successor_hidden_paired_visit8_open',GAME9_TEST,GAME8_TEST,'successor_hidden_paired_visit7_open',SETTLED_TEST,NPC_TEST,HUMAN_TEST,'successor_hidden_paired_visit6_sign',
                  'successor_hidden_paired_visit6_open','successor_hidden_paired_third_return_settlement',
                  'successor_hidden_paired_third_return','successor_hidden_paired_third_first_settlement',
                  'successor_hidden_paired_third_first','successor_hidden_paired_next_return_settlement',
                  'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                  'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                  'successor_hidden_paired_return','successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    for name in (TEST,HUMAN_TEST):
        (project/'tests'/(name+'.tscn')).write_text(
            '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
            + name + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home=root/'visit9-open'
    completed=args.completed_stage.resolve()/'visit9-open'/draft.SLOT if args.completed_stage else None
    primary=install(home,verify_fixture(slot_pair(completed),VISIT9) if completed else paid)
    if not completed:
        run(project,home,'open',godot)
    durable=slot_pair(primary)
    old,_=verify_preserved(paid,durable)
    cold=root/'cold'
    cold_copy=install(cold,durable)
    run(project,cold,'cold',godot)
    assert slot_pair(cold_copy)==durable
    text=durable[0].decode()
    parent=['ordinary','build','build']
    history=raw_rows(text,parent+['_recruits'])
    stale=old['ordinary']['build']['build']['_recruits'][1]['offer']
    faults={
        'stale-current-recruit':edit_span(text,parent+['_visit','recruit'],json.dumps(stale,separators=(',',':'))),
        'false-late-chance':edit_span(text,parent+['_recruits'],'['+','.join(history[:-1]+[edit_span(history[-1],['chance'],'0.25')])+']'),
        'forged-open':once(text,'"id":"visit9-open:25"','"id":"visit9-open:24"'),
    }
    for name,changed in faults.items():
        case=root/('tamper-'+name)
        pair=changed.encode(),durable[1]
        path=install(case,pair)
        run(project,case,'tamper-'+name,godot)
        assert slot_pair(path)==pair
    ordinary=root/'standard'
    standard=install(ordinary,control)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(standard)==control
    assert slot_pair(origin)==paid and slot_pair(control_path)==control
    assert slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    print('PASS: same signed owner, real visit9 stock with no recruitment, stale signing and all purchases remain closed')


if __name__=='__main__':
    main()
