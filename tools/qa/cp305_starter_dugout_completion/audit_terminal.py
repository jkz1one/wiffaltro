"""Independently audit observed score/economy/custody; not a native save validator."""
from pathlib import Path
import hashlib,json,sys
def sha(b):return hashlib.sha256(b).hexdigest()
def load(p):
 b=Path(p).read_bytes()
 print(Path(p).name, len(b),sha(b),'headroom vs 20MiB',20*1024*1024-len(b))
 return json.loads(b)
opener,terminal,closed=map(load,sys.argv[1:4])
t,c=terminal['ordinary_state'],closed['ordinary_state']
native=terminal['ordinary']
s=native['state']
assert t["archive"]==opener["ordinary_state"]["archive"]
first,second=t["archive"]["entries"]
standard=first["source"]
assert sha(standard.encode())==first["sha256"]=="8894317a3e9b862b41714a6e69eca4948702f7c7da5c272b715501da03f45cdb"
prior_standard=json.loads(standard)
assert prior_standard["ordinary_state"]["last_close"]["reason"]=="complete"
assert len(prior_standard["ordinary"]["state"]["results"])==33
# Godot canonical JSON uses an exact escaped source literal. Proof requires
# exact byte equality, not a parser normalization or an alternative candidate.
raw_dugout=(second["prefix"]+json.dumps(standard,ensure_ascii=False)+second["suffix"]).encode()
assert sha(raw_dugout)==second["sha256"]=="3f34084c98b630b4f5fa9d5023fb325ef426c7d41defb3283aa07547a18bc36d"
prior_dugout=json.loads(raw_dugout)
assert prior_dugout["ordinary_state"]["archive"]==first
assert prior_dugout["ordinary_state"]["last_close"]["reason"]=="complete"
assert len(prior_dugout["ordinary"]["state"]["results"])==33
assert terminal["common"]==opener["common"]==prior_dugout["common"]
assert s["results"][:3]==opener["ordinary"]["state"]["results"]
assert native["physical"]["reports"][:2]==opener["ordinary"]["physical"]["reports"]
for path,key in ((("build","_events"),"id"),(("book","_events"),"id"),(("bank","_events"),"id")):
 initial=opener["ordinary"]["build"][path[0]][path[1]]
 final=native["build"][path[0]][path[1]]
 assert final[:len(initial)]==initial and len({x[key] for x in final})==len(final)
 assert sum(e["id"]=="shop:4" and e.get("item")=="development.fielding" and e.get("player")=="player.harper_fox" for e in final)==(path[0]=="build")
 assert sum(e["id"]=="growth:4" and e.get("target")=="fielding" and e.get("player")=="player.harper_fox" for e in final)==(path[0]=="book")
 assert sum(e["id"]=="charge:3" and e.get("amount")==8 for e in final)==(path[0]=="bank")
print("PASS exact opener results, NPC reports and one CP304 paid-pack debit, one selection, one Fielding event preserved")
assert t['status']=='active' and c['status']=='closed'
assert c['archive']==t['archive'] and c['last_transition']==t['last_transition']
assert c['last_close']['reason']=='complete' and c['last_close']['league']=='dugout'
assert closed['ordinary']==native and closed['dynasty']==terminal['dynasty']=={}
rows={int(r['id']):r for r in s['results']}
assert sorted(rows)==list(range(33)) and not native['physical']['pending']
assert len(s['player_results'])+len(native['physical']['reports'])==33
def winner(g):return int(g['home'] if g['home_runs']>g['away_runs'] else g['away'])
table=[{'wins':0,'rf':0,'ra':0} for _ in range(6)]
for i in range(30):
 g=rows[i]
 a,h=int(g['away']),int(g['home'])
 ar,hr=int(g['away_runs']),int(g['home_runs'])
 table[a]['rf']+=ar;table[a]['ra']+=hr
 table[h]['rf']+=hr;table[h]['ra']+=ar
 table[winner(g)]['wins']+=1
