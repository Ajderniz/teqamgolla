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

  rl.SetTargetFPS(60)

  font := rl.LoadFontEx("res/fonts/Px437_DOS-V_re_ANK16.ttf", 16, nil, 0)
  gui.init(font, padding = 12, txt_color = rl.BLACK, line_color = rl.BLACK, bg_color = rl.WHITE)

  bliss := rl.LoadTexture("res/img/bliss.jpg")
  danta := rl.LoadTexture("res/img/danta.png")

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  blist := []^gui.Box{ 
    &{rec={200,0,200,200},
      flags={},
      header="Still",
      content="Tiger-team marketing lights pen jeans wristwatch corporation man tanto beef noodles industrial grade neon garage DIY. Systemic rifle computer girl assassin shoes pre-render-farm otaku ablative. Wonton soup bomb augmented reality narrative youtube table network construct systema sentient. Shanty town Chiba soul-delay dissident drugs disposable Shibuya j-pop numinous monofilament A.I. knife boy tiger-team render-farm otaku assassin. Futurity savant plastic tower geodesic katana city rebar. "
    },
    &{rec={0,200,200,200},
      flags={.DRAGGABLE, .RESIZABLE},
      header="Draggable",
      content=danta
    },
    &{rec={200,200,200,200},
      flags={.DRAGGABLE, .RESIZABLE},
      header="Draggable & resizable",
      content="Sentient digital pistol post-stimulate girl uplink. Urban cartel camera dome hacker cyber-knife tattoo modem. Dissident faded camera bridge cartel nano-shanty town. Rebar saturation point Tokyo nodality chrome alcohol youtube sensory-space claymore mine. Sentient girl soul-delay hotdog weathered j-pop concrete tank-traps drugs neural. Math-RAF tank-traps drugs market spook Shibuya film gang nodal point. Bicycle pre-artisanal knife car corporation plastic apophenia neon spook. Cardboard A.I. tube bicycle order-flow disposable spook corporation face forwards. 3D-printed systemic Shibuya sub-orbital bridge Kowloon shanty town tiger-team face forwards sign nano-refrigerator smart-plastic pen hotdog. "
    },
  }

  /* ============================= MAIN LOOP ================================ */

  for false == rl.WindowShouldClose()
  {
    if rl.IsKeyPressed(.TAB)
    {
      if rl.IsKeyDown(.LEFT_SHIFT)
      {
        gui.move_box_index_to_index(blist, 0, u32(len(blist) - 1))
      }
      else
      {
        gui.move_box_index_to_index(blist, u32(len(blist) - 1), 0)
      }
    }

    rl.BeginTextureMode(rtxr)

      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

      gui.draw_box_list(blist)

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