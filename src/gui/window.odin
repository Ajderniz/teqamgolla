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
  case TextItem:
    if update_sizes
    {
      update_text_item_buffer(&data, win_size, font)
    }
    draw_item_background(bg, win.rec)

  case ImageItem:
    draw_item_background(bg, win.rec)

  case BoxItem:
    if update_sizes
    {
      update_box_item_content_sizes(&data, win_size, font, pad)
    }
  }
  draw_item(win.item, font, pad, fg_color, bg, highlight)
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

process_window_list_input :: proc(list: []^Window, mouse_pos: rl.Vector2)
{
  @(static) frame_counter: int
  @(static) scroll_counter: int
  @(static) mouse_offset: rl.Vector2

  frame_counter = (frame_counter + 1) % g_frame_delay

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

  new_top_index := -1
  windows: for win, i in list
  {
    vf_check: #partial switch win.act_state
    {
      case .DRAG, .RESIZE, .SCROLL_DOWN, .SCROLL_UP:
        if frame_counter != 0
        {
          return
        }
    }

    action: switch win.act_state
    {
    case .NONE:
      if 0 == i
      {
        g_cursor_state = .DEFAULT
      }
      else
      {
        g_cursor_state = (g_cursor_state != .DEFAULT)? g_cursor_state : .DEFAULT
      }
      
      if !is_v2_within_rec(mouse_pos, win.rec)
      {
        continue windows
      }
      for j in 0..<i
      {
        if is_v2_within_rec(mouse_pos, list[j].item.rec)
        {
          continue windows
        }
      }
      
      g_cursor_state = .POTENTIAL

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
      else if rl.IsMouseButtonPressed(.MIDDLE)
      {
        button_pressed = .MIDDLE
      }

      item := get_item_under_mouse(win.item, mouse_pos)

      hovering_txt_item := false
      txt_item_dir: enum{PREV, NEXT}
      if item != nil
      {
        #partial switch d in item.data
        {
        case TextItem:
          hovering_txt_item = true
          if .VERTICAL == d.scroll_type
          {
            if mouse_pos.y <= item.y + math.trunc(item.height / 2)
            {
              txt_item_dir = .PREV
              g_cursor_state = .SCROLL_UP
            }
            else
            {
              txt_item_dir = .NEXT
              g_cursor_state = .SCROLL_DOWN
            }
          }
          else // PAGED
          {
            if mouse_pos.x <= item.x + math.trunc(item.width / 2)
            {
              txt_item_dir = .PREV
              g_cursor_state = .PAGE_PREV
            }
            else
            {
              txt_item_dir = .NEXT
              g_cursor_state = .PAGE_NEXT
            }
          }
        }
      }

      #partial switch button_pressed
      {
      case .LEFT:
        if hovering_txt_item
        {
          txte := &item.data.(TextItem)
          if .VERTICAL == txte.scroll_type
          {
            if .PREV == txt_item_dir
            {
              win.act_state = .SCROLL_UP
            }
            else
            {
              win.act_state = .SCROLL_DOWN
            }
          }
          else
          {
            if .PREV == txt_item_dir
            {
              scroll_text_item(txte, .PREV)
            }
            else
            {
              scroll_text_item(txte, .NEXT)
            }
          }
        }
        else if win.draggable
        {
          mouse_offset = {
            (mouse_pos.x - win.x), 
            (mouse_pos.y - win.y)
          }
          win.act_state = .DRAG
          g_cursor_state = .DRAG

          win.maximized = false
        } 
        break action

      case .RIGHT:
        if !(win.non_resizable.x && win.non_resizable.y)
        {
          rl.SetMousePosition(
            i32(win.x + win.width) * i32(global.SCALE),
            i32(win.y + win.height) * i32(global.SCALE)
            )
          win.act_state = .RESIZE
          g_cursor_state = .RESIZE

          win.maximized = false
        }
        break action

      case .MIDDLE:
        if (win.non_resizable.x && win.non_resizable.y) ||
           (0 < win.max_size.x && win.max_size.x < global.NAT_SCR_W) ||
           (0 < win.max_size.y && win.max_size.y < global.NAT_SCR_H)
        {
          break action
        }
        if !win.maximized
        {
          win.saved_rec = win.rec

          if !win.non_resizable.x
          {
            win.x = 0
            win.width = global.NAT_SCR_W
          }
          if !win.non_resizable.y
          {
            win.y = 0
            win.height = global.NAT_SCR_H
          }

          win.maximized = true
        }
        else
        {
          win.rec = win.saved_rec
          win.maximized = false
        }
        win.act_state = .RESIZE

        break action
      }

      if wheel_move != 0
      {
        if !hovering_txt_item
        {
          break windows
        }
        txt_item := &item.data.(TextItem)
        if wheel_move < 0
        {
          scroll_text_item(txt_item, .NEXT)
        }
        else
        {
          scroll_text_item(txt_item, .PREV)
        }
        break windows
      }
      continue

    case .DRAG:
      if !rl.IsMouseButtonDown(.LEFT)
      {
        win.act_state = .NONE
        break windows
      }
      win.x = mouse_pos.x - mouse_offset.x
      win.y = mouse_pos.y - mouse_offset.y

    case .RESIZE:
      if !rl.IsMouseButtonDown(.RIGHT)
      {
        win.act_state = .NONE
        break windows
      }
      win.width =  (!win.non_resizable.x) ? mouse_pos.x - win.x : win.width
      win.height = (!win.non_resizable.y) ? mouse_pos.y - win.y : win.height

    case .SCROLL_UP, .SCROLL_DOWN:
      if !rl.IsMouseButtonDown(.LEFT)
      {
        win.act_state = .NONE
        break windows
      }
      
      scroll_counter = (scroll_counter + 1) % g_scroll_delay
      if scroll_counter != 0
      {
        break action
      }

      item := get_item_under_mouse(win.item, mouse_pos)
      if nil == item
      {
        win.act_state = .NONE
        break windows
      }
      txt_item: ^TextItem
      #partial switch &d in item.data
      {
      case TextItem:
        txt_item = &d
      }
      if nil == txt_item
      {
        win.act_state = .NONE
        break windows
      }
      if mouse_pos.y <= item.y + math.trunc(item.height / 2)
      {
        scroll_text_item(txt_item, .PREV)
        g_cursor_state = .SCROLL_UP
      }
      else
      {
        scroll_text_item(txt_item, .NEXT)
        g_cursor_state = .SCROLL_DOWN
      }
    }
    new_top_index = (i != 0) ? i : -1
    break windows
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
