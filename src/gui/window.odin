package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

import    "../global"

Window :: struct {
  draggable     : bool,
  act_state     : ActionState,

  maximized     : bool,
  saved_rec     : rl.Rectangle,

  using element : ^Element
}

@(private)
draw_window :: proc(win: ^Window, highlight := false, update_sizes := false)
{
  font     := (win.font     != nil) ? win.font^     : g_font
  pad      := (win.pad      != nil) ? win.pad^      : g_pad
  fg_color := (win.fg_color != nil) ? win.fg_color^ : g_fg_color
  bg_color := (win.bg_color != nil) ? win.bg_color^ : g_bg_color

  if win.min_size.x <= 0 || win.min_size.y <= 0
  {
    configure_element_min_size(win.element, font, pad)
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

  switch &data in win.data
  {
  case TextElement:
    if update_sizes{
      update_text_element_buffer(&data, win.rec, font)
    }
    rl.DrawRectangleRec(win.rec, bg_color)
    draw_text_element(data, win.rec, font, fg_color)

  case ImageElement:
    rl.DrawRectangleRec(win.rec, bg_color)
    draw_image_element(data, win.rec)

  case BoxElement:
    if update_sizes
    {
      update_box_element_content_sizes(&data, win.rec, font, pad)
    }
    draw_box_element(data, win.rec, font, pad, fg_color, bg_color, highlight)
  }

  rl.DrawRectangleLinesEx(win.rec, g_line_thick, g_fg_color)
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
        if is_v2_within_rec(mouse_pos, list[j].element.rec)
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

      element := get_element_under_mouse(win.element, mouse_pos)

      hovering_txt_element := false
      txt_element_dir: enum{PREV, NEXT}
      if element != nil
      {
        #partial switch d in element.data
        {
        case TextElement:
          hovering_txt_element = true
          if .VERTICAL == d.scroll_type
          {
            if mouse_pos.y <= element.y + math.trunc(element.height / 2)
            {
              txt_element_dir = .PREV
              g_cursor_state = .SCROLL_UP
            }
            else
            {
              txt_element_dir = .NEXT
              g_cursor_state = .SCROLL_DOWN
            }
          }
          else // PAGED
          {
            if mouse_pos.x <= element.x + math.trunc(element.width / 2)
            {
              txt_element_dir = .PREV
              g_cursor_state = .PAGE_PREV
            }
            else
            {
              txt_element_dir = .NEXT
              g_cursor_state = .PAGE_NEXT
            }
          }
        }
      }

      #partial switch button_pressed
      {
      case .LEFT:
        if hovering_txt_element
        {
          txte := &element.data.(TextElement)
          if .VERTICAL == txte.scroll_type
          {
            if .PREV == txt_element_dir
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
            if .PREV == txt_element_dir
            {
              scroll_text_element(txte, .PREV)
            }
            else
            {
              scroll_text_element(txte, .NEXT)
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
        if !hovering_txt_element
        {
          break windows
        }
        txt_element := &element.data.(TextElement)
        if wheel_move < 0
        {
          scroll_text_element(txt_element, .NEXT)
        }
        else
        {
          scroll_text_element(txt_element, .PREV)
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

      element := get_element_under_mouse(win.element, mouse_pos)
      if nil == element
      {
        win.act_state = .NONE
        break windows
      }
      txt_element: ^TextElement
      #partial switch &d in element.data
      {
      case TextElement:
        txt_element = &d
      }
      if nil == txt_element
      {
        win.act_state = .NONE
        break windows
      }
      if mouse_pos.y <= element.y + math.trunc(element.height / 2)
      {
        scroll_text_element(txt_element, .PREV)
        g_cursor_state = .SCROLL_UP
      }
      else
      {
        scroll_text_element(txt_element, .NEXT)
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
