#!/usr/bin/env python3
"""Compare exact cp115 and scoped paid V4 return workload reuse on one Linux CPU.

Regenerate --pending-stage via tools/test_successor_hidden_paired_return_npcs.py
and --paid-stage via tools/test_successor_hidden_paired_return_settlement.py at
cp114, as documented by those runners. No games are run by this comparison.
All save copies, including malformed primaries, stay in the isolated scratch.
"""
import argparse
from collections import Counter
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, native, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

BASE = 'e30bf5c9ab61f404e09af58d29f090f6caae023e'
LEAF = 'src/gameplay/season/successor_settled_workload_v1/npc_report.gd'
FAMILY = 'drafts/successor-settled-workload-v1/'
SOURCE = FAMILY + 'npc_report.gd.txt'
FROZEN = 'drafts/successor-league-general-v2/src/gameplay/season/successor_league_general_v2/'
TEST = 'successor_hidden_paired_return_settlement'
PROBE = '''extends RefCounted
static var counts: Dictionary={}
static var accepted: Array=[]
static func called(game: int, path: String) -> void:
 var key: String=str(game)+":"+path
 counts[key]=int(counts.get(key,0))+1
static func passed(game: int, digest: String) -> void:
 accepted.append([game,digest])
static func flush(phase: String) -> void:
 print("RESOLVER_PROFILE ",JSON.stringify([phase,counts,accepted],"",true,true))
 counts.clear()
 accepted.clear()
'''


def instrument(source, optimized):
    source = once(source, 'extends RefCounted\n',
                  'extends RefCounted\nconst Probe=preload("res://tests/workload_probe.gd")\n')
    source = once(source, 'if not Report.matches(report,state):',
                  'Probe.called(game,"matches")\n\tif not Report.matches(report,state):')
    source = once(source, 'for side: int in range(2):',
                  'for side: int in range(2):\n\t\tProbe.called(game,"local" if v4_return else "human")'
                  if optimized else 'for side: int in range(2):\n\t\tProbe.called(game,"human")')
    return once(source, '\n\treturn true', '\n\tProbe.passed(game,archive.request)\n\treturn true')


def fixtures(args):
    paths = (args.pending_stage.resolve() / 'return-npcs' / draft.SLOT,
             args.paid_stage.resolve() / 'settlement' / draft.SLOT,
             args.paid_stage.resolve() / 'ordinary' / draft.SLOT)
    digests = (
        ('781b4392e33d95ed8ac44d1eabf4920fd56e0e633e99ec7f249f52378f6947e9',
         'dd4ed382ea0b3c13b5ad0ba34fe6e6d7eeffb288d8892e10de073036d75462a8'),
        ('df33238b26a8fe17136b5f9ace57e175a0ac2bd7db09ea8fffa997bed6ff014d',
         '781b4392e33d95ed8ac44d1eabf4920fd56e0e633e99ec7f249f52378f6947e9'),
        ('d93a1df232c150e34752db3f598095bee230051e527ae9ed5292690b25fdb2d4',
         '9c4361ddd6d613bfb03e7415f2e90317f49416f5388db74655c76f5122031985'))
    return paths, tuple(verify_fixture(slot_pair(path), pair) for path, pair in zip(paths, digests))


