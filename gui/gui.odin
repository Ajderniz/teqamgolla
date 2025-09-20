/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import      "core:c"
import      "core:math"
import sort "core:sort"
import str  "core:strings"

import rl   "vendor:raylib"


import "core:fmt"

TextElement :: struct {
  txt        : string,
  buffer     : [dynamic]string,
  glyph_size : rl.Vector2,
  offset     : uint
}

ImageElement :: struct {
  texture : rl.Texture,
  resize  : enum { NONE, CENTER, STRETCH },
}

BoxElement :: struct {
  header   : string,
  content  : []^Element,
  layout   : enum{ VERTICAL, HORIZONTAL },

  font     : ^rl.Font,
  pad      : ^f32,
  fg_color : ^rl.Color,
  bg_color : ^rl.Color,
}

Element :: struct {
  data          : union { TextElement, ImageElement, BoxElement },

  rec           : rl.Rectangle,
  min_size      : rl.Vector2,
  max_size      : rl.Vector2,
  non_resizable : bool
}

ActionState :: enum {
  NONE,
  POTENTIAL,
  DRAG,
  RESIZE,
}

Window :: struct {
  draggable : bool,
  act_state : ActionState,

  emt       : ^Element
}

@(private) g_act_state  : ActionState

@(private) g_font       : rl.Font
@(private) g_pad        : f32
@(private) g_fg_color   : rl.Color
@(private) g_bg_color   : rl.Color
@(private) g_line_thick : f32

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

@(private)
scroll_text_element_under_mouse :: proc(
  element   : ^Element,
  mouse_pos : rl.Vector2,
  dir       : enum{UP, DOWN}
  ) -> bool
{
  if !is_v2_within_rec(mouse_pos, element.rec)
  {
    return false
  }
  #partial switch &d in element.data
  {
  case TextElement:
    if .UP == dir
    {
      d.offset -= (0 < d.offset) ? 1 : 0
    }
    else
    {
      limit := len(d.buffer) - int(d.glyph_size.y)
      //limit += (0 < d.offset) ? 1 : 0
      limit =  (limit < 0) ? 0 : limit
      d.offset += (d.offset < uint(limit)) ? 1 : 0
    }
    return true

  case BoxElement:
    for e in d.content
    {
      scrolled := scroll_text_element_under_mouse(e, mouse_pos, dir)
      if scrolled
      {
        return true
      }
    }
  }
  return false
}

@(private)
update_text_element_buffer :: proc(
  txte : ^TextElement,
  rec  : rl.Rectangle,
  font : rl.Font
  ) {
  {
    txte.glyph_size.x = math.trunc(rec.width / font.recs[0].width)

    glyph_pad    := f32(font.glyphPadding) / 2
    max_height   := rec.height + glyph_pad
    glyph_height := f32(font.baseSize) + glyph_pad

    txte.glyph_size.y = math.trunc(max_height / glyph_height)
  }

  if txte.buffer != nil
  {
    clear(&txte.buffer)
  }

  start := 0

  for i := 1;; i += 1
  {
    end := start + int(txte.glyph_size.x)
    line: string
    ok: bool

    if end < (str.rune_count(txte.txt) - 1)
    {
      line, ok = str.substring(txte.txt, start, end)
    }
    else
    {
      end = str.rune_count(txte.txt)
      line, ok = str.substring(txte.txt, start, end)
      append(&txte.buffer, line)
      break
    }

    line = str.trim_space(line)

    has_spaces := str.contains_any(line, " \t\r\n")
    if has_spaces && ok
    {
      limit: int
      if str.contains_any(line, "\r\n")
      {
        limit = str.index_any(line, "\r\n")
        i += 1
      }
      else
      {
        limit = str.last_index_any(line, " \t")
      }

      ko: bool // unused
      line, ko = str.substring_to(line, limit)

      limit -= len(line) - str.rune_count(line)
      line, ko = str.substring_to(line, limit)

      end = start + limit
    }
    if 0 < len(line)
    {
      append(&txte.buffer, line)
    }
    start = (has_spaces) ? (end + 1) : end
  }
  offset_limit := len(txte.buffer) - int(txte.glyph_size.y)
  offset_limit =  (offset_limit < 0) ? 0 : offset_limit
  txte.offset = (uint(offset_limit) < txte.offset) ? uint(offset_limit) :
                                                     txte.offset
}

