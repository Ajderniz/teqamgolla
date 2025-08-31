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

  rl.SetTargetFPS(30)

  font := rl.LoadFontEx("res/fonts/Px437_DOS-V_re_ANK16.ttf", 16, nil, 0)
  gui.init(font, 12)

  bliss := rl.LoadTexture("res/img/bliss.jpg")

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  /* ============================= MAIN LOOP ================================ */

  for false == rl.WindowShouldClose()
  {
    scr_w := f32(rl.GetScreenWidth())
    scr_h := f32(rl.GetScreenHeight())
    scale := scr_h / NAT_SCR_H
    scaled_w := scr_h / 3 * 4
    scaled_x := (scr_w - scaled_w) / 2

    mx := f32(rl.GetMouseX()) * (scaled_w / NAT_SCR_W)
    my := f32(rl.GetMouseY()) * (scr_h / NAT_SCR_H)

    rl.BeginTextureMode(rtxr)

      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

      gui.draw_message_box({0,0, mx, my}, "In a village of La Mancha, the name of which I have no desire to call to mind, there lived not long since one of those gentlemen that keep a lance in the lance-rack, an old buckler, a lean hack, and a greyhound for coursing. An olla of rather more beef than mutton, a salad on most nights, scraps on Saturdays, lentils on Fridays, and a pigeon or so extra on Sundays, made away with three-quarters of his income. The rest of it went in a doublet of fine cloth and velvet breeches and shoes to match for holidays, while on week-days he made a brave figure in his best homespun. He had in his house a housekeeper past forty, a niece under twenty, and a lad for the field and market-place, who used to saddle the hack as well as handle the bill-hook. The age of this gentleman of ours was bordering on fifty; he was of a hardy habit, spare, gaunt-featured, a very early riser and a great sportsman. They will have it his surname was Quixada or Quesada (for here there is some difference of opinion among the authors who write on the subject), although from reasonable conjectures it seems plain that he was called Quexana. This, however, is of but little importance to our tale; it will be enough not to stray a hair's breadth from the truth in the telling of it.")
      gui.draw_label({0, 0}, rl.TextFormat("%f", scale))

    rl.EndTextureMode()

    rl.BeginDrawing()
      rl.ClearBackground(rl.BLACK)
      rl.DrawTexturePro(
        rtxr.texture,
        { 0, 0, NAT_SCR_W, -NAT_SCR_H },
        { scaled_x, 0, scaled_w, scr_h },
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