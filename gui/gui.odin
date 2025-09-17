/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import      "core:math"
import sort "core:sort"
import str  "core:strings"

import rl   "vendor:raylib"

import "core:fmt"

ImageElement :: struct {
  texture    : rl.Texture,
  resize     : enum { NONE, CENTER, STRETCH },
}

BoxElement :: struct {
  header     : string,
  content    : []^Element,
  layout     : enum{ VERTICAL, HORIZONTAL },

  style      : enum{ GLOBAL, CUSTOM },
  font       : rl.Font,
  pad        : f32,
  txt_color  : rl.Color,
  bg_color   : rl.Color,
}

Element :: struct {
  data       : union { string, ImageElement, BoxElement },

  rec           : rl.Rectangle,
  min_size      : rl.Vector2,
  max_size      : rl.Vector2,
  non_resizable : bool
}

MouseState :: enum {
  DEFAULT,
  DRAG,
  RESIZE
}

Window :: struct {
  draggable   : bool,
  mouse_state : MouseState,

  emt         : ^Element
}

@(private) g_font       : rl.Font
@(private) g_pad        : f32
@(private) g_txt_color  : rl.Color
@(private) g_bg_color   : rl.Color
@(private) g_line_color : rl.Color
@(private) g_line_thick : f32

@(private) g_header_height : f32
@(private) g_base_unit     : rl.Vector2

@(private)
is_vector_within_rectangle :: #force_inline proc(
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

@(private)
draw_text :: proc(
  rec       : rl.Rectangle,
  txt       : string,
  font      : rl.Font,
  txt_color : rl.Color
  ) {
  max_cols: int
  max_lines: int
  {
    max_cols = int(math.trunc(rec.width / font.recs[0].width))

    glyph_pad := f32(font.glyphPadding) / 2
    max_height := rec.height + glyph_pad
    glyph_height := f32(font.baseSize) + glyph_pad
    max_lines = int(math.trunc(max_height / glyph_height))
  }

  lines := [dynamic]string{}
  defer delete(lines)

  txt_needs_ellipsis := true
  start := 0
  for i := 1; i <= max_lines; i += 1
  {
    end := start + max_cols
    line: string
    ok: bool

    if end < (str.rune_count(txt) - 1)
    {
      line, ok = str.substring(txt, start, end)
    }
    else
    {
      end = str.rune_count(txt)
      line, ok = str.substring(txt, start, end)
      append(&lines, line)
      txt_needs_ellipsis = false
      break
    }

    line = str.trim_left_space(line)

    has_spaces := str.contains_any(line, " \t\r\n")
    is_last_line := max_lines <= i
    if has_spaces && ok && !is_last_line
    {

      limit := str.last_index_any(line, " \t\r\n")
      ko: bool // unused
      line, ko = str.substring_to(line, limit)

      limit -= len(line) - str.rune_count(line)
      line, ko = str.substring_to(line, limit)

      end = start + limit
    }
    else if is_last_line
    {
      ko: bool
      line, ko = str.substring_to(line, str.rune_count(line) - 3)
    }
    if 0 < len(line)
    {
      append(&lines, line)
    }
    start = has_spaces ? end + 1 : end
  }

  if max_cols <= 3
  {
    length := len(lines)
    if 0 < length
    {
      lines[length - 1] = "..."
    } 
    else
    {
      append(&lines, "...")
    }
    txt_needs_ellipsis = false
  }

  printed_txt := str.join(lines[:], "\n")
  if txt_needs_ellipsis
  {
    old_txt := printed_txt
    printed_txt = str.join({printed_txt, "..."}, "")
    delete(old_txt)
  }
  printed_msg_cstring := str.clone_to_cstring(printed_txt)
  defer delete(printed_txt)
  defer delete(printed_msg_cstring)

  rl.DrawTextEx(
    font,
    printed_msg_cstring,
    {rec.x, rec.y},
    cast(f32)g_font.baseSize,
    0,
    txt_color,
  )
}

