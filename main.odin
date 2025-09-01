/*******************************************************************************
 *
 * "The Exploration of the Vaults of King Teqamgolla" - by Axel "Ajderniz" Lopez
 * 
 * Mostly a hidden objects game.
 *
 * ****************************************************************************/

package teqamgolla

import "core:log"
import "core:mem"

import rl "vendor:raylib"

import "gui"

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
  rl.SetWindowState( { .WINDOW_RESIZABLE } )

  rl.SetTargetFPS(60)

  font := rl.LoadFontEx("res/fonts/Px437_DOS-V_re_ANK16.ttf", 16, nil, 0)
  gui.init(font, 12)

  bliss := rl.LoadTexture("res/img/bliss.jpg")

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  /* ============================= MAIN LOOP ================================ */

  dbox1: gui.DraggableBox
  dbox1.rec = { 0, 0, 300, 200 }

  dbox2: gui.DraggableBox
  dbox2.rec = { 300, 0, 200, 300 }

  for false == rl.WindowShouldClose()
  {
    rl.BeginTextureMode(rtxr)

      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

      gui.draw_draggable_box(&dbox1)
      gui.draw_draggable_box(&dbox2)

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

  rl.UnloadRenderTexture(rtxr)

  rl.CloseWindow()
}