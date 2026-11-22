from pathlib import Path
import hashlib,json,sys
def sha(b):return hashlib.sha256(b).hexdigest()
def load(p):
 b=Path(p).read_bytes()
 print(Path(p).name, len(b),sha(b),'headroom vs 20MiB',20*1024*1024-len(b))
 return json.loads(b)
terminal,closed=map(load,sys.argv[1:3])
t,c=terminal['ordinary_state'],closed['ordinary_state']
native=terminal['ordinary']
s=native['state']
prev=t['archive']['source'].encode()
assert sha(prev)==t['archive']['sha256']=='8894317a3e9b862b41714a6e69eca4948702f7c7da5c272b715501da03f45cdb'
assert json.loads(prev)['ordinary_state']['last_close']['reason']=='complete'
assert len(json.loads(prev)['ordinary']['state']['results'])==33
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
assert before['currency']==72 and not before['titles']
assert c['last_close']['receipt']['total']==amount and after['currency']==72+amount
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
assert closed['common']['sequence']==2 and closed['common']['cursors']=={'dynasty':0,'ordinary':2}
assert closed['common']['last_fold']['receipt']==c['last_close']['receipt']
count=0
for i in range(6):
 build=native['build'] if i==0 else native['opponents']['clubs'][str(i)]['build']
 actual=[(int(e['game']),e['win']) for e in build['bank']['_events'] if e['op']=='reward']
 assert len(dict(actual))==len(actual)
 assert dict(actual)=={k:winner(r)==i for k,r in rows.items() if i in (r['away'],r['home'])}
 count+=len(actual)
assert count==66
print('PASS exact earlier 33 scores and current 33 settled outcomes, 66 unique correct bank receipts; no modified gameplay or archived source')
print('PASS actual seeds/finalists/champion',s['playoff_seeds'],sorted(finalists),champ)
print('PASS actual finish/wins/career payout/total/title',finish,wins,amount,after['currency'],bool(after['titles']))
