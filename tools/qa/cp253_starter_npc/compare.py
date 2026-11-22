"""Read-only actual predecessor, generated headless primary/backup, rendered settled oracle."""
import copy, hashlib, json, sys
from pathlib import Path

def read(path):
    data=Path(path).read_bytes()
    return json.loads(data), hashlib.sha256(data).hexdigest()

def diff(x,y,p=""):
    if type(x)!=type(y): yield(p,type(x).__name__,type(y).__name__)
    if isinstance(x,dict) and isinstance(y,dict):
        for k in sorted(x.keys()|y.keys()):
            if k not in x or k not in y: yield(p+'/'+k,"absent" if k not in x else "present","absent" if k not in y else "present")
            else: yield from diff(x[k],y[k],p+'/'+k)
    elif isinstance(x,list) and isinstance(y,list):
        if len(x)!=len(y): yield(p+"/length",len(x),len(y))
        for k,(a,b) in enumerate(zip(x,y)): yield from diff(a,b,p+'/'+str(k))
    elif x!=y: yield(p,x,y)

def main():
    prior_path, made_path, settled_path, number = sys.argv[1:]
    n=int(number)
    prior, prior_sha=read(prior_path)
    made, made_sha=read(made_path)
    settled, settled_sha=read(settled_path)
    backup, backup_sha=read(made_path+".bak")
    if prior_sha!=backup_sha or prior!=backup: raise ValueError("non-exact original primary backup")
    expected=copy.deepcopy(prior)
    reports=settled["ordinary"]["physical"]["reports"]
    row=next(row for row in reports if row["fixture"]==n)
    pending=expected["ordinary"]["physical"]["pending"]
    pending["reports"].append(copy.deepcopy(row))
    native=made["ordinary"]["physical"]["pending"]["reports"][-1]
    phys=native["report"]["physical"]
    # The sole timer-diagnostic exception. Everything else including numeric JSON types is compared.
    pending["reports"][-1]["report"]["physical"]["elapsed"]=phys["elapsed"]
    changes=list(diff(expected,made))
    print("fixture",n,"rendered source",prior_sha,"settled oracle",settled_sha,"generated",made_sha)
    print("request",native["request"],"score",phys["away_runs"],phys["home_runs"],"plays",len(phys["plays"]))
    print("elapsed only permitted",row["report"]["physical"]["elapsed"],phys["elapsed"])
    print("other differences",len(changes))
    for path,x,y in changes[:12]: print(path,str(x)[:120],str(y)[:120])
    if changes: raise SystemExit(1)
    print("PASS entire decoded pending owner equals rendered-source owner plus exact retained rendered row, with only physical.elapsed different; backup bytes identical")

if __name__=="__main__": main()
