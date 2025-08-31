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

is_rec_touching_mouse :: proc(rec: rl.Rectangle) -> bool
{
  mpos := rl.GetMousePosition()
  return (rec.x <= mpos.x && mpos.x <= (rec.x + rec.width)) &&
         (rec.y <= mpos.y && mpos.y <= (rec.y + rec.height))
}

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

  mbrec := rl.Rectangle{10,10,300,200}
  resize := false
  move := false
  diff := rl.Vector2{0,0}

  for false == rl.WindowShouldClose()
  {
    scr_w := f32(rl.GetScreenWidth())
    scr_h := f32(rl.GetScreenHeight())
    scale := scr_h / NAT_SCR_H
    scaled_w := scr_h / 3 * 4
    scaled_x := (scr_w - scaled_w) / 2

    if is_rec_touching_mouse(mbrec)
    {
      if !resize && rl.IsMouseButtonDown(.RIGHT) 
      {
        rl.SetMousePosition(
          i32(mbrec.x + mbrec.width),
          i32(mbrec.y + mbrec.height))
        rl.SetMouseCursor(.RESIZE_NWSE)
        resize = true
    }
      else if !move && rl.IsMouseButtonDown(.LEFT)
      {
        rl.SetMouseCursor(.RESIZE_ALL)
        mpos := rl.GetMousePosition()
        diff = { mpos.x - mbrec.x, mpos.y - mbrec.y }
        move = true
      }
    }
    if resize
    {
      if rl.IsMouseButtonDown(.RIGHT)
      {
        mpos := rl.GetMousePosition()
        mbrec.width = mpos.x - mbrec.x if 24 <= mpos.x - mbrec.x else 24
        mbrec.height = mpos.y - mbrec.y if 24 <= mpos.y - mbrec.y else 24
      }
      else
      {
        rl.SetMouseCursor(.DEFAULT)
        resize = false
      }
    }
    else if move
    {
      if rl.IsMouseButtonDown(.LEFT)
      {
        mpos := rl.GetMousePosition()
        mbrec.x = mpos.x - diff.x//mbrec.x
        mbrec.y = mpos.y - diff.y//mbrec.y
      }
      else
      {
        rl.SetMouseCursor(.DEFAULT)
        move = false
      }
    }

    rl.BeginTextureMode(rtxr)

      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

      gui.draw_message_box(mbrec, "Beef noodles denim-space convenience store pistol Legba claymore mine rifle sign market knife silent Chiba A.I.. Footage face forwards shoes disposable man bicycle chrome. Wonton soup bridge camera 8-bit monofilament shrine semiotics grenade disposable ablative tank-traps cartel.")
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