@(private)
configure_box_min_size :: proc(element: ^Element)
{
  #partial switch d in element.data
  {
  case string, ImageElement:
    return
  }
  if 0 < element.min_size.x && 0 < element.min_size.y
  {
    return
  }
  box := element.data.(BoxElement)

  min_size: rl.Vector2

  pad  := (.CUSTOM == box.style) ? box.pad  : g_pad
  font := (.CUSTOM == box.style) ? box.font : g_font

  double_pad   := pad * 2
  three_glyphs := f32(font.recs[0].width) * 3
  font_height  := f32(font.baseSize)

  for e, i in box.content
  {
    switch d in e.data
    {
    case string:
      e.min_size.x = (e.min_size.x < three_glyphs) ? three_glyphs : e.min_size.x
      e.min_size.y = (e.min_size.y < font_height)  ? font_height  : e.min_size.y

    case ImageElement:
      og_size: rl.Vector2 = { f32(d.texture.width), f32(d.texture.height) }
      e.min_size.x = (e.min_size.x < og_size.x) ? og_size.x : e.min_size.x
      e.min_size.y = (e.min_size.y < og_size.y) ? og_size.y : e.min_size.y

    case BoxElement:
      configure_box_min_size(e)
    }

    this_min_size := e.min_size
    switch d in e.data
    {
    case string, ImageElement:
      this_min_size.x += (.VERTICAL == box.layout) ? double_pad : pad
      this_min_size.y += (.VERTICAL == box.layout) ? pad        : double_pad

    case BoxElement:
      this_min_size.x -= (.VERTICAL == box.layout) ? 0   : pad
      this_min_size.y -= (.VERTICAL == box.layout) ? pad : 0
    }

    if .VERTICAL == box.layout
    {
      min_size.x=(min_size.x < this_min_size.x)?this_min_size.x:min_size.x
      min_size.y += this_min_size.y
    }
    else
    {
      min_size.x += this_min_size.x
      min_size.y=(min_size.y < this_min_size.y)?this_min_size.y:min_size.y
    }
  }
  min_size.x += (.VERTICAL == box.layout) ? 0   : pad
  min_size.y += (.VERTICAL == box.layout) ? pad : 0
  min_size.y += (box.header != "") ? g_header_height : 0
  element.min_size = min_size
}

@(private)
update_box_content_sizes :: proc(element: ^Element)
{
  #partial switch d in element.data
  {
  case string, ImageElement:
    return
  }
  box := element.data.(BoxElement)

  IndexSizePair :: struct { index: int, size: f32 }
  isp_list: [dynamic]IndexSizePair
  defer delete(isp_list)

  pad := (.CUSTOM == box.style) ? box.pad : g_pad
  double_pad := pad * 2

  box_count: int

  for e, i in box.content
  {
    size := (.VERTICAL == box.layout) ? e.min_size.y : e.min_size.x
    switch d in e.data
    {
    case string, ImageElement:
      size += pad
    case BoxElement:
      size -= pad
      box_count += 1
    }
    append(&isp_list, IndexSizePair{i, size})
  }
  sort.quick_sort_proc(
    isp_list[:],
    proc(left, right: IndexSizePair) -> int
    {
      if left.size < right.size
      {
        return 1
      }
      else if right.size < left.size
      {
        return -1
      }
      else
      {
        return 0
      }
    })

  remaining_elements := f32(len(box.content))

  available_space: f32
  if .VERTICAL == box.layout
  {
    available_space = element.rec.height
    available_space -= (box.header != "") ? g_header_height : 0
  }
  else
  {
    available_space = element.rec.width
  }
  available_space -= (pad * (remaining_elements + 1)) -
                     (double_pad * f32(box_count))

  for isp in isp_list
  {
    e := box.content[isp.index]

    share := math.trunc(available_space / remaining_elements)

    if e.non_resizable
    {
      e.rec.width  = e.min_size.x
      e.rec.height = e.min_size.y
      available_space -= (.VERTICAL == box.layout) ? e.rec.height : e.rec.width
      remaining_elements -= 1
      continue
    }

    if .VERTICAL == box.layout
    {
      e.rec.width = element.rec.width
      e.rec.height = (share < e.min_size.y) ? e.min_size.y : share
    }
    else
    {
      e.rec.width = (share < e.min_size.x) ? e.min_size.x : share
      e.rec.height = element.rec.height
      e.rec.height -= (box.header != "") ? g_header_height : 0
    }

    switch d in e.data
    {
    case string, ImageElement:
      e.rec.width  -= (.VERTICAL == box.layout) ? double_pad : 0
      e.rec.height -= (.VERTICAL == box.layout) ? 0 : double_pad
    case BoxElement:
      update_box_content_sizes(e)
    }

    if e.min_size.x <= e.max_size.x
    {
      e.rec.width = (e.max_size.x < e.rec.width) ? e.max_size.x : e.rec.width
    }
    if e.min_size.y <= e.max_size.y
    {
      e.rec.height = (e.max_size.y < e.rec.height) ? e.max_size.y : e.rec.height
    }

    available_space -= (.VERTICAL == box.layout) ? e.rec.height : e.rec.width
    remaining_elements -= 1
  }
}

