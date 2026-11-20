#!/usr/bin/env python3
"""Settle exact cp145 postseason reports once, then verify COMPLETE cold.

No runner or matches. --completed-stage reuses exact paid bytes after an
interruption. All files are isolated and retained locally for exact replay.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_late_game10_pending import TEST as PENDING_TEST
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_return_settlement import STORE
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_third_return_settlement import raw_rows
from test_successor_hidden_paired_visit6_sign import edit_span, span
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST='successor_hidden_paired_postseason_settlement'
FINAL_TEST='successor_hidden_paired_final_npc'
SEMI_TEST='successor_hidden_paired_semifinal_npc'
HUMAN_TEST='successor_hidden_paired_semifinal_human'
SETTLED_TEST='successor_hidden_paired_late_game10_settlement'
UNPAID=('c23c6b7666d844a257ee766b3ab131261e8b3be23b985511f9c5974a7327da94',
        '2d998edfb57446b650c6d5e192cc92b65a15c87076459dcde2509404ac7ef0bf')
PAID=('b0e7f21f6c1f32222a57b1b9f2663051a85214cc411433fe9739bc4ec84234db',UNPAID[0])
BUDGET={'startup':35,'cold':520,'candidate':530,'paid':460,'retry':65}


def run(project,home,mode,godot):
    native(project,home,mode,godot,scene=TEST,budgets=BUDGET,outer=1630,
           stages=['cold','candidate','paid','retry'] if mode=='settle' else ['cold'])


def digest(value):
    return hashlib.sha256(value).hexdigest()


def record(path,data):
    text=json.dumps(data,sort_keys=True)+'\n'
    if path.exists():
        assert path.read_text()==text,path.name
    else:
        temp=path.with_suffix('.tmp')
        temp.write_text(text)
        temp.replace(path)


def stamp(repo):
    families=('successor-live-play-v1','successor-dynasty-owner-v1','successor-settled-workload-v1',
              'successor-league-general-v2','successor-request-composition-v1')
    files=[f'drafts/{family}/DRAFT_MANIFEST.json' for family in families]
    files.extend('tests/'+name+'.gd.txt' for name in (TEST,FINAL_TEST,SEMI_TEST,HUMAN_TEST,SETTLED_TEST))
    return {'base':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
            'files':{path:digest((repo/path).read_bytes()) for path in files}}


def verify_added(source,durable):
    assert durable[1]==source[0]
    print('DURABLE POSTSEASON COMPLETE',hashlib.sha256(durable[0]).hexdigest(),flush=True)
    before,after=(item.decode() for item in (source[0],durable[0]))
    old,new=(json.loads(item) for item in (before,after))
    assert {k:v for k,v in old.items() if k!='ordinary'}=={k:v for k,v in new.items() if k!='ordinary'}
    a,b=(item['ordinary'] for item in (old,new))
    assert a['state']['round_index']==10 and b['state']['round_index']==10 and b['physical']['pending']=={}
    assert [row['id'] for row in b['state']['results']]==list(range(33))
    assert b['state']['playoff_seeds']==[0,4,1,3] and [row['id'] for row in b['state']['semifinals']]==[30,31]
    assert b['state']['champion']==3 and b['state']['final_fixture']=={'id':32,'round':11,'away':3,'home':4,'neutral':True}
    assert b['state']['phase']==4 and b['build']['bank']['_state']['cash']==158
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
    parser.add_argument('--fixture-stage',required=True,type=Path,help='exact cp145 directory containing the native paid-prefix plus 30/31/32 pending')
    parser.add_argument('--paid-stage',required=True,type=Path,help='cp121 stage containing Standard control')
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--stage-root',type=Path,help='reuse local proof case digests without rerunning passed checks')
    parser.add_argument('--only',nargs='+',choices=('settle','complete','foreign-key','missing-terminal-physical','champion','cash','standard'),help='resume named checks only; requires exact retained paid stage')
    parser.add_argument('--godot',default='godot')
    args=parser.parse_args()
    if args.only and not (args.completed_stage or args.stage_root):
        parser.error('--only requires a pinned local stage')
    godot=shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    origin=args.fixture_stage.resolve()/draft.SLOT
    standard_path=args.paid_stage.resolve()/'standard'/draft.SLOT
    source=verify_fixture(slot_pair(origin),UNPAID)
    standard=verify_fixture(slot_pair(standard_path),STANDARD)
    repo=Path(__file__).resolve().parents[1]
    root=args.stage_root.resolve() if args.stage_root else Path(tempfile.mkdtemp(prefix='wiffaltro-postseason-complete-'))
    root.mkdir(parents=True,exist_ok=True)
    record(root/'source.json',stamp(repo))
    print('Retained disposable local stage:',root,flush=True)
    project=draft.stage(repo,Path(tempfile.mkdtemp(prefix='engine-',dir=root)),(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    store=project/STORE
    marker='\tpaired_candidate_ms=Time.get_ticks_msec()-started'
    line='\tvar result: bool = _write_data(_candidate_data,_expected)'
    prepared=once(store.read_text(),marker,marker+'\n\tif leg==10 and current!=null: print("CP127_STAGE paid")')
    store.write_text(once(prepared,line,'\tvar t:int=Time.get_ticks_usec()\n'+line+
                          '\n\tprint("POSTSEASON_WRITE_USEC=",Time.get_ticks_usec()-t," OK=",result)'))
    dependencies=(TEST,FINAL_TEST,SEMI_TEST,HUMAN_TEST,SETTLED_TEST,PENDING_TEST,'successor_hidden_paired_visit9_open','successor_hidden_paired_late_game9',
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

    home=root/'postseason-settle'
    primary=home/draft.SLOT
    settled_stamp=root/'settle-pass.json'
    completed=args.completed_stage.resolve()/'postseason-settle'/draft.SLOT if args.completed_stage else None
    if completed:
        durable=verify_fixture(slot_pair(completed),PAID)
    elif settled_stamp.exists():
        durable=verify_fixture(slot_pair(primary),tuple(json.loads(settled_stamp.read_text())['sha256']))
    else:
        assert not primary.exists(), 'interrupted candidate: inspect retained bytes and do not blindly retry'
        assert not args.only or 'settle' in args.only
        install(home,source)
        run(project,home,'settle',godot)
        durable=slot_pair(primary)
    paid=verify_added(source,durable)
    record(settled_stamp,{'sha256':list(map(digest,durable))})
    if not args.only or 'complete' in args.only:
        case=root/'complete-pass.json'
        if not case.exists():
            cold=Path(tempfile.mkdtemp(prefix='paid-cold-',dir=root))
            cold_copy=install(cold,durable)
            run(project,cold,'complete',godot)
            assert slot_pair(cold_copy)==durable
        record(case,{'sha256':list(map(digest,durable))})
    text=durable[0].decode()
    reports=['ordinary','physical','reports']
    rows=raw_rows(text,reports)
    archive=paid['ordinary']['physical']['reports']
    old_key=next(row['request'] for row in archive if row['fixture']==26)
    faults={
        'foreign-key':once(text,archive[-1]['request'],old_key),
        'missing-terminal-physical':edit_span(text,reports,'['+','.join(rows[:-1])+']'),
        'champion':edit_span(text,['ordinary','state','champion'],'4'),
        'cash':edit_span(text,['ordinary','build','bank','_state','cash'],'159'),
    }
    for name,changed in faults.items():
        if args.only and name not in args.only:
            continue
        case=root/(name+'-pass.json')
        pair=changed.encode(),durable[1]
        if not case.exists():
            attempt=Path(tempfile.mkdtemp(prefix='tamper-'+name+'-',dir=root))
            path=install(attempt,pair)
            run(project,attempt,'tamper-'+name,godot)
            assert slot_pair(path)==pair
        record(case,{'sha256':list(map(digest,pair))})
    if not args.only or 'standard' in args.only:
        case=root/'standard-pass.json'
        if not case.exists():
            ordinary=Path(tempfile.mkdtemp(prefix='standard-',dir=root))
            control=install(ordinary,standard)
            out=execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                         '--','cold','standard'],environment(ordinary),180)
            assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(control)==standard
        record(case,{'sha256':list(map(digest,standard))})
    assert slot_pair(origin)==source and slot_pair(standard_path)==standard
    if not completed:
        assert slot_pair(primary)==durable
    if completed:
        assert slot_pair(completed)==durable
    if args.only:
        print('PASS: selected cold checks only:', ', '.join(args.only))
    else:
        print('PASS: native complete postseason settlement, exact replay and once-only held write; lifecycle closed')


if __name__ == '__main__':
    main()
