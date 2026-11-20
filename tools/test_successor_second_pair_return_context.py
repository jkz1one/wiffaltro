#!/usr/bin/env python3
"""Pinned cp121 A/B: one exact local MatchState for private NPCs 10 and 11.

Generate --pending-stage from the cp120 next-return runner, and --paid-stage
from the cp121 next-return settlement runner. The latter includes the
independent Standard reference. No game simulation or external files.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
import test_successor_hidden_paired_draft as draft
from test_successor_hidden_paired_next_first import STANDARD
from test_successor_hidden_paired_next_return_settlement import PENDING, TEST, add_profile, archives
from test_successor_pair_history_context import execute
from test_successor_paired_resolver_context import install, once, slot_pair, verify_fixture
from test_successor_schedule_wiring import environment

BASE = 'c1c150cc56922c8b4752b843c4684985411e340d'
LEAF = 'src/gameplay/season/successor_live_play_v1/physical_fixtures.gd'
FAMILY = 'drafts/successor-live-play-v1/'
SOURCE = FAMILY + LEAF + '.txt'
SCRIPT = 'tools/test_successor_second_pair_return_context.py'
PAID = ('1d411717213a736f101dad5b28a06da9151a7dfaaeff16144484ff6032706acc', PENDING[0])
PROBE = '''extends RefCounted
static var counts: Dictionary={}
static var accepted: Array=[]
static func built(season: SeasonState,game: int) -> void:
 if season!=null and season.round_index==3 and game in [10,11]:
  counts[str(game)]=int(counts.get(str(game),0))+1
static func passed(season: SeasonState,game: int,key: String) -> void:
 if season.round_index==3 and game in [10,11]:accepted.append([game,key])
static func flush(phase: String) -> void:
 print("CP122_COUNTS ",JSON.stringify([phase,counts,accepted],"",true,true))
 counts.clear()
 accepted.clear()
'''


def instrument(source):
    source = once(source, 'extends SeasonPhysicalFixtures\n',
                  'extends SeasonPhysicalFixtures\nconst ContextProbe=preload("res://tests/second_pair_context_probe.gd")\n')
    start = 'static func match_for(season: SeasonState, fixture: Dictionary) -> MatchState:\n'
    source = once(source,start,start+'\tContextProbe.built(season,int(fixture.get("id",-1)))\n')
    passed = '\tcursor += 1\n\tvar result: Dictionary'
    return once(source,passed,'\tContextProbe.passed(season,int(fixture.id),row.request)\n'+passed)


def run(project,home,mode,godot):
    out = execute([godot,'--headless','--fixed-fps','60','--path',str(project),
                   'res://tests/'+TEST+'.tscn','--',mode],environment(home),480)
    assert 'HIDDEN_PAIRED_NEXT_RETURN_SETTLEMENT_PASS' in out
    counts = [json.loads(line.split(' ',1)[1]) for line in out.splitlines()
              if line.startswith('CP122_COUNTS ')]
    histories = [json.loads(line.split(' ',1)[1])[:6] for line in out.splitlines()
                 if line.startswith('CP121_HISTORY ')]
    writes = [line for line in out.splitlines() if line.startswith('CP121_WRITE ')]
    if mode == 'settle':
        assert histories==[[3,6,9,18,6,36],[3,6,9,18,6,36],[4,6,12,24,8,48]]
        assert len(writes)==1 and writes[0].endswith(' true')
    elif mode == 'cold':
        assert histories==[[4,6,12,24,8,48]] and not writes
    else:
        assert not writes
    return {phase:(c,fixtures) for phase,c,fixtures in counts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pending-stage',required=True,type=Path)
    parser.add_argument('--paid-stage',required=True,type=Path)
    parser.add_argument('--godot',default='godot')
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if godot is None or not hasattr(os,'sched_getaffinity'):
        parser.error('Requires Godot and Linux CPU affinity')
    cpus = os.sched_getaffinity(0)
    pinned = 1 if 1 in cpus else min(cpus)
    os.sched_setaffinity(0,{pinned})
    print('Matched A/B pinned Linux CPU:',pinned,flush=True)
    pending_path = args.pending_stage.resolve()/'next-return'/draft.SLOT
    paid_path = args.paid_stage.resolve()/'next-return-settlement'/draft.SLOT
    standard_path = args.paid_stage.resolve()/'standard'/draft.SLOT
    pending = verify_fixture(slot_pair(pending_path),PENDING)
    paid = verify_fixture(slot_pair(paid_path),PAID)
    standard = verify_fixture(slot_pair(standard_path),STANDARD)
    expected = [[r['fixture'],r['request']]
                for r in json.loads(pending[0])['ordinary']['physical']['pending']['reports']]
    assert [fixture for fixture,_ in expected] == [10,11]
    repo = Path(__file__).resolve().parents[1]
    scope = subprocess.check_output(['git','diff','--name-only',BASE],cwd=repo,text=True).splitlines()
    assert set(scope)<={SOURCE,FAMILY+'DRAFT_MANIFEST.json',SCRIPT}
    baseline = subprocess.check_output(['git','show',BASE+':'+SOURCE],cwd=repo).decode()
    current = (repo/SOURCE).read_text()
    root = Path(tempfile.mkdtemp(prefix='wiffaltro-second-pair-context-'))
    print('Retained disposable local stage:',root,flush=True)
    project = draft.stage(repo,root/'engine',(repo/'tests'/(draft.TEST+'.gd.txt')).read_bytes(),godot)
    add_profile(project)
    for name in (TEST,'successor_hidden_paired_next_return','successor_hidden_paired_next_first_settlement',
                 'successor_hidden_paired_next_first','successor_hidden_paired_return_settlement',
                 'successor_hidden_paired_return','successor_hidden_first_settlement'):
        (project/'tests'/(name+'.gd')).write_bytes((repo/'tests'/(name+'.gd.txt')).read_bytes())
    (project/'tests'/(TEST+'.tscn')).write_text(
        '[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://tests/'
        + TEST + '.gd" id="1"]\n[node name="Proof" type="Node"]\nscript = ExtResource("1")\n')
    test = project/'tests'/(TEST+'.gd')
    source = once(test.read_text(),'func run() -> void:',
                  'const ContextProbe=preload("res://tests/second_pair_context_probe.gd")\n\nfunc run() -> void:')
    for anchor,phase,indent in [('app.reload_save()','cold',' '),
                                 ('app._settle_paired_next_return_leg()\n print("SECOND_PAIR_PAID_CANDIDATE_MS=',
                                  'settle',' '),('app.retry_save()','retry',' ')]:
        first,_,rest = anchor.partition('\n')
        source = once(source,anchor,first+'\n'+indent+'ContextProbe.flush("'+phase+'")'
                      + ('\n'+rest if rest else ''))
    test.write_text(source)
    (project/'tests'/'second_pair_context_probe.gd').write_text(PROBE)
    assert (project/LEAF).read_text()==current
    for name, variant, n in [('before',baseline,2),('after',current,1)]:
        print('MATCHED',name,flush=True)
        (project/LEAF).write_text(instrument(variant))
        settle = root/(name+'-settle')
        cold = root/(name+'-cold')
        write_path, cold_path = install(settle,pending), install(cold,paid)
        exact = ({'10':n,'11':n},expected)
        assert run(project,settle,'settle',godot)=={'cold':exact,'settle':exact,'retry':({},[])}
        assert slot_pair(write_path)==paid
        assert run(project,cold,'cold',godot)=={'cold':({},[])}
        assert slot_pair(cold_path)==paid
    rows = archives(pending[0])
    _, head = rows[10].split(',"report":',1)
    _, tail = rows[11].split(',"report":',1)
    decoder = json.JSONDecoder()
    foreign = head[:decoder.raw_decode(head)[1]]
    terminal = tail[:decoder.raw_decode(tail)[1]]
    faults = {
        'pending-key': (once(pending[0].decode(),expected[-1][1],'0'*64),pending[1]),
        'pending-foreign-report': (once(pending[0].decode(),rows[11],once(rows[11],terminal,foreign)),pending[1]),
        'paid-older-key': (once(paid[0].decode(),json.loads(archives(paid[0])[5])['request'],'0'*64),paid[1]),
    }
    for label,(text,backup) in faults.items():
        case = root/('tamper-'+label)
        bad = text.encode(),backup
        path = install(case,bad)
        trace = run(project,case,'tamper-'+label,godot)
        assert not any(n==11 for n,_ in trace['cold'][1])
        assert slot_pair(path)==bad
    ordinary = root/'ordinary'
    path = install(ordinary,standard)
    out = execute([godot,'--headless','--path',str(project),'res://tests/'+draft.TEST+'.tscn',
                   '--','cold','standard'],environment(ordinary),180)
    assert 'HIDDEN_DRAFT_PASS' in out and 'GATES=0' in out and 'CP121_HISTORY' not in out
    assert slot_pair(path)==standard
    assert (slot_pair(pending_path),slot_pair(paid_path),slot_pair(standard_path))==(pending,paid,standard)
    print('PASS: 2→1 exact contexts for both fixtures; unchanged full history, raw bytes and refusal paths')


if __name__ == '__main__':
    main()
