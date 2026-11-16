extends Node
var checks=0
var failures=0
func check(ok:bool,label:String):
	checks+=1
	print('PROJECTED_GRAPH_CHECK ',checks,' ',ok,' ',label)
	if not ok:failures+=1
func _ready():
	var owner_path: String = ""
	var pending_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--projection-owner="):owner_path=arg.trim_prefix("--projection-owner=")
		if arg.begins_with("--projection-pending="):pending_path=arg.trim_prefix("--projection-pending=")
	if not owner_path.is_absolute_path() or not pending_path.is_absolute_path():
		get_tree().quit(2)
		return
	var runtime=load('res://src/gameplay/season/dynasty_standard_runtime.gd')
	SeasonSave.bind_dynasty_owner(owner_path)
	var source=SeasonSave._decode(JSON.parse_string(FileAccess.get_file_as_string(pending_path)))
	check(source!=null,'retained genuine pending decode')
	if source!=null:
		var a=SeasonRoundSettlement.project(source)
		var b=SeasonRoundSettlement.project(source)
		check(a.has('candidate') and b.has('candidate'),'two independent public projections')
		if a.has('candidate') and b.has('candidate'):
			var c=a.candidate
			var e=b.candidate
			check(runtime._same_projection(c,e),'complete runtime graphs agree')
			var v=c.ownership._state.cash
			c.ownership._state.cash=v+1
			check(not runtime._same_projection(c,e),'derived ownership cash refused')
			c.ownership._state.cash=v
			v=c.build._bank._state.cash
			c.build._bank._state.cash=v+1
			check(not runtime._same_projection(c,e),'derived player build cash refused')
			c.build._bank._state.cash=v
			v=c.opponents.clubs['1'].build._bank._state.cash
			c.opponents.clubs['1'].build._bank._state.cash=v+1
			check(not runtime._same_projection(c,e),'derived opponent cash refused')
			c.opponents.clubs['1'].build._bank._state.cash=v
			c._pool_replay_ledger._events.append({'corrupt':true})
			check(not runtime._same_projection(c,e),'paid ledger journal refused')
			c._pool_replay_ledger._events.pop_back()
			for field in ['cursor','projecting','needed','error']:
				var old=c.physical.get(field)
				var altered:Variant=old+1 if field=='cursor' else (not old if field=='projecting' else ({'bad':true} if field=='needed' else 'bad'))
				c.physical.set(field,altered)
				check(not runtime._same_projection(c,e),'physical '+field+' refused')
				c.physical.set(field,old)
			c.physical.pending={'bad':true}
			check(not runtime._same_projection(c,e),'physical pending journal refused')
			c.physical.pending=e.physical.pending.duplicate(true)
			check(not runtime._same_value(RefCounted.new(),{}),'malformed object-versus-value returns false')
			check(runtime._same_projection(c,e),'restored exact graph agrees')
	SeasonSave._dynasty_owner_path=''
	print('PROJECTED_GRAPH_RESULT checks=',checks,' failures=',failures)
	get_tree().quit(0 if failures==0 else 1)
