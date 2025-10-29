package cursor

import    "core:math"

import rl "vendor:raylib"

CURSOR_SIZE :: 16

State :: enum {
  DEFAULT     = 0,
  POTENTIAL,
  DRAG,
  RESIZE,
  SCROLL_UP,
  SCROLL_DOWN,
  PAGE_PREV,
  PAGE_NEXT
}

@(private)
cfg: struct {
  txr     : rl.Texture,
  offsets : [State]rl.Vector2
}
@(private) state: State

init :: proc(txr_path: cstring)
{
  cfg.txr  = rl.LoadTexture(txr_path)
  rl.HideCursor()

  cfg.offsets[.DEFAULT]     = {}
  cfg.offsets[.POTENTIAL]   = { -8,  -8}
  cfg.offsets[.DRAG]        = { -8,  -8}
  cfg.offsets[.RESIZE]      = {-16, -16}
  cfg.offsets[.SCROLL_UP]   = { -4, -10}
  cfg.offsets[.SCROLL_DOWN] = { -4,  -4}
  cfg.offsets[.PAGE_PREV]   = { -8,  -8}
  cfg.offsets[.PAGE_NEXT]   = { -8,  -8}
}

fini :: proc()
{
  rl.UnloadTexture(cfg.txr)
}

set_state :: #force_inline proc(p_state: State)
{
  state = p_state
}

get_state :: #force_inline proc() -> State
{
  return state
}

draw :: proc(scale: f32)
{
  pos := rl.GetMousePosition()
  pos.x = math.trunc(pos.x / scale)
  pos.y = math.trunc(pos.y / scale)

  offset := cfg.offsets[state]
  rl.DrawTextureRec(
    cfg.txr, 
    {
      CURSOR_SIZE * f32(state), 
      0, 
      CURSOR_SIZE, 
      CURSOR_SIZE
    }, 
    pos + offset,
    rl.WHITE)
}