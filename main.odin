/*******************************************************************************
 *
 * "Exploring the Vaults of King Teqamgolla" - by Axel "Ajderniz" Lopez
 * 
 * Mostly a hidden objects game.
 *
 * ****************************************************************************/

package teqamgolla

import "core:log"
import "core:mem"
import "core:math"

import rl "vendor:raylib"

import "gui"

import "core:fmt"

/* 'NAT' here stands for 'native'. */
NAT_SCR_W :: 640
NAT_SCR_H :: (NAT_SCR_W / 4) * 3

SCALE :: 1
SCR_W :: NAT_SCR_W * SCALE
SCR_H :: NAT_SCR_H * SCALE

FPS       :: 60
VFPS      :: 60
VFPS_FREQ :: FPS / VFPS


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

  rl.InitWindow(SCR_W, SCR_H, "Teqamgolla")


  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  font := rl.LoadFontEx("res/fonts/Px437_DOS-V_re_ANK16.ttf", 16, nil, 0)
  gui.init(font, base_unit=4) 

  cursor := rl.LoadTexture("res/img/cursor.png")

  bliss := rl.LoadTexture("res/img/bliss.jpg")
  danta := rl.LoadTexture("res/img/danta.png")

  rl.SetTargetFPS(FPS)

  txt1 := gui.Element{
    data="Chiba man paranoid math-spook shanty town render-farm sensory futurity office tube. Military-grade faded refrigerator ablative range-rover rain numinous shoes. Pen cyber-spook market bridge bomb sunglasses courier post-into math-warehouse papier-mache boy shoes."
  }

  txt2 := gui.Element{
    data="Singularity decay tank-traps jeans numinous sprawl realism beef noodles narrative motion pistol cardboard crypto-tower. Vinyl RAF smart-euro-pop spook footage weathered wristwatch wonton soup. Boat crypto-hotdog faded j-pop soul-delay cardboard. Nodality marketing vinyl narrative paranoid beef noodles sign human systema monofilament boat decay. Film tanto papier-mache office sign table weathered. Range-rover computer soul-delay long-chain hydrocarbons pre-DIY systema systemic-ware footage sentient office weathered monofilament. Drugs neon modem rebar garage table savant franchise nano-narrative hotdog geodesic pen hacker realism. DIY cardboard Shibuya film drone monofilament ablative."
  }

  img := gui.Element{
    data=gui.ImageElement{
      texture=danta,
      resize=.STRETCH
    }
  }

  box1 := gui.Element{
    data=gui.BoxElement{
      header="BOX1",
      content={&txt1, &img}
    }
  }

  box2 := gui.Element{
    data=gui.BoxElement{
      header="BOX2",
      content={&txt2}
    }
  }

  win: gui.Window = {
    draggable=true,

    emt=&gui.Element {
      data=gui.BoxElement{
        header="HEADER",
        content={&box1, &box2},
        layout=.HORIZONTAL,
      }
    }
  }

  wlist := []^gui.Window{ 
    &win
  }

  vfps_counter := 0

  /* ============================= MAIN LOOP ================================ */

  rl.HideCursor()

  for false == rl.WindowShouldClose()
  {
    mpos := rl.GetMousePosition()
    mpos.x = math.trunc(mpos.x / SCALE)
    mpos.y = math.trunc(mpos.y / SCALE)
    mpos.x = (mpos.x < 0) ? 0 : mpos.x
    mpos.y = (mpos.y < 0) ? 0 : mpos.y
    mpos.x = (NAT_SCR_W < mpos.x) ? NAT_SCR_W : mpos.x
    mpos.y = (NAT_SCR_H < mpos.y) ? NAT_SCR_H : mpos.y

    if rl.IsKeyPressed(.TAB)
    {
      if rl.IsKeyDown(.LEFT_SHIFT)
      {
        gui.move_window_index_to_index(wlist, 0, u32(len(wlist) - 1))
      }
      else
      {
        gui.move_window_index_to_index(wlist, u32(len(wlist) - 1), 0)
      }
    }

    vfps_counter = (vfps_counter + 1) % VFPS_FREQ

    mstate: gui.MouseState

    rl.BeginTextureMode(rtxr)

      mstate = gui.update_window_list(wlist, mpos, SCALE)
      if (0 == vfps_counter)
      {
        rl.DrawTexture(bliss, 0, 0, rl.WHITE)

        gui.draw_window_list(wlist)

      }
      mpos = rl.GetMousePosition()
      mpos.x = math.trunc(mpos.x / SCALE)
      mpos.y = math.trunc(mpos.y / SCALE)
      switch mstate
      {
      case .DEFAULT:
        rl.DrawTextureRec(cursor, { 0, 0, 16, 16}, mpos, rl.WHITE)
      case .DRAG:
        rl.DrawTextureRec(cursor, {16, 0, 16, 16}, mpos - 8, rl.WHITE)
      case .RESIZE:
        rl.DrawTextureRec(cursor, {32, 0, 16, 16}, mpos - 16, rl.WHITE)
      }

    rl.EndTextureMode()

    rl.BeginDrawing()
      rl.ClearBackground(rl.BLACK)
      rl.DrawTexturePro(
        rtxr.texture,
        { 0, 0, NAT_SCR_W, -NAT_SCR_H },
        { 0, 0, SCR_W, SCR_H },
        0,
        0,
        rl.WHITE)
    rl.EndDrawing()
  }
    rl.UnloadTexture(danta)
    rl.UnloadTexture(bliss)
    rl.UnloadTexture(cursor)
    rl.UnloadFont(font)
    rl.UnloadRenderTexture(rtxr)

    rl.CloseWindow()
}