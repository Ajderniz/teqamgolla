/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import    "core:math"
import    "core:log"

import rl "vendor:raylib"

ImageElement :: struct {
  texture : rl.Texture,
  resize  : enum { NONE, CENTER, STRETCH },
}

ActionState :: enum {
  NONE,
  DRAG,
  RESIZE,
  SCROLL_UP,
  SCROLL_DOWN,
}

CursorState :: enum {
  DEFAULT,
  POTENTIAL,
  DRAG,
  RESIZE,
  SCROLL_UP,
  SCROLL_DOWN,
  PAGE_PREV,
  PAGE_NEXT
}

@(private) g_vf_freq       : int

@(private) g_cursor_state  : CursorState

@(private) g_font          : rl.Font
@(private) g_pad           : f32
@(private) g_fg_color      : rl.Color
@(private) g_bg_color      : rl.Color
@(private) g_line_thick    : f32

@(private) g_header_height : f32
@(private) g_base_unit     : rl.Vector2

@(private)
is_v2_within_rec :: #force_inline proc(
  v2: rl.Vector2,
  rec: rl.Rectangle) -> bool
{
  return(!((v2.x < rec.x || (rec.x + rec.width) < v2.x) ||
          (v2.y < rec.y || (rec.y + rec.height) < v2.y)))
}

@(private)
are_rectangles_overlapping :: #force_inline proc(
  rec1: rl.Rectangle, 
  rec2: rl.Rectangle
  ) -> bool
{
  return(!(((rec1.x + rec1.width) < rec2.x || (rec2.x + rec2.width) < rec1.x) ||
         ((rec1.y + rec1.height) < rec2.y || (rec2.y + rec2.height) < rec1.y)))
}

init :: proc(
  font       : rl.Font,
  pad        : f32        = 12,
  fg_color   :            = rl.BLACK,
  bg_color   :            = rl.WHITE,
  line_thick : f32        = 1,
  base_unit  : rl.Vector2 = { 1, 1 },
  vf_freq    :            = 1
) {
  g_font       = font
  g_pad        = pad
  g_fg_color   = fg_color
  g_bg_color   = bg_color
  g_line_thick = line_thick
  g_base_unit  = base_unit
  g_vf_freq    = (0 < vf_freq) ? vf_freq : 1

  g_header_height = f32(g_font.baseSize) + math.trunc(g_pad / 2)
}

get_cursor_state :: #force_inline proc() -> CursorState
{
  return g_cursor_state
}
