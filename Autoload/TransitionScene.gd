extends CanvasLayer
## TransitionScreen - Persistent fade overlay for scene transitions
##
## SETUP:
## 1. Save this as TransitionScreen.gd
## 2. Save TransitionScreen.tscn with this script attached
## 3. Project → Project Settings → Autoload
## 4. Add TransitionScreen.tscn as "TransitionScreen"
##
## USAGE:
## await TransitionScreen.fade_out(0.5)
## SceneManager.change_scene(...)
## await TransitionScreen.fade_in(0.5)

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	# Ensure we're on top of everything
	layer = 100
	
	# Start fully transparent
	if color_rect:
		color_rect.modulate.a = 0.0
	
	print("TransitionScreen ready")

## Fade to black
func fade_out(duration: float = 0.5) -> void:
	if not color_rect:
		push_warning("TransitionScreen: ColorRect not found!")
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	await tween.finished
	print("TransitionScreen: Faded out")

## Fade from black to transparent
func fade_in(duration: float = 0.5) -> void:
	if not color_rect:
		push_warning("TransitionScreen: ColorRect not found!")
		return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	await tween.finished
	print("TransitionScreen: Faded in")

## Complete fade transition (out then in)
func transition(fade_out_time: float = 0.5, fade_in_time: float = 0.5, hold_time: float = 0.1) -> void:
	await fade_out(fade_out_time)
	await get_tree().create_timer(hold_time).timeout
	await fade_in(fade_in_time)

## Instant black (for starting game)
func instant_black() -> void:
	if color_rect:
		color_rect.modulate.a = 1.0

## Instant transparent (for clearing)
func instant_clear() -> void:
	if color_rect:
		color_rect.modulate.a = 0.0
