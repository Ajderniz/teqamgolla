/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

import    "../global"

ActionState :: enum {
  NONE,
  DRAG,
  RESIZE,
  SCROLL_UP,
  SCROLL_DOWN,
  BUTTON_DOWN,
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

      txt_item_dir: enum{PREV, NEXT}
      if item != nil
      {
        #partial switch &d in item.data
        {
        case TextItem:
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

        case ButtonItem:
          d.highlight = true
          g_cursor_state = .DEFAULT
        }
      }

      #partial switch button_pressed
      {
      case .LEFT:
        if item != nil
        {
          #partial switch &d in item.data
          {
          case TextItem:
            if .VERTICAL == d.scroll_type
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
            else // PAGED
            {
              if .PREV == txt_item_dir
              {
                scroll_text_item(&d, .PREV)
              }
              else
              {
                scroll_text_item(&d, .NEXT)
              }
            }
            break action

          case ButtonItem:
            d.highlight = false
            win.act_state = .BUTTON_DOWN
            break action
          }
        }

        if win.draggable
        {
          mouse_offset = { (mouse_pos.x - win.x), (mouse_pos.y - win.y) }
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
        #partial switch &data in item.data
        {
        case TextItem:
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

    case .BUTTON_DOWN:
      if !rl.IsMouseButtonDown(.LEFT)
      {
        win.act_state = .NONE
        break windows
      }
      break windows
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
