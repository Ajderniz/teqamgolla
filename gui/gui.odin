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
  texture : rl.Texture,
  resize  : enum { NONE, CENTER, STRETCH }
}

StyleOptions :: struct {
  style      : enum{ GLOBAL, CUSTOM },
  font       : rl.Font,
  pad        : f32,
  txt_color  : rl.Color,
  line_color : rl.Color,
  bg_color   : rl.Color,
  line_thick : f32
}

Box :: struct {
  header              : string,
  content             : []union{ string, ImageElement, ^Window },
  layout              : enum{ VERTICAL, HORIZONTAL },
  using style_options : StyleOptions
}

Window :: struct {
  rec       : rl.Rectangle,

  options   : bit_set[enum{ DRAGGABLE, RESIZABLE }],
  drag_mode : enum{ NONE, DRAG, RESIZE },

  using box : Box
}

@(private) g_font       : rl.Font
@(private) g_pad        : f32
@(private) g_txt_color  : rl.Color
@(private) g_line_color : rl.Color
@(private) g_bg_color   : rl.Color
@(private) g_line_thick : f32

@(private)
is_vector_within_rectangle :: proc(v2: rl.Vector2, rec: rl.Rectangle) -> bool
{
  return(!((v2.x < rec.x || (rec.x + rec.width) < v2.x) ||
          (v2.y < rec.y || (rec.y + rec.height) < v2.y)))
}

@(private)
are_rectangles_overlapping :: proc(
  rec1: rl.Rectangle, 
  rec2: rl.Rectangle
  ) -> bool
{
  return(!(((rec1.x + rec1.width) < rec2.x || (rec2.x + rec2.width) < rec1.x) ||
         ((rec1.y + rec1.height) < rec2.y || (rec2.y + rec2.height) < rec1.y)))
}

@(private)
draw_rectangle_with_outline :: proc(
  rec        : rl.Rectangle,
  line_color : rl.Color,
  bg_color   : rl.Color,
  line_thick : f32
) {
  rl.DrawRectangleRec(rec, bg_color)
  rl.DrawRectangleLinesEx(rec, line_thick, line_color)
}