@(private)
draw_box :: proc(box : BoxElement, rec: rl.Rectangle, highlight := false) {

  font := (.CUSTOM == box.style) ? box.font       : g_font
  pad  := (.CUSTOM == box.style) ? box.pad        : g_pad
  double_pad := pad * 2

  // HEADER ====================================================================

  header_offset: f32
  if box.header != ""
  {
    header_offset = g_header_height
    header_rec := rec
    header_rec.height = header_offset

    bg_color := highlight ? rl.BLACK : rl.WHITE
    rl.DrawRectangleRec(header_rec, bg_color)
    rl.DrawRectangleLinesEx(header_rec, g_line_thick, g_line_color)

    font_color := highlight ? rl.WHITE : rl.BLACK
    header_rec.x += pad
    header_rec.y += math.trunc(pad * 0.25)
    header_rec.width -= double_pad
    draw_text(header_rec, box.header, font, font_color)
  }

  // CONTENT ===================================================================

  txt_color  := (.CUSTOM == box.style) ? box.txt_color : g_txt_color
  bg_color   := (.CUSTOM == box.style) ? box.bg_color  : g_bg_color

  content_rec        := rec
  content_rec.y      += header_offset
  content_rec.height -= header_offset

  rl.DrawRectangleRec(content_rec, bg_color)

  content_offset: f32
  for e, i in box.content
  {
    e.rec.x =  rec.x
    e.rec.x += (.VERTICAL == box.layout) ? 0 : content_offset

    e.rec.y =  rec.y + header_offset
    e.rec.y += (.VERTICAL == box.layout) ? content_offset : 0

    switch d in e.data
    {
    case string, ImageElement:
      e.rec.x += pad
      e.rec.y += pad
      content_offset += pad

    case BoxElement:
      if .VERTICAL == box.layout
      {
        e.rec.y -= (i != 0) ? pad : 0
      }
      else
      {
        e.rec.x -= (i != 0) ? pad : 0
      }
    }

    switch d in e.data
    {
    case string:
      draw_text(e.rec, d, font, txt_color)

    case ImageElement:
      switch d.resize
      {
      case .NONE:
        rl.DrawTextureV(d.texture, {e.rec.x, e.rec.y}, rl.WHITE)
      case .CENTER:
        rl.DrawTextureV(
          d.texture,
          {
            e.rec.x + (e.rec.width - f32(d.texture.width)) / 2,
            e.rec.y + (e.rec.height - f32(d.texture.height)) / 2
          },
          rl.WHITE)
      case .STRETCH:
        rl.DrawTexturePro(
          d.texture,
          { 0, 0, f32(d.texture.width), f32(d.texture.height) },
          e.rec,
          { 0, 0 },
          0,
          rl.WHITE)
      }

    case BoxElement:
      draw_box(d, e.rec)
    }

    content_offset += (.VERTICAL == box.layout) ? e.rec.height : e.rec.width
  }
}

@(private)
draw_window :: proc(win: ^Window, highlight := false, update_sizes := false)
{
  #partial switch d in win.emt.data
  {
  case string, ImageElement:
    return
  }

  configure_box_min_size(win.emt)

  rec := &win.emt.rec
  min_size := win.emt.min_size
  max_size := win.emt.max_size

  rec.width  = (rec.width < min_size.x)  ? min_size.x : rec.width
  rec.height = (rec.height < min_size.y) ? min_size.y : rec.height

  if min_size.x < max_size.x
  {
    rec.width = (max_size.x < rec.width) ? max_size.x : rec.width
  }
  if min_size.y < max_size.y
  {
    rec.height = (max_size.y < rec.height) ? max_size.x : rec.height
  }

  if 1 < g_base_unit.x && 1 < g_base_unit.y
  {
    rec.x      -= f32(int(rec.x)      % int(g_base_unit.x))
    rec.y      -= f32(int(rec.y)      % int(g_base_unit.y))
    rec.width  -= f32(int(rec.width)  % int(g_base_unit.x))
    rec.height -= f32(int(rec.height) % int(g_base_unit.y))
  }

  if update_sizes
  {
    update_box_content_sizes(win.emt)
  }
  draw_box(win.emt.data.(BoxElement), win.emt.rec, highlight)
  rl.DrawRectangleLinesEx(win.emt.rec, g_line_thick, g_line_color)
}