@(private)
draw_text_element :: proc(
  txte     : TextElement,
  rec      : rl.Rectangle,
  font     : rl.Font,
  fg_color : rl.Color
  ) {
  start := txte.offset
  end   := txte.offset + uint(txte.glyph_size.y)

  {
    center := rec.x + math.trunc(rec.width / 2)
    half_font_width := f32(font.recs[0].width / 2)

    if 0 < txte.offset
    {
      start += 1

      plus_height := rec.y + f32(font.baseSize)
      rl.DrawTriangle(
        {center,                   rec.y},
        {center - half_font_width, plus_height},
        {center + half_font_width, plus_height},
        fg_color
        )
    }
    if end < uint(len(txte.buffer))
    {
      end -= 1

      after_text := rec.y + rec.height - f32(font.baseSize)
      rl.DrawTriangle(
        {center + half_font_width, after_text},
        {center - half_font_width, after_text},
        {center,                   after_text + f32(font.baseSize)},
        fg_color
        )
    }
  }
  end = (uint(len(txte.buffer)) < end) ? len(txte.buffer) : end

  joined_txt := str.join(txte.buffer[start:end], "\n")
  joined_txt_cstring := str.clone_to_cstring(joined_txt)
  defer delete(joined_txt)
  defer delete(joined_txt_cstring)

  txt_pos := rl.Vector2{rec.x, rec.y}
  txt_pos.y += (0 < txte.offset)?f32(font.baseSize)+f32(font.glyphPadding/2) : 0

  rl.DrawTextEx(
    font,
    joined_txt_cstring,
    txt_pos,
    f32(font.baseSize),
    0,
    fg_color)
}

@(private)
draw_label :: proc(
  txt       : string,
  pos       : rl.Vector2,
  max_width : f32,
  font      : rl.Font,
  fg_color  : rl.Color,
  ) {

  len      := str.rune_count(txt)
  max_cols := int(math.trunc(max_width / font.recs[0].width))

  ok: bool
  line: string
  must_add_tilde := (max_cols < len)
  if must_add_tilde
  {
    line, ok = str.substring_to(txt, max_cols - 1)
  }
  else
  {
    line, ok = str.substring_to(txt, len)
  }

  line_cstring := str.clone_to_cstring(line)
  defer delete(line_cstring)

  if must_add_tilde
  {
    rl.DrawTextEx(
      font,
      rl.TextFormat("%s~", line_cstring),
      pos,
      f32(font.baseSize),
      0,
      fg_color)
  }
  else
  {
    rl.DrawTextEx(font, line_cstring, pos, f32(font.baseSize), 0, fg_color)
  }
}

