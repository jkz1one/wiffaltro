#!/usr/bin/env python3
"""Play only private NPC 13 then 14 from exact cp123 human12 pending.

Generate the pinned --fixture-stage with the cp123 command in
tools/test_successor_hidden_paired_third_first.py; the cp121 --paid-stage
supplies its previously admitted Standard control. Inputs are copied and
never changed. NPC14's independent process first cold-opens the actual
NPC13 partial. A third process checks the complete unpaid owner.
Use --resume-stage plus --retained-count 1 or 2 to recheck earlier
successful native outputs without replaying those games. The runner
copies exact retained primary+backup to a new private scratch directory.
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
from test_successor_hidden_paired_third_first import COMPLETE12
from test_successor_hidden_paired_next_return_settlement import PENDING as PRIOR
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

TEST = 'successor_hidden_paired_third_first_npcs'
COMPLETE14_SHA = "08ce00cf4ba915c62bbfbba90c3838663dc7035bc1cfd54b2c174cc0e90de204"
PARTIAL13 = ('730590c93459fe830777a003d844a92ffd043e754732375f03f1b2fc9e318d92', COMPLETE12[0])


def run(project, home, mode, godot):
    out = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                   'res://tests/'+TEST+'.tscn','--',mode],environment(home),420)
    assert 'HIDDEN_PAIRED_THIRD_FIRST_NPCS_PASS' in out


def raw_value(raw, marker):
    offset = raw.index(marker) + len(marker)
    decoded, end = json.JSONDecoder().raw_decode(raw,offset)
    return decoded, raw[offset:end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixture-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--resume-stage',type=Path)
    parser.add_argument('--retained-count',type=int,choices=(1,2))
    parser.add_argument('--prior-stage',required=True,type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot unavailable')
    if bool(args.resume_stage) != bool(args.retained_count):
        parser.error('--resume-stage and --retained-count are required together')
    origin = args.fixture_stage.resolve()/'third-human'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    starter = verify_fixture(slot_pair(origin), COMPLETE12)
    standard = verify_fixture(slot_pair(standard_path), STANDARD)
    legacy_path = args.prior_stage.resolve()/'next-return'/draft.SLOT
    legacy = verify_fixture(slot_pair(legacy_path),PRIOR)
    repo = Path(__file__).resolve().parents[1]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-third-first-npcs-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    for name in (TEST,'successor_hidden_paired_third_first','successor_hidden_paired_next_return_settlement',
                 'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                 'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    home = root/'third-first-npcs'
    primary = install(home,starter)
    phases = []
    completed_path = (args.resume_stage.resolve()/'third-first-npcs'/draft.SLOT
                      if args.resume_stage else None)
    completed = slot_pair(completed_path) if completed_path else None
    if args.retained_count == 1:
        verify_fixture(completed,PARTIAL13)
    elif args.retained_count == 2:
        verify_fixture(completed,(COMPLETE14_SHA,PARTIAL13[0]))
    previous = starter[0]
    marker = '"pending":'
    original, original_raw = raw_value(previous.decode(),marker)
    assert original['human'][0] == 12 and original['reports'] == []
    prior_reports = []
    first_raw = None
    for fixture in (13,14):
        # Each job uses a fresh process; NPC14 independently cold-checks
        # original human evidence plus the complete NPC13 report before launch.
        if completed is None or fixture - 12 > args.retained_count:
            run(project,home,'npc'+str(fixture),godot)
        else:
            primary.write_bytes(completed[args.retained_count - (fixture - 12)])
            Path(str(primary)+'.bak').write_bytes(previous)
            if args.retained_count == 2:
                run(project,home,'partial' if fixture==13 else 'cold',godot)
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
        assert [row['fixture'] for row in value['reports']] == list(range(13,fixture+1))
        assert value['reports'][:-1] == prior_reports
        previous = durable[0]
        prior_reports = value['reports']
        phases.append(durable)
    if args.retained_count != 2:
        run(project,home,'cold',godot)
    assert slot_pair(primary) == phases[-1]
    raw = phases[-1][0].decode()
    rows = []
    for fixture in (13,14):
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
    previous_owner = root/'prior'
    prior_path = install(previous_owner,legacy)
    old = 'successor_hidden_paired_third_first'
    (project/'tests'/(old+'.tscn')).write_text(
        (project/'tests'/(TEST+'.tscn')).read_text().replace(TEST,old))
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+old+'.tscn',
                   '--','legacy3'],environment(previous_owner),420)
    assert 'HIDDEN_PAIRED_THIRD_FIRST_PASS' in out and slot_pair(prior_path)==slot_pair(legacy_path)==legacy
    ordinary = root/'standard'
    ordinary_path = install(ordinary,standard)
    result = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                      '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in result and 'GATES=0' in result and slot_pair(ordinary_path)==standard
    assert slot_pair(origin)==starter and slot_pair(standard_path)==standard
    if completed_path:
        assert slot_pair(completed_path)==completed
    print('PASS: NPC 13 then 14 with fresh physical workloads, exact partial/complete cold and no new payout')


if __name__ == '__main__':
    main()
