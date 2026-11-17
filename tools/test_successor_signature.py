#!/usr/bin/env python3
"""Restore the inactive draft into an isolated project and test real Godot persistence.
Never launches the source checkout or reads/writes the owner's Godot user data.
The temporary evidence directory is retained, printed, and must never be published.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--expect-broken', action='store_true')
    mode.add_argument('--flow', action='store_true', help='Run draft UI and one actual native match instead of the signature-only suite')
    mode.add_argument('--round', action='store_true', help='Run actual three-game round and earned pack purchase suite')
    mode.add_argument('--shop-fixture', type=Path, help='Read-only previously earned isolated round save; copied to a new isolated test directory')
    mode.add_argument('--recruit', action='store_true', help='Run controlled build-ledger recruitment and cold replay, not actual-game qualification')
    mode.add_argument('--dugout', action='store_true', help='Run live Dugout admission/request/cold suite, not completed gameplay')
    mode.add_argument('--dugout-round', action='store_true', help='Run actual live Dugout human game, cold pending resume, AI round and earned pack')
    mode.add_argument('--dugout-pending-fixture', type=Path, help='Audit a read-only isolated actual human+one-AI pending checkpoint')
    mode.add_argument('--identity', action='store_true', help='Check local signature helper equivalence and scoped timings')
    mode.add_argument('--career-fixture', type=Path, help='Capture and cold-verify career evidence from an isolated actual settled checkpoint')
    mode.add_argument('--owner', action='store_true', help='Verify genuine fresh owner, all initial access and draft-only cold replay')
    mode.add_argument('--owner-round', action='store_true', help='Run genuine owned human game, cold pending resume, actual AI settlement and earned shop')
    mode.add_argument('--owner-performance-fixture', type=Path, help='Compare baseline and resource-retaining facade on an isolated actual owned checkpoint')
    mode.add_argument('--completion-fixture', type=Path, help='Verify pure successor metrics and synthetic receipt policy against actual owned-round evidence')
    mode.add_argument('--assets-fixture', type=Path, help='Verify successor asset basis and synthetic award policies against isolated actual owned evidence')
    mode.add_argument('--terminal-policy', action='store_true', help='Synthetic terminal outcome policy checks; not physical completion')
    mode.add_argument('--terminal-birth', action='store_true', help='Verify additive terminal owner birth and cold draft replay only')
    mode.add_argument('--terminal-round', action='store_true', help='Verify actual round/shop under additive terminal owner; not full-season completion')
    mode.add_argument('--terminal-batch-fixture', type=Path, help='One cold-entry same-App round from an immutable actual earned owner boundary')
    mode.add_argument('--terminal-season', action='store_true', help='Play a full actual first owned season, one cold durable boundary per process')
    mode.add_argument('--recapture-fixture', type=Path, help='Measure private transaction-local row reuse against isolated actual112 evidence')
    mode.add_argument('--history-fixture', type=Path, help='Verify pure closed-prefix legacy109 exotic history; no owner admission')
    mode.add_argument('--general-build', action='store_true', help='Structural generalized Build matrix only; public Game114 season admission remains closed')
    mode.add_argument('--general-physical', action='store_true', help='Ordinary single-game physical context tests only; no owned season admission')
    mode.add_argument('--general-birth', action='store_true', help='General ordinary season birth/draft exact cold replay')
    mode.add_argument('--general-round', action='store_true', help='General actual ordinary season round/earned shop/cold replay')
    mode.add_argument('--general-equipment', action='store_true', help='Actual earned Equipment sequence across three rounds and cold durable boundaries')
    mode.add_argument('--equipment-unit', action='store_true', help='Synthetic Equipment capacity and rejection policies only')
    parser.add_argument('--equipment-resume-stage', type=Path, help='Resume only an exact-source isolated Equipment stage')
    mode.add_argument('--doubleheader-round', action='store_true', help='Actual two-leg Doubleheader round/shop/cold qualification')
    parser.add_argument('--doubleheader-resume-stage', type=Path, help='Resume only exact-source isolated Doubleheader stage')
    mode.add_argument('--returning-recruit', action='store_true', help='Actual earned Standard release/return across six rounds; separate final cold')
    parser.add_argument('--returning-recruit-resume-stage', type=Path, help='Resume exact-source isolated returning recruit sequence')
    mode.add_argument('--recruit-pair-fixture', type=Path, help='Continue authentic Doubleheader pair through earned fresh recruitment and next pair')
    parser.add_argument('--recruit-pair-resume-stage', type=Path, help='Resume exact-source isolated recruitment sequence')
    mode.add_argument('--continuation-fixture', type=Path, help='Closed predecessor reader against immutable actual owner112 boundary evidence')
    parser.add_argument('--continuation-prefix', action='store_true', help='Derive closed run2 start basis only; no owner admission')
    parser.add_argument('--continuation-completed', action='store_true', help='Require actual terminal positive projection; never use synthetic completion')
    mode.add_argument('--owned-general-season-fixture', type=Path, help='Continue an actual paid fresh-owned General checkpoint through a full season and final cold')
    mode.add_argument('--owned-general-fresh', action='store_true', help='Actual App fresh owned General birth, draft, round, earned shop and cold reopen without predecessor fixture')
    mode.add_argument('--owned-general-fixture', type=Path, help='Integrated owned run2 negative boundary from authentic active Owner112 evidence')
    parser.add_argument('--owned-general-completed', action='store_true', help='Require actual terminal112 predecessor and actual owned run2 round/shop/cold')
    parser.add_argument('--owned-general-resume-stage', type=Path, help='Resume exact-source isolated owned integration or full-season sequence')
    mode.add_argument('--next-owner-fixture', type=Path, help='Draft-only owned run2 qualification; requires actual terminal for positive mode')
    parser.add_argument('--next-owner-birth-fixture', type=Path, help='Original isolated Owner112 birth for negative checks')
    parser.add_argument('--next-owner-completed', action='store_true', help='Require real terminal predecessor, birth/four picks/cold; no gameplay admission')
    parser.add_argument('--continuation-birth-fixture', type=Path, help='Original isolated birth when current evidence comes from a round-batch archive')
    mode.add_argument('--persistent-identity', action='store_true', help='Read-only partial authored identity and cold deterministic projection')
    mode.add_argument('--general-career-fixture', type=Path, help='Strict General114 checkpoint-to-career evidence only, not owner admission')
    parser.add_argument('--general-career-profile', choices=['standard','doubleheader','recruit'], default='standard')
    mode.add_argument('--shop-app-fixture', type=Path, help='Actual reroll App confirmation/retention/retry and cold replay')
    parser.add_argument('--shop-app-scenario', choices=['success','fault','reference'], default='success')
    mode.add_argument('--physical-validation-fixture', type=Path, help='Unbound ordinary report validator parity on actual current-source history')
    parser.add_argument('--physical-validation-doubleheader', action='store_true', help='Require unchanged Doubleheader delegate parity')
    mode.add_argument('--shop-transaction-fixture', type=Path, help='Unbound fixed shop transaction against authentic paid Standard fixture')
    parser.add_argument('--shop-transaction-mode', choices=['equal','format','different','malformed','fault'], default='equal')
    mode.add_argument('--general-save-cost-fixture', type=Path, help='Diagnose distinct save validation costs on copied actual current-source evidence')
    mode.add_argument('--general-doubleheader', action='store_true', help='Doubleheader adapter policy foundation; no actual paired gameplay proof')
    mode.add_argument('--general-scramble', action='store_true', help='Seed-exact Scramble profiles, UI and cold draft verification')
    parser.add_argument('--scramble-flows', action='store_true', help='Verify actual earned Scramble upgrade against unchanged permutation policy')
    mode.add_argument('--general-prefix', action='store_true', help='Fresh six-profile private human-prefix replay equivalence')
    parser.add_argument('--prefix-replay', action='store_true', help='Current-source actual history prefix replay parity after round or Equipment sequence')
    mode.add_argument('--general-signature', action='store_true', help='Exact one-Provider signature parity, mutation and diagnostic timing')
    parser.add_argument('--signature-benchmark', action='store_true', help='After general actual round/cold, audit current paid fixture and signature parity/timing')
    mode.add_argument('--general-interrupt', action='store_true', help='General App cancel, close and retained-write guards')
    parser.add_argument('--academy-flows', action='store_true', help='Qualify actual earned Academy first-pick retry and separate cold second/skip branches')
    parser.add_argument('--interrupt-flows', action='store_true', help='Test actual pending close and isolated earned shop confirmation during general round')
    mode.add_argument('--general-economies', action='store_true', help='Original Sponsorship/Earnings policy and paid synthetic unit mechanics')
    parser.add_argument('--resolve-benchmark', action='store_true', help='After a fresh general round, compare immediate report reuse against full validation')
    parser.add_argument('--general-profile', choices=['standard', 'dugout', 'sponsorship', 'earnings', 'academy', 'equipment', 'scramble', 'doubleheader'], default='standard')
    parser.add_argument('--terminal-resume-stage', type=Path, help='Resume only an exact-source isolated --terminal-season stage')
    parser.add_argument('--facade', action='store_true', help='Use the additive resource-retaining UI facade during --owner-round')
    args = parser.parse_args()
    if args.owned_general_completed and not args.owned_general_fixture:
        parser.error('Owned General completion/resume requires --owned-general-fixture')
    if args.owned_general_resume_stage and not (args.owned_general_completed or args.owned_general_fresh or args.owned_general_season_fixture):
        parser.error('--owned-general-resume-stage requires completed fixture or --owned-general-fresh')
    if args.returning_recruit_resume_stage and not args.returning_recruit:
        parser.error('--returning-recruit-resume-stage requires --returning-recruit')
    if args.recruit_pair_resume_stage and not args.recruit_pair_fixture:
        parser.error('--recruit-pair-resume-stage requires --recruit-pair-fixture')
    if args.continuation_prefix and not args.continuation_fixture:
        parser.error('--continuation-prefix requires --continuation-fixture')
    if args.continuation_completed and not args.continuation_fixture:
        parser.error('--continuation-completed requires --continuation-fixture')
    if args.general_profile == 'doubleheader' and not args.general_birth:
        parser.error('Doubleheader profile is for --general-birth; actual paired play uses --doubleheader-round')
    if args.doubleheader_resume_stage and not args.doubleheader_round:
        parser.error('--doubleheader-resume-stage requires --doubleheader-round')
    if args.equipment_resume_stage and not args.general_equipment:
        parser.error('--equipment-resume-stage requires --general-equipment')
    if args.scramble_flows and (not args.general_round or args.general_profile != 'scramble'):
        parser.error('--scramble-flows requires --general-round --general-profile scramble')
    if args.prefix_replay and not (args.general_round or args.general_equipment):
        parser.error('--prefix-replay requires --general-round or --general-equipment')
    if args.signature_benchmark and not args.general_round:
        parser.error('--signature-benchmark requires --general-round')
    if args.academy_flows and (not args.general_round or args.general_profile != 'academy'):
        parser.error('--academy-flows requires --general-round --general-profile academy')
    if args.interrupt_flows and not args.general_round:
        parser.error('--interrupt-flows requires a fresh --general-round')
    if args.resolve_benchmark and not args.general_round:
        parser.error('--resolve-benchmark requires a fresh --general-round')
    if args.facade and not args.owner_round:
        parser.error('--facade requires --owner-round')
    if args.terminal_resume_stage and not args.terminal_season:
        parser.error('--terminal-resume-stage requires --terminal-season')
    root = Path(__file__).resolve().parents[1]
    resume_stage = args.terminal_resume_stage or args.equipment_resume_stage or args.doubleheader_resume_stage or args.recruit_pair_resume_stage or args.returning_recruit_resume_stage or args.owned_general_resume_stage
    stage = resume_stage.resolve() if resume_stage else Path(tempfile.mkdtemp(prefix='wiffaltro-signature-'))
    assert stage.is_dir() and stage.name.startswith('wiffaltro-signature-')
    project = stage / 'project'
    if resume_stage:
        assert (project / 'project.godot').read_bytes() == (root / 'project.godot').read_bytes()
        for source in (root / 'src').rglob('*'):
            if source.is_file():
                assert (project / source.relative_to(root)).read_bytes() == source.read_bytes(), source
    else:
        project.mkdir()
        shutil.copytree(root / 'src', project / 'src')
        shutil.copy2(root / 'project.godot', project / 'project.godot')
        (project / 'tests').mkdir()
    names = ['successor_signature.gd', 'successor_signature.tscn']
    if args.flow or args.round or args.shop_fixture:
        names += ['successor_flow.gd', 'successor_flow.tscn']
    if args.round or args.shop_fixture:
        names += ['successor_round.gd', 'successor_round.tscn', 'successor_shop.gd', 'successor_shop.tscn']
    if args.recruit:
        names += ['successor_recruit.gd', 'successor_recruit.tscn']
    if args.dugout or args.dugout_round or args.dugout_pending_fixture or args.identity or args.career_fixture or args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        names += ['successor_dugout_live.gd', 'successor_dugout_live.tscn', 'successor_dugout_round.gd', 'successor_dugout_round.tscn', 'successor_dugout_integrity.gd', 'successor_dugout_integrity.tscn']
    if args.identity:
        names += ['successor_identity.gd', 'successor_identity.tscn']
    if args.owner_performance_fixture:
        names += ['successor_owner_performance.gd', 'successor_owner_performance.tscn']
    if args.owner_round:
        names += ['successor_owner_round.gd', 'successor_owner_round.tscn']
    if args.owner:
        names += ['successor_owner.gd', 'successor_owner.tscn']
    if args.career_fixture:
        names += ['successor_career.gd', 'successor_career.tscn']
    for name in names:
        if resume_stage:
            assert (project / 'tests' / name).read_bytes() == (root / 'tests' / (name + '.txt')).read_bytes()
            continue
        shutil.copy2(root / 'tests' / (name + '.txt'), project / 'tests' / name)
    manifest = json.loads((root / 'drafts/successor-v7/DRAFT_MANIFEST.json').read_text())
    assert len(manifest['files']) == 47
    entries = manifest['files'] + manifest.get('additions', [])
    if args.dugout or args.dugout_round or args.dugout_pending_fixture or args.identity or args.career_fixture or args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        league_manifest = json.loads((root / 'drafts/successor-league-v1/DRAFT_MANIFEST.json').read_text())
        entries += league_manifest['files'] + league_manifest.get('additions', [])
    if args.career_fixture or args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        career_manifest = json.loads((root / 'drafts/successor-career-v1/DRAFT_MANIFEST.json').read_text())
        entries += career_manifest['files']
    if args.owner or args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        owner_manifest = json.loads((root / 'drafts/successor-owner-v1/DRAFT_MANIFEST.json').read_text())
        entries += owner_manifest['files']
    if args.owner_round or args.owner_performance_fixture or args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        live_owner_manifest = json.loads((root / 'drafts/successor-owner-live-v1/DRAFT_MANIFEST.json').read_text())
        entries += live_owner_manifest['files'] + live_owner_manifest.get('additions', [])
    if args.owner_performance_fixture or args.facade:
        facade_manifest = json.loads((root / 'drafts/successor-owner-ui-v1/DRAFT_MANIFEST.json').read_text())
        entries += facade_manifest['files']
    if args.completion_fixture or args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        completion_manifest = json.loads((root / 'drafts/successor-career-completion-v1/DRAFT_MANIFEST.json').read_text())
        entries += completion_manifest['files']
    if args.assets_fixture or args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        entries += json.loads((root / 'drafts/successor-career-assets-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.terminal_birth or args.terminal_round or args.terminal_batch_fixture or args.terminal_season or args.terminal_policy or args.recapture_fixture or args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        entries += json.loads((root / 'drafts/successor-owner-terminal-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.recapture_fixture:
        entries += json.loads((root / 'drafts/successor-owner-recapture-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.history_fixture or args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        entries += json.loads((root / 'drafts/successor-career-history-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.general_build or args.general_physical or args.general_birth or args.general_round or args.general_economies or args.general_interrupt or args.general_signature or args.general_prefix or args.general_scramble or args.recruit_pair_fixture or args.returning_recruit or args.continuation_fixture or args.persistent_identity or args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.physical_validation_fixture or args.shop_transaction_fixture or args.general_save_cost_fixture or args.general_doubleheader or args.doubleheader_round or args.general_equipment or args.equipment_unit:
        entries += json.loads((root / 'drafts/successor-league-general-v2/DRAFT_MANIFEST.json').read_text())['files']
    if args.persistent_identity:
        entries += json.loads((root / 'drafts/successor-persistent-identity-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.general_career_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture):
        entries += json.loads((root / 'drafts/successor-career-general-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.shop_app_fixture:
        entries += json.loads((root / 'drafts/successor-shop-app-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.next_owner_fixture:
        entries += json.loads((root / 'drafts/successor-owner-next-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.physical_validation_fixture:
        entries += json.loads((root / 'drafts/successor-physical-validation-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.shop_transaction_fixture or args.shop_app_fixture:
        entries += json.loads((root / 'drafts/successor-shop-transaction-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.continuation_fixture or args.next_owner_fixture or (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture) or args.shop_app_fixture or args.terminal_batch_fixture:
        entries += json.loads((root / 'drafts/successor-owner-continuation-v1/DRAFT_MANIFEST.json').read_text())['files']
    if args.returning_recruit:
        entries += json.loads((root / 'drafts/successor-returning-recruit-v1/DRAFT_MANIFEST.json').read_text())['files']
    if (args.owned_general_fixture or args.owned_general_fresh or args.owned_general_season_fixture):
        entries += json.loads((root / 'drafts/successor-owner-general-v1/DRAFT_MANIFEST.json').read_text())['files']
    assert len({entry['restore_path'] for entry in entries}) == len(entries)
    for entry in entries:
        source = root / entry['backup_path']
        data = source.read_bytes()
        assert len(data) == entry['bytes']
        assert hashlib.sha256(data).hexdigest() == entry['sha256'], source
        target = project / entry['restore_path']
        assert target.is_relative_to(project), target
        if resume_stage:
            assert target.read_bytes() == data, target
            continue
        assert not target.exists(), target
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    env = dict(os.environ, WIFFALTRO_ISOLATED_TEST='1')
    env['WIFFALTRO_TEST_FACADE'] = '1' if args.facade else '0'
    for key, directory in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'),
                           ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        env[key] = str(stage / directory)
        Path(env[key]).mkdir(exist_ok=bool(resume_stage))
    print(f'Isolated test evidence: {stage}', flush=True)
    def run(label, switches, timeout=300, run_env=None):
        is_import = label == 'import'
        while (stage / f'{label}.log').exists():
            label += '-resume'
        command = [args.godot, '--headless', '--path', str(project), *switches]
        with (stage / f'{label}.log').open('w') as log:
            result = subprocess.run(command, env=run_env or env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        output = (stage / f'{label}.log').read_text()
        if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output or 'FAIL:' in output:
            raise RuntimeError(f'{label} failed (exit {result.returncode}):\n{output[-6000:]}')
        if not is_import and 'PASS:' not in output:
            raise RuntimeError(f'{label} produced no success marker: {output}')
        print(f'{label}: ' + '\n'.join(line for line in output.splitlines() if 'PASS:' in line), flush=True)
        return output
    run('import', ['--editor', '--import', '--quit'])
    script = ['res://tests/successor_signature.tscn', '--']
    if args.completion_fixture or args.assets_fixture:
        source = (args.completion_fixture or args.assets_fixture).resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-live-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        if args.assets_fixture:
            for suite in ['stadium_progress', 'plaque_adapter', 'asset_basis']:
                run('assets-' + suite, ['res://tests/successor_' + suite + '.tscn'], timeout=900)
            assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
            return
        run('completion-policy', ['res://tests/successor_completion_policy.tscn'], timeout=600)
        run('completion-metrics', ['res://tests/successor_player_metrics.tscn'], timeout=900)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.owner_performance_fixture:
        source = args.owner_performance_fixture.resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-live-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        for trial in ['baseline', 'facade', 'facade-repeat', 'baseline-repeat', 'facade-failure']:
            run('owner-performance-' + trial, ['res://tests/successor_owner_performance.tscn', '--', trial], timeout=1800)
        run('owner-performance-cold', ['res://tests/successor_owner_performance.tscn', '--', 'reopen'], timeout=1200)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.general_economies:
        run('general-economies', ['res://tests/successor_general_economies.tscn'], timeout=1800)
        return
    if args.equipment_unit:
        run('equipment-unit', ['res://tests/successor_general_equipment_unit.tscn'], timeout=1800)
        return
    if args.general_equipment:
        scene = ['--fixed-fps', '60', 'res://tests/successor_general_equipment.tscn', '--']
        for step in range(40):
            output = run(f'equipment-step-{step:03}', scene + ['step'], timeout=3600)
            records = [json.loads(line.split('EQUIPMENT_STEP_DONE: ', 1)[1]) for line in output.splitlines() if line.startswith('EQUIPMENT_STEP_DONE: ')]
            assert len(records) == 1, 'Missing unique Equipment durable boundary record'
            if records[0]['complete']:
                run('equipment-cold-complete', scene + ['verify-complete'], timeout=3600)
                if args.prefix_replay:
                    run('equipment-prefix-replay', ['res://tests/successor_general_replay_prefix.tscn', '--', 'paid'], timeout=3600)
                return
        raise RuntimeError('Equipment sequence exceeded bounded steps; retained checkpoints remain available')
    if args.owned_general_season_fixture:
        source = args.owned_general_season_fixture.resolve()
        assert source.is_file() and source.suffix == '.json' and source.parent.name == 'owned-general-evidence'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        parsed = json.loads(original)
        assert parsed.get('version') == 116 and parsed['checkpoint']['career'].get('origin') == 'fresh-general'
        user = stage / 'data/godot/app_userdata/Wiffaltro'
        user.mkdir(parents=True, exist_ok=True)
        destination = user / 'source-owned-general-season.json'
        primary = user / 'successor-owned-general-live-v1.json'
        if resume_stage:
            assert destination.read_bytes() == original and primary.is_file()
        else:
            assert not destination.exists() and not primary.exists()
            destination.write_bytes(original)
            # The scene independently reconstructs and strictly saves its first
            # primary; a prior source identity is never relabelled here.
        scene = ['--fixed-fps', '60', 'res://tests/successor_owner_general_season.tscn', '--']
        run('owned-general-primitive-policy', scene + ['primitive-policy'], timeout=300)
        for step in range(16):
            output = run(f'owned-general-season-batch-{step:03}', scene + ['step'], timeout=8*3600)
            assert source.read_bytes() == original and destination.read_bytes() == original
            records = [json.loads(line.split('OWNED_SEASON_STEP_DONE: ',1)[1]) for line in output.splitlines() if line.startswith('OWNED_SEASON_STEP_DONE: ')]
            assert 1 <= len(records) <= 8 and records[-1]['batch_done'], 'Missing bounded owned season completion'
            assert all(records[i]['step'] == records[i-1]['step']+1 for i in range(1,len(records)))
            if records[-1]['complete']:
                run('owned-general-season-final-cold', scene + ['verify-complete'], timeout=8*3600)
                assert source.read_bytes() == original and destination.read_bytes() == original
                return
        raise RuntimeError('Owned season exceeded bounded batches; earned checkpoints preserved')
    if args.owned_general_fresh:
        assert not (stage / 'data/godot/app_userdata/Wiffaltro/source-owned.json').exists()
        scene = ['--fixed-fps', '60', 'res://tests/successor_owner_general.tscn', '--', 'fresh']
        for step in range(12):
            output = run(f'owned-general-fresh-batch-{step:03}', scene, timeout=8*3600)
            records = [json.loads(line.split('OWNED_GENERAL_STEP_DONE: ',1)[1]) for line in output.splitlines() if line.startswith('OWNED_GENERAL_STEP_DONE: ')]
            assert records and all(records[i]['step'] == records[i-1]['step']+1 for i in range(1,len(records))), 'Missing/nonconsecutive fresh owned boundaries'
            if records[-1]['complete']:
                run('owned-general-fresh-cold-complete', scene + ['verify-complete'], timeout=8*3600)
                return
        raise RuntimeError('Fresh owned sequence exceeded bounded batches; actual checkpoints preserved')
    if args.owned_general_fixture:
        source = args.owned_general_fixture.resolve()
        assert source.is_file() and source.parent.name in ('full-season-evidence', 'batch-season-evidence') and source.suffix == '.json'
        if not args.owned_general_completed:
            assert source.parent.name == 'full-season-evidence' and source.name == '0000.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        if resume_stage:
            assert destination.read_bytes() == original
        else:
            assert not destination.exists()
            destination.write_bytes(original)
        scene = ['--fixed-fps', '60', 'res://tests/successor_owner_general.tscn', '--']
        if args.owned_general_completed:
            for step in range(12):
                output = run(f'owned-general-batch-{step:03}', scene + ['completed'], timeout=8*3600)
                assert source.read_bytes() == original and destination.read_bytes() == original
                records = [json.loads(line.split('OWNED_GENERAL_STEP_DONE: ',1)[1]) for line in output.splitlines() if line.startswith('OWNED_GENERAL_STEP_DONE: ')]
                assert records and all(records[i]['step'] == records[i-1]['step']+1 for i in range(1,len(records))), 'Missing/nonconsecutive owned durable boundaries'
                if records[-1]['complete']:
                    run('owned-general-cold-complete', scene + ['completed','verify-complete'], timeout=8*3600)
                    assert source.read_bytes() == original and destination.read_bytes() == original
                    return
            raise RuntimeError('Owned sequence exceeded bounded batches; earned checkpoints preserved')
        for label in ['negative', 'negative-cold']:
            run('owned-general-' + label, scene, timeout=3600)
            assert source.read_bytes() == original and destination.read_bytes() == original
        return
    if args.returning_recruit:
        scene = ['--fixed-fps', '60', 'res://tests/successor_returning_recruit.tscn', '--']
        for step in range(20):
            output = run(f'returning-recruit-batch-{step:03}', scene, timeout=8*3600)
            records = [json.loads(line.split('RETURNING_RECRUIT_STEP_DONE: ', 1)[1]) for line in output.splitlines() if line.startswith('RETURNING_RECRUIT_STEP_DONE: ')]
            assert records and all(records[i]['step'] == records[i-1]['step']+1 for i in range(1,len(records))), 'Missing/nonconsecutive durable archive records'
            if records[-1]['complete']:
                run('returning-recruit-cold-complete', scene + ['verify-complete'], timeout=8*3600)
                return
        raise RuntimeError('Returning recruitment exceeded bounded batches; durable evidence preserved')
    if args.recruit_pair_fixture:
        source = args.recruit_pair_fixture.resolve()
        assert source.is_file() and source.parent.name == 'doubleheader-evidence' and source.suffix == '.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro'
        destination.mkdir(parents=True, exist_ok=True)
        copied = destination / 'source-general.json'
        primary = destination / 'successor-general-build-v7-r2.json'
        if resume_stage:
            assert copied.read_bytes() == original
        else:
            assert not copied.exists() and not primary.exists()
            copied.write_bytes(original)
            primary.write_bytes(original)
        scene = ['--fixed-fps', '60', 'res://tests/successor_general_recruit_pair.tscn', '--']
        for step in range(32):
            output = run(f'recruit-pair-step-{step:03}', scene + ['step'], timeout=3600)
            assert source.read_bytes() == original and copied.read_bytes() == original, 'Original/copy source evidence changed'
            records = [json.loads(line.split('RECRUIT_PAIR_STEP_DONE: ', 1)[1]) for line in output.splitlines() if line.startswith('RECRUIT_PAIR_STEP_DONE: ')]
            assert len(records) == 1, 'Missing unique recruitment durable boundary'
            if records[0]['complete']:
                run('recruit-pair-cold-complete', scene + ['verify-complete'], timeout=3600)
                assert source.read_bytes() == original and copied.read_bytes() == original
                return
        raise RuntimeError('Recruitment sequence exceeded bounded steps; durable checkpoints preserved')
    if args.continuation_fixture or args.next_owner_fixture:
        source = (args.next_owner_fixture or args.continuation_fixture).resolve()
        assert source.is_file() and source.parent.name in ('full-season-evidence', 'batch-season-evidence') and source.suffix == '.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        supplied_birth = args.next_owner_birth_fixture if args.next_owner_fixture else args.continuation_birth_fixture
        assert supplied_birth or source.parent.name == 'full-season-evidence', 'Batch evidence requires explicit original birth'
        birth = supplied_birth.resolve() if supplied_birth else source.with_name('0000.json')
        assert birth.is_file() and birth.name == '0000.json' and birth.parent.name == 'full-season-evidence'
        assert any(part.startswith('wiffaltro-signature-') for part in birth.parts)
        original, original_birth = source.read_bytes(), birth.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro'
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'source-owner-current.json').write_bytes(original)
        (destination / 'source-owner-birth.json').write_bytes(original_birth)
        suite = 'continuation-prefix' if args.continuation_prefix else 'continuation-predecessor'
        scene_path = 'res://tests/successor_continuation_prefix.tscn' if args.continuation_prefix else 'res://tests/successor_continuation_predecessor.tscn'
        completed = args.continuation_completed
        if args.next_owner_fixture:
            suite, scene_path, completed = 'next-owner-draft', 'res://tests/successor_owner_next.tscn', args.next_owner_completed
        scene = [scene_path, '--'] + (['completed'] if completed else [])
        run(suite, scene, timeout=3600)
        run(suite + '-cold', scene + ['reopen'], timeout=3600)
        assert source.read_bytes() == original and birth.read_bytes() == original_birth, 'Original owner evidence changed'
        return
    if args.persistent_identity:
        run('persistent-identity', ['res://tests/successor_persistent_identity.tscn'], timeout=1800)
        run('persistent-identity-cold', ['res://tests/successor_persistent_identity.tscn', '--', 'reopen'], timeout=1800)
        return
    if args.shop_app_fixture:
        source = args.shop_app_fixture.resolve()
        assert source.is_file() and source.suffix == '.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-general.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(original)
        flags = [] if args.shop_app_scenario == 'success' else [args.shop_app_scenario]
        scene = ['res://tests/successor_shop_app.tscn', '--'] + flags
        run('shop-app', scene, timeout=3600)
        run('shop-app-cold', scene + ['reopen'], timeout=3600)
        assert source.read_bytes() == original and destination.read_bytes() == original
        return
    if args.general_career_fixture:
        source = args.general_career_fixture.resolve()
        assert source.is_file() and source.suffix == '.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-general.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(original)
        flags = [] if args.general_career_profile == 'standard' else [args.general_career_profile]
        scene = ['res://tests/successor_career_general.tscn', '--'] + flags
        run('general-career', scene, timeout=3600)
        run('general-career-cold', scene + ['reopen'], timeout=3600)
        assert source.read_bytes() == original and destination.read_bytes() == original
        return
    if args.physical_validation_fixture:
        source = args.physical_validation_fixture.resolve()
        assert source.is_file() and source.suffix == '.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-general.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(original)
        scene = ['res://tests/successor_physical_validation.tscn', '--'] + (['doubleheader'] if args.physical_validation_doubleheader else [])
        bound = project / 'src/gameplay/season/successor_league_general_v2/doubleheader.gd'
        bound_before = bound.read_bytes()
        run('physical-validation', scene, timeout=3600)
        assert bound.read_bytes() == bound_before
        run('physical-validation-cold', scene, timeout=3600)
        assert source.read_bytes() == original and destination.read_bytes() == original and bound.read_bytes() == bound_before
        return
    if args.shop_transaction_fixture:
        source = args.shop_transaction_fixture.resolve()
        assert source.is_file() and source.name == 'successor-general-build-v7-r2.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro'
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'source-general.json').write_bytes(original)
        (destination / source.name).write_bytes(original)
        scene = ['res://tests/successor_shop_transaction.tscn', '--']
        run('shop-transaction-' + args.shop_transaction_mode, scene + [args.shop_transaction_mode], timeout=3600)
        run('shop-transaction-cold', scene + ['reopen'], timeout=3600)
        assert source.read_bytes() == original and (destination / 'source-general.json').read_bytes() == original, 'Original earned fixture was changed'
        return
    if args.general_save_cost_fixture:
        source = args.general_save_cost_fixture.resolve()
        assert source.is_file() and source.name == 'successor-general-build-v7-r2.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-general.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(original)
        run('general-save-cost', ['res://tests/successor_general_save_cost.tscn'], timeout=3600)
        run('general-save-cost-cold', ['res://tests/successor_general_save_cost.tscn', '--', 'reopen'], timeout=3600)
        assert source.read_bytes() == original, 'Original earned fixture was changed'
        return
    if args.doubleheader_round:
        scene = ['--fixed-fps', '60', 'res://tests/successor_general_doubleheader_round.tscn', '--']
        for step in range(40):
            output = run(f'doubleheader-step-{step:03}', scene + ['step'], timeout=3600)
            records = [json.loads(line.split('DOUBLEHEADER_STEP_DONE: ', 1)[1]) for line in output.splitlines() if line.startswith('DOUBLEHEADER_STEP_DONE: ')]
            assert len(records) == 1, 'Missing unique Doubleheader durable boundary record'
            if records[0]['complete']:
                run('doubleheader-cold-complete', scene + ['verify-complete'], timeout=3600)
                return
        raise RuntimeError('Doubleheader sequence exceeded bounded steps; retained checkpoints remain available')
    if args.general_doubleheader:
        run('general-doubleheader-foundation', ['res://tests/successor_general_doubleheader.tscn'], timeout=3600)
        return
    if args.general_scramble:
        run('general-scramble', ['res://tests/successor_general_scramble.tscn'], timeout=3600)
        run('general-scramble-cold', ['res://tests/successor_general_scramble.tscn', '--', 'reopen'], timeout=1800)
        return
    if args.general_prefix:
        run('general-prefix-fresh', ['res://tests/successor_general_replay_prefix.tscn'], timeout=3600)
        return
    if args.general_signature:
        run('general-signature', ['res://tests/successor_general_signature.tscn'], timeout=1800)
        return
    if args.general_interrupt:
        run('general-interrupt', ['res://tests/successor_general_interrupt.tscn', '--', args.general_profile], timeout=1800)
        return
    if args.general_birth or args.general_round:
        selected = [args.general_profile] if args.general_profile != 'standard' else []
        if args.general_birth:
            scene = ['res://tests/successor_general_birth.tscn', '--', *selected]
            run('general-birth', scene, timeout=1800)
            run('general-birth-cold', scene + ['reopen'], timeout=900)
        else:
            scene = ['--fixed-fps', '60', 'res://tests/successor_general_round.tscn', '--', *selected]
            run('general-human', scene + ['human-only'], timeout=2400)
            if args.interrupt_flows:
                run('general-interrupt-pending', ['res://tests/successor_general_interrupt.tscn', '--', *selected, 'pending'], timeout=1800)
            run('general-ai-first', scene + ['resume-round', 'one-ai'], timeout=2400)
            run('general-ai-second', scene + ['resume-round', 'one-ai'], timeout=2400)
            run('general-settle-shop', scene + ['resume-round'] + (['retain-shop-prepack'] if args.interrupt_flows or args.academy_flows else []), timeout=2400)
            run('general-round-cold', scene + ['reopen'], timeout=1800)
            if args.interrupt_flows:
                data_root = stage / 'data/godot/app_userdata/Wiffaltro'
                primary = data_root / 'successor-general-build-v7-r2.json'
                prepack = data_root / 'earned-shop-prepack.json'
                primary_before, prepack_before = primary.read_bytes(), prepack.read_bytes()
                isolated = stage / 'shop-confirm'
                assert not isolated.exists()
                isolated.mkdir()
                shop_env = dict(env)
                for key, directory in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
                    shop_env[key] = str(isolated / directory)
                    Path(shop_env[key]).mkdir()
                destination = isolated / 'data/godot/app_userdata/Wiffaltro' / primary.name
                destination.parent.mkdir(parents=True)
                destination.write_bytes(prepack_before)
                run('general-shop-confirm', ['res://tests/successor_general_shop_confirm.tscn', '--', *selected], timeout=2400, run_env=shop_env)
                assert primary.read_bytes() == primary_before
                assert prepack.read_bytes() == prepack_before
            if args.academy_flows:
                data_root = stage / 'data/godot/app_userdata/Wiffaltro'
                primary = data_root / 'successor-general-build-v7-r2.json'
                prepack = data_root / 'earned-shop-prepack.json'
                primary_before, prepack_before = primary.read_bytes(), prepack.read_bytes()

                def academy_slot(name, saved_bytes):
                    isolated = stage / name
                    assert not isolated.exists()
                    isolated.mkdir()
                    branch_env = dict(env)
                    for key, directory in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
                        branch_env[key] = str(isolated / directory)
                        Path(branch_env[key]).mkdir()
                    destination = isolated / 'data/godot/app_userdata/Wiffaltro' / primary.name
                    destination.parent.mkdir(parents=True)
                    destination.write_bytes(saved_bytes)
                    assert destination.read_bytes() == saved_bytes
                    return branch_env, destination

                run('general-academy-npc', ['res://tests/successor_general_academy_npc.tscn', '--', 'academy'], timeout=2400)
                first_env, first_save = academy_slot('academy-first', prepack_before)
                academy_scene = ['res://tests/successor_general_academy.tscn', '--', 'academy']
                run('general-academy-first', academy_scene, timeout=2400, run_env=first_env)
                first_bytes = first_save.read_bytes()
                skip_env, skip_save = academy_slot('academy-skip', first_bytes)
                run('general-academy-second', academy_scene + ['reopen-second'], timeout=2400, run_env=first_env)
                second_bytes = first_save.read_bytes()
                run('general-academy-skip', academy_scene + ['reopen-skip'], timeout=2400, run_env=skip_env)
                assert first_save.read_bytes() == second_bytes
                assert primary.read_bytes() == primary_before
                assert prepack.read_bytes() == prepack_before
            if args.scramble_flows:
                run('general-scramble-paid', ['res://tests/successor_general_scramble.tscn', '--', 'paid'], timeout=3600)
            if args.prefix_replay:
                run('general-prefix-paid', ['res://tests/successor_general_replay_prefix.tscn', '--', 'paid'], timeout=3600)
            if args.signature_benchmark:
                run('general-signature-paid', ['res://tests/successor_general_signature.tscn', '--', 'paid'], timeout=2400)
            if args.resolve_benchmark:
                run('general-resolve', ['res://tests/successor_general_resolve.tscn', '--', *selected], timeout=2400)
        return
    if args.general_physical:
        run('general-physical', ['--fixed-fps', '60', 'res://tests/successor_general_physical.tscn'], timeout=3600)
        run('general-physical-cold', ['res://tests/successor_general_physical.tscn', '--', 'reopen'], timeout=1800)
        return
    if args.general_build:
        run('general-build', ['res://tests/successor_general_matrix.tscn'], timeout=2400)
        return
    if args.history_fixture:
        source = args.history_fixture.resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-terminal-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned112.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        run('exotic-history', ['res://tests/successor_exotic_history.tscn'], timeout=1200)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.recapture_fixture:
        source = args.recapture_fixture.resolve()
        assert source.is_file() and source.name == 'successor-fresh-owner-terminal-v1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        source_before = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-owned112.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(source_before)
        run('recapture-equivalence', ['res://tests/successor_recapture.tscn'], timeout=3600)
        run('recapture-cold', ['res://tests/successor_recapture.tscn', '--', 'reopen'], timeout=1800)
        assert source.read_bytes() == source_before, 'Original isolated fixture was changed'
        return
    if args.terminal_policy:
        run('terminal-policy', ['res://tests/successor_terminal_policy.tscn'], timeout=1200)
        return
    if args.terminal_batch_fixture:
        source = args.terminal_batch_fixture.resolve()
        assert source.is_file() and source.suffix == '.json' and source.parent.name in ['full-season-evidence', 'batch-season-evidence']
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        original = source.read_bytes()
        destination = stage / 'data/godot/app_userdata/Wiffaltro'
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'source-owner-batch.json').write_bytes(original)
        (destination / 'successor-fresh-owner-terminal-v1.json').write_bytes(original)
        provenance = {'source_stage':source.parents[5].name, 'source_boundary':source.name, 'source_sha256':hashlib.sha256(original).hexdigest(), 'coverage':'cold round entry; individually durable same-App boundaries; no per-fixture cold claim'}
        (stage / 'batch-provenance.json').write_text(json.dumps(provenance, indent=2)+'\n')
        output = run('terminal-round-batch', ['--fixed-fps','60','res://tests/successor_terminal_round_batch.tscn'], timeout=8*3600)
        assert source.read_bytes() == original and (destination / 'source-owner-batch.json').read_bytes() == original
        records = [json.loads(line.split('BATCH_STEP_DONE: ',1)[1]) for line in output.splitlines() if line.startswith('BATCH_STEP_DONE: ')]
        assert 1 <= len(records) <= 8 and records[-1]['batch_done']
        if records[-1]['complete']:
            run('terminal-batch-final-cold', ['--fixed-fps','60','res://tests/successor_terminal_season.tscn','--','verify-terminal'], timeout=3600)
        print('BATCH_COMPLETE: '+json.dumps(records[-1]), flush=True)
        return
    if args.terminal_season:
        scene = ['--fixed-fps', '60', 'res://tests/successor_terminal_season.tscn', '--']
        for step in range(80):
            label = f'terminal-season-step-{step:03}'
            while (stage / (label + '.log')).exists():
                label += '-resume'
            output = run(label, scene + ['step'], timeout=3600)
            records = [json.loads(line.split('STEP_DONE: ', 1)[1]) for line in output.splitlines() if line.startswith('STEP_DONE: ')]
            assert len(records) == 1, 'Missing unique durable boundary record'
            if records[0]['complete']:
                run('terminal-season-cold', scene + ['verify-terminal'], timeout=3600)
                return
        raise RuntimeError('Season exceeded bounded steps; retained checkpoints are available')
    if args.terminal_birth:
        run('terminal-birth', ['res://tests/successor_terminal_birth.tscn', '--'], timeout=1200)
        run('terminal-birth-cold', ['res://tests/successor_terminal_birth.tscn', '--', 'reopen'], timeout=900)
        return
    if args.owner_round or args.terminal_round:
        scene = ['--fixed-fps', '60', 'res://tests/successor_terminal_round.tscn' if args.terminal_round else 'res://tests/successor_owner_round.tscn', '--']
        run('owned-human', scene + ['human-only'], timeout=1800)
        run('owned-first-ai', scene + ['resume-round', 'first-ai-only'], timeout=1800)
        run('owned-second-ai', scene + ['resume-round', 'second-ai-only'], timeout=1800)
        run('owned-resume-round', scene + ['resume-round', 'settle-only'], timeout=2400)
        run('owned-round-cold', scene + ['reopen'], timeout=1200)
        return
    if args.owner:
        run('fresh-owner', ['res://tests/successor_owner.tscn', '--'], timeout=1200)
        run('fresh-owner-cold', ['res://tests/successor_owner.tscn', '--', 'reopen'], timeout=900)
        return
    if args.career_fixture:
        source = args.career_fixture.resolve()
        assert source.is_file() and source.name == 'successor-dugout-live-v7-r1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        destination = stage / 'data/godot/app_userdata/Wiffaltro/source-season.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        origin = next(parent for parent in source.parents if parent.name.startswith('wiffaltro-signature-'))
        pending = origin / 'retained-pending-1' / source.name
        if pending.is_file():
            shutil.copy2(pending, destination.with_name('source-pending.json'))
        run('career-evidence', ['res://tests/successor_career.tscn', '--'], timeout=1800)
        run('career-evidence-cold', ['res://tests/successor_career.tscn', '--', 'reopen'], timeout=900)
        return
    if args.identity:
        run('local-identity', ['res://tests/successor_identity.tscn', '--'], timeout=900)
        return
    if args.dugout_pending_fixture:
        source = args.dugout_pending_fixture.resolve()
        assert source.is_file() and source.name == 'successor-dugout-live-v7-r1.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts)
        destination = stage / 'data/godot/app_userdata/Wiffaltro' / source.name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        run('live-pending-integrity', ['res://tests/successor_dugout_integrity.tscn', '--'], timeout=1200)
        run('live-pending-integrity-cold', ['res://tests/successor_dugout_integrity.tscn', '--', 'reopen'], timeout=900)
        return
    if args.dugout_round:
        scene = ['--fixed-fps', '60', 'res://tests/successor_dugout_round.tscn', '--']
        run('live-dugout-human', scene + ['human-only'], timeout=1200)
        run('live-dugout-resume-round', scene + ['resume-round'], timeout=1800)
        run('live-dugout-round-cold', scene + ['reopen'], timeout=900)
        return
    if args.dugout:
        run('live-dugout', ['res://tests/successor_dugout_live.tscn', '--'], timeout=900)
        run('live-dugout-cold', ['res://tests/successor_dugout_live.tscn', '--', 'reopen'], timeout=600)
        return
    if args.recruit:
        run('controlled-recruit', ['res://tests/successor_recruit.tscn', '--'], timeout=600)
        run('controlled-recruit-cold', ['res://tests/successor_recruit.tscn', '--', 'reopen'], timeout=600)
        return
    if args.shop_fixture:
        source = args.shop_fixture.resolve()
        assert source.is_file() and source.name == 'successor-standard-v7.json'
        assert any(part.startswith('wiffaltro-signature-') for part in source.parts), 'Only explicitly isolated prior test evidence is accepted'
        destination = stage / 'data/godot/app_userdata/Wiffaltro/successor-standard-v7.json'
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        run('full-shop', ['res://tests/successor_shop.tscn', '--'], timeout=1200)
        run('full-shop-cold', ['res://tests/successor_shop.tscn', '--', 'reopen'], timeout=600)
        return
    if args.round:
        flow = ['--fixed-fps', '60', 'res://tests/successor_round.tscn', '--']
        run('actual-round-shop', flow, timeout=1200)
        run('round-shop-cold', flow + ['reopen'], timeout=600)
    elif args.flow:
        flow = ['--fixed-fps', '60', 'res://tests/successor_flow.tscn', '--']
        run('draft-physical-flow', flow, timeout=900)
        run('draft-cold-reopen', flow + ['reopen'])
    elif args.expect_broken:
        run('original-failure', script + ['broken'])
    else:
        run('create-save', script)
        run('cold-reopen', script + ['reopen'])


if __name__ == '__main__':
    main()
