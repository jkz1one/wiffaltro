#!/usr/bin/env python3
"""Resume bounded genuine career play QA; preserve every stage/save/log.

Use --source only to create a new stage from an actual fully drafted fresh save.
Resume an existing stage without --source. Never invent results or overwrite logs.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import assemble_successor

SCENE = 'res://tests/successor_owner_career_play.tscn'
TESTS = ['tests/successor_owner_career_play.gd', 'tests/successor_owner_career_play.tscn']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--source', type=Path)
    parser.add_argument('--max-steps', type=int, default=6)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    if not 1 <= args.max_steps <= 8:
        parser.error('max-steps must be 1..8')
    stage = args.stage.resolve()
    data = stage/'data/godot/app_userdata/Wiffaltro'
    fixture = data/'source-career-play.json'
    if args.source:
        if stage.exists():
            raise RuntimeError('New-source stage must not exist')
        source = args.source.resolve()
        raw = source.read_bytes()
        record = json.loads(raw)
        if record.get('origin_close') != 'fresh' or record.get('active', {}).get('id') != 1:
            raise RuntimeError('Expected actual fresh run1 source')
        assemble_successor.assemble(Path(__file__).resolve().parents[1], stage/'project', TESTS)
        data.mkdir(parents=True)
        fixture.write_bytes(raw)
        (data/'successor-owned-career-live-v3.json').write_bytes(raw)
        (stage/'INPUT.json').write_text(json.dumps({'source_sha256':digest(fixture)},indent=2)+'\n')
    identity = json.loads((stage/'INPUT.json').read_text())
    if digest(fixture) != identity['source_sha256']:
        raise RuntimeError('Immutable input changed')
    assembly = json.loads((stage/'project/ASSEMBLY.json').read_text())
    for name, expected in assembly['files'].items():
        if digest(stage/'project'/name) != expected:
            raise RuntimeError(f'Staged source changed: {name}')
    env = os.environ.copy()
    for key, folder in [('HOME','home'),('XDG_DATA_HOME','data'),('XDG_CACHE_HOME','cache'),('XDG_CONFIG_HOME','config')]:
        path = stage/folder
        path.mkdir(exist_ok=True)
        env[key] = str(path)
    env['WIFFALTRO_ISOLATED_TEST'] = '1'
    def run(mode):
        index = 0
        while (stage/f'{mode}-{index:03d}.log').exists():
            index += 1
        log = stage/f'{mode}-{index:03d}.log'
        command = [args.godot,'--headless','--path',str(stage/'project')]
        # Same60Hz physics as the existing qualification runner, without wall
        # clock synchronization. This accelerates QA, not player performance.
        command += ['--editor','--import','--quit'] if mode == 'import' else ['--fixed-fps','60',SCENE,'--',mode]
        print(f'Running {mode}; preserving {log.name}',flush=True)
        with log.open('xb') as output:
            completed = subprocess.run(command,env=env,stdout=output,stderr=subprocess.STDOUT)
        text = log.read_text(errors='replace')
        if completed.returncode or any(marker in text for marker in ['FAIL:','SCRIPT ERROR:','Parse Error:']):
            raise RuntimeError(f'{mode} failed; preserve stage and inspect {log.name}')
        if mode != 'import' and 'PASS: actual fresh117' not in text:
            raise RuntimeError(f'{mode} exited without qualification marker')
    def complete():
        pairs = sorted((data/'owned-career-play-evidence').glob('*.meta.json'))
        return bool(pairs and json.loads(pairs[-1].read_text()).get('complete'))
    if not (stage/'project/.godot/global_script_class_cache.cfg').exists():
        run('import')
    for _ in range(args.max_steps):
        if complete():
            break
        run('step')
    if complete():
        run('cold')
        print('Verified one genuine fresh round/shop and separate cold process; not Dynasty or release.',flush=True)
    else:
        print('Preserved bounded partial progress; resume this stage without --source.',flush=True)
    if digest(fixture) != identity['source_sha256']:
        raise RuntimeError('Input modified during QA')

if __name__ == '__main__':
    main()
