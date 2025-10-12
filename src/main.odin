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

import     "cursor"
import dgn "dungeon"
import     "gui"

NAT_SCR_W :: 640
NAT_SCR_H :: (NAT_SCR_W / 4) * 3

SCALE :: 2
SCR_W :: NAT_SCR_W * SCALE
SCR_H :: NAT_SCR_H * SCALE

FPS   :: 20

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
  rl.SetTargetFPS(FPS)

  cursor.init("../res/img/cursor.png")

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)
  first_person_rtxr := rl.LoadRenderTexture(
    i32(math.trunc(f32(NAT_SCR_H) * .75)),
    i32(math.trunc(f32(NAT_SCR_H) * .75))
    )
  minimap_rtxr := rl.LoadRenderTexture(100, 100)

  wall_txr := rl.LoadTexture("../res/img/wall.png")
  rl.SetTextureFilter(wall_txr, .BILINEAR)
  wall_east: dgn.Face = { base=wall_txr }

  dum: dgn.Block
  dum.faces[.TOP] = &wall_east
  dum.faces[.NORTH] = &wall_east
  dum.faces[.EAST] = &wall_east
  dum.faces[.SOUTH] = &wall_east
  dum.faces[.WEST] = &wall_east
  dum.faces[.BOTTOM] = &wall_east

  bmap: dgn.BlockMap = {
    {
      { &dum, &dum, &dum, &dum },
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
    },
    {
      { &dum, &dum, &dum, &dum },
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
      { nil,  nil,  nil,  nil },
    },
    {
      { &dum, &dum, &dum, &dum },
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

  for !rl.WindowShouldClose()
  {
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
          (NAT_SCR_W - f32(first_person_rtxr.texture.width))  / 2,
          (NAT_SCR_H - f32(first_person_rtxr.texture.height)) / 2,
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

      //cursor.draw(SCALE)
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
    cursor.fini()
    rl.UnloadRenderTexture(rtxr)
    rl.UnloadRenderTexture(first_person_rtxr)
    rl.UnloadRenderTexture(minimap_rtxr)

    rl.CloseWindow()
}