class_name GameUI
extends CanvasLayer
## Every 2D overlay, drawn in code on a 1920x1080 canvas.

signal menu_chosen(id: String)

const GOLD := Color(0.9, 0.76, 0.42)
const CREAM := Color(0.96, 0.91, 0.8)
const MUTED := Color(0.78, 0.72, 0.6)

var disp: Font
var body: FontVariation
var bold: FontVariation
var canvas: Control
var mode := "none"           # none | title | play | map | pause | gameover | ending
var boss: Node = null
var banner_text := ""
var banner_t := 99.0
var toasts: Array = []
var fade := 0.0
var prompt := ""
var t := 0.0
# dialog
var dlg_queue: Array = []
var dlg_cur = null
var dlg_shown := 0.0
var dlg_lines: Array = []
var dlg_sel := 0
var dlg_done: Callable
# menus
var menu_items: Array = []
var menu_sel := 0
var menu_title := ""
# map
var map_info := ""
var tree_sel := "s_edge"
var fp := false
var streak := 0
var inv_sel := 0
var loot_log: Array = []
var ending_t := 0.0
var gameover_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	disp = load("res://assets/fonts/UncialAntiqua-Regular.ttf")
	var base: Font = load("res://assets/fonts/Alegreya.ttf")
	body = FontVariation.new()
	body.base_font = base
	body.variation_opentype = {"wght": 560}
	bold = FontVariation.new()
	bold.base_font = base
	bold.variation_opentype = {"wght": 800}
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_all)
	add_child(canvas)
	Game.toast.connect(func(s): toast(s))


func _process(dt: float) -> void:
	t += dt
	banner_t += dt
	for x in toasts:
		x["life"] -= dt
	for x in loot_log:
		x["life"] -= dt
	loot_log = loot_log.filter(func(x): return x["life"] > 0.0)
	toasts = toasts.filter(func(x): return x["life"] > 0.0)
	if dlg_cur != null:
		dlg_shown = min(float(String(dlg_cur["t"]).length()), dlg_shown + dt * 55.0)
	if mode == "ending":
		ending_t += dt
	if mode == "gameover":
		gameover_t += dt
	canvas.queue_redraw()


# ---------------------------------------------------------------- api

func toast(s: String) -> void:
	toasts.append({"t": s, "life": 2.8})


func banner(s: String) -> void:
	banner_text = s
	banner_t = 0.0


func dialog_active() -> bool:
	return dlg_cur != null


func say(entries: Array, done := Callable()) -> void:
	dlg_queue = entries.duplicate()
	dlg_done = done
	_next_line()


func _next_line() -> void:
	dlg_cur = dlg_queue.pop_front() if dlg_queue.size() > 0 else null
	dlg_shown = 0.0
	dlg_sel = 0
	if dlg_cur == null:
		var d := dlg_done
		dlg_done = Callable()
		if d.is_valid():
			d.call()
		return
	dlg_lines = _wrap(String(dlg_cur["t"]), bold, 34, 1380.0)
	Sfx.play("blip", -8.0)


## Handles input while a dialog is open. Returns true if it consumed the event.
func dialog_input() -> bool:
	if dlg_cur == null:
		return false
	var total := String(dlg_cur["t"]).length()
	var choices: Array = dlg_cur.get("ch", [])
	if choices.size() > 0 and dlg_shown >= total:
		if Input.is_action_just_pressed("move_up"):
			dlg_sel = (dlg_sel + choices.size() - 1) % choices.size()
			Sfx.play("blip", -8.0)
		if Input.is_action_just_pressed("move_down"):
			dlg_sel = (dlg_sel + 1) % choices.size()
			Sfx.play("blip", -8.0)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		if dlg_shown < total:
			dlg_shown = total
		elif choices.size() > 0:
			var c: Dictionary = choices[dlg_sel]
			dlg_queue = []
			dlg_cur = null
			dlg_done = Callable()
			Sfx.play("select")
			(c["f"] as Callable).call()
		else:
			_next_line()
	return true


func open_menu(title: String, items: Array) -> void:
	menu_title = title
	menu_items = items
	menu_sel = 0


## Returns the chosen item id or "".
func menu_input() -> String:
	if menu_items.is_empty():
		return ""
	if Input.is_action_just_pressed("move_up"):
		menu_sel = (menu_sel + menu_items.size() - 1) % menu_items.size()
		Sfx.play("blip", -6.0)
	if Input.is_action_just_pressed("move_down"):
		menu_sel = (menu_sel + 1) % menu_items.size()
		Sfx.play("blip", -6.0)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack"):
		Sfx.play("select")
		return menu_items[menu_sel]["id"]
	return ""


func _wrap(text: String, font: Font, size: int, max_w: float) -> Array:
	var words := text.split(" ")
	var lines := []
	var cur := ""
	for w in words:
		var test = w if cur == "" else cur + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = test
	if cur != "":
		lines.append(cur)
	return lines


# ---------------------------------------------------------------- drawing helpers

func _panel(r: Rect2, alpha := 0.9, radius := 14) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.045, alpha)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 5)
	canvas.draw_style_box(sb, r)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0, 0, 0, 0)
	inner.border_color = Color(1, 0.9, 0.65, 0.16)
	inner.set_border_width_all(2)
	inner.set_corner_radius_all(radius - 4)
	canvas.draw_style_box(inner, r.grow(-7))
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]), GOLD)


func _text(s: String, pos: Vector2, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if outline > 0:
		canvas.draw_string_outline(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, outline, Color(0.06, 0.03, 0.01, 0.9))
	canvas.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, col)


func _bar(r: Rect2, v: float, c1: Color, c2: Color, label: String, value_text: String) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.02, 0.9)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	canvas.draw_style_box(sb, r)
	var w: float = (r.size.x - 4) * clamp(v, 0.0, 1.0)
	if w > 2:
		var fill := StyleBoxFlat.new()
		fill.bg_color = c1
		fill.set_corner_radius_all(int(r.size.y * 0.5) - 2)
		canvas.draw_style_box(fill, Rect2(r.position + Vector2(2, 2), Vector2(w, r.size.y - 4)))
		canvas.draw_rect(Rect2(r.position + Vector2(6, 3), Vector2(max(0.0, w - 8), 3)), Color(1, 1, 1, 0.3))
		canvas.draw_rect(Rect2(r.position + Vector2(4, r.size.y * 0.55), Vector2(max(0.0, w - 4), r.size.y * 0.3)), Color(c2.r, c2.g, c2.b, 0.6))
	_text(label, r.position + Vector2(12, r.size.y - 5), bold, 18, CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	_text(value_text, Vector2(r.end.x - 10, r.end.y - 5), bold, 18, CREAM, HORIZONTAL_ALIGNMENT_RIGHT, -1, 4)


func _spell_icon(id: String, c: Vector2, s: float) -> void:
	match id:
		"fire":
			var pts := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				var r: float = s * (0.55 + 0.45 * maxf(0.0, -sin(a)) + 0.1 * sin(a * 5.0))
				pts.append(c + Vector2(cos(a) * s * 0.6, sin(a) * r * 0.9 + s * 0.15))
			canvas.draw_colored_polygon(pts, Color(1.0, 0.45, 0.15))
			canvas.draw_circle(c + Vector2(0, s * 0.3), s * 0.32, Color(1.0, 0.85, 0.35))
		"ice":
			for i in 3:
				var a := PI / 3.0 * i
				var d := Vector2(cos(a), sin(a)) * s
				canvas.draw_line(c - d, c + d, Color(0.75, 0.93, 1.0), 3.0)
				for sgn in [-1, 1]:
					var p: Vector2 = c + d * 0.6 * sgn
					canvas.draw_line(p, p + d.rotated(0.8 * sgn).normalized() * s * -0.3 * sgn, Color(0.75, 0.93, 1.0), 2.0)
		_:
			canvas.draw_circle(c, s * 0.75, Color(0.35, 0.8, 0.4))
			canvas.draw_rect(Rect2(c - Vector2(s * 0.45, s * 0.13), Vector2(s * 0.9, s * 0.26)), Color(1, 1, 1))
			canvas.draw_rect(Rect2(c - Vector2(s * 0.13, s * 0.45), Vector2(s * 0.26, s * 0.9)), Color(1, 1, 1))


# ---------------------------------------------------------------- frame

func _draw_all() -> void:
	var sz := canvas.size
	match mode:
		"title":
			_draw_title(sz)
		"play", "pause", "gameover", "ending":
			_draw_hud(sz)
			if prompt != "" and dlg_cur == null and mode == "play":
				_draw_prompt(sz)
			if mode == "play":
				_draw_combat_extras(sz)
			_draw_banner(sz)
			_draw_dialog(sz)
			if mode == "pause":
				_draw_pause(sz)
			elif mode == "gameover":
				_draw_gameover(sz)
			elif mode == "ending":
				_draw_ending(sz)
		"map":
			_draw_map(sz)
			_draw_dialog(sz)
		"tree":
			_draw_hud(sz)
			_draw_tree(sz)
		"inv":
			_draw_hud(sz)
			_draw_inventory(sz)
	_draw_toasts(sz)
	if fade > 0.0:
		canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, fade))


func _draw_hud(sz: Vector2) -> void:
	# portrait + bars
	_panel(Rect2(24, 24, 470, 132), 0.82)
	canvas.draw_circle(Vector2(92, 90), 50, Color(0.12, 0.2, 0.35))
	canvas.draw_circle(Vector2(92, 90), 44, Color(0.2, 0.33, 0.55))
	_text("K", Vector2(92, 110), disp, 56, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	canvas.draw_arc(Vector2(92, 90), 50, 0, TAU, 48, GOLD, 3.0)
	_text("Kael", Vector2(162, 62), bold, 28, CREAM)
	_text(Game.CLASSES[Game.cls]["name"], Vector2(232, 62), body, 20, MUTED)
	_text("Nível %d" % Game.lvl, Vector2(472, 62), bold, 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	if Game.essence > 0:
		var pulse := 0.75 + 0.25 * sin(t * 4.0)
		_panel(Rect2(24, 166, 250, 44), 0.8, 10)
		_diamond(Vector2(52, 188), 10)
		_text("%d Essência  ·  T" % Game.essence, Vector2(72, 197), bold, 22, Color(1.0, 0.9, 0.6, pulse))
	_bar(Rect2(162, 74, 310, 26), Game.hp / Game.max_hp, Color(0.86, 0.3, 0.22), Color(0.6, 0.15, 0.1), "PV", "%d / %d" % [ceil(Game.hp), Game.max_hp])
	_bar(Rect2(162, 106, 310, 22), Game.mp / Game.max_mp, Color(0.3, 0.55, 0.95), Color(0.15, 0.3, 0.7), "PM", "%d / %d" % [floor(Game.mp), Game.max_mp])
	canvas.draw_rect(Rect2(162, 136, 310, 6), Color(0.05, 0.03, 0.02, 0.9))
	canvas.draw_rect(Rect2(162, 136, 310 * clamp(float(Game.xp) / Game.xp_next(), 0.0, 1.0), 6), GOLD)
	# gold & potions
	_panel(Rect2(sz.x - 330, 24, 306, 64), 0.82)
	canvas.draw_circle(Vector2(sz.x - 294, 56), 14, Color(0.72, 0.5, 0.12))
	canvas.draw_circle(Vector2(sz.x - 294, 56), 10, Color(1.0, 0.82, 0.3))
	_text(str(Game.gold), Vector2(sz.x - 270, 66), bold, 28, Color(1.0, 0.9, 0.6))
	canvas.draw_circle(Vector2(sz.x - 142, 60), 13, Color(0.95, 0.3, 0.45))
	canvas.draw_rect(Rect2(sz.x - 147, 38, 10, 10), Color(0.9, 0.85, 0.7))
	_text("× %d" % Game.potions, Vector2(sz.x - 118, 66), bold, 28, Color(1.0, 0.9, 0.6))
	# spells
	var n := Game.spells.size()
	var w := n * 92 + 36
	var r := Rect2(sz.x - w - 24, sz.y - 132, w, 108)
	_panel(r, 0.82)
	for i in n:
		var id: String = Game.spells[i]
		var c := Vector2(r.position.x + 64 + i * 92, r.position.y + 54)
		var act := i == Game.spell_idx
		canvas.draw_circle(c, 36, Color(0.9, 0.76, 0.42, 0.22) if act else Color(0, 0, 0, 0.4))
		canvas.draw_arc(c, 36, 0, TAU, 40, Color(1, 0.92, 0.6) if act else Color(0.45, 0.35, 0.2), 4.0 if act else 2.0)
		var col = Color(1, 1, 1, 1.0 if Game.mp >= Game.spell_cost(id) else 0.35)
		canvas.draw_set_transform(Vector2.ZERO)
		_spell_icon(id, c, 20)
		if col.a < 1.0:
			canvas.draw_circle(c, 34, Color(0, 0, 0, 0.5))
		_text(str(Game.spell_cost(id)), c + Vector2(26, 34), bold, 20, Color(0.6, 0.78, 1.0), HORIZONTAL_ALIGNMENT_CENTER, -1, 4)
	_text(Game.SPELLS[Game.current_spell()]["name"], Vector2(r.get_center().x, r.position.y - 12), bold, 24, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_CENTER, -1, 5)
	# boss bar
	if boss != null and is_instance_valid(boss) and boss.state != "intro" and not boss.dead:
		var bw := 720.0
		var br := Rect2((sz.x - bw) * 0.5, sz.y - 118, bw, 86)
		_panel(br, 0.85)
		_text("Carvalho Ancião Corrompido", Vector2(br.get_center().x, br.position.y + 38), disp, 30, Color(0.92, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		canvas.draw_rect(Rect2(br.position.x + 30, br.position.y + 52, bw - 60, 16), Color(0.05, 0.02, 0.05))
		var k: float = clamp(boss.hp / boss.max_hp, 0.0, 1.0)
		canvas.draw_rect(Rect2(br.position.x + 30, br.position.y + 52, (bw - 60) * k, 16), Color(0.62, 0.25, 0.85))
		canvas.draw_rect(Rect2(br.position.x + 30, br.position.y + 52, (bw - 60) * k, 5), Color(0.95, 0.5, 0.8))


func _draw_prompt(sz: Vector2) -> void:
	var s := prompt
	var w := bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 60
	var r := Rect2((sz.x - w) * 0.5, sz.y - 250, w, 50)
	_panel(r, 0.85, 12)
	_text(s, Vector2(sz.x * 0.5, r.position.y + 34), bold, 26, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_banner(sz: Vector2) -> void:
	if banner_t > 3.4:
		return
	var a: float = min(banner_t / 0.5, 1.0) if banner_t < 2.6 else max(0.0, 1.0 - (banner_t - 2.6) / 0.8)
	var y := 230.0
	var col := Color(0.98, 0.9, 0.66, a)
	var bg := Color(0.04, 0.03, 0.02, 0.55 * a)
	canvas.draw_rect(Rect2(sz.x * 0.5 - 520, y - 70, 1040, 100), bg)
	_text(banner_text, Vector2(sz.x * 0.5, y), disp, 64, col, HORIZONTAL_ALIGNMENT_CENTER, -1, 10 if a > 0.3 else 0)
	var gy := y + 22
	canvas.draw_line(Vector2(sz.x * 0.5 - 300, gy), Vector2(sz.x * 0.5 - 24, gy), Color(GOLD, a), 2.0)
	canvas.draw_line(Vector2(sz.x * 0.5 + 24, gy), Vector2(sz.x * 0.5 + 300, gy), Color(GOLD, a), 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(sz.x * 0.5, gy - 9), Vector2(sz.x * 0.5 + 9, gy), Vector2(sz.x * 0.5, gy + 9), Vector2(sz.x * 0.5 - 9, gy)]), Color(GOLD, a))


func _draw_toasts(sz: Vector2) -> void:
	var list = toasts.slice(max(0, toasts.size() - 3))
	for i in list.size():
		var x: Dictionary = list[i]
		var a: float = min(1.0, min(x["life"] * 2.0, (2.8 - x["life"]) * 5.0))
		var s: String = x["t"]
		var w := bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 70
		var r := Rect2((sz.x - w) * 0.5, 320 + i * 70, w, 56)
		canvas.draw_set_transform(Vector2.ZERO)
		var m := canvas.modulate
		_panel(r, 0.9 * a, 12)
		_text(s, Vector2(sz.x * 0.5, r.position.y + 39), bold, 30, Color(1, 0.92, 0.65, a), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_dialog(sz: Vector2) -> void:
	if dlg_cur == null:
		return
	var r := Rect2(sz.x * 0.5 - 760, sz.y - 300, 1520, 230)
	_panel(r, 0.94)
	var name: String = dlg_cur.get("n", "")
	if name != "":
		var nw := disp.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x + 60
		_panel(Rect2(r.position.x + 40, r.position.y - 34, nw, 58), 0.97, 12)
		_text(name, Vector2(r.position.x + 40 + nw * 0.5, r.position.y + 6), disp, 32, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
	var left := int(dlg_shown)
	for i in dlg_lines.size():
		if left <= 0:
			break
		var line: String = dlg_lines[i]
		_text(line.substr(0, left), Vector2(r.position.x + 64, r.position.y + 76 + i * 46), bold, 34, CREAM)
		left -= line.length() + 1
	var done := dlg_shown >= String(dlg_cur["t"]).length()
	var choices: Array = dlg_cur.get("ch", [])
	if done and choices.size() > 0:
		var cw := 520.0
		var ch := choices.size() * 56 + 30
		var cr := Rect2(r.end.x - cw - 20, r.position.y - ch - 18, cw, ch)
		_panel(cr, 0.97)
		for i in choices.size():
			var sel := i == dlg_sel
			if sel:
				canvas.draw_rect(Rect2(cr.position.x + 14, cr.position.y + 15 + i * 56, cw - 28, 50), Color(0.9, 0.76, 0.42, 0.2))
			_text(("▸  " if sel else "    ") + String(choices[i]["l"]), Vector2(cr.position.x + 32, cr.position.y + 50 + i * 56), bold, 30, Color(1, 0.92, 0.65) if sel else MUTED)
	elif done:
		var b := sin(t * 6.0) * 4.0
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 60, r.end.y - 44 + b), Vector2(r.end.x - 36, r.end.y - 44 + b), Vector2(r.end.x - 48, r.end.y - 30 + b)]), GOLD)


func _draw_title(sz: Vector2) -> void:
	var cx := sz.x * 0.5
	canvas.draw_rect(Rect2(0, sz.y * 0.14, sz.x, sz.y * 0.42), Color(0.02, 0.03, 0.02, 0.35))
	var f := 1.0 + sin(t * 1.4) * 0.01
	_text("Crônicas de", Vector2(cx, sz.y * 0.25), disp, 54, Color(0.95, 0.88, 0.66), HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	_text("Aetheria", Vector2(cx, sz.y * 0.25 + 150 * f), disp, int(150 * f), Color(1.0, 0.82, 0.42), HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
	_text("uma lenda de espada, sementes e mana", Vector2(cx, sz.y * 0.25 + 220), body, 36, Color(0.88, 0.95, 0.82), HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	for i in menu_items.size():
		var y := sz.y * 0.62 + i * 70
		var sel := i == menu_sel
		if sel:
			_panel(Rect2(cx - 220, y - 46, 440, 62), 0.75, 12)
			_diamond(Vector2(cx - 250, y - 15), 8)
			_diamond(Vector2(cx + 250, y - 15), 8)
		_text(menu_items[i]["label"], Vector2(cx, y), bold, 38, Color(1, 0.92, 0.65) if sel else Color(0.85, 0.8, 0.7), HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	_text("WASD mover  ·  J espada  ·  K magia  ·  L esquiva  ·  Q/E trocar magia  ·  R poção  ·  Espaço falar  ·  Esc pausa", Vector2(cx, sz.y - 40), body, 24, Color(0.8, 0.85, 0.75), HORIZONTAL_ALIGNMENT_CENTER, -1, 6)


func _diamond(c: Vector2, s: float) -> void:
	var k := s * (0.8 + 0.25 * sin(t * 6.0))
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k * 0.4, 0), c + Vector2(0, k), c + Vector2(-k * 0.4, 0)]), Color(1, 0.92, 0.65))
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-k, 0), c + Vector2(0, k * 0.4), c + Vector2(k, 0), c + Vector2(0, -k * 0.4)]), Color(1, 0.92, 0.65))


