package cursor

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

CURSOR_SIZE   ::             16
CENTER_CURSOR : rl.Vector2 : { -CURSOR_SIZE/2, -CURSOR_SIZE/2 }

BASE_FIELD_ID :: "base"

State :: struct {
  field_id  : string,
  cur_index : int
}

CursorState :: enum {
  DEFAULT = 0,
  HOVER,
  PRESS,
  COUNT
}

FieldConf :: struct {
  txr     : rl.Texture,
  offsets : []rl.Vector2
}

@(private) cursors : map[string]FieldConf
@(private) state   : State

init :: proc(txr_path: cstring, offsets: []rl.Vector2) -> bool
{
  if len(offsets) != int(CursorState.COUNT)
  {
    log.error("Invalid offset array size")
    return false
  }
  if !add_field(BASE_FIELD_ID, txr_path, offsets[:3])
  {
    log.error("Could not add base cursor field")
    return false
  }
  rl.HideCursor()
  set_base_state(.DEFAULT)
  return true
}

fini :: proc()
{
  for field_id, field in cursors
  {
    rl.UnloadTexture(field.txr)
  }
  delete(cursors)
}

add_field :: proc(
  field_id : string, 
  txr_path : cstring, 
  offsets  : []rl.Vector2) -> bool
{
  cfg: FieldConf
  cfg.txr = rl.LoadTexture(txr_path)
  if !rl.IsTextureValid(cfg.txr)
  {
    log.errorf("'%v': could not load texture '%v'", field_id, txr_path)
    return false
  }
  cfg.offsets = offsets
  cursors[field_id] = cfg
  return true
}

set_state :: proc(field_id: string, cur_index: int)
{
  if field_id not_in cursors || 
     cur_index < 0 || 
     len(cursors[field_id].offsets) <= cur_index
  {
    state.field_id  = BASE_FIELD_ID
    state.cur_index = int(CursorState.DEFAULT)
    return
  }
  state.field_id  = field_id
  state.cur_index = cur_index
}

set_base_state :: #force_inline proc(state: CursorState)
{
  set_state(BASE_FIELD_ID, int(state))
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

  cfg    := cursors[state.field_id]
  offset := cfg.offsets[state.cur_index]
  rl.DrawTextureRec(
    cfg.txr,
    {
      CURSOR_SIZE * f32(state.cur_index),
      0,
      CURSOR_SIZE,
      CURSOR_SIZE
    },
    pos + offset,
    rl.WHITE
  )
}