/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import     "core:math"
import str "core:strings"

import rl  "vendor:raylib"

import     "cursor"
import inp "../input"

@(private)
cfg: struct {
  frame_delay   : int,
  scroll_delay  : int,

  font          : rl.Font,
  pad           : f32,
  fg_color      : rl.Color,
  bg            : ItemBackground,

  win_shadow    : f32,

  line_thick    : f32,
  border        : ItemBorder,

  header_height : f32,
  base_unit     : rl.Vector2
}

@(private)
st: struct {
  wlist             : [dynamic]^Window,
  button_pressed_id : int
}

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
get_text_size :: proc(txt: string, font: rl.Font) -> rl.Vector2
{
  txt_cstring := str.clone_to_cstring(txt)
  defer delete(txt_cstring)
  return rl.MeasureTextEx(font, txt_cstring, f32(font.baseSize), 0)
}

process_input :: proc(
  input           : inp.InputState,
  scr_width       : f32,
  scr_height      : f32,
  scr_scale       : f32
  ) {

  @(static) frame_counter: int
  @(static) scroll_counter: int
  @(static) mouse_offset: rl.Vector2

  frame_counter = (frame_counter + 1) % cfg.frame_delay

  if .TAB == input.key_pressed
  {
    if rl.IsKeyDown(.LEFT_SHIFT)
    {
      move_window_index_to_index(0, uint(len(st.wlist) - 1))
    }
    else
    {
      move_window_index_to_index(uint(len(st.wlist) - 1), 0)
    }
  }

  mouse_pos := input.mouse_pos
  mouse_pos.x = math.trunc(mouse_pos.x / scr_scale)
  mouse_pos.y = math.trunc(mouse_pos.y / scr_scale)
  mouse_pos.x = (mouse_pos.x < 0) ? 0 : mouse_pos.x
  mouse_pos.y = (mouse_pos.y < 0) ? 0 : mouse_pos.y
  mouse_pos.x = (scr_width  < mouse_pos.x) ? scr_width  : mouse_pos.x
  mouse_pos.y = (scr_height < mouse_pos.y) ? scr_height : mouse_pos.y

  new_top_index := -1
  windows:
  for win, i in st.wlist
  {
    vf_check:
    #partial switch win._act_state
    {
      case .DRAG, .RESIZE, .SCROLL_DOWN, .SCROLL_UP:
        if frame_counter != 0
        {
          return
        }
    }

    action:
    switch win._act_state
    {
    case .NONE:
      if 0 == i
      {
        cursor.set_state(.DEFAULT)
      }
      
      if !is_v2_within_rec(mouse_pos, win.rec)
      {
        continue windows
      }
      for j in 0..<i
      {
        if is_v2_within_rec(mouse_pos, st.wlist[j].item.rec)
        {
          continue windows
        }
      }
      
      cursor.set_state(.POTENTIAL)

      item := get_sub_item_under_mouse(win.item, mouse_pos)

      txt_item_dir: enum{PREV, NEXT}
      if item != nil
      {
        #partial switch &f in item.form
        {
        case TextItem:
          if .VERTICAL == f.scroll_type
          {
            if mouse_pos.y <= item.y + math.trunc(item.height / 2)
            {
              txt_item_dir = .PREV
              cursor.set_state(.SCROLL_UP)
            }
            else
            {
              txt_item_dir = .NEXT
              cursor.set_state(.SCROLL_DOWN)
            }
          }
          else // PAGED
          {
            if mouse_pos.x <= item.x + math.trunc(item.width / 2)
            {
              txt_item_dir = .PREV
              cursor.set_state(.PAGE_PREV)
            }
            else
            {
              txt_item_dir = .NEXT
              cursor.set_state(.PAGE_NEXT)
            }
          }

        case ButtonItem:
          f.hovered = true
          cursor.set_state(.DEFAULT)
        }
      }

      #partial switch input.mouse_button_pressed
      {
      case .LEFT:
        if item != nil
        {
          #partial switch &f in item.form
          {
          case TextItem:
            if .VERTICAL == f.scroll_type
            {
              if .PREV == txt_item_dir
              {
                win._act_state = .SCROLL_UP
              }
              else
              {
                win._act_state = .SCROLL_DOWN
              }
            }
            else // PAGED
            {
              if .PREV == txt_item_dir
              {
                scroll_text_item(&f, .PREV)
              }
              else
              {
                scroll_text_item(&f, .NEXT)
              }
            }
            break action

          case ButtonItem:
            f.hovered = false
            st.button_pressed_id = int(f.id)
            break action
          }
        }

        if win.draggable
        {
          mouse_offset = { (mouse_pos.x - win.x), (mouse_pos.y - win.y) }
          win._act_state = .DRAG
          cursor.set_state(.DRAG)

          win._maximized = false
        } 
        break action

      case .RIGHT:
        if !(win.non_resizable.x && win.non_resizable.y)
        {
          rl.SetMousePosition(
            i32(win.x + win.width) * i32(scr_scale),
            i32(win.y + win.height) * i32(scr_scale)
            )
          cursor.set_state(.RESIZE)

          win._act_state = .RESIZE
          win._maximized = false
        }
        break action

      case .MIDDLE:
        if (win.non_resizable.x && win.non_resizable.y) ||
           (0 < win.max_size.x && win.max_size.x < scr_width) ||
           (0 < win.max_size.y && win.max_size.y < scr_height)
        {
          break action
        }
        if !win._maximized
        {
          win._saved_rec = win.rec

          if !win.non_resizable.x
          {
            win.x = 0
            win.width = scr_width
          }
          if !win.non_resizable.y
          {
            win.y = 0
            win.height = scr_height
          }

          win._maximized = true
        }
        else
        {
          win.rec = win._saved_rec
          win._maximized = false
        }
        win._act_state = .RESIZE

        break action
      }

      if input.mouse_wheel_move != 0
      {
        #partial switch &form in item.form
        {
        case TextItem:
          txt_item := &item.form.(TextItem)
          if input.mouse_wheel_move < 0
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
        win._act_state = .NONE
        break windows
      }
      win.x = mouse_pos.x - mouse_offset.x
      win.y = mouse_pos.y - mouse_offset.y

    case .RESIZE:
      if !rl.IsMouseButtonDown(.RIGHT)
      {
        win._act_state = .NONE
        break windows
      }
      win.width =  (!win.non_resizable.x) ? mouse_pos.x - win.x : win.width
      win.height = (!win.non_resizable.y) ? mouse_pos.y - win.y : win.height

    case .SCROLL_UP, .SCROLL_DOWN:
      if !rl.IsMouseButtonDown(.LEFT)
      {
        win._act_state = .NONE
        break windows
      }
      
      scroll_counter = (scroll_counter + 1) % cfg.scroll_delay
      if scroll_counter != 0
      {
        break action
      }

      item := get_sub_item_under_mouse(win.item, mouse_pos)
      if nil == item
      {
        win._act_state = .NONE
        break windows
      }
      txt_item: ^TextItem
      #partial switch &f in item.form
      {
      case TextItem:
        txt_item = &f
      }
      if nil == txt_item
      {
        win._act_state = .NONE
        break windows
      }
      if mouse_pos.y <= item.y + math.trunc(item.height / 2)
      {
        scroll_text_item(txt_item, .PREV)
        cursor.set_state(.SCROLL_UP)
      }
      else
      {
        scroll_text_item(txt_item, .NEXT)
        cursor.set_state(.SCROLL_DOWN)
      }
    }

    new_top_index = (i != 0) ? i : -1
    break windows
  }
  if 0 < new_top_index
  {
    move_window_index_to_index(uint(new_top_index), 0)
  }
}

draw_window_list :: proc()
{
  @(static) first_time := true
  #reverse for win, i in st.wlist
  {
    draw_window(win, 0 == i, .RESIZE == win._act_state || first_time)
  }
  if first_time
  {
    first_time = false
  }
}

get_button_down_id :: #force_inline proc() -> int
{
  defer st.button_pressed_id = -1
  return st.button_pressed_id
}

init :: proc(
  font         : rl.Font,

  wlist        : []^Window      = {},

  pad          : f32            = 12,
  fg_color     :                = rl.BLACK,
  bg           : ItemBackground = { color=rl.WHITE },

  win_shadow   : f32            = 2,
  border       : ItemBorder     = {},
  line_thick   : f32            = 1,
  base_unit    : rl.Vector2     = { 1, 1 },

  frame_delay  :                = 1,
  scroll_delay :                = 1,
) {
  cfg.font        = font

  cfg.pad         = pad
  cfg.fg_color      = fg_color
  cfg.bg            = bg

  cfg.win_shadow    = win_shadow
  cfg.border        = border
  cfg.line_thick    = line_thick
  cfg.base_unit     = base_unit

  cfg.frame_delay   = (frame_delay < 0) ? 1 : frame_delay
  cfg.scroll_delay  = (scroll_delay < 0) ? 1 : scroll_delay

  reserve(&st.wlist, len(wlist))
  for win in wlist
  {
    add_window(win)
  }

  cfg.header_height = f32(cfg.font.baseSize) + math.trunc(cfg.pad / 2)
}

fini :: proc()
{
  delete(st.wlist)
  rl.UnloadFont(cfg.font)
}