func _draw_pause(sz: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.02, 0.01, 0.6))
	var r := Rect2(sz.x * 0.5 - 520, sz.y * 0.5 - 360, 1040, 720)
	_panel(r, 0.96)
	_text("Pausa", Vector2(sz.x * 0.5, r.position.y + 84), disp, 60, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
	var rows = [["Vocação", Game.CLASSES[Game.cls]["name"]], ["Nível", Game.lvl], ["Ataque", int(Game.atk)], ["Magia", int(Game.mag)], ["Arma", Game.WEAPON_TIERS[Game.weapon_tier]["name"].replace("Lâmina de ", "")], ["Ouro", Game.gold], ["Poções", Game.potions]]
	for i in rows.size():
		_text(rows[i][0], Vector2(r.position.x + 90, r.position.y + 160 + i * 42), bold, 28, MUTED)
		_text(str(rows[i][1]), Vector2(r.position.x + 480, r.position.y + 160 + i * 42), bold, 28, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	var ctl := [["Mover", "WASD / Setas"], ["Espada", "J"], ["Magia", "K"], ["Esquiva", "L / Shift"], ["Trocar magia", "Q / E"], ["Poção", "R"], ["Árvore de Mana", "T"]]
	for i in ctl.size():
		_text(ctl[i][0], Vector2(r.position.x + 560, r.position.y + 170 + i * 44), bold, 28, MUTED)
		_text(ctl[i][1], Vector2(r.end.x - 90, r.position.y + 170 + i * 44), bold, 28, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_RIGHT)
	var names := []
	for s in Game.spells:
		names.append(Game.SPELLS[s]["name"])
	_text("Magias: " + ", ".join(names), Vector2(sz.x * 0.5, r.position.y + 505), bold, 28, Color(0.7, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	for i in menu_items.size():
		var y := r.position.y + 560 + i * 46
		var sel := i == menu_sel
		_text(("▸  " if sel else "") + String(menu_items[i]["label"]), Vector2(sz.x * 0.5, y), bold, 32, Color(1, 0.92, 0.65) if sel else MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_map(sz: Vector2) -> void:
	_text("Aetheria", Vector2(sz.x - 70, 110), disp, 88, Color(0.82, 0.92, 1.0), HORIZONTAL_ALIGNMENT_RIGHT, -1, 12)
	_text("Mapa do Mundo", Vector2(sz.x - 76, 160), body, 32, Color(0.7, 0.85, 0.78), HORIZONTAL_ALIGNMENT_RIGHT, -1, 6)
	if Game.arts.size() > 0:
		var r := Rect2(40, 40, 560, 70 + Game.arts.size() * 50)
		_panel(r, 0.9)
		_text("Artefatos para plantar", Vector2(70, 84), bold, 26, GOLD)
		for i in Game.arts.size():
			var a: String = Game.arts[i]
			var c: Color = Game.ARTS[a]["color"]
			canvas.draw_circle(Vector2(84, 124 + i * 50), 14, c)
			canvas.draw_circle(Vector2(80, 119 + i * 50), 5, Color(1, 1, 1, 0.8))
			_text(Game.ARTS[a]["name"], Vector2(112, 134 + i * 50), bold, 28, CREAM)
	var w := 1100.0
	var r2 := Rect2((sz.x - w) * 0.5, sz.y - 110, w, 72)
	_panel(r2, 0.92)
	_text(map_info, Vector2(sz.x * 0.5, r2.position.y + 47), bold, 30, CREAM, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_gameover(sz: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.08, 0.0, 0.0, min(0.75, gameover_t)))
	if gameover_t > 0.8:
		_text("Você desmaiou...", Vector2(sz.x * 0.5, sz.y * 0.44), disp, 80, Color(0.95, 0.72, 0.62), HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		_text("A mana te leva de volta à Vila Lumen. Metade do ouro fica pelo caminho.", Vector2(sz.x * 0.5, sz.y * 0.52), bold, 32, Color(0.9, 0.84, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
		_text("Espaço para continuar", Vector2(sz.x * 0.5, sz.y * 0.6), bold, 32, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_ending(sz: Vector2) -> void:
	var k: float = min(0.78, ending_t * 0.35)
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.02, 0.1, k))
	var lines := [["A Árvore de Mana floresce outra vez.", 1.0, 0.24, 44], ["Pétalas de luz caem sobre Aetheria,", 2.5, 0.31, 44], ["e cada terra plantada volta a sonhar.", 3.5, 0.38, 44], ["FIM", 5.5, 0.55, 110], ["Obrigado por jogar Crônicas de Aetheria", 6.5, 0.66, 34], ["Espaço para continuar explorando", 8.0, 0.78, 32]]
	for L in lines:
		if ending_t < L[1]:
			continue
		var a: float = min(1.0, ending_t - L[1])
		var f: Font = disp if L[0] == "FIM" else bold
		_text(L[0], Vector2(sz.x * 0.5, sz.y * L[2]), f, L[3], Color(1, 0.95, 1.0, a) if L[0] != "Espaço para continuar explorando" else Color(1, 0.92, 0.65, a), HORIZONTAL_ALIGNMENT_CENTER, -1, 8)


# ---------------------------------------------------------------- Mana Tree screen

const BRANCH_COL := {"sword": Color(1.0, 0.62, 0.3), "magic": Color(0.55, 0.72, 1.0), "life": Color(0.5, 0.95, 0.5)}
const BRANCH_NAME := {"sword": "Galho da Espada", "magic": "Galho da Magia", "life": "Galho da Vida"}


func tree_move(dir: Vector2) -> void:
	var from: Vector2 = Game.SKILLS[tree_sel]["pos"]
	var best := ""
	var bd := 1e9
	for id in Game.SKILLS:
		if id == tree_sel:
			continue
		var d: Vector2 = Game.SKILLS[id]["pos"] - from
		if d.normalized().dot(dir) < 0.35:
			continue
		var score := d.length() * (2.0 - d.normalized().dot(dir))
		if score < bd:
			bd = score
			best = id
	if best != "":
		tree_sel = best
		Sfx.play("blip", -8.0)


func _draw_tree(sz: Vector2) -> void:
	# the canvas is laid out for 1920x1080; centre it on wider screens
	var off := Vector2((sz.x - 1920.0) * 0.5, (sz.y - 1080.0) * 0.5)
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.03, 0.05, 0.86))
	_text("Árvore de Mana", Vector2(sz.x * 0.5, 110 + off.y), disp, 72, Color(0.85, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	_diamond(Vector2(sz.x * 0.5 - 150, 160 + off.y), 12)
	_text("%d Essência" % Game.essence, Vector2(sz.x * 0.5 + 12, 172 + off.y), bold, 34, Color(1.0, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	# trunk and roots
	var base := Vector2(960, 1010) + off
	var fork := Vector2(960, 820) + off
	canvas.draw_line(base, fork, Color(0.45, 0.32, 0.2), 34.0)
	canvas.draw_line(base, fork, Color(0.62, 0.46, 0.3), 14.0)
	for k in [-1, 1]:
		canvas.draw_line(base, base + Vector2(k * 140, 40), Color(0.45, 0.32, 0.2), 16.0)
	for root_id in ["s_edge", "m_flow", "v_root"]:
		var p: Vector2 = Game.SKILLS[root_id]["pos"] + off
		canvas.draw_line(fork, p, Color(0.45, 0.32, 0.2), 20.0)
	# links
	for id in Game.SKILLS:
		var s: Dictionary = Game.SKILLS[id]
		for r in s["req"]:
			for alt in String(r).split("|"):
				var a: Vector2 = Game.SKILLS[alt]["pos"] + off
				var b: Vector2 = s["pos"] + off
				var lit := Game.has_skill(alt)
				canvas.draw_line(a, b, Color(0.45, 0.32, 0.2), 14.0)
				canvas.draw_line(a, b, BRANCH_COL[s["branch"]] * (1.0 if lit else 0.35), 5.0)
	# branch titles
	_text(BRANCH_NAME["sword"], Vector2(480, 300) + off, bold, 30, BRANCH_COL["sword"], HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
	_text(BRANCH_NAME["magic"], Vector2(960, 330) + off + Vector2(250, 0), bold, 30, BRANCH_COL["magic"], HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
	_text(BRANCH_NAME["life"], Vector2(1440, 300) + off, bold, 30, BRANCH_COL["life"], HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
	# nodes
	for id in Game.SKILLS:
		var s: Dictionary = Game.SKILLS[id]
		var p: Vector2 = s["pos"] + off
		var st := Game.skill_state(id)
		var col: Color = BRANCH_COL[s["branch"]]
		var pulse := 0.5 + 0.5 * sin(t * 4.0 + p.x * 0.01)
		if st == "owned":
			canvas.draw_circle(p, 58, Color(col.r, col.g, col.b, 0.22))
			canvas.draw_circle(p, 42, col)
			canvas.draw_circle(p, 34, col.lightened(0.35))
		elif st == "available":
			canvas.draw_circle(p, 42, Color(0.08, 0.06, 0.05, 0.95))
			canvas.draw_arc(p, 42, 0, TAU, 48, Color(col.r, col.g, col.b, 0.5 + 0.5 * pulse), 5.0)
		else:
			canvas.draw_circle(p, 38, Color(0.1, 0.1, 0.1, 0.9))
			canvas.draw_arc(p, 38, 0, TAU, 40, Color(0.35, 0.35, 0.35), 3.0)
		_text(str(s["cost"]), p + Vector2(0, 12), bold, 34, Color(0.1, 0.06, 0.02) if st == "owned" else (col if st == "available" else Color(0.45, 0.45, 0.45)), HORIZONTAL_ALIGNMENT_CENTER)
		if id == tree_sel:
			canvas.draw_arc(p, 54 + pulse * 4.0, 0, TAU, 56, Color(1, 1, 1), 4.0)
		_text(s["name"], p + Vector2(0, 76), bold, 24, CREAM if st != "locked" else Color(0.55, 0.55, 0.55), HORIZONTAL_ALIGNMENT_CENTER, -1, 6)
	# detail panel
	var sel: Dictionary = Game.SKILLS[tree_sel]
	var r := Rect2(sz.x * 0.5 - 620, sz.y - 190, 1240, 150)
	_panel(r, 0.95)
	_text(sel["name"], Vector2(r.position.x + 40, r.position.y + 52), disp, 38, BRANCH_COL[sel["branch"]])
	_text(sel["desc"], Vector2(r.position.x + 40, r.position.y + 98), bold, 28, CREAM)
	var st2 := Game.skill_state(tree_sel)
	var info := ""
	if st2 == "owned":
		info = "Aprendida"
	elif st2 == "locked":
		info = "Aprenda o galho anterior primeiro"
	elif Game.essence < sel["cost"]:
		info = "Custa %d Essência  ·  suba de nível para ganhar mais" % sel["cost"]
	else:
		info = "Custa %d Essência  ·  Espaço para aprender" % sel["cost"]
	_text(info, Vector2(r.end.x - 40, r.position.y + 52), bold, 26, Color(1, 0.92, 0.65) if st2 == "available" else MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("Setas para navegar  ·  T ou Esc para fechar", Vector2(sz.x * 0.5, sz.y - 18), body, 22, MUTED, HORIZONTAL_ALIGNMENT_CENTER)



# ---------------------------------------------------------------- combat extras

func loot_toast(item: Dictionary) -> void:
	loot_log.append({"item": item, "life": 4.0})
	if loot_log.size() > 5:
		loot_log.pop_front()
	if int(item["rarity"]) >= 3:
		banner_text = item["name"]
		banner_t = 0.0


func _draw_combat_extras(sz: Vector2) -> void:
	# rift progress
	var main := get_tree().get_first_node_in_group("main")
	if main and main.level and main.level.id == "rift":
		var lv = main.level
		var w := 700.0
		var r := Rect2((sz.x - w) * 0.5, 70, w, 58)
		_panel(r, 0.85, 12)
		var k: float = lv.rift_progress / 100.0
		canvas.draw_rect(Rect2(r.position.x + 20, r.position.y + 34, w - 40, 12), Color(0.05, 0.02, 0.06))
		canvas.draw_rect(Rect2(r.position.x + 20, r.position.y + 34, (w - 40) * k, 12), Color(0.75, 0.4, 1.2) if not lv.guardian_spawned else Color(1.4, 0.5, 0.4))
		var tl2 := "Fenda nível %d  ·  %d:%02d" % [Game.rift_level, int(lv.time_left) / 60, int(lv.time_left) % 60]
		if lv.guardian_spawned and not lv.finished:
			tl2 += "  ·  Derrote o Guardião!"
		elif lv.finished:
			tl2 += "  ·  Concluída — use o portal"
		_text(tl2, Vector2(sz.x * 0.5, r.position.y + 26), bold, 22, Color(1.0, 0.4, 0.4) if lv.time_left <= 0.0 else Color(0.9, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	# difficulty and area level
	var tl = "%s  ·  Nível dos monstros %d" % [Game.TORMENT[Game.torment]["name"], Game.monster_level(1)]
	_text(tl, Vector2(sz.x * 0.5, 44), bold, 22, Color(1.0, 0.75, 0.55) if Game.torment >= 4 else MUTED, HORIZONTAL_ALIGNMENT_CENTER, -1, 5)
	# kill streak
	if streak >= 3:
		var s = 1.0 + min(streak, 40) * 0.012
		_text("x%d" % streak, Vector2(sz.x - 60, 260), disp, int(64 * s), Color(1.0, 0.7, 0.3), HORIZONTAL_ALIGNMENT_RIGHT, -1, 10)
		_text("MASSACRE" if streak >= 10 else "Combo", Vector2(sz.x - 60, 300), bold, 26, Color(1.0, 0.85, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, -1, 6)
	# picked-up items
	for i in loot_log.size():
		var x: Dictionary = loot_log[i]
		var a: float = min(1.0, x["life"])
		var it: Dictionary = x["item"]
		var c := Items.color(it)
		_text("+ " + String(it["name"]), Vector2(40, sz.y - 300 + i * 34), bold, 26, Color(c.r, c.g, c.b, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
	# crosshair
	if fp:
		var c := sz * 0.5
		canvas.draw_arc(c, 12, 0, TAU, 32, Color(1, 1, 1, 0.7), 2.0)
		canvas.draw_circle(c, 2.5, Color(1, 0.95, 0.8, 0.9))


# ---------------------------------------------------------------- inventory

const EQUIP_POS := {
	"helm": Vector2(380, 150), "amulet": Vector2(540, 170), "weapon": Vector2(220, 310), "chest": Vector2(380, 310),
	"gloves": Vector2(540, 330), "ring1": Vector2(220, 470), "boots": Vector2(380, 470), "ring2": Vector2(540, 490),
}
const GRID_ORIGIN := Vector2(820, 150)
const GRID_COLS := 8
const CELL := 104.0
const STAT_LABELS := {
	"atk": "Ataque", "mag": "Magia", "hp": "Vida", "mp": "Mana", "armor": "Armadura", "crit": "Chance Crítica %", "critdmg": "Dano Crítico %",
	"aspd": "Vel. de Ataque %", "move": "Vel. de Movimento %", "leech": "Roubo de Vida %", "regen": "Vida/s", "fire": "Dano de Fogo %",
	"ice": "Dano de Gelo %", "bolt": "Dano de Raio %", "cost": "Custo de Mana -%", "gold": "Ouro %", "mf": "Achado Mágico %",
	"thorns": "Espinhos", "area": "Área %", "elite": "Dano vs Elites %",
}


func _inv_rects(off: Vector2) -> Array:
	var out := []
	for s in Items.SLOTS:
		out.append({"kind": "equip", "slot": s, "rect": Rect2(EQUIP_POS[s] + off, Vector2(130, 130))})
	for i in Game.INV_SIZE:
		var c := i % GRID_COLS
		var r := i / GRID_COLS
		out.append({"kind": "bag", "idx": i, "rect": Rect2(GRID_ORIGIN + off + Vector2(c * CELL, r * CELL), Vector2(CELL - 8, CELL - 8))})
	return out


func _inv_off() -> Vector2:
	return Vector2((canvas.size.x - 1920.0) * 0.5, (canvas.size.y - 1080.0) * 0.5)


func inv_selected() -> Dictionary:
	var rects := _inv_rects(Vector2.ZERO)
	if inv_sel < 0 or inv_sel >= rects.size():
		return {}
	var e: Dictionary = rects[inv_sel]
	if e["kind"] == "equip":
		return e if Game.equipment.get(e["slot"]) != null else {}
	return e if e["idx"] < Game.inventory.size() else {}


func inv_move(dir: Vector2) -> void:
	var rects := _inv_rects(Vector2.ZERO)
	var from: Vector2 = rects[inv_sel]["rect"].get_center()
	var best := -1
	var bd := 1e9
	for i in rects.size():
		if i == inv_sel:
			continue
		var d: Vector2 = rects[i]["rect"].get_center() - from
		if d.length() < 1.0 or d.normalized().dot(dir) < 0.5:
			continue
		var score := d.length() * (2.0 - d.normalized().dot(dir))
		if score < bd:
			bd = score
			best = i
	if best >= 0:
		inv_sel = best
		Sfx.play("blip", -10.0)


func inv_hover(p: Vector2) -> void:
	var rects := _inv_rects(_inv_off())
	for i in rects.size():
		if (rects[i]["rect"] as Rect2).has_point(p):
			inv_sel = i
			return


func _item_glyph(r: Rect2, slot: String, col: Color) -> void:
	var c := r.get_center()
	var s := r.size.x * 0.32
	match slot:
		"weapon":
			canvas.draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 7.0)
			canvas.draw_line(c + Vector2(-s * 0.9, s * 0.2), c + Vector2(-s * 0.2, s * 0.9), col, 6.0)
		"helm":
			canvas.draw_arc(c + Vector2(0, s * 0.3), s, PI, TAU, 24, col, 7.0)
			canvas.draw_line(c + Vector2(-s, s * 0.3), c + Vector2(s, s * 0.3), col, 6.0)
			canvas.draw_line(c + Vector2(0, s * 0.3), c + Vector2(0, s * 0.9), col, 5.0)
		"chest":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.8), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.7, s), c + Vector2(-s * 0.7, s)]), Color(col, 0.85))
		"gloves":
			canvas.draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.4), Vector2(s * 1.2, s * 1.3)), Color(col, 0.85))
			for k in 3:
				canvas.draw_line(c + Vector2(-s * 0.4 + k * s * 0.4, -s * 0.4), c + Vector2(-s * 0.4 + k * s * 0.4, -s), col, 6.0)
		"boots":
			canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s), c + Vector2(s * 0.1, -s), c + Vector2(s * 0.1, s * 0.4), c + Vector2(s, s * 0.5), c + Vector2(s, s), c + Vector2(-s * 0.5, s)]), Color(col, 0.85))
		"amulet":
			canvas.draw_arc(c + Vector2(0, -s * 0.4), s * 0.8, PI * 0.1, PI * 0.9, 16, col, 3.0)
			canvas.draw_circle(c + Vector2(0, s * 0.5), s * 0.45, col)
		_:
			canvas.draw_arc(c, s * 0.6, 0, TAU, 24, col, 7.0)
			canvas.draw_circle(c + Vector2(0, -s * 0.6), s * 0.25, col)


func _slot_box(r: Rect2, item, selected: bool, empty_slot := "") -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.045, 0.03, 0.92)
	var border := Color(0.35, 0.28, 0.18)
	if item != null:
		border = Items.color(item)
		sb.bg_color = Color(border.r * 0.14, border.g * 0.12, border.b * 0.1, 0.95)
	sb.border_color = Color(1, 1, 1) if selected else border
	sb.set_border_width_all(4 if selected else 2)
	sb.set_corner_radius_all(8)
	canvas.draw_style_box(sb, r)
	if item != null:
		_item_glyph(r, item["slot"] if item["slot"] != "ring" else "ring", Items.color(item))
		if int(item["rarity"]) >= 3:
			canvas.draw_arc(r.get_center(), r.size.x * 0.46, 0, TAU, 32, Color(Items.color(item), 0.4 + 0.3 * sin(t * 3.0)), 3.0)
	elif empty_slot != "":
		_item_glyph(r, empty_slot.trim_suffix("1").trim_suffix("2"), Color(0.35, 0.3, 0.22))


func _item_panel(r: Rect2, item: Dictionary, title := "") -> float:
	_panel(r, 0.96)
	var y := r.position.y + 44
	if title != "":
		_text(title, Vector2(r.position.x + 28, y - 8), body, 20, MUTED)
		y += 22
	var ls := Items.lines(item)
	for i in ls.size():
		var L: Array = ls[i]
		var size = 26 if i == 0 else 19
		var f: Font = disp if i == 0 and int(item["rarity"]) >= 3 else bold
		for w in _wrap(String(L[0]), f, size, r.size.x - 56):
			_text(w, Vector2(r.position.x + 28, y), f, size, L[1])
			y += size + 5
	return y


func _draw_inventory(sz: Vector2) -> void:
	var off := _inv_off()
	canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.015, 0.01, 0.82))
	_panel(Rect2(Vector2(150, 60) + off, Vector2(600, 960)), 0.9)
	_panel(Rect2(Vector2(790, 60) + off, Vector2(870, 700)), 0.9)
	_text("Kael, %s  ·  Nível %d" % [Game.CLASSES[Game.cls]["name"], Game.lvl], Vector2(450, 120) + off, disp, 34, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
	_text("Bolsa  (%d/%d)" % [Game.inventory.size(), Game.INV_SIZE], Vector2(1225, 120) + off, disp, 34, Color(1, 0.92, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
	var rects := _inv_rects(off)
	for i in rects.size():
		var e: Dictionary = rects[i]
		if e["kind"] == "equip":
			_slot_box(e["rect"], Game.equipment.get(e["slot"]), i == inv_sel, e["slot"])
		else:
			_slot_box(e["rect"], Game.inventory[e["idx"]] if e["idx"] < Game.inventory.size() else null, i == inv_sel)
	# stats
	var dr := Game.damage_reduction(Game.monster_level(1)) * 100.0
	var rows := [
		["Ataque", "%d" % Game.atk], ["Magia", "%d" % Game.mag], ["Vida", "%d" % Game.max_hp], ["Mana", "%d" % Game.max_mp],
		["Armadura", "%d  (-%d%% dano)" % [Game.stat("armor"), dr]], ["Crítico", "%d%%  ·  x%.1f" % [Game.crit_chance() * 100.0, Game.crit_mult()]],
		["Vel. de ataque", "+%d%%" % Game.stat("aspd")], ["Vel. de movimento", "+%d%%" % ((Game.move_speed() - 1.0) * 100.0)],
		["Roubo de vida", "%.1f%%" % (Game.leech() * 100.0)], ["Achado mágico", "+%d%%" % Game.stat("mf")],
		["Ouro", "%d" % Game.gold], ["Pó de Mana", "%d" % Game.dust],
	]
	for i in rows.size():
		_text(rows[i][0], Vector2(190, 680 + i * 28) + off, bold, 22, MUTED)
		_text(rows[i][1], Vector2(710, 680 + i * 28) + off, bold, 22, CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	# tooltip + comparison
	var sel := inv_selected()
	if not sel.is_empty():
		var item: Dictionary = Game.equipment[sel["slot"]] if sel["kind"] == "equip" else Game.inventory[sel["idx"]]
		_item_panel(Rect2(Vector2(790, 776) + off, Vector2(430, 268)), item, "Equipado" if sel["kind"] == "equip" else "")
		if sel["kind"] == "bag":
			var cur = Game.equipped_for(item)
			var cmp := Rect2(Vector2(1230, 776) + off, Vector2(430, 268))
			_panel(cmp, 0.96)
			_text("Se equipar:", Vector2(cmp.position.x + 28, cmp.position.y + 40), bold, 24, Color(1, 0.92, 0.65))
			var a := {}
			var b := {}
			Items.add_stats(a, item)
			if cur != null:
				Items.add_stats(b, cur)
			var keys := {}
			for k in a:
				keys[k] = true
			for k in b:
				keys[k] = true
			var y := cmp.position.y + 76
			for k in keys:
				if String(k).begins_with("legend_"):
					continue
				var d: float = float(a.get(k, 0.0)) - float(b.get(k, 0.0))
				if abs(d) < 0.5:
					continue
				var col = Color(0.45, 1.0, 0.45) if d > 0 else Color(1.0, 0.45, 0.4)
				_text("%s%d %s" % ["+" if d > 0 else "", d, STAT_LABELS.get(k, k)], Vector2(cmp.position.x + 28, y), bold, 22, col)
				y += 28
				if y > cmp.end.y - 20:
					break
			if item.get("legend", "") != "":
				_text("+ poder lendário", Vector2(cmp.position.x + 28, min(y, cmp.end.y - 16)), bold, 22, Color(1.0, 0.62, 0.2))
	_text("Espaço/clique: equipar  ·  X/clique direito: desmontar  ·  G: desmontar comuns e mágicos  ·  I: fechar", Vector2(sz.x * 0.5, 1074 + off.y), body, 19, MUTED, HORIZONTAL_ALIGNMENT_CENTER, -1, 4)
