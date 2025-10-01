/*******************************************************************************
 *
 * "Exploring the Vaults of King Teqamgolla" - by Axel "Ajderniz" Lopez
 * 
 * Mostly a hidden objects game.
 *
 * ****************************************************************************/

package teqamgolla

import     "core:log"
import     "core:mem"
import     "core:math"
import str "core:strings"

import rl  "vendor:raylib"

import g   "global"
import     "gui"

main :: proc()
{
  /* Logger boilerplate, copied from Karl Zylinski */
  context.logger = log.create_console_logger()
  context.logger.options = {
    .Level,
    .Short_File_Path,
    .Line,
    .Procedure,
    .Terminal_Color
  }

  /* Debug-mode tracking alloctor, also inspired by Karl Zylinski */
  when ODIN_DEBUG
  {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)

    defer
    {
      for _, entry in tracking_allocator.allocation_map
      {
        log.warnf("%v BYTES LEAKED AT %v\n", entry.size, entry.location)
      }
      mem.tracking_allocator_destroy(&tracking_allocator)
    }
  }

  /* ========================== INITIALIZATION ============================== */

  rl.InitWindow(g.SCR_W, g.SCR_H, "Teqamgolla")

  rtxr := rl.LoadRenderTexture(g.NAT_SCR_W, g.NAT_SCR_H)

  font: rl.Font
  {
    codepoint_count: i32
    codepoints := rl.LoadCodepoints(
      "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20!\"#$%&'()*+,-./0123456789:;<>=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~\x7F\xA0¡¿ÁÉÍÑÓÚÜáéíñóúü\x00",
      &codepoint_count)

    font = rl.LoadFontEx(
      "../res/fonts/Px437_DOS-V_re_ANK16.ttf",
      16,
      codepoints,
      codepoint_count)

    rl.UnloadCodepoints(codepoints)
  }

  border := rl.LoadTexture("../res/img/border.png")
  eborder := gui.ElementBorder {
    texture=border,
    corner_rec={
      default={0,0,5,5},
    },
    line_rec={
      default={5,0,5,5},
    },
  }
  background := rl.LoadTexture("../res/img/background.png")
  gui.init(font, base_unit=4, frame_delay=3, scroll_delay=4, border=eborder)

  cursor_txr := rl.LoadTexture("../res/img/cursor.png")

  bliss := rl.LoadTexture("../res/img/bliss.jpg")
  danta := rl.LoadTexture("../res/img/danta.png")

  rl.SetTargetFPS(g.FPS)

  txt1 := gui.Element{
    data=gui.TextElement{
      txt="Chiba man paranoid math-spook shanty town render-farm sensory futurity office tube. Military-grade faded refrigerator ablative range-rover rain numinous shoes. Pen cyber-spook market bridge bomb sunglasses courier post-into  math-warehouse papier-mache boy shoes."
    },
  }
  defer gui.delete_text_element(&txt1.data.(gui.TextElement))

  txt2 := gui.Element{
    data=gui.TextElement{
      txt="Singularity decay tank-traps jeans numinous sprawl realism beef noodles narrative motion pistol cardboard crypto-tower. Vinyl RAF smart-euro-pop spook footage weathered wristwatch wonton soup. Boat crypto-hotdog faded j-pop soul-delay cardboard. Nodality marketing vinyl narrative paranoid beef noodles sign human systema monofilament boat decay. Film tanto papier-mache office sign table weathered. Range-rover computer soul-delay long-chain hydrocarbons pre-DIY systema systemic-ware footage sentient office weathered monofilament. Drugs neon modem rebar garage table savant franchise nano-narrative hotdog geodesic pen hacker realism. DIY cardboard Shibuya film drone monofilament ablative.",
      scroll_type=.PAGED
    },
  }
  defer gui.delete_text_element(&txt2.data.(gui.TextElement))

  img := gui.Element{
    data=gui.ImageElement{
      texture=danta,
      resize=.STRETCH
    },
    non_resizable={true,true},
  }

  box1 := gui.Element{
    data=gui.BoxElement{
      content={&txt1, &img}
    },
    non_resizable={true,false},
  }

  box2 := gui.Element{
    data=gui.BoxElement{
      header="BOX2",
      content={&txt2}
    }
  }

  win1: gui.Window = {
    draggable=true,
    element=&gui.Element {
      data=gui.BoxElement{
        header="HEADER",
        content={&txt2, &box1},
        layout=.HORIZONTAL,
      },
      border_style=.GLOBAL
    },
  }

  win2: gui.Window = {
    draggable=true,
    element=&gui.Element{
      data=gui.BoxElement{
      },
      border_style=.LINE
    }
  }

  wlist := []^gui.Window{ 
    &win1, &win2
  }

  vfps_counter := 0

  /* ============================= MAIN LOOP ================================ */

  rl.HideCursor()

  for false == rl.WindowShouldClose()
  {
    mpos := rl.GetMousePosition()
    mpos.x = math.trunc(mpos.x / g.SCALE)
    mpos.y = math.trunc(mpos.y / g.SCALE)
    mpos.x = (mpos.x < 0) ? 0 : mpos.x
    mpos.y = (mpos.y < 0) ? 0 : mpos.y
    mpos.x = (g.NAT_SCR_W < mpos.x) ? g.NAT_SCR_W : mpos.x
    mpos.y = (g.NAT_SCR_H < mpos.y) ? g.NAT_SCR_H : mpos.y

    rl.BeginTextureMode(rtxr)
    {
      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

      gui.process_window_list_input(wlist, mpos)
      gui.draw_window_list(wlist)

      cursor_txr_offset: f32 = 0
      cursor_pos := rl.GetMousePosition()
      cursor_pos.x = math.trunc(cursor_pos.x / g.SCALE)
      cursor_pos.y = math.trunc(cursor_pos.y / g.SCALE)
      #partial switch gui.get_cursor_state()
      {
      case .POTENTIAL:
        cursor_txr_offset = 16
        cursor_pos -= 8
      case .DRAG:
        cursor_txr_offset = 32
        cursor_pos -= 8
      case .RESIZE:
        cursor_txr_offset = 48
        cursor_pos -= 16
      case .SCROLL_UP:
        cursor_txr_offset = 64
        cursor_pos.x -= 8
        cursor_pos.y -= 12
      case .SCROLL_DOWN:
        cursor_txr_offset = 80
        cursor_pos.x -= 8
        cursor_pos.y -= 4
      case .PAGE_PREV:
        cursor_txr_offset = 96
        cursor_pos -= 8
      case .PAGE_NEXT:
        cursor_txr_offset = 112
        cursor_pos -= 8
      }
      rl.DrawTextureRec(
        cursor_txr,
        { cursor_txr_offset, 0, 16, 16 },
        cursor_pos,
        rl.WHITE)
    }
    rl.EndTextureMode()

    rl.BeginDrawing()
    {
      rl.ClearBackground(rl.BLACK)
      rl.DrawTexturePro(
        rtxr.texture,
        { 0, 0, g.NAT_SCR_W, -g.NAT_SCR_H },
        { 0, 0, g.SCR_W, g.SCR_H },
        0,
        0,
        rl.WHITE)
    }
    rl.EndDrawing()
  }
    rl.UnloadTexture(danta)
    rl.UnloadTexture(bliss)
    rl.UnloadTexture(border)
    rl.UnloadTexture(cursor_txr)
    rl.UnloadFont(font)
    rl.UnloadRenderTexture(rtxr)

    rl.CloseWindow()
}