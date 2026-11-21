#!/usr/bin/env python3
"""Read-only check of the actual retained synthetic Dynasty season and Workshop purchase."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

TERMINAL_SHA = "1c8360512dfdc48b2c4f3b0db3e60147829f7cd75617008ce46d86d88c77bbe3"
CLOSED_SHA = "b7edea0e923df22194a2e90dc35c65233b4bfa313891d4d6e9a0f50dd6c6e3b2"
RECEIPT = {"version": 1, "finish": "runner_up", "wins": 6, "finish_award": 95,
           "record_bonus": 9, "first_bonus": 0, "total": 104}
MAX_BYTES = 64 * 1024 * 1024


def load(path, expected=None):
    assert path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= MAX_BYTES
    data = path.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    assert expected is None or sha == expected, f"unexpected synthetic slot hash {sha}"
    slot = json.loads(data)
    assert slot["format"] == "wiffaltro-common-career-v4" and slot["active"] == "dynasty"
    return data, slot


def without(obj, keys):
    return {k: v for k, v in obj.items() if k not in keys}


def check_reports(session):
    state = session["state"]
    rows = state["results"]
    assert [int(r["id"]) for r in rows] == list(range(33)) and state["phase"] == 4
    last = rows[-1]
    assert state["final_fixture"]["neutral"] and int(last["home"]) == 0
    assert (last["away_runs"], last["home_runs"], state["champion"]) == (4, 3, 4)
    human = {int(r["id"]) for r in rows if 0 in (r["away"], r["home"])}
    assert len(human) == 12 and [int(r["id"]) for r in state["player_results"]] == sorted(human)
    reports = session["physical"]["reports"]
    assert len(reports) == 21 and {int(r["fixture"]) for r in reports} == set(range(33)) - human
    assert not session["physical"]["pending"]
    expected = {i: {} for i in range(6)}
    for r in rows:
        a, h, g = (int(r[n]) for n in ("away", "home", "id"))
        expected[a][g] = r["away_runs"] > r["home_runs"]
        expected[h][g] = r["home_runs"] > r["away_runs"]
    for i, games in expected.items():
        club = session["build"] if i == 0 else session["opponents"]["clubs"][str(i)]["build"]
        bank = club["bank"]
        rewards = [e for e in bank["_events"] if e["op"] == "reward"]
        assert len(rewards) == len(games) == len({int(e["game"]) for e in rewards})
        assert {int(e["game"]): e["win"] for e in rewards} == games
        assert {int(k): v for k, v in bank["_state"]["rewards"].items()} == games
    assert sum(map(len, expected.values())) == 66


def verify(args):
    terminal_raw, terminal = load(args.terminal, TERMINAL_SHA)
    closed_raw, closed = load(args.closed, CLOSED_SHA)
    assert args.closed_backup.read_bytes() == terminal_raw
    assert terminal["ordinal"] == closed["ordinal"] == 2 and terminal["status"] == "active"
    assert closed["status"] == "closed" and closed["last_close"]["reason"] == "complete"
    assert closed["last_close"]["receipt"] == RECEIPT and closed["ledger"]["currency"] == 104
    assert terminal["ledger"]["currency"] == 0 and terminal["dynasty"] == closed["dynasty"]
    assert terminal["ordinary"] == closed["ordinary"]
    history = closed["workshop_close_history"]
    assert history["opening"] == {"closed": 1, "completed": 0, "currency": 0, "champion": False}
    assert len(history["rows"]) == 1 and history["rows"][0]["receipt"] == RECEIPT
    assert history["rows"][0]["source"] == closed["last_close"]["session_sha256"]
    check_reports(closed["dynasty"])
    if args.paid:
        paid_raw, paid = load(args.paid)
        assert args.paid_backup.read_bytes() == closed_raw
        assert without(paid, {"workshop_chair_purchase"}) == closed
        purchase = paid["workshop_chair_purchase"]
        ledger = purchase["ledger"]
        assert purchase["ordinal"] == 2 and purchase["source"] == history["rows"][0]["source"]
        assert len(ledger["events"]) == 1
        event = ledger["events"][0]
        assert event["op"] == "stadium_buy" and event["item"] == "ST-079" and event["through"] == 1
        assert event["price_version"] == 1 and event["quantity"] == 1 and event["rev"] == 0
        if args.carried:
            _, carried = load(args.carried)
            assert args.carried_backup.read_bytes() != paid_raw  # Next proposal is the immediate predecessor.
            _, proposed = load(args.carried_backup)
            assert proposed["status"] == "closed" and proposed["proposal"]
            assert not paid["proposal"] and without(proposed, {"proposal"}) == without(paid, {"proposal"})
            assert carried["ordinal"] == 3 and carried["status"] == "active"
            assert carried["workshop_chair_purchase"] == purchase
            assert carried["workshop_close_history"] == history and carried["ledger"]["currency"] == 104
            assert carried["ordinary"] == paid["ordinary"]
            assert not carried["dynasty"]["state"]["results"] and not carried["last_close"]
    print("DYNASTY_COMPLETION_PAYOUT_PARITY_PASS", "carry" if args.carried else ("paid" if args.paid else "closed"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for field in ("terminal", "closed", "closed-backup", "paid", "paid-backup", "carried", "carried-backup"):
        parser.add_argument("--" + field, type=Path, required=field in ("terminal", "closed", "closed-backup"))
    parser.add_argument("--synthetic-test-only", required=True, action="store_true")
    cfg = parser.parse_args()
    if sys.flags.optimize or bool(cfg.paid) != bool(cfg.paid_backup) or bool(cfg.carried) != bool(cfg.carried_backup) or cfg.carried and not cfg.paid:
        parser.error("use ordinary Python and supply all paired stages in order")
    verify(cfg)
