package gui

import    "core:log"

import rl "vendor:raylib"

import    "../common"

@(private)
draw_window :: proc(win: ^Window, highlight := false, update_sizes := false)
{
  font     := (win.font     != nil) ? win.font^     : cfg.font
  pad      := (win.pad      != nil) ? win.pad^      : cfg.pad
  fg_color := (win.fg_color != nil) ? win.fg_color^ : cfg.fg_color
  bg       := (win.bg       != nil) ? win.bg^       : cfg.bg

  if win.min_size.x <= 0 || win.min_size.y <= 0
  {
    configure_item_min_size(win.item, font, pad)
  }

  if 2 <= cfg.base_unit.x && 2 <= cfg.base_unit.y
  {
    win.x      -= f32(int(win.x)      % int(cfg.base_unit.x))
    win.y      -= f32(int(win.y)      % int(cfg.base_unit.y))
    win.width  -= f32(int(win.width)  % int(cfg.base_unit.x))
    win.height -= f32(int(win.height) % int(cfg.base_unit.y))
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
    border = &cfg.border
  case .CUSTOM:
    border = win.border
  }

  win_size := rl.Vector2{ win.width, win.height }
  if border != nil
  {
    line_rec := &border.line_rec

    win_size.x -=(line_rec.custom[.LEFT]!= nil)? line_rec.custom[.LEFT].height :
                                                 line_rec.height
    win_size.x -=(line_rec.custom[.RIGHT]!=nil)?line_rec.custom[.RIGHT].height :
                                                line_rec.height

    win_size.y -= (line_rec.custom[.TOP] != nil)? line_rec.custom[.TOP].height :
                                                  line_rec.height
    win_size.y -= (line_rec.custom[.BOT] != nil)? line_rec.custom[.BOT].height :
                                                  line_rec.height
  }

  #partial switch &form in win.form
  {
  case TextItem, TextureItem:
    if update_sizes
    {
      #partial switch &f in form
      {
      case TextItem:
        update_text_item_buffer(&f, win_size, font)
      }
    }
    draw_item_background(bg, win.rec)

  case BoxItem:
    if update_sizes
    {
      update_box_item_content_sizes(&form, win_size, font, pad)
    }
  }
  draw_item(win.item, font, pad, fg_color, bg, highlight)

  if .DRAG == win._act_state || .RESIZE == win._act_state
  {
    rl.DrawRectangleRec(
      { win.x + cfg.win_shadow, win.y + win.height, win.width, cfg.win_shadow },
      rl.BLACK)
    rl.DrawRectangleRec(
      { win.x + win.width, win.y + cfg.win_shadow, cfg.win_shadow, win.height },
      rl.BLACK)
  }
}

@(private)
move_window_index_to_index :: proc(
  src_index : uint,
  dst_index : uint 
  ) {
  cap := uint(len(st.wlist) - 1)
  if cap < src_index || cap < dst_index
  {
    return
  }

  win := st.wlist[src_index]  

  if dst_index < src_index
  {
    for i := src_index; 0 < i; i -= 1
    {
      st.wlist[i] = st.wlist[i-1]
    }
    st.wlist[dst_index] = win
  }
  else if src_index < dst_index
  {
    for i := src_index; i < dst_index; i += 1
    {
      st.wlist[i] = st.wlist[i+1]
    }
  }
  st.wlist[dst_index] = win
}

add_window :: proc(win: ^Window) -> bool
{
  @(static) wid_counter: uint = 0

  win._id = wid_counter
  ok := inject_at(&st.wlist, 0, win)
  if !ok
  {
    log.error("Could not inject window")
    return false
  }
  wid_counter += 1
  return true
}

remove_window :: #force_inline proc(win: ^Window)
{
  ordered_remove(&st.wlist, win._id)
}

can_window_capure_input :: proc(id: uint, mouse_pos: rl.Vector2) -> bool
{
  for win, i in st.wlist
  {
    if win._id != id
    {
      continue
    }
    if !common.is_v2_within_rec(mouse_pos, win.rec)
    {
      return false
    }
    for j in 0..<i
    {
      if common.is_v2_within_rec(mouse_pos, st.wlist[j].item.rec)
      {
        return false
      }
    }
    return true
  }
  return false
}

