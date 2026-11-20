#!/usr/bin/env python3
"""Matched cp114 vs current resolver profile; no games replayed.

Generate inputs with the source-only cp114
tools/test_successor_hidden_paired_return_settlement.py --fixture-stage <cp113-stage>.
Pass that cp113 stage as --pending-stage, and the cp114 output as --paid-stage
(it holds the paid pair and the admitted Standard fixture). Raw bytes stay local.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_pair_history_context import execute
from test_successor_schedule_wiring import environment

BASE = '1428fa2b111768e90f84a51647357e60bc8d5102'
LEAF = 'src/gameplay/season/successor_live_play_v1/physical_fixtures.gd'
SOURCE = 'drafts/successor-live-play-v1/' + LEAF + '.txt'
TEST = 'successor_hidden_paired_return_settlement'

PROBE = '''extends RefCounted
static var counts: Dictionary={}
static var accepted: Array=[]
static func built(id: int) -> void:
 if id in [4,5]:counts[str(id)]=int(counts.get(str(id),0))+1
static func passed(id: int, digest: String) -> void:
 if id in [4,5]:accepted.append([id,digest])
static func flush(phase: String) -> void:
 print("RESOLVER_PROFILE ",JSON.stringify([phase,counts,accepted],"",true,true))
 counts.clear()
 accepted.clear()
'''


def slot_pair(path):
    return tuple(Path(str(path) + suffix).read_bytes() for suffix in ('', '.bak'))


def verify_fixture(bytes_pair, expected):
    assert tuple(hashlib.sha256(data).hexdigest() for data in bytes_pair) == expected
    return bytes_pair


def install(home, pair):
    path = home / draft.SLOT
    path.parent.mkdir(parents=True)
    for suffix, data in zip(('', '.bak'), pair):
        Path(str(path) + suffix).write_bytes(data)
    return path


def once(source, old, new):
    assert source.count(old) == 1, old
    return source.replace(old, new, 1)


def instrument(source):
    source = once(source, 'extends SeasonPhysicalFixtures\n',
                  'extends SeasonPhysicalFixtures\nconst ResolverProbe=preload("res://tests/resolver_probe.gd")\n')
    signature = 'static func match_for(season: SeasonState, fixture: Dictionary) -> MatchState:\n'
    source = once(source, signature, signature + '\tResolverProbe.built(int(fixture.get("id",-1)))\n')
    accept = '\tcursor += 1\n\tvar result: Dictionary'
    return once(source, accept, '\tResolverProbe.passed(int(fixture.id),row.request)\n' + accept)


def native(project, godot, home, mode):
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    start = time.perf_counter()
    output = execute([godot, '--headless', '--fixed-fps', '60', '--path', str(project),
                      'res://tests/' + TEST + '.tscn', '--', mode], environment(home), 420)
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    print('PROCESS seconds wall/user/system', round(time.perf_counter()-start, 3),
          round(after.ru_utime-before.ru_utime, 3), round(after.ru_stime-before.ru_stime, 3), flush=True)
    assert 'HIDDEN_PAIRED_RETURN_SETTLEMENT_PASS' in output
    return {phase: (counts, archives) for phase, counts, archives in
            (json.loads(line.split(' ', 1)[1]) for line in output.splitlines()
             if line.startswith('RESOLVER_PROFILE '))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pending-stage', required=True, type=Path)
    parser.add_argument('--paid-stage', required=True, type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot unavailable')
    affinity = os.sched_getaffinity(0)
    cpu = 1 if 1 in affinity else min(affinity)
    os.sched_setaffinity(0, {cpu})
    print('Same Linux vCPU for both variants:', cpu, 'of', sorted(affinity), flush=True)
    cp113_disk = args.pending_stage.resolve() / 'return-npcs' / draft.SLOT
    cp114_disk = args.paid_stage.resolve() / 'settlement' / draft.SLOT
    standard_disk = args.paid_stage.resolve() / 'ordinary' / draft.SLOT
    pending = verify_fixture(slot_pair(cp113_disk), (
        '781b4392e33d95ed8ac44d1eabf4920fd56e0e633e99ec7f249f52378f6947e9',
        'dd4ed382ea0b3c13b5ad0ba34fe6e6d7eeffb288d8892e10de073036d75462a8'))
    paid = verify_fixture(slot_pair(cp114_disk), (
        'df33238b26a8fe17136b5f9ace57e175a0ac2bd7db09ea8fffa997bed6ff014d',
        '781b4392e33d95ed8ac44d1eabf4920fd56e0e633e99ec7f249f52378f6947e9'))
    standard = verify_fixture(slot_pair(standard_disk), (
        'd93a1df232c150e34752db3f598095bee230051e527ae9ed5292690b25fdb2d4',
        '9c4361ddd6d613bfb03e7415f2e90317f49416f5388db74655c76f5122031985'))
    repo = Path(__file__).resolve().parents[1]
    scoped = subprocess.check_output(['git','diff','--name-only',BASE], cwd=repo, text=True).splitlines()
    assert set(scoped) <= {SOURCE, 'drafts/successor-live-play-v1/DRAFT_MANIFEST.json',
                           'tools/test_successor_paired_resolver_context.py'}
    expected = [[r['fixture'], r['request']] for r in
                json.loads(pending[0])['ordinary']['physical']['pending']['reports']]
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-paired-resolver-'))
    print('Retained isolated stage:', root, flush=True)
    project = draft.stage(repo, root / 'engine', (repo / 'tests' / (draft.TEST + '.gd.txt')).read_bytes(), godot)
    native_paths = project / 'tests'
    for name in [TEST, 'successor_hidden_paired_return', 'successor_hidden_first_settlement']:
        (native_paths / (name + '.gd')).write_bytes((repo / 'tests' / (name + '.gd.txt')).read_bytes())
    test = native_paths / (TEST + '.gd')
    code = once(test.read_text(), 'func run() -> void:', 'const ResolverProbe=preload("res://tests/resolver_probe.gd")\n\nfunc run() -> void:')
    for anchor, phase in [('app.reload_save()', 'cold'),
                          ('app._settle_paired_return_leg()\n print("PAIR_SETTLEMENT_CANDIDATE_MS=', 'settle'),
                          ('app.retry_save()\n print("PAIR_SETTLEMENT_RETRY', 'retry')]:
        first, _, rest = anchor.partition('\n')
        code = once(code, anchor, first + f'\n ResolverProbe.flush("{phase}")' + ('\n' + rest if rest else ''))
    test.write_text(code)
    (native_paths / 'resolver_probe.gd').write_text(PROBE)
    (native_paths / (TEST + '.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    prior = subprocess.check_output(['git','show',BASE+':'+SOURCE], cwd=repo).decode()
    current = (repo / SOURCE).read_text()
    assert (project / LEAF).read_text() == current
    for name, source, count in [('before', prior, 2), ('after', current, 1)]:
        print('MATCHED PROFILE', name, flush=True)
        (project / LEAF).write_text(instrument(source))
        settle_home, cold_home = (root / (name + '-' + mode) for mode in ('settle', 'cold'))
        settle_path, cold_path = install(settle_home,pending), install(cold_home,paid)
        traces = native(project,godot,settle_home,'settle')
        assert traces == {'cold': ({'4':count,'5':count}, expected),
                          'settle': ({'4':count,'5':count}, expected), 'retry': ({}, [])}
        assert slot_pair(settle_path) == paid
        assert native(project,godot,cold_home,'cold') == {'cold': ({}, [])}
        assert slot_pair(cold_path) == paid
    for name, pair, prefix in [('pending', pending, ('physical','pending','reports')),
                               ('paid', paid, ('physical','reports'))]:
        frame = json.loads(pair[0])
        reports = frame['ordinary']
        for key in prefix:
            reports = reports[key]
        digest = ('"request":"' + reports[-1]['request'] + '"').encode()
        assert pair[0].count(digest) == 1
        changed = (pair[0].replace(digest, b'"request":"' + b'0'*64+b'"'), pair[1])
        home = root / ('tamper-' + name)
        path = install(home,changed)
        native(project,godot,home,'tamper-' + name)
        assert slot_pair(path) == changed
    home = root / 'standard-cold'
    path = install(home,standard)
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                   '--','cold','standard'],environment(home),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and slot_pair(path) == standard
    assert slot_pair(cp113_disk)==pending and slot_pair(cp114_disk)==paid and slot_pair(standard_disk)==standard
    print('PASS: exact keys/bytes and two→one construction per fixture; both corruption cases and Standard cold')


if __name__ == '__main__':
    main()
