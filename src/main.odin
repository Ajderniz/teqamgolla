/*******************************************************************************
 *
 * "Exploring the Vaults of King Teqamgolla" - by Axel "Ajderniz" Lopez
 * 
 * Mostly a hidden objects game.
 *
 * ****************************************************************************/

package teqamgolla

import "base:runtime"
import      "core:log"
import      "core:mem"
import      "core:os"
import path "core:path/filepath"
import str  "core:strings"

import rl   "vendor:raylib"

import cht  "chat"
import      "gui"
import cur  "gui/cursor"
import inp  "input"

ROOT_DIR  :: "/home/axell/Work/odin/teqamgolla"

NAT_SCR_W :: 640
NAT_SCR_H :: NAT_SCR_W * .75

SCR_SCALE :: 2
SCR_W :: NAT_SCR_W * SCR_SCALE
SCR_H :: NAT_SCR_H * SCR_SCALE

FPS   :: 60

cfg: struct
{
  dir: [enum {RES, FONTS, IMG, MAPS}]string
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

  err: mem.Allocator_Error
  cfg.dir[.RES], err   = path.join({ROOT_DIR,      "res"})
  cfg.dir[.FONTS], err = path.join({cfg.dir[.RES], "fonts"})
  cfg.dir[.IMG], err   = path.join({cfg.dir[.RES], "img"})
  cfg.dir[.MAPS], err  = path.join({cfg.dir[.RES], "maps"})

  rl.InitWindow(SCR_W, SCR_H, "Teqamgolla")
  rl.SetTargetFPS(FPS)

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  res_path: string
  res_path_cstring: cstring

  res_path, err = path.join({cfg.dir[.IMG], "cursor-base.png"})
  res_path_cstring = str.clone_to_cstring(res_path)
  delete(res_path)
  {
    half_size := f32(cur.CURSOR_SIZE / 2)
    center: rl.Vector2 = { -half_size, -half_size }
    if !cur.init(res_path_cstring, { {0,0}, center, center })
    {
      log.error("Could not initialize cursor package")
      os.exit(1)
    }
  }
  delete(res_path_cstring)
  font: rl.Font
  {
    codepoint_count: i32
    codepoints := rl.LoadCodepoints(
      "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20!\"#$%&'()*+,-./0123456789:;<>=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_abcdefghijklmnopqrstuvwxyz{|}~\x7F\xA0¡¿ÁÉÍÑÓÚÜáéíñóúü\x00",
      &codepoint_count)

    res_path, err = path.join({cfg.dir[.FONTS], "Px437_DOS-V_re_ANK16.ttf"})
    res_path_cstring = str.clone_to_cstring(res_path)
    delete(res_path)
    font = rl.LoadFontEx(res_path_cstring, 16, codepoints, codepoint_count)
    delete(res_path_cstring)

    rl.UnloadCodepoints(codepoints)
  }

  txti := gui.Item {
    form = gui.TextItem {
      txt = "Hola, amigos de yutub el dia de oy les ensenare a como descargar gta san andres full gratis para windows 7, comensemos",
    },
  }
  win1 := gui.Window {
    draggable = true,
    item = &gui.Item { 
      form = gui.BoxItem {
        header = "BOX",
        content = {&txti}
      }
    }
  }

  res_path, err = path.join({cfg.dir[.IMG], "cursor-gui.png"})
  res_path_cstring = str.clone_to_cstring(res_path)
  delete(res_path)
  ok := gui.init(
    font         = font, 
    cur_txr_path = res_path_cstring,
    cur_offsets  = { 
      {-16,-16}, 
      {-4,-10}, 
      {-4,-4}, 
      cur.CENTER_CURSOR, 
      cur.CENTER_CURSOR },
    wlist        = {&win1},
    base_unit    = 8, 
    frame_delay  = 3
  )
  delete(res_path_cstring)
  if !ok
  {
    log.error("Could not initialize GUI")
    os.exit(1)
  }

  log.debug("INIT COMPLETE")

  defer
  {
    rl.UnloadRenderTexture(rtxr)

    cur.fini()
    gui.fini()

    gui.delete_text_item(&txti.form.(gui.TextItem))

    rl.CloseWindow()

    for dir in cfg.dir
    {
      delete(dir)
    }
  }

  /* ============================= MAIN LOOP ================================ */

  for !rl.WindowShouldClose()
  {
    input := inp.get_input_state(SCR_SCALE)
    gui.process_input(input, NAT_SCR_W, NAT_SCR_H, SCR_SCALE)

    rl.BeginTextureMode(rtxr)
    {
      if rl.IsKeyPressed(.P)
      {
        gui.change_text_item_txt(
          &txti.form.(gui.TextItem),
          "COCK",
          { txti.width, txti.height },
          txti.font)
      }

      rl.ClearBackground(rl.DARKBLUE)
      gui.draw_window_list()
      cur.draw(SCR_SCALE)
    }
    rl.EndTextureMode()

    rl.BeginDrawing()
    {
      rl.ClearBackground(rl.BLACK)
      rl.DrawTexturePro(
        rtxr.texture,
        { 0, 0, NAT_SCR_W, -NAT_SCR_H },
        { 0, 0, SCR_W, SCR_H },
        0,
        0,
        rl.WHITE)
    }
    rl.EndDrawing()
  }
}