@(private)
draw_text :: proc(
  rec       : rl.Rectangle,
  txt       : string,
  font      : rl.Font,
  txt_color : rl.Color,
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
get_window_min_size :: proc(win: Window) -> rl.Vector2
{
  min_width: f32
  min_height: f32
  {
    font := .CUSTOM == win.style ? win.font : g_font
    pad  := .CUSTOM == win.style ? win.pad  : g_pad

    three_glyphs := f32(font.recs[0].width) * 3

    for element in win.content
    {
      new_width:  f32
      new_height: f32

      switch e in element
      {
      case string:
        new_width=.VERTICAL == win.layout? three_glyphs:min_width + three_glyphs
        new_height = .VERTICAL == win.layout ? min_height + f32(font.baseSize) :
                                               f32(font.baseSize)
      case ImageElement:
        txr_width  := f32(e.texture.width)
        txr_height := f32(e.texture.width)
        new_width = .VERTICAL == win.layout ? txr_width : min_width + txr_width
        new_height=.VERTICAL == win.layout? min_height + txr_height : txr_height

      case ^Window:
        // TODO
        win_size := get_window_min_size(e^)
        new_width= .VERTICAL == win.layout ? win_size.x : min_width + win_size.x
        new_height=.VERTICAL == win.layout? min_height + win_size.y : win_size.y
      }

      if .VERTICAL == win.layout
      {
        min_width  = min_width < new_width ? new_width : min_width
        min_height = new_height
      }
      else
      {
        min_width  = new_width
        min_height = min_height < new_height ? new_height : min_height
      }
      min_width  += pad
      min_height += pad
    }
    min_width += pad
    min_height += win.header != "" ? f32(g_font.baseSize) + (g_pad / 2) : 0
  }

  win_size: rl.Vector2
  win_size.x = win.rec.width  < min_width  ? min_width  : win.rec.width
  win_size.y = win.rec.height < min_height ? min_height : win.rec.height
  return win_size
}

@(private)
draw_window :: proc(win: ^Window, highlight: bool)
{
  min_size := get_window_min_size(win^)
  win.rec.width  = min_size.x
  win.rec.height = min_size.y

  content_rec: rl.Rectangle = win.rec

  if win.header != ""
  {
    txt_color := highlight ? rl.WHITE : g_txt_color
    bg_color  := highlight ? rl.BLACK : g_bg_color

    header_offset := f32(g_font.baseSize) + (g_pad / 2)

    header_rec := win.rec
    header_rec.height = header_offset
    draw_rectangle_with_outline(header_rec, rl.BLACK, bg_color, 1)

    draw_text(
      {
        header_rec.x + g_pad,
        header_rec.y + g_pad * 0.25,
        header_rec.width - (g_pad * 2),
        header_rec.height
      },
      win.header,
      g_font, txt_color)

    content_rec.y += header_offset
    content_rec.height -= header_offset
  }

  font       := .CUSTOM == win.style ? win.font       : g_font
  pad        := .CUSTOM == win.style ? win.pad        : g_pad
  txt_color  := .CUSTOM == win.style ? win.txt_color  : g_txt_color
  line_color := .CUSTOM == win.style ? win.line_color : g_line_color
  bg_color   := .CUSTOM == win.style ? win.bg_color   : g_bg_color
  line_thick := .CUSTOM == win.style ? win.line_thick : g_line_thick

  draw_rectangle_with_outline(content_rec, line_color, bg_color, line_thick)


  half_pad := math.trunc(pad / 2)
  double_pad := pad * 2

  txt_count: int
  rec_count: int

  txt_space: f32
  rec_space: f32
  rec_space_map: map[int]f32
  defer delete(rec_space_map)

  space_calculations:
  {
    IndexSpacePair :: struct{ index: int, space: f32 }
    isp_list: [dynamic]IndexSpacePair
    defer delete(isp_list)

    for element, i in win.content
    {
      switch e in element
      {
      case string:
        txt_count += 1

      case ImageElement:

        rec_count += 1

        isp: IndexSpacePair = { i, pad }
        isp.space += .VERTICAL == win.layout ? f32(e.texture.height) :
                                               f32(e.texture.width)

        append(&isp_list, isp)
        rec_space += isp.space

      case ^Window:
        // TODO

        rec_count += 1

        isp: IndexSpacePair = { i, pad }
        isp.space += .VERTICAL == win.layout ? min_size.x : min_size.y

        append(&isp_list, isp)
        rec_space += isp.space
      }
    }
    {
      remainder := .VERTICAL == win.layout ? f32(content_rec.height) : 
                                             f32(content_rec.width)
      remainder -= (rec_space + pad)

      if 0 < txt_count
      {
        txt_space = remainder
      }
      else
      {
        rec_space += remainder
      }
    }

    if rec_count <= 0
    {
      break space_calculations
    }

    sort.quick_sort_proc(
      isp_list[:], 
      proc(left, right: IndexSpacePair) -> int
      {
        if left.space < right.space
        {
          return 1
        }
        else if right.space < left.space
        {
          return -1
        }
        else
        {
          return 0
        }
      })

    for &isp,i in isp_list
    {
      rec := win.content[isp.index].(ImageElement)

      space_portion := math.trunc(rec_space / f32(rec_count))
      original_size := .VERTICAL == win.layout ?  f32(rec.texture.height) :
                                                  f32(rec.texture.width)

      new_size := space_portion < original_size ? original_size : space_portion

      rec_space -= new_size
      new_size -= pad

      rec_space_map[isp.index] = new_size

      rec_count -= 1
    }
  }

  element_offset: f32

  for element, i in win.content
  {
    pre_pad  := 0 == i                      ? pad : half_pad
    post_pad := (len(win.content) - 1) <= i ? pad : half_pad

    element_rec := content_rec

    element_rec.x += 
      (.VERTICAL == win.layout) ? pad : element_offset + pre_pad
    element_rec.y +=
      (.VERTICAL == win.layout) ? element_offset + pre_pad : pad

    element_offset += pre_pad

    switch e in element
    {
      case string:

        if .VERTICAL == win.layout
        {
          element_rec.width -= double_pad

          element_rec.height = math.trunc(txt_space / f32(txt_count))
          element_rec.height -= pad

          element_offset += element_rec.height
        }
        else
        {
          element_rec.width = math.trunc(txt_space / f32(txt_count))
          element_rec.width -= pad

          element_rec.height -= double_pad

          element_offset += element_rec.width
        }

        draw_text(element_rec, e, font, txt_color)

      case ImageElement:

        if .VERTICAL == win.layout
        {
          element_rec.width -= double_pad
          element_rec.height = rec_space_map[i]

          element_offset += f32(element_rec.height)
        }
        else
        {
          element_rec.width = rec_space_map[i]
          element_rec.height -= double_pad

          element_offset += f32(element_rec.width)
        }

        switch e.resize
        {
        case .NONE:

          rl.DrawTextureV(e.texture, {element_rec.x, element_rec.y}, rl.WHITE)

        case .CENTER:

          center_pos: rl.Vector2 = {
            element_rec.x + ((element_rec.width - f32(e.texture.width)) / 2),
            element_rec.y + ((element_rec.height - f32(e.texture.height)) / 2)
          }
          rl.DrawTextureV(e.texture, center_pos, rl.WHITE)

        case .STRETCH:

          rl.DrawTexturePro(
            e.texture,
            { 0, 0, f32(e.texture.width), f32(e.texture.height) },
            element_rec,
            { 0, 0 },
            0,
            rl.WHITE)
        }

      case ^Window:

        // TODO
        element_rec.x -= pad
        element_rec.y -= pad

    }
    element_offset += post_pad
  }
}

init :: proc(
  font       :  rl.Font,
  pad    : f32 = 12,
  txt_color  := rl.WHITE,
  line_color := rl.WHITE,
  bg_color   := rl.BLACK,
  line_thick : f32 = 1,
) {
  g_font       = font
  g_pad    = pad
  g_txt_color  = txt_color
  g_line_color = line_color
  g_bg_color   = bg_color
  g_line_thick = line_thick
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

draw_window_list :: proc(list: []^Window)
{
  @(static) mouse_offset: rl.Vector2

  mouse_pos := rl.GetMousePosition()

  new_top_index := -1
  outer: for win, i in list
  {
    reset := false

    mode: switch win.drag_mode
    {
    case .NONE:
      if !is_vector_within_rectangle(mouse_pos, win.rec)
      {
        continue
      }
      for j in 0..<i
      {
        if is_vector_within_rectangle(mouse_pos, list[j].rec)
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

      if .DRAGGABLE in win.options && .LEFT == button_pressed
      {
        rl.SetMouseCursor(.RESIZE_ALL)
        mouse_offset = {
          (mouse_pos.x - win.rec.x), 
          (mouse_pos.y - win.rec.y)
        }
        win.drag_mode = .DRAG
      } 
      else if .RESIZABLE in win.options && .RIGHT == button_pressed
      {
        rl.SetMousePosition(
          i32(win.rec.x + win.rec.width),
          i32(win.rec.y + win.rec.height)
          )
        rl.SetMouseCursor(.RESIZE_NWSE)
        win.drag_mode = .RESIZE
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
        win.rec.x = mouse_pos.x - mouse_offset.x
        win.rec.y = mouse_pos.y - mouse_offset.y
      }
      else
      {
        reset = true
      }
    case .RESIZE:
      if rl.IsMouseButtonDown(.RIGHT)
      {
        win.rec.width = mouse_pos.x - win.rec.x
        win.rec.height = mouse_pos.y - win.rec.y
      }
      else
      {
        reset = true
      }
    }
    if reset
    {
      rl.SetMouseCursor(.DEFAULT)
      win.drag_mode = .NONE
      continue
    }
    new_top_index = i != 0 ? i : -1
    break
  }
  if 0 < new_top_index
  {
    move_window_index_to_index(list, u32(new_top_index), 0)
  }

  #reverse for win, i in list
  {
    draw_window(win, 0 == i)
  }
}
