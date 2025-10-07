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

import dgn "dungeon"
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
  rl.SetTargetFPS(g.FPS)

  rtxr := rl.LoadRenderTexture(g.NAT_SCR_W, g.NAT_SCR_H)
  first_person_rtxr := rl.LoadRenderTexture(
    i32(math.trunc(f32(g.NAT_SCR_H) * .75)),
    i32(math.trunc(f32(g.NAT_SCR_H) * .75))
    )
  minimap_rtxr := rl.LoadRenderTexture(100, 100)

  //cursor_txr := rl.LoadTexture("../res/img/cursor.png")

  dum: dgn.Block
  bmap: dgn.BlockMap = {
    {
      { &dum, &dum, &dum, &dum },
      { &dum, &dum, &dum, &dum },
      { &dum, &dum, &dum, &dum },
      { &dum, &dum, &dum, &dum },
    },
    {
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
      { nil,  &dum, nil,  nil },
      { nil,  nil,  nil,  nil },
    },
    {
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
    }
  }
  player: dgn.PlayerState = {pos={z=1}}
  stretch: f32 = 2

  dgn.update_first_person(bmap, player, first_person_rtxr, stretch)
  dgn.update_minimap(5, bmap, player, minimap_rtxr)

  /* ============================= MAIN LOOP ================================ */

  //rl.HideCursor()

  for !rl.WindowShouldClose()
  {
    /*
    // TODO: Maybe this should go into the GUI package

    mpos := rl.GetMousePosition()
    mpos.x = math.trunc(mpos.x / g.SCALE)
    mpos.y = math.trunc(mpos.y / g.SCALE)
    mpos.x = (mpos.x < 0) ? 0 : mpos.x
    mpos.y = (mpos.y < 0) ? 0 : mpos.y
    mpos.x = (g.NAT_SCR_W < mpos.x) ? g.NAT_SCR_W : mpos.x
    mpos.y = (g.NAT_SCR_H < mpos.y) ? g.NAT_SCR_H : mpos.y
    */

    key_pressed := rl.GetKeyPressed()
    old_player := player
    old_stretch := stretch
    #partial switch key_pressed
    {
    case .W:
      switch player.dir
      {
      case .NORTH: player.y -= (0        < player.y)              ? 1 : 0
      case .EAST:  player.x += (player.x < (len(bmap[0][0]) - 1)) ? 1 : 0
      case .SOUTH: player.y += (player.y < (len(bmap[0]) - 1))    ? 1 : 0
      case .WEST:  player.x -= (0        < player.x)              ? 1 : 0
      }
    case .S:
      switch player.dir
      {
      case .NORTH: player.y += (player.y < (len(bmap[0]) - 1))    ? 1 : 0
      case .EAST:  player.x -= (0        < player.x)              ? 1 : 0
      case .SOUTH: player.y -= (0        < player.y)              ? 1 : 0
      case .WEST:  player.x += (player.x < (len(bmap[0][0]) - 1)) ? 1 : 0
      }
    case .A:
      switch player.dir
      {
      case .NORTH: player.x -= (0        < player.x)              ? 1 : 0
      case .EAST:  player.y -= (0        < player.y)              ? 1 : 0
      case .SOUTH: player.x += (player.x < (len(bmap[0][0]) - 1)) ? 1 : 0
      case .WEST:  player.y += (player.y < (len(bmap[0]) - 1 ))   ? 1 : 0
      }
    case .D:
      switch player.dir
      {
      case .NORTH: player.x += (player.x < (len(bmap[0][0]) - 1)) ? 1 : 0
      case .EAST:  player.y += (player.y < (len(bmap[0]) - 1 ))   ? 1 : 0
      case .SOUTH: player.x -= (0        < player.x)              ? 1 : 0
      case .WEST:  player.y -= (0        < player.y)              ? 1 : 0
      }
    case .Q:
      switch player.dir
      {
      case .NORTH: player.dir = .WEST
      case .EAST:  player.dir = .NORTH
      case .SOUTH: player.dir = .EAST
      case .WEST:  player.dir = .SOUTH
      }
    case .E:
      switch player.dir
      {
      case .NORTH: player.dir = .EAST
      case .EAST:  player.dir = .SOUTH
      case .SOUTH: player.dir = .WEST
      case .WEST:  player.dir = .NORTH
      }
    case .R:    player.z += (player.z < (len(bmap) - 1)) ? 1 : 0
    case .F:    player.z -= (0        < player.z)        ? 1 : 0
    case .UP:   stretch += 0.1
    case .DOWN: stretch -= (0.1 < stretch) ? 0.1 : 0
    }

    must_update := false
    #partial switch key_pressed
    {
    case .W, .S, .A, .D, .R, .F: must_update = (old_player.pos != player.pos)
    case .Q, .E:                 must_update = (old_player.dir != player.dir)
    case .UP, .DOWN:             must_update = (old_stretch    != stretch)

    }
    if must_update
    {
      dgn.update_first_person(bmap, player, first_person_rtxr, stretch)
      dgn.update_minimap(5, bmap, player, minimap_rtxr)
    }

    rl.BeginTextureMode(rtxr)
    {
      rl.ClearBackground(rl.DARKBLUE)

      rl.DrawTexturePro(
        first_person_rtxr.texture,
        {
          0,
          0,
          f32(first_person_rtxr.texture.width),
          -f32(first_person_rtxr.texture.height),
        },
        {
          (g.NAT_SCR_W - f32(first_person_rtxr.texture.width))  / 2,
          (g.NAT_SCR_H - f32(first_person_rtxr.texture.height)) / 2,
          f32(first_person_rtxr.texture.width),
          f32(first_person_rtxr.texture.height),
        },
        0,
        0,
        rl.WHITE
        )

      rl.DrawTexturePro(
        minimap_rtxr.texture,
        {
          0,
          0,
          f32(minimap_rtxr.texture.width),
          -f32(minimap_rtxr.texture.height),
        },
        {
          12,
          12,
          f32(minimap_rtxr.texture.width),
          f32(minimap_rtxr.texture.height),
        },
        0,
        0,
        rl.WHITE
        )


      /*
      // TODO: move this cursor thing into its own package
      cursor_txr_offset: f32 = 0
      cursor_pos := rl.GetMousePosition()
      cursor_pos.x = math.trunc(cursor_pos.x / g.SCALE)
      cursor_pos.y = math.trunc(cursor_pos.y / g.SCALE)
      // Should not depend on GUI
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
      */
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
    //rl.UnloadTexture(cursor_txr)
    rl.UnloadRenderTexture(rtxr)
    rl.UnloadRenderTexture(first_person_rtxr)
    rl.UnloadRenderTexture(minimap_rtxr)

    rl.CloseWindow()
}