class_name StadiumNpcAc02IssuedWritersV1
extends RefCounted
## Narrow supported static writer gate. Initial historical construction is unchanged.
## Refusal is terminal for a new issue, even if the requested values match its originals.


static func preissue_only(node: Node, reason: String) -> bool:
	var current: Node = node
	while is_instance_valid(current):
		if current is StadiumNpcPublicProperty:
			var property: StadiumNpcPublicProperty = current as StadiumNpcPublicProperty
			if property.ac02_startup_pending() or property.has_ac02_issue() or property._ac02_preparing:
				property.ac02_revoke(reason)
				return false
			return true
		current = current.get_parent()
	return true