seeds=sorted(range(6),key=lambda i:(table[i]['wins'],table[i]['rf']-table[i]['ra'],table[i]['rf'],s['teams'][i]['draw']),reverse=True)[:4]
assert seeds==s['playoff_seeds']
for i,(home,away) in enumerate(((seeds[0],seeds[3]),(seeds[1],seeds[2])),30):
 assert rows[i]['home']==home and rows[i]['away']==away and rows[i]['round']==10
assert rows[32]['neutral'] is True and rows[32]['round']==11
assert s['final_fixture']['home']==rows[32]['home'] and s['final_fixture']['away']==rows[32]['away']
wins=table[0]['wins']
finalists={winner(rows[i]) for i in (30,31)}
champ=winner(rows[32])
assert champ==s['champion'] and finalists=={int(rows[32][k]) for k in ('away','home')}
finish='champion' if champ==0 else 'runner_up' if 0 in finalists else 'semifinal' if 0 in s['playoff_seeds'] else 'missed'
amount={'missed':35,'semifinal':65,'runner_up':95,'champion':180}[finish]+(3*wins)//2+(25 if champ==0 else 0)
before=terminal['common']['aggregate'];after=closed['common']['aggregate']
assert before['currency']==111 and not before['titles']
assert c['last_close']['receipt']['total']==amount and after['currency']==111+amount
assert c['last_close']['receipt']['finish']==finish and c['last_close']['receipt']['wins']==wins
assert bool(after['titles'])==(champ==0)
humans={i for i,r in rows.items() if 0 in (r['away'],r['home'])}
npcs={int(r['fixture']):r for r in native['physical']['reports']}
expected=(10,23) if finish=='missed' else (11,22) if finish=='semifinal' else (12,21)
assert (len(humans),len(npcs))==expected and set(npcs)==set(rows)-humans
assert list(npcs)==[int(r['id']) for r in s['results'] if r['id'] not in humans]
for i,report in npcs.items():
 for side in ('away','home'):
  assert report['report']['physical'][f'{side}_runs']==rows[i][f'{side}_runs']
assert set(int(r['id']) for r in s['player_results'])==humans
print('PASS managed / NPC partition and exact native report fixture IDs',expected)
assert closed['common']['sequence']==3 and closed['common']['cursors']=={'dynasty':0,'ordinary':3}
assert closed['common']['last_fold']['receipt']==c['last_close']['receipt']
count=0
for i in range(6):
 build=native['build'] if i==0 else native['opponents']['clubs'][str(i)]['build']
 actual=[(int(e['game']),e['win']) for e in build['bank']['_events'] if e['op']=='reward']
 assert len(dict(actual))==len(actual)
 assert dict(actual)=={k:winner(r)==i for k,r in rows.items() if i in (r['away'],r['home'])}
 count+=len(actual)
assert count==66
print('PASS exact earlier 66 scores and current 33 settled outcomes, 66 unique correct bank receipts; no modified gameplay or archived source')
print('PASS actual seeds/finalists/champion',s['playoff_seeds'],sorted(finalists),champ)
print('PASS actual finish/wins/career payout/total/title',finish,wins,amount,after['currency'],bool(after['titles']))

stat_events=[x for x in native["build"]["book"]["_events"] if x["op"]=="stat"]
assert after["development"]["stat"]-before["development"]["stat"]==len(stat_events)
assert len([e for e in stat_events if e["id"]=="growth:4"])==1
print("PASS prior Common refolded once, development stat increment",len(stat_events),"including one Harper Fox paid Fielding")
harper="player.harper_fox"
opener_book=opener["ordinary"]["build"]["book"]
new_game=rows[3]
assert opener_book["_players"][harper]["stats"]["fielding"]==3
assert harper in new_game["club_roster"] and harper in new_game["performance"]
print("PASS Harper Fox present in real next fixture3; exact starting book Fielding 3; native fielding evidence:",
      [e for e in new_game["fielding"] if e.get("player")==harper])
