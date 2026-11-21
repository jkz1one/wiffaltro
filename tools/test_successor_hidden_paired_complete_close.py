#!/usr/bin/env python3
"""Isolated native Close of exact cp146 COMPLETE. No match runner or settlement."""
import argparse
import json
from pathlib import Path
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

TEST = 'successor_hidden_paired_complete_close'
CASES = ('close', 'closed', 'identity', 'receipt', 'cross-mode', 'standard')


def proof(project, home, mode, godot):
    stages = ['cold', 'candidate', 'retry'] if mode == 'close' else ['cold']
    native(project, home, mode, godot, scene=TEST, budgets=postseason.BUDGET,
           outer=1200 if mode == 'close' else 575, stages=stages)


def verify_close(original, closed):
    assert closed[1] == original[0]
    previous, current = (data.decode() for data in (original[0], closed[0]))
    a, b = (json.loads(data) for data in (previous, current))
    for key in a:
        if key not in ('common', 'ordinary_state'):
            assert a[key] == b[key], key
            start, end = span(previous, [key])
            lo, hi = span(current, [key])
            assert previous[start:end] == current[lo:hi], key
    state = b['ordinary_state']
    close = state['last_close']
    aggregate = b['common']['aggregate']
    assert state['status'] == 'closed' and state['ordinal'] == 1
    assert state['lineage'] == a['ordinary_state']['lineage'] and close['id'] == state['lineage'] + ':1:close'
    assert not state['proposal'] and not state['last_transition']
    assert b['common']['sequence'] == 1 and b['common']['cursors'] == {'ordinary': 1, 'dynasty': 0}
    assert close['receipt'] == {'version':1,'finish':'semifinal','wins':8,'finish_award':65,
                                'record_bonus':12,'first_bonus':0,'total':77}
    assert aggregate['currency'] == 77 and aggregate['completed'] == 1 and not aggregate['titles']
    assert b['ordinary']['build']['bank']['_state']['cash'] == 158
    print('DURABLE PRIVATE CLOSE', postseason.digest(closed[0]), 'AUTHORED FOLD',
          json.dumps({key:aggregate[key] for key in ('wins','games','currency','titles','exotic_rights','pennants','plaques')}),
          flush=True)
    return b


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--complete-stage', type=Path, required=True, help='cp146 root containing postseason-settle')
    parser.add_argument('--paid-stage', type=Path, required=True, help='prior staged Standard control')
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
    for path in ('tests/'+TEST+'.gd.txt', 'tools/'+Path(__file__).name):
        source_meta['files'][path] = postseason.digest((repo/path).read_bytes())
    postseason.record(root/'source.json', source_meta)
    starter = args.complete_stage.resolve()/'postseason-settle'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    original = verify_fixture(slot_pair(starter), postseason.PAID)
    standard = verify_fixture(slot_pair(standard_path), postseason.STANDARD)
    project = draft.stage(repo,Path(tempfile.mkdtemp(prefix='engine-',dir=root)),
                          (repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    dependencies = (TEST, postseason.TEST, postseason.FINAL_TEST, postseason.SEMI_TEST,
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
    home = root/'owned-close'
    close_stamp = root/'close-pass.json'
    if not close_stamp.exists():
        assert 'close' in selected and not (home/draft.SLOT).exists(), 'unverified close stage: preserve and inspect retained bytes'
        install(home, original)
        proof(project, home, 'close', godot)
    durable = slot_pair(home/draft.SLOT)
    b = verify_close(original, durable)
    postseason.record(close_stamp, {'sha256': list(map(postseason.digest,durable))})
    closed = durable[0].decode()
    state = b['ordinary_state']
    chosen = 'ordinary:'+'0'*64
    assert state['lineage'] != chosen
    faults = {
        'closed': durable,
        'identity': (closed.replace(state['lineage'],chosen).encode(),durable[1]),
        'receipt': (edit_span(closed,['ordinary_state','last_close','receipt','total'],'78').encode(),durable[1]),
        'cross-mode': (edit_span(closed,['common','last_fold','side'],'"dynasty"').encode(),durable[1]),
        'standard': standard,
    }
    for name, pair in faults.items():
        if name not in selected:
            continue
        case = root/(name+'-pass.json')
        if not case.exists():
            isolated = Path(tempfile.mkdtemp(prefix=name+'-',dir=root))
            path = install(isolated,pair)
            proof(project, isolated, name if name in ('closed','standard') else 'tamper-'+name,godot)
            assert slot_pair(path)==pair
        postseason.record(case, {'sha256':list(map(postseason.digest,pair))})
    assert slot_pair(starter)==original and slot_pair(standard_path)==standard and slot_pair(home/draft.SLOT)==durable
    print('PASS native private close cases:', ', '.join(selected))


if __name__ == '__main__':
    main()