init :: proc(
  font       :  rl.Font,
  pad        : f32 = 12,
  txt_color  := rl.BLACK,
  line_color := rl.BLACK,
  bg_color   := rl.WHITE,
  line_thick : f32 = 1,
  base_unit  : rl.Vector2 = { 1, 1 }
) {
  g_font       = font
  g_pad        = pad
  g_txt_color  = txt_color
  g_line_color = line_color
  g_bg_color   = bg_color
  g_line_thick = line_thick
  g_base_unit  = base_unit

  g_header_height = f32(g_font.baseSize) + math.trunc(g_pad / 2)
}

move_window_index_to_index :: proc(
  list  : []^Window,
  src_index : u32,
  dst_index : u32
  ) {
  cap := u32(len(list) - 1)
  if cap < src_index || cap < dst_index
  {
    return
  }

  win := list[src_index]  

  if dst_index < src_index
  {
    for i := src_index; 0 < i; i -= 1
    {
      list[i] = list[i-1]
    }
    list[dst_index] = win
  }
  else if src_index < dst_index
  {
    for i := src_index; i < dst_index; i += 1
    {
      list[i] = list[i+1]
    }
  }
  list[dst_index] = win
}

update_window_list :: proc(
  list: []^Window,
  mouse_pos: rl.Vector2,
  scale: int
  ) -> MouseState
{
  @(static) mouse_offset: rl.Vector2

  mouse_state: MouseState

  new_top_index := -1
  outer: for win, i in list
  {
    reset := false

    mode: switch win.mouse_state
    {
    case .DEFAULT:
      if !is_vector_within_rectangle(mouse_pos, win.emt.rec)
      {
        continue
      }
      for j in 0..<i
      {
        if is_vector_within_rectangle(mouse_pos, list[j].emt.rec)
        {
          continue outer
        }
      }

      button_pressed := rl.MouseButton.BACK
      if rl.IsMouseButtonPressed(.LEFT)
      {
        button_pressed = .LEFT
      }
      else if rl.IsMouseButtonPressed(.RIGHT)
      {
        button_pressed = .RIGHT
      }

      if win.draggable && .LEFT == button_pressed
      {
        mouse_state = .DRAG
        mouse_offset = {
          (mouse_pos.x - win.emt.rec.x), 
          (mouse_pos.y - win.emt.rec.y)
        }
        win.mouse_state = .DRAG
      } 
      else if !win.emt.non_resizable && .RIGHT == button_pressed
      {
        rl.SetMousePosition(
          i32(win.emt.rec.x + win.emt.rec.width) * i32(scale),
          i32(win.emt.rec.y + win.emt.rec.height) * i32(scale)
          )
        mouse_state = .RESIZE
        win.mouse_state = .RESIZE
      }
      else if .LEFT == button_pressed || .RIGHT == button_pressed
      {
        break 
      }
      else
      {
        continue
      }
    case .DRAG:
      if rl.IsMouseButtonDown(.LEFT)
      {
        mouse_state = .DRAG
        win.emt.rec.x = mouse_pos.x - mouse_offset.x
        win.emt.rec.y = mouse_pos.y - mouse_offset.y
      }
      else
      {
        reset = true
      }
    case .RESIZE:
      if rl.IsMouseButtonDown(.RIGHT)
      {
        mouse_state = .RESIZE
        win.emt.rec.width = mouse_pos.x - win.emt.rec.x
        win.emt.rec.height = mouse_pos.y - win.emt.rec.y
      }
      else
      {
        reset = true
      }
    }
    if reset
    {
      mouse_state = .DEFAULT
      win.mouse_state = .DEFAULT
      continue
    }
    new_top_index = i != 0 ? i : -1
    break
  }
  if 0 < new_top_index
  {
    move_window_index_to_index(list, u32(new_top_index), 0)
  }
  return mouse_state
}

draw_window_list :: proc(list: []^Window)
{
  @(static) first_time := true
  #reverse for win, i in list
  {
    draw_window(win, 0 == i, .RESIZE == win.mouse_state || first_time)
  }
  if first_time
  {
    first_time = false
  }
}
