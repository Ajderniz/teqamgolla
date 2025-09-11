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

import rl "vendor:raylib"

import "gui"

import "core:fmt"

/* 'NAT' here stands for 'native'. */
NAT_SCR_W :: 640
NAT_SCR_H :: NAT_SCR_W / 4 * 3

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

  rl.InitWindow(NAT_SCR_W, NAT_SCR_H, "Teqamgolla")

  rl.SetTargetFPS(25)

  font := rl.LoadFontEx("res/fonts/Px437_DOS-V_re_ANK16.ttf", 16, nil, 0)
  gui.init(font, pad = 12, txt_color = rl.BLACK, line_color = rl.BLACK, bg_color = rl.WHITE)

  bliss := rl.LoadTexture("res/img/bliss.jpg")
  danta := rl.LoadTexture("res/img/danta.png")
  dalila := rl.LoadTexture("res/img/dalila.png")

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  img1 := gui.ImageElement{danta, .CENTER}
  blist := []^gui.Window{ 
    &{
      rec={10, 10, 300, 300},
      options={ .DRAGGABLE, .RESIZABLE },
      header="HEADER",
      content={img1, "Faded concrete shanty town katana gang dissident semiotics receding A.I. Shibuya apophenia drugs Legba systema RAF. Spook Legba military-grade geodesic render-farm shrine pen computer market film-space faded augmented reality sprawl nodal point long-chain hydrocarbons. Drone denim engine narrative modem systema bicycle vinyl city refrigerator corrupted table bomb lights tank-traps. Engine motion DIY plastic-space silent assault numinous cartel order-flow weathered physical geodesic pen construct range-rover. Realism neon military-grade construct modem advert tiger-team cyber-man 8-bit tube office dissident garage disposable render-farm soul-delay. J-pop soul-delay kanji shrine military-grade render-farm city warehouse decay shanty town engine. Office Kowloon footage digital table drugs neon market fetishism dead courier. Shrine knife digital alcohol bomb free-market convenience store vinyl sunglasses shoes dead tanto Tokyo."},
      layout=.HORIZONTAL
    },
  }

  /* ============================= MAIN LOOP ================================ */

  for false == rl.WindowShouldClose()
  {
    if rl.IsKeyPressed(.TAB)
    {
      if rl.IsKeyDown(.LEFT_SHIFT)
      {
        gui.move_window_index_to_index(blist, 0, u32(len(blist) - 1))
      }
      else
      {
        gui.move_window_index_to_index(blist, u32(len(blist) - 1), 0)
      }
    }

    rl.BeginTextureMode(rtxr)

      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

      gui.draw_window_list(blist)

    rl.EndTextureMode()

    rl.BeginDrawing()
      rl.ClearBackground(rl.BLACK)
      rl.DrawTexturePro(
        rtxr.texture,
        { 0, 0, NAT_SCR_W, -NAT_SCR_H },
        { 0, 0, NAT_SCR_W, NAT_SCR_H },
        0,
        0,
        rl.WHITE)
    rl.EndDrawing()
  }

  /* ========================= DE-INITIALIZATION ============================ */

  rl.UnloadTexture(bliss)
  rl.UnloadTexture(danta)
  rl.UnloadTexture(dalila)

  rl.UnloadRenderTexture(rtxr)

  rl.CloseWindow()
}