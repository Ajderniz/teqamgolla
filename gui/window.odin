package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

Window :: struct {
  draggable     : bool,
  act_state     : ActionState,

  using element : ^Element
}

@(private)
draw_window :: proc(win: ^Window, highlight := false, update_sizes := false)
{
  #partial switch d in win.data
  {
  case TextElement, ImageElement:
    return
  }
  if win.min_size.x <= 0 || win.min_size.y <= 0
  {
    configure_box_element_min_size(win.element)
  }

  rec := &win.rec
  min_size := win.min_size
  max_size := win.max_size

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
    update_box_element_content_sizes(win.element)
  }
  draw_box_element(win.data.(BoxElement), win.rec, highlight)
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

process_window_list_input :: proc(
  list: []^Window,
  mouse_pos: rl.Vector2,
  scale: int
  )
{
  @(static) vf_counter: int
  @(static) scroll_counter: int
  @(static) mouse_offset: rl.Vector2

  vf_counter = (vf_counter + 1) % g_vf_delay

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
        if vf_counter != 0
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
            if mouse_pos.y <= element.rec.y + math.trunc(element.rec.height / 2)
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
            if mouse_pos.x <= element.rec.x + math.trunc(element.rec.width / 2)
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
            (mouse_pos.x - win.rec.x), 
            (mouse_pos.y - win.rec.y)
          }
          win.act_state = .DRAG
          g_cursor_state = .DRAG
        } 
        break action

      case .RIGHT:
        if !win.non_resizable
        {
          rl.SetMousePosition(
            i32(win.rec.x + win.rec.width) * i32(scale),
            i32(win.rec.y + win.rec.height) * i32(scale)
            )
          win.act_state = .RESIZE
          g_cursor_state = .RESIZE
        }
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
      win.rec.x = mouse_pos.x - mouse_offset.x
      win.rec.y = mouse_pos.y - mouse_offset.y

    case .RESIZE:
      if !rl.IsMouseButtonDown(.RIGHT)
      {
        win.act_state = .NONE
        break windows
      }
      win.rec.width = mouse_pos.x - win.rec.x
      win.rec.height = mouse_pos.y - win.rec.y

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
      if mouse_pos.y <= element.rec.y + math.trunc(element.rec.height / 2)
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
