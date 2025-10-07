package cursor

import    "core:math"

import rl "vendor:raylib"

State :: enum {
  DEFAULT,
  POTENTIAL,
  DRAG,
  RESIZE,
  SCROLL_UP,
  SCROLL_DOWN,
  PAGE_PREV,
  PAGE_NEXT
}

@(private) g_state : State
@(private) g_txr   : rl.Texture

@(private) g_conf  : [State]struct{txr_offset: f32, pos: rl.Vector2}

init :: proc(txr_path: cstring)
{
  g_txr  = rl.LoadTexture(txr_path)
  rl.HideCursor()

  g_conf[.DEFAULT]     = {}
  g_conf[.POTENTIAL]   = {16,  { -8,  -8}}
  g_conf[.DRAG]        = {32,  { -8,  -8}}
  g_conf[.RESIZE]      = {48,  {-16, -16}}
  g_conf[.SCROLL_UP]   = {64,  { -4, -10}}
  g_conf[.SCROLL_DOWN] = {80,  { -4,  -4}}
  g_conf[.PAGE_PREV]   = {96,  { -8,  -8}}
  g_conf[.PAGE_NEXT]   = {112, { -8,  -8}}
}

fini :: proc()
{
  rl.UnloadTexture(g_txr)
}

set_state :: #force_inline proc(state: State)
{
  g_state = state
}

get_state :: #force_inline proc() -> State
{
  return g_state
}

draw :: proc(scale: f32)
{
  pos := rl.GetMousePosition()
  pos.x = math.trunc(pos.x / scale)
  pos.y = math.trunc(pos.y / scale)

  conf := g_conf[g_state]
  rl.DrawTextureRec(g_txr, {conf.txr_offset, 0, 16, 16}, pos+conf.pos, rl.WHITE)
}