/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

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

@(private) g_frame_delay   : int
@(private) g_scroll_delay  : int

@(private) g_cursor_state  : CursorState

@(private) g_font          : rl.Font
@(private) g_pad           : f32
@(private) g_fg_color      : rl.Color
@(private) g_bg            : ItemBackground

@(private) g_line_thick    : f32
@(private) g_border        : ItemBorder

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
  font         : rl.Font,
  pad          : f32            = 12,
  fg_color     :                = rl.BLACK,
  bg           : ItemBackground = { color=rl.WHITE },
  border       : ItemBorder     = {},
  line_thick   : f32            = 1,
  base_unit    : rl.Vector2     = { 1, 1 },
  frame_delay  :                = 1,
  scroll_delay :                = 1,
) {
  g_font         = font
  g_pad          = pad
  g_fg_color     = fg_color
  g_bg           = bg
  g_border       = border
  g_line_thick   = line_thick
  g_base_unit    = base_unit
  g_frame_delay  = (frame_delay < 0) ? 1 : frame_delay
  g_scroll_delay = (scroll_delay < 0) ? 1 : scroll_delay

  g_header_height = f32(g_font.baseSize) + math.trunc(g_pad / 2)
}

get_cursor_state :: #force_inline proc() -> CursorState
{
  return g_cursor_state
}
