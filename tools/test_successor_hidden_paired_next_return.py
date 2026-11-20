#!/usr/bin/env python3
"""Qualify only the second pair's private return: fixtures 9/10/11.

Generate --fixture-stage using tools/test_successor_hidden_paired_next_first_settlement.py
at cp119. Supply the cp114 paid-pair stage as --paid-stage for its pinned
Standard cold control. Authentic fixtures 0–8 are not replayed. Saves, logs,
and all scratch diagnostics remain in the disposable local stage.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_first_npcs import raw_value
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_next_return'
START = ('0da3f84b23f2d586b8140b60c777890ee565db8532720616a1e0db16919c4df5',
         'd5748cc616b15fbe343ddf257dd4ebc5523b9ed813f9e37de10ac495c9f54fc1')


def run(project,home,mode,godot):
    out = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                   'res://tests/'+TEST+'.tscn','--',mode],environment(home),480)
    assert 'HIDDEN_PAIRED_NEXT_RETURN_PASS' in out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    origin = args.fixture_stage.resolve()/'next-first-settlement'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'ordinary'/draft.SLOT
    start = verify_fixture(slot_pair(origin),START)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-next-return-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    for name in (TEST,'successor_hidden_paired_next_first_settlement','successor_hidden_paired_next_first',
                 'successor_hidden_paired_return_settlement','successor_hidden_paired_return',
                 'successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'next-return'
    primary = install(home,start)
    marker = '"pending":'
    previous = start[0]
    first_row = None
    exact_human = None
    for phase, expected in [('human',[]),('npc10',[10]),('npc11',[10,11])]:
        run(project,home,phase,godot)
        durable = slot_pair(primary)
        assert durable[1] == previous
        value, raw = raw_value(durable[0].decode(),marker)
        assert once(durable[0].decode(),marker+raw,marker+'{}').encode() == start[0]
        _, reports = raw_value(raw,'"reports":')
        human = once(raw,'"reports":'+reports,'"reports":[]')
        if exact_human is None:
            exact_human = human
        assert human == exact_human and value['human'][0] == 9
        assert [row['fixture'] for row in value['reports']] == expected
        if expected:
            _, end = json.JSONDecoder().raw_decode(reports,1)
            if first_row is None:
                first_row = reports[1:end]
            assert reports[1:end] == first_row
        previous = durable[0]
        print('DURABLE',phase,hashlib.sha256(durable[0]).hexdigest(),flush=True)
    run(project,home,'cold',godot)
    assert slot_pair(primary) == durable
    text = durable[0].decode()
    rows = []
    for fixture in (10,11):
        found = list(re.finditer(r'\{"fixture":%d(?:\.0)?,"report":\{"dynasty_start"' % fixture,text))
        assert len(found) == 1
        offset = found[0].start()
        _, end = json.JSONDecoder().raw_decode(text,offset)
        rows.append(text[offset:end])
    first,last = rows
    _, first_body = raw_value(first,',"report":')
    _, last_body = raw_value(last,',"report":')
    older = json.loads(start[0])['ordinary']['physical']['reports'][3]['request']
    faults = {
        'human-start':once(text,value['binding']['request'],'0'*64),
        'reordered':once(text,first+','+last,last+','+first),
        'terminal-request':once(text,value['reports'][1]['request'],'0'*64),
        'foreign-report':once(text,last,once(last,last_body,first_body)),
        'older-archive':once(text,older,'0'*64),
    }
    for fault, corrupt in faults.items():
        case = root/('tamper-'+fault)
        pair = corrupt.encode(),durable[1]
        path = install(case,pair)
        run(project,case,'tamper-'+fault,godot)
        assert slot_pair(path)==pair
    ordinary = root/'standard'
    ordinary_path = install(ordinary,standard)
    result = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                      '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in result and 'GATES=0' in result and slot_pair(ordinary_path)==standard
    assert slot_pair(origin)==start and slot_pair(standard_path)==standard
    print('PASS: real fixture 9/10/11, exact second-pair debt, byte-identical paid history, unopened payout and Standard parity')


if __name__ == '__main__':
    main()