@(private)
configure_box_min_size :: proc(element: ^Element)
{
  #partial switch d in element.data
  {
  case TextElement, ImageElement:
    return
  }
  if 0 < element.min_size.x && 0 < element.min_size.y
  {
    return
  }
  box := element.data.(BoxElement)

  min_size: rl.Vector2

  pad  := (box.pad  != nil) ? box.pad^  : g_pad
  font := (box.font != nil) ? box.font^ : g_font

  double_pad  := pad * 2
  glyph_width  := f32(font.recs[0].width)
  glyph_height := f32(font.baseSize + (font.glyphPadding / 2))

  if len(box.content) <= 0 {
    bare_min: rl.Vector2

    bare_min.x = glyph_width + double_pad

    bare_min.y =  glyph_height + double_pad
    bare_min.y += (box.header != "") ? g_header_height : 0

    element.min_size = bare_min
    return
  }

  for e, i in box.content
  {
    switch d in e.data
    {
    case TextElement:
      e.min_size.x = (e.min_size.x < glyph_width)  ? glyph_width  : e.min_size.x
      e.min_size.y=(e.min_size.y<(glyph_height*3))?(glyph_height*3):e.min_size.y

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
    case TextElement, ImageElement:
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
  case TextElement, ImageElement:
    return
  }
  box := element.data.(BoxElement)

  IndexSizePair :: struct { index: int, size: f32 }
  isp_list: [dynamic]IndexSizePair
  defer delete(isp_list)

  pad := (box.pad != nil) ? box.pad^ : g_pad
  double_pad := pad * 2

  box_count: int

  for e, i in box.content
  {
    size := (.VERTICAL == box.layout) ? e.min_size.y : e.min_size.x
    switch d in e.data
    {
    case TextElement, ImageElement:
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
    case TextElement, ImageElement:
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

    #partial switch &d in e.data
    {
    case TextElement:
      update_text_element_buffer(&d, e.rec, ((box.font!=nil)?box.font^:g_font))
    }

    available_space -= (.VERTICAL == box.layout) ? e.rec.height : e.rec.width
    remaining_elements -= 1
  }
}

@(private)
draw_box :: proc(box : BoxElement, rec: rl.Rectangle, highlight := false)
{
  font     := (box.font     != nil) ? box.font^     : g_font
  pad      := (box.pad      != nil) ? box.pad^      : g_pad
  fg_color := (box.fg_color != nil) ? box.fg_color^ : g_fg_color
  bg_color := (box.bg_color != nil) ? box.bg_color^ : g_bg_color

  double_pad := pad * 2

  // HEADER ====================================================================

  header_offset: f32
  if box.header != ""
  {
    header_offset = g_header_height
    header_rec := rec
    header_rec.height = header_offset

    header_bg_color := (highlight) ? fg_color : bg_color
    header_fg_color := (highlight) ? bg_color : fg_color

    rl.DrawRectangleRec(header_rec, header_bg_color)
    rl.DrawRectangleLinesEx(header_rec, g_line_thick, g_fg_color)

    header_rec.x += pad
    header_rec.y += math.trunc(pad * 0.25)
    header_rec.width -= double_pad
    draw_label(
      box.header,
      {header_rec.x, header_rec.y},
      header_rec.width,
      font,
      header_fg_color)
  }

  // CONTENT ===================================================================

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
    case TextElement, ImageElement:
      must_add_pad := false
      if 0 == i
      {
        must_add_pad = true
      }
      else if 1 <= i
      {
        #partial switch pd in box.content[i-1].data
        {
        case TextElement, ImageElement:
          must_add_pad = true
        }
      }
      if .VERTICAL == box.layout
      {
        e.rec.x += pad
        e.rec.y += (must_add_pad) ? pad : 0
      }
      else
      {
        e.rec.x += (must_add_pad) ? pad : 0
        e.rec.y += pad
      }
      content_offset += (must_add_pad) ? pad : 0

    case BoxElement:
      if 1 <= i
      {
        #partial switch d in box.content[i-1].data
        {
        case BoxElement:
          e.rec.y -= (.VERTICAL == box.layout) ? pad : 0
          e.rec.x -= (.VERTICAL == box.layout) ? 0   : pad
        }
      }
    }
    content_offset += (.VERTICAL == box.layout) ? e.rec.height : e.rec.width

    switch d in e.data
    {
    case TextElement:
      draw_text_element(d, e.rec, font, fg_color)

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
  }
}

@(private)
draw_window :: proc(win: ^Window, highlight := false, update_sizes := false)
{
  #partial switch d in win.emt.data
  {
  case TextElement, ImageElement:
    return
  }

  configure_box_min_size(win.emt)

  rec := &win.emt.rec
  min_size := win.emt.min_size
  max_size := win.emt.max_size

  if 2 <= g_base_unit.x && 2 <= g_base_unit.y
  {
    rec.x      -= f32(int(rec.x)      % int(g_base_unit.x))
    rec.y      -= f32(int(rec.y)      % int(g_base_unit.y))
    rec.width  -= f32(int(rec.width)  % int(g_base_unit.x))
    rec.height -= f32(int(rec.height) % int(g_base_unit.y))
  }

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

  if update_sizes
  {
    update_box_content_sizes(win.emt)
  }
  draw_box(win.emt.data.(BoxElement), win.emt.rec, highlight)
  rl.DrawRectangleLinesEx(win.emt.rec, g_line_thick, g_fg_color)
}

@(private)
move_window_index_to_index :: proc(
  list  : []^Window,
  src_index : uint,
  dst_index : uint 
  ) {
  cap := uint(len(list) - 1)
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

init :: proc(
  font       :  rl.Font,
  pad        : f32 = 12,
  fg_color  := rl.BLACK,
  bg_color   := rl.WHITE,
  line_thick : f32 = 1,
  base_unit  : rl.Vector2 = { 1, 1 }
) {
  g_font       = font
  g_pad        = pad
  g_fg_color  = fg_color
  g_bg_color   = bg_color
  g_line_thick = line_thick
  g_base_unit  = base_unit

  g_header_height = f32(g_font.baseSize) + math.trunc(g_pad / 2)
}

delete_text_element :: #force_inline proc(element: ^TextElement)
{
  delete(element.buffer)
}

process_window_list_input :: proc(
  list: []^Window,
  mouse_pos: rl.Vector2,
  scale: int
  )
{
  if rl.IsKeyPressed(.TAB)
  {
    if rl.IsKeyDown(.LEFT_SHIFT)
    {
      move_window_index_to_index(list, 0, uint(len(list) - 1))
    }
    else
    {
      move_window_index_to_index(list, uint(len(list) - 1), 0)
    }
  }

  @(static) mouse_offset: rl.Vector2

  new_top_index := -1
  outer: for win, i in list
  {
    must_reset_state := false

    g_act_state = (is_v2_within_rec(mouse_pos, win.emt.rec))? .POTENTIAL : .NONE

    action: #partial switch win.act_state
    {
    case .NONE, .POTENTIAL:
      if g_act_state != .POTENTIAL
      {
        continue
      }
      for j in 0..<i
      {
        if is_v2_within_rec(mouse_pos, list[j].emt.rec)
        {
          continue outer
        }
      }

      wheel_move := rl.GetMouseWheelMove()

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
        g_act_state = .DRAG
        mouse_offset = {
          (mouse_pos.x - win.emt.rec.x), 
          (mouse_pos.y - win.emt.rec.y)
        }
        win.act_state = .DRAG
      } 
      else if !win.emt.non_resizable && .RIGHT == button_pressed
      {
        rl.SetMousePosition(
          i32(win.emt.rec.x + win.emt.rec.width) * i32(scale),
          i32(win.emt.rec.y + win.emt.rec.height) * i32(scale)
          )
        g_act_state = .RESIZE
        win.act_state = .RESIZE
      }
      else if wheel_move != 0
      {
        if wheel_move < 0
        {
          scroll_text_element_under_mouse(win.emt, mouse_pos, .DOWN)
        }
        else
        {
          scroll_text_element_under_mouse(win.emt, mouse_pos, .UP)
        }
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
      if !rl.IsMouseButtonDown(.LEFT)
      {
        must_reset_state = true
        break
      }
      g_act_state = .DRAG
      win.emt.rec.x = mouse_pos.x - mouse_offset.x
      win.emt.rec.y = mouse_pos.y - mouse_offset.y

    case .RESIZE:
      if !rl.IsMouseButtonDown(.RIGHT)
      {
        must_reset_state = true
        break
      }
      g_act_state = .RESIZE
      win.emt.rec.width = mouse_pos.x - win.emt.rec.x
      win.emt.rec.height = mouse_pos.y - win.emt.rec.y
    }
    if must_reset_state
    {
      g_act_state = (g_act_state != .POTENTIAL) ? .NONE : .POTENTIAL
      win.act_state = .NONE
      continue
    }
    new_top_index = (i != 0) ? i : -1
    break
  }
  if 0 < new_top_index
  {
    move_window_index_to_index(list, uint(new_top_index), 0)
  }
}

draw_window_list :: proc(list: []^Window)
{
  @(static) first_time := true
  #reverse for win, i in list
  {
    draw_window(win, 0 == i, .RESIZE == win.act_state || first_time)
  }
  if first_time
  {
    first_time = false
  }
}

get_action_state :: #force_inline proc() -> ActionState
{
  return g_act_state
}
