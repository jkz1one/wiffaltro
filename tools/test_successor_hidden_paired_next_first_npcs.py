#!/usr/bin/env python3
"""Run only actual private NPC 7 then 8, not any earlier game.

Produce --fixture-stage at cp117 via
python3 tools/test_successor_hidden_paired_next_first.py --fixture-stage <cp114-stage>
and pass that cp114 stage as --paid-stage for its admitted Standard control.
Sources are hash-pinned; all gameplay/checkpoint bytes remain disposable local.
--completed-stage rechecks exact retained outputs without replaying either game.
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
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_next_first_npcs'
START = ('82a95f7c1cef9221c809848f2a73229074bda2e2b159d3e1cf80b3b9279d9469',
         'df33238b26a8fe17136b5f9ace57e175a0ac2bd7db09ea8fffa997bed6ff014d')
COMPLETE = ('d5748cc616b15fbe343ddf257dd4ebc5523b9ed813f9e37de10ac495c9f54fc1',
            'a297a073b8996f2452269e2839b0ca9d62bd733b7f52130a6551f4b4bda5b5a0')


def run(project, home, mode, godot):
    out = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                   'res://tests/'+TEST+'.tscn','--',mode],environment(home),420)
    assert 'HIDDEN_PAIRED_NEXT_FIRST_NPCS_PASS' in out


def raw_value(raw, marker):
    offset = raw.index(marker) + len(marker)
    decoded, end = json.JSONDecoder().raw_decode(raw,offset)
    return decoded, raw[offset:end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--completed-stage',type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    origin = args.fixture_stage.resolve()/'next-human'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'ordinary'/draft.SLOT
    starter = verify_fixture(slot_pair(origin), START)
    standard = verify_fixture(slot_pair(standard_path), STANDARD)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-next-first-npcs-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    for name in (TEST,'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'next-first-npcs'
    primary = install(home,starter)
    phases = []
    completed_path = (args.completed_stage.resolve()/'next-first-npcs'/draft.SLOT
                      if args.completed_stage else None)
    completed = (verify_fixture(slot_pair(completed_path), COMPLETE)
                 if completed_path else None)
    previous = starter[0]
    marker = '"pending":'
    original, original_raw = raw_value(previous.decode(),marker)
    assert original['human'][0] == 6 and original['reports'] == []
    prior_reports = []
    first_raw = None
    for fixture in (7,8):
        # Each round uses a fresh process; NPC8 also independently cold-checks
        # original human evidence plus the complete NPC7 report before launch.
        if completed is None:
            run(project,home,'npc'+str(fixture),godot)
        else:
            primary.write_bytes(completed[1 if fixture == 7 else 0])
            Path(str(primary)+'.bak').write_bytes(previous)
        durable = slot_pair(primary)
        print('DURABLE NPC',fixture,hashlib.sha256(durable[0]).hexdigest(),flush=True)
        assert durable[1] == previous
        value, raw = raw_value(durable[0].decode(),marker)
        assert once(durable[0].decode(),marker+raw,marker+original_raw).encode() == starter[0]
        assert {**value,'reports':[]} == original
        _, reports_raw = raw_value(raw,'"reports":')
        assert once(raw,'"reports":'+reports_raw,'"reports":[]') == original_raw
        first, end = json.JSONDecoder().raw_decode(reports_raw,1)
        if first_raw is None:
            first_raw = reports_raw[1:end]
        assert reports_raw[1:end] == first_raw and first == value['reports'][0]
        assert [row['fixture'] for row in value['reports']] == list(range(7,fixture+1))
        assert value['reports'][:-1] == prior_reports
        previous = durable[0]
        prior_reports = value['reports']
        phases.append(durable)
    run(project,home,'cold',godot)
    assert slot_pair(primary) == phases[-1]
    raw = phases[-1][0].decode()
    rows = []
    for fixture in (7,8):
        matches = list(re.finditer(r'\{"fixture":%d(?:\.0)?,"report":\{"dynasty_start"' % fixture,raw))
        assert len(matches) == 1
        start = matches[0].start()
        _, end = json.JSONDecoder().raw_decode(raw,start)
        rows.append(raw[start:end])
    first, last = rows
    start = last.index(',"report":')+len(',"report":')
    _, end = json.JSONDecoder().raw_decode(last,start)
    terminal = last[start:end]
    workload = terminal.rindex(',"workload":')+len(',"workload":')
    _, stop = json.JSONDecoder().raw_decode(terminal,workload)
    malformed = terminal[:workload]+'[{},{}]'+terminal[stop:]
    _, foreign = raw_value(first,',"report":')
    faults = {
        'reordered':once(raw,first+','+last,last+','+first),
        'duplicate':once(raw,first+','+last,first+','+first),
        'terminal-request':once(raw,prior_reports[1]['request'],'0'*64),
        'terminal-workload':once(raw,last,once(last,terminal,malformed)),
        'foreign-report':once(raw,last,once(last,terminal,foreign)),
    }
    for fault, corrupt in faults.items():
        target = root/('tamper-'+fault)
        pair = corrupt.encode(),phases[-1][1]
        path = install(target,pair)
        run(project,target,'tamper-'+fault,godot)
        assert slot_pair(path) == pair
    ordinary = root/'standard'
    ordinary_path = install(ordinary,standard)
    result = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                      '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in result and 'GATES=0' in result and slot_pair(ordinary_path)==standard
    assert slot_pair(origin)==starter and slot_pair(standard_path)==standard
    if completed_path:
        assert slot_pair(completed_path)==completed
    print('PASS: NPC 7 then 8 with fresh physical workloads, exact partial/complete cold and no new payout')


if __name__ == '__main__':
    main()