def variants(raw):
    raw = raw.decode()
    rows = json.loads(raw)['ordinary']['physical']['reports']
    decoder = json.JSONDecoder()
    slices = []
    for n in (4, 5):
        start = raw.index('{"fixture":%d.0,"report":{"dynasty_start"' % n)
        _, end = decoder.raw_decode(raw, start)
        slices.append(raw[start:end])
    first, last = slices
    assert raw.count(first + ',' + last) == 1
    yield 'missing', once(raw, ',' + last, '').encode(), False
    yield 'reordered', once(raw, first + ',' + last, last + ',' + first).encode(), False
    yield 'request', once(raw, rows[-1]['request'], '0'*64).encode(), False
    body_start = last.index(',"report":') + len(',"report":')
    _, body_end = decoder.raw_decode(last, body_start)
    terminal = last[body_start:body_end]
    field = terminal.rindex(',"workload":') + len(',"workload":')
    _, end = decoder.raw_decode(terminal, field)
    malformed = terminal[:field] + '[{},{}]' + terminal[end:]
    yield 'malformed', once(raw,last,once(last,terminal,malformed)).encode(), True
    body_start = first.index(',"report":') + len(',"report":')
    _, body_end = decoder.raw_decode(first, body_start)
    foreign = first[body_start:body_end]
    yield 'foreign-report', once(raw,last,once(last,terminal,foreign)).encode(), False
    # Keep valid outer report shape and the exact owned scores/request. Only
    # substitute the other fixture's independently genuine workload evidence.
    start = foreign.rindex(',"workload":') + len(',"workload":')
    _, stop = decoder.raw_decode(foreign,start)
    foreign_workload = terminal[:field] + foreign[start:stop] + terminal[end:]
    assert foreign_workload != terminal
    yield 'foreign-workload', once(raw,last,once(last,terminal,foreign_workload)).encode(), True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pending-stage', required=True, type=Path)
    parser.add_argument('--paid-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    cpus = os.sched_getaffinity(0)
    cpu = 1 if 1 in cpus else min(cpus)
    os.sched_setaffinity(0, {cpu})
    print('Same Linux vCPU for both variants:', cpu, 'of', sorted(cpus), flush=True)
    paths, original = fixtures(args)
    pending, paid, standard = original
    repo = Path(__file__).resolve().parents[1]

    def frozen(path):
        return subprocess.check_output(['git','show',BASE+':'+path], cwd=repo).decode()

    report = frozen(FROZEN+'physical_report.gd.txt')
    matches = report.split('static func matches(',1)[1].split('\nstatic func ',1)[0]
    human = report.split('static func human(',1)[1].split('\nstatic func ',1)[0]
    assert matches.count('valid(value, state.pitch_catalog)') == human.count('valid(value, pitch_catalog)') == 1
    assert 'valid_for_team(' in matches and 'LeagueRules.doubleheader(value.league_rules)' in human
    current = (repo / SOURCE).read_text()
    envelope = '{"version":Workload.VERSION,"pair":report.pair[side].duplicate(true),"proof":report.workload[side].duplicate(true)}'
    frozen_envelope = human.split('return {"version":',1)[1].strip()
    frozen_envelope = '{"version":' + frozen_envelope.replace(
        'load("res://'+FROZEN.removeprefix('drafts/successor-league-general-v2/')+'physical_workload.gd").VERSION',
        'Workload.VERSION').replace('value.', 'report.').replace('[index]', '[side]')
    assert ''.join(frozen_envelope.split()) == envelope and current.count(envelope) == 1
    assert report == (repo / (FROZEN+'physical_report.gd.txt')).read_text()
    scoped = subprocess.check_output(['git','diff','--name-only',BASE],cwd=repo,text=True).splitlines()
    assert set(scoped) <= {SOURCE, FAMILY+'DRAFT_MANIFEST.json', 'tools/test_successor_paid_return_workload.py'}

    root = Path(tempfile.mkdtemp(prefix='wiffaltro-paid-return-workload-'))
    print('Retained isolated stage:', root, flush=True)
    project = draft.stage(repo, root / 'engine', (repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(), godot)
    target = project/'tests'
    for name in [TEST, 'successor_hidden_paired_return', 'successor_hidden_first_settlement']:
        (target/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    test = target/(TEST+'.gd')
    script = once(test.read_text(), 'func run() -> void:',
                  'const Probe=preload("res://tests/workload_probe.gd")\n\nfunc run() -> void:')
    for anchor, phase in [('app.reload_save()', 'cold'),
                          ('app._settle_paired_return_leg()\n print("PAIR_SETTLEMENT_CANDIDATE_MS=', 'settle'),
                          ('app.retry_save()\n print("PAIR_SETTLEMENT_RETRY', 'retry')]:
        first, _, rest = anchor.partition('\n')
        script = once(script,anchor,first+f'\n Probe.flush("{phase}")'+('\n'+rest if rest else ''))
    test.write_text(script)
    (target/'workload_probe.gd').write_text(PROBE)
    (target/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    expected = [[r['fixture'],r['request']] for r in json.loads(paid[0])['ordinary']['physical']['reports']]
    def counts(rows, optimized):
        out = Counter()
        for n, _ in rows:
            out[f'{int(n)}:matches'] += 1
            out[f'{int(n)}:'+('local' if optimized and n in (4,5) else 'human')] += 2
        return dict(out)
    assert (project/LEAF).read_text() == current
    for name,source,optimized in [('before',frozen(SOURCE),False),('after',current,True)]:
        print('MATCHED PROFILE',name,flush=True)
        (project/LEAF).write_text(instrument(source,optimized))
        settle_home, cold_home = (root/(name+'-'+mode) for mode in ('settle','cold'))
        settle_path,cold_path = install(settle_home,pending),install(cold_home,paid)
        full = (counts(expected,optimized),expected)
        # Candidate authenticates the previous paid first leg; independent
        # paid admission then validates all four archives on the new owner.
        settling = expected[:2] + expected
        assert native(project,godot,settle_home,'settle') == {
            'cold':(counts(expected[:2],False),expected[:2]),'settle':(counts(settling,optimized),settling),'retry':({},[])}
        assert slot_pair(settle_path) == paid
        assert native(project,godot,cold_home,'cold') == {'cold':full}
        assert slot_pair(cold_path) == paid
    for name,raw,reaches_match in variants(paid[0]):
        home = root/('tamper-'+name)
        pair = raw,paid[1]
        path = install(home,pair)
        trace, accepted = native(project,godot,home,'tamper-'+name)['cold']
        assert not any(n==5 for n,_ in accepted) and not trace.get('5:local')
        if reaches_match:
            assert trace.get('5:matches') == 1
        assert slot_pair(path) == pair
    home = root/'standard-cold'
    path = install(home,standard)
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                   '--','cold','standard'],environment(home),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(path) == standard
    assert tuple(slot_pair(path) for path in paths) == original
    print('PASS: exact archived envelopes and paid bytes, 3→1 full validations per return report (first unchanged)')


if __name__ == '__main__':
    main()
