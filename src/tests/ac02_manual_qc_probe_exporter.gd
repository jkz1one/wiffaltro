extends PlayRecordExport
## Test-only historical/custom exporter. A native eligible sample must NEVER use this.
var save_calls: int = 0
var on_save: Callable
var observed_states: Array[int] = []
var issue: WeakRef
var force_error: Error = OK


func save(records: Array[PlayRecord], field: FieldDefinition, stadium: Dictionary = {}) -> Error:
	save_calls += 1
	if issue != null and issue.get_ref() != null:
		observed_states.append(issue.get_ref().state)
	if on_save.is_valid():
		var once: Callable = on_save
		on_save = Callable()
		once.call()
	if force_error != OK:
		return force_error
	return super.save(records, field, stadium)
