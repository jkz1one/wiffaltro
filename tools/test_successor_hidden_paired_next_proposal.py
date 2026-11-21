#!/usr/bin/env python3
"""Isolated same-Base Next proposal from exact cp147 CLOSED. No season birth or game."""
import argparse
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
import test_successor_hidden_paired_postseason_settlement as postseason
from test_successor_hidden_paired_late_game10_pending import TEST as PENDING
from test_successor_hidden_paired_third_return_first_npc import native
from test_successor_hidden_paired_visit6_sign import edit_span, span
from test_successor_paired_resolver_context import install, slot_pair, verify_fixture

TEST = 'successor_hidden_paired_next_proposal'
CLOSE = 'successor_hidden_paired_complete_close'
CLOSED = ('949ad1aa4ef43133b5835a34bb97be1be6a587e4a779eed5eb498230a5e1b00c',postseason.PAID[0])
PROPOSED = ('f34c4610cdbf978cb1144894d45e41cbe995eb0dbe46aab9ffe1cc712ebeb13f',CLOSED[0])
CASES = ('propose', 'proposal', 'source', 'cross-mode', 'basis', 'fractional-tier', 'standard')


def proof(project, home, mode, godot):
    native(project, home, mode, godot, scene=TEST, budgets=postseason.BUDGET,
           outer=1200 if mode == 'propose' else 575,
           stages=['cold', 'candidate', 'retry'] if mode == 'propose' else ['cold'])


def whole_spelling(text):
    # Ignore only unchanged whole-value int / float spelling outside strings.
    tokens = r'(?:"(?:[^"\\]|\\.)*")|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?'
    return re.sub(tokens,lambda m:m[0][:-2] if not m[0].startswith('"') and m[0].endswith('.0') else m[0],text)


def verify_proposal(original, durable):
    assert durable[1] == original[0]
    previous, current = (data.decode() for data in (original[0],durable[0]))
    a,b = (json.loads(data) for data in (previous,current))
    assert set(a)==set(b)
    stripped=edit_span(current,['ordinary_state','proposal'],'{}')
    for key in a:
        start,end = span(previous,[key])
        lo,hi = span(stripped,[key])
        prior,now=previous[start:end],stripped[lo:hi]
        if key in ('common','ordinary_state'):
            assert whole_spelling(prior)==whole_spelling(now),key
        else:
            assert prior==now,key
    old,new = (data['ordinary_state'] for data in (a,b))
    assert {k:v for k,v in old.items() if k!='proposal'}=={k:v for k,v in new.items() if k!='proposal'}
    assert not old['proposal'] and not new['last_transition'] and new['status']=='closed' and new['ordinal']==1
    p=new['proposal']
    assert p['id']==new['lineage']+':1:next' and p['source']==old['last_close']['session_sha256']
    assert p['league']=='doubleheader' and p['tier']==0
    assert p['basis']['seed']==1002 and p['basis']['ordinal']==2 and p['basis']['common_sequence']==1
    assert p['basis']['exotic_rights']==['pitch.corkscrew','pitch.switchback']
    print('DURABLE PRIVATE PROPOSAL',postseason.digest(durable[0]),flush=True)
    return b


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--closed-stage', type=Path, required=True, help='cp147 root containing owned-close')
    parser.add_argument('--paid-stage', type=Path, required=True, help='prior staged Standard control')
    parser.add_argument('--proposed-stage', type=Path, help='independently pinned existing owned proposal; do not repeat native proposal/retry')
    parser.add_argument('--stage-root', type=Path, required=True, help='retain exact slot and per-case immutable stamps locally')
    parser.add_argument('--only', nargs='+', choices=CASES)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    root = args.stage_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    repo = Path(__file__).resolve().parents[1]
    source_meta = postseason.stamp(repo)
    for path in ('tests/'+TEST+'.gd.txt','tests/'+CLOSE+'.gd.txt','tools/'+Path(__file__).name):
        source_meta['files'][path] = postseason.digest((repo/path).read_bytes())
    postseason.record(root/'source.json', source_meta)
    starter = args.closed_stage.resolve()/'owned-close'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    original = verify_fixture(slot_pair(starter), CLOSED)
    standard = verify_fixture(slot_pair(standard_path), postseason.STANDARD)
    project = draft.stage(repo,Path(tempfile.mkdtemp(prefix='engine-',dir=root)),
                          (repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    dependencies = (TEST, CLOSE, postseason.TEST, postseason.FINAL_TEST, postseason.SEMI_TEST,
                    postseason.HUMAN_TEST, postseason.SETTLED_TEST, PENDING,
                    'successor_hidden_paired_visit9_open','successor_hidden_paired_late_game9',
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
        +TEST+'.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')

    selected = args.only or CASES
    home = root/'owned-proposal'
    close_stamp = root/'propose-pass.json'
    proven=args.proposed_stage.resolve()/'owned-proposal'/draft.SLOT if args.proposed_stage else None
    if not proven and not close_stamp.exists():
        assert 'propose' in selected and not (home/draft.SLOT).exists(), 'unverified proposal stage: preserve and inspect retained bytes'
        install(home, original)
        proof(project, home, 'propose', godot)
    durable = verify_fixture(slot_pair(proven),PROPOSED) if proven else slot_pair(home/draft.SLOT)
    verify_proposal(original,durable)
    postseason.record(close_stamp,{'sha256':list(map(postseason.digest,durable))})
    proposed=durable[0].decode()
    path=['ordinary_state','proposal']
    faults={
        'proposal':durable,
        'source':(edit_span(proposed,path+['source'],'"'+('0'*64)+'"').encode(),durable[1]),
        'cross-mode':(edit_span(proposed,path+['league'],'"dynasty"').encode(),durable[1]),
        'basis':(edit_span(proposed,path+['basis','exotic_rights'],'[]').encode(),durable[1]),
        'fractional-tier':(edit_span(proposed,path+['tier'],'0.5').encode(),durable[1]),
        'standard':standard,
    }
    for name, pair in faults.items():
        if name not in selected:
            continue
        case = root/(name+'-pass.json')
        if not case.exists():
            isolated = Path(tempfile.mkdtemp(prefix=name+'-',dir=root))
            path = install(isolated,pair)
            proof(project, isolated, name if name in ('proposal','standard') else 'tamper-'+name,godot)
            assert slot_pair(path)==pair
        postseason.record(case, {'sha256':list(map(postseason.digest,pair))})
    assert slot_pair(starter)==original and slot_pair(standard_path)==standard and slot_pair(proven or home/draft.SLOT)==durable
    print('PASS native private proposal cases:', ', '.join(selected))


if __name__ == '__main__':
    main()
