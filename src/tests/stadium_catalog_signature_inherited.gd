extends StadiumCatalog
## Ordinary inherited static calls only; no shadow or invalid instance dispatch.


static func inherited_signature() -> String:
	return signature()
