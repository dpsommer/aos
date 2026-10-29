class_name RulesFormatter
extends RefCounted
## Turns faction data into BBCode for display in a [RichTextLabel].


## The ability's rules without its name, timing, keywords or source, which an [AbilityCard] shows
## around them.
static func ability_body(rule: Ability) -> String:
	var lines := PackedStringArray()
	if not rule.text.is_empty():
		lines.append(_escape(rule.text))
	if not rule.declare.is_empty():
		lines.append("[b]Declare:[/b] %s" % _escape(rule.declare))
	if not rule.effect.is_empty():
		lines.append("[b]Effect:[/b] %s" % _escape(rule.effect))
	for option in rule.options:
		lines.append("[indent][b]%s:[/b] %s[/indent]" % [_escape(option.name), _escape(option.text)])
	return "\n".join(lines)


## Stops rules text such as "[Shoot in Combat]" being read as BBCode.
static func _escape(value: String) -> String:
	return value.replace("[", "[lb]")
