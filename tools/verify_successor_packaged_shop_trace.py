#!/usr/bin/env python3
"""Verify slot custody and one shop debit from a rendered engineering-package test."""
import argparse
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
from test_successor_dynasty_post_purchase import digest, evidence

PCK = '8d8da4dc929817c8ff0df141ce59447282d0e6921a022fac4816f932dc2d1d59'
ELF = '2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0'


def verify(origin, before, current, backup, post_purchase_sha):
    assert origin == before == backup, 'round trip, Cancel or backup differs from the initial earned owner'
    assert digest(current) == post_purchase_sha, 'fresh-process reopen did not preserve the observed paid bytes'
    a, b = json.loads(before), json.loads(current)
    assert a['active'] == b['active'] == 'dynasty'
    assert {k:v for k,v in a.items() if k!='dynasty'} == {k:v for k,v in b.items() if k!='dynasty'}
    for field in ('state','physical','opponents','career','session','game_catalog','player_catalog'):
        assert a['dynasty'][field] == b['dynasty'][field], field
    old, new = a['dynasty']['build'], b['dynasty']['build']
    prior, now = old['bank']['_state'], new['bank']['_state']
    assert prior['cash'] == 4 and prior['held'] == []
    assert now['cash'] == 1 and len(now['held']) == 1
    item, = now['held']
    assert item['item'] == 'C03' and item['kind'] == 'held' and item['paid'] == 3
    assert {k:v for k,v in prior.items() if k not in ('cash','held','seen_offers')} == {
        k:v for k,v in now.items() if k not in ('cash','held','seen_offers')
    }
    previous_events, current_events = old['build']['_events'], new['build']['_events']
    assert len(current_events) == len(previous_events) + 1 and current_events[:-1] == previous_events
    event = current_events[-1]
    assert event['op'] == 'tactical_buy'
    assert now['seen_offers'] == prior['seen_offers'] + [item['id']]
    prev_build, curr_build = old['build'], new['build']
    assert set(curr_build['_requests']) - set(prev_build['_requests']) == {event['id']}
    assert all(curr_build['_requests'][key]==value for key,value in prev_build['_requests'].items())
    prev_visit, curr_visit = prev_build['_visit'], curr_build['_visit']
    assert prev_visit['pack_status'] == curr_visit['pack_status'] == 'used'
    assert set(prev_visit['offers']) - set(curr_visit['offers']) == {event['offer']}
    assert all(prev_visit['offers'][key]==value for key,value in curr_visit['offers'].items())
    assert sum(row['op']=='pack_pick' for row in current_events) == 1
    print('PASS: parked ordinary, old results and prior pack pick exact; one rendered Swing Plan purchase; cold bytes unchanged.')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('pck','elf','evidence','before','cold-primary','backup'):
        p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--post-purchase-sha',required=True,help='Observed primary SHA-256 before closing the test process')
    o=p.parse_args()
    assert digest(o.pck.read_bytes()) == PCK and digest(o.elf.read_bytes()) == ELF
    origin,_=evidence(o.evidence)
    verify(origin,o.before.read_bytes(),o.cold_primary.read_bytes(),o.backup.read_bytes(),o.post_purchase_sha)


if __name__ == '__main__':
    main()
