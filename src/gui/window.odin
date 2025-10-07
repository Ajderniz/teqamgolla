package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

import    "../global"

Window :: struct {
  draggable  : bool,
  act_state  : ActionState,

  maximized  : bool,
  saved_rec  : rl.Rectangle,

  using item : ^Item
}

// TODO: consider making windows contain a RenderTexture

@(private)
draw_window :: proc(win: ^Window, highlight := false, update_sizes := false)
{
  font     := (win.font     != nil) ? win.font^     : g_font
  pad      := (win.pad      != nil) ? win.pad^      : g_pad
  fg_color := (win.fg_color != nil) ? win.fg_color^ : g_fg_color
  bg       := (win.bg       != nil) ? win.bg^       : g_bg

  if win.min_size.x <= 0 || win.min_size.y <= 0
  {
    configure_item_min_size(win.item, font, pad)
  }

  if 2 <= g_base_unit.x && 2 <= g_base_unit.y
  {
    win.x      -= f32(int(win.x)      % int(g_base_unit.x))
    win.y      -= f32(int(win.y)      % int(g_base_unit.y))
    win.width  -= f32(int(win.width)  % int(g_base_unit.x))
    win.height -= f32(int(win.height) % int(g_base_unit.y))
  }

  restrain_min_max_sizes:
  {
    min_size := win.min_size
    max_size := win.max_size

    win.width  = (win.width < min_size.x)  ? min_size.x : win.width
    win.height = (win.height < min_size.y) ? min_size.y : win.height

    if min_size.x <= max_size.x
    {
      win.width = (max_size.x < win.width) ? max_size.x : win.width
    }
    if min_size.y <= max_size.y
    {
      win.height = (max_size.y < win.height) ? max_size.x : win.height
    }
  }

  border: ^ItemBorder
  #partial switch win.border_style
  {
  case .GLOBAL:
    border = &g_border
  case .CUSTOM:
    border = win.border
  }

  win_size := rl.Vector2{ win.width, win.height }
  if border != nil
  {
    line_rec := &border.line_rec

    win_size.x -= (line_rec.left != nil)? line_rec.left.height : line_rec.height
    win_size.x -= (line_rec.right!=nil) ?line_rec.right.height : line_rec.height

    win_size.y -= (line_rec.top != nil) ? line_rec.top.height  : line_rec.height
    win_size.y -= (line_rec.bot != nil) ? line_rec.bot.height  : line_rec.height
  }

  switch &data in win.data
  {
  case TextItem, ImageItem, ButtonItem:
    if update_sizes
    {
      #partial switch &d in data
      {
      case TextItem:
        update_text_item_buffer(&d, win_size, font)
      }
    }
    draw_item_background(bg, win.rec)

  case BoxItem:
    if update_sizes
    {
      update_box_item_content_sizes(&data, win_size, font, pad)
    }
  }
  draw_item(win.item, font, pad, fg_color, bg, highlight)

  if .DRAG == win.act_state || .RESIZE == win.act_state
  {
    rl.DrawRectangleRec(
      { win.x + g_win_shadow, win.y + win.height, win.width, g_win_shadow },
      rl.BLACK)
    rl.DrawRectangleRec(
      { win.x + win.width, win.y + g_win_shadow, g_win_shadow, win.height },
      rl.BLACK)
  }
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
