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

  img1 := gui.Image{danta, .CENTER}
  img2 := gui.Image{dalila, .STRETCH}
  blist := []^gui.Box{ 
    &{
      options={ .DRAGGABLE, .RESIZABLE },
      header="HEADER",
      content={img1, img2}, //img1},//, "Lights wonton soup soul-delay refrigerator construct into monofilament chrome. Carbon jeans courier garage long-chain hydrocarbons sunglasses RAF camera stimulate hacker towards. Assassin corrupted geodesic cyber-table chrome saturation point. Wristwatch tattoo office pre-Kowloon construct vinyl shrine cardboard katana kanji narrative numinous sensory concrete corporation. Rebar 8-bit savant RAF network advert rain woman face forwards receding industrial grade geodesic concrete military-grade monofilament. Girl network rebar ablative city dissident cyber-bicycle youtube long-chain hydrocarbons vehicle car DIY sentient franchise j-pop.", "A.I. dead market otaku kanji euro-pop rifle weathered tiger-team neon. Cardboard artisanal neural market sign courier corrupted BASE jump. Bicycle chrome girl pen tiger-team saturation point math-franchise render-farm wonton soup. Boy 8-bit katana nodality futurity alcohol man dissident girl convenience store corrupted disposable j-pop pistol ablative. Rebar market drone skyscraper disposable artisanal refrigerator plastic DIY Tokyo papier-mache smart-shoes monofilament paranoid boat advert. Order-flow city industrial grade kanji wristwatch marketing katana wonton soup woman tanto geodesic.", "Otaku katana weathered geodesic marketing Kowloon RAF sub-orbital papier-mache soul-delay dead augmented reality media nano-jeans neon. Geodesic vehicle Kowloon neon construct RAF tube DIY meta-bridge post-decay kanji modem systemic sign range-rover. Marketing dome tanto sprawl youtube long-chain hydrocarbons nodal point. Corporation tube assassin grenade j-pop nano-franchise cartel artisanal kanji render-farm tiger-team free-market tanto bomb. Artisanal sign drugs nodality neural knife city."},
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
  rl.UnloadTexture(danta)
  rl.UnloadTexture(dalila)

  rl.UnloadRenderTexture(rtxr)

  rl.CloseWindow()
}