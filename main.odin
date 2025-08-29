package teqamgolla

import "core:log"
import "core:mem"

import rl "vendor:raylib"

NAT_SCR_W :: 640
NAT_SCR_H :: 480

main :: proc()
{
  context.logger = log.create_console_logger()
  context.logger.options = {
    .Level,
    .Short_File_Path,
    .Line,
    .Procedure,
    .Terminal_Color
  }

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

  rl.InitWindow(NAT_SCR_W, NAT_SCR_H, "Teqamgolla")
  rl.SetWindowState( { .WINDOW_RESIZABLE } )

  rl.SetTargetFPS(30)

  bliss := rl.LoadTexture("res/img/bliss.jpg")

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  for false == rl.WindowShouldClose()
  {
    scr_w := rl.GetScreenWidth()
    scr_h := rl.GetScreenHeight()

    rl.BeginTextureMode(rtxr)

      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

    rl.EndTextureMode()

    rl.BeginDrawing()
      rl.ClearBackground(rl.BLACK)
      rl.DrawTexturePro(
        rtxr.texture,
        { 0, 0, NAT_SCR_W, -NAT_SCR_H },
        { 0, 0, cast(f32)scr_w, cast(f32)scr_h },
        0,
        0,
        rl.WHITE
        )
    rl.EndDrawing()
  }

  rl.UnloadTexture(bliss)

  rl.UnloadRenderTexture(rtxr)

  rl.CloseWindow()
}