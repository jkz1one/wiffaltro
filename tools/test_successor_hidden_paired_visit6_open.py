#!/usr/bin/env python3
"""Open only the actual private sixth visit on exact cp129 settled bytes.

Obtain --fixture-stage from the cp129 third-return settlement reproducer.
--paid-stage is the cp121 Standard control. --completed-stage verifies the
pinned open slot without running another transaction. This runs no games or
signings, writes no original input, and retains synthetic output locally.
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
from test_successor_hidden_paired_third_return_settlement import PAID, raw_rows
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_visit6_open'
OPEN = ('6e930faba062977e6ff756b9b321e0c6d9a2265f64ba79c68bc53e084e8ca652', PAID[0])
BUDGET = {'startup':30, 'cold':165, 'candidate':60, 'paid':165, 'retry':30}


def run(project,home,mode,godot):
    stages=['cold','candidate','paid','retry'] if mode=='open' else ['cold']
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=470,stages=stages)


def span(text, keys):
    decoder=json.JSONDecoder()
    pos=0
    for part in keys:
        assert text[pos]=='{'
        pos+=1
        while text[pos]!='}':
            key,end=decoder.raw_decode(text,pos)
            assert text[end]==':'
            if key==part:
                pos=end+1
                break
            _, end=decoder.raw_decode(text,end+1)
            pos=end+1 if text[end]==',' else end
        else:
            raise KeyError(keys)
    _,end=decoder.raw_decode(text,pos)
    return pos,end


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    godot=shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/'third-return-settlement'/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    start=verify_fixture(slot_pair(origin),PAID)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=Path(tempfile.mkdtemp(prefix='wiffaltro-private-visit6-open-'))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    # Stopwatch on the already-qualified Store boundary, only in staging.
    store=project/STORE
    marker='\n\tpaired_shop_candidate_ms=Time.get_ticks_msec()-started'
    store.write_text(once(store.read_text(),marker,marker+'\n\tif visit==6: print("CP127_STAGE paid")'))
    dependencies=(TEST,'successor_hidden_paired_third_return_settlement','successor_hidden_paired_third_return',
                  'successor_hidden_paired_third_first_settlement','successor_hidden_paired_third_first',
                  'successor_hidden_paired_next_return_settlement','successor_hidden_paired_next_return',
                  'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                  'successor_hidden_paired_return_settlement','successor_hidden_paired_return','successor_hidden_first_settlement')
    for name in dependencies:
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home=root/'visit6-open'
    completed=args.completed_stage.resolve()/'visit6-open'/draft.SLOT if args.completed_stage else None
    primary=install(home,verify_fixture(slot_pair(completed),OPEN) if completed else start)
    if not completed:
        run(project,home,'open',godot)
    durable=slot_pair(primary)
    assert durable[1]==start[0]
    print('DURABLE VISIT6 OPEN',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    before,after=(json.loads(value) for value in (start[0],durable[0]))
    old,new=before['ordinary'],after['ordinary']
    raw_before,raw_after=(value.decode() for value in (start[0],durable[0]))
    assert {k:v for k,v in before.items() if k!='ordinary'}=={k:v for k,v in after.items() if k!='ordinary'}
    for name in ('state','physical','career','opponents','ownership'):
        raw=lambda text: text[slice(*span(text,['ordinary',name]))]
        assert raw(raw_before)==raw(raw_after)
    for name in set(old['build'])-{'build'}:
        raw=lambda text: text[slice(*span(text,['ordinary','build',name]))]
        assert raw(raw_before)==raw(raw_after)
    key=['ordinary','build','build','_events']
    old_events=raw_rows(raw_before,key)
    assert raw_rows(raw_after,key)[:-1]==old_events
    old_build,new_build=old['build']['build'],new['build']['build']
    changed={key for key in old_build if old_build[key]!=new_build[key]}
    assert changed=={'_events','_requests','_visit','_appeared','_recruits'}
    offer=new_build['_visit']['recruit']
    assert (offer['player'],offer['price'],offer['stage'],offer['returning'],offer['signed'])==('player.dakota_wells',32,'late',False,False)
    cold=root/'cold'
    cold_path=install(cold,durable)
    run(project,cold,'cold',godot)
    assert slot_pair(cold_path)==durable
    pos,end=span(raw_after,['ordinary','build','build','_visit','recruit','price'])
    bad_price=raw_after[:pos]+'1'+raw_after[end:]
    pos,end=span(raw_after,['ordinary','build','build','_events'])
    bad_journal=raw_after[:pos]+raw_after[pos:end].replace('visit6-open:15','visit7-open:15',1)+raw_after[end:]
    for name,changed in [('quote',bad_price),('journal',bad_journal)]:
        target=root/('tamper-'+name)
        corrupt=changed.encode(),durable[1]
        path=install(target,corrupt)
        run(project,target,'tamper-'+name,godot)
        assert slot_pair(path)==corrupt
    ordinary=root/'standard'
    ordinary_path=install(ordinary,standard)
    out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                 '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(ordinary_path)==standard
    assert slot_pair(origin)==start and slot_pair(standard_path)==standard and slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    print('PASS: real eligible private visit6 opening, Dakota quote, no sign, exact prior history and Standard')


if __name__=='__main__':
    main()
