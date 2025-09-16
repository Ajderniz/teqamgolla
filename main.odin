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
import "core:math"

import rl "vendor:raylib"

import "gui"

import "core:fmt"

/* 'NAT' here stands for 'native'. */
NAT_SCR_W :: 640
NAT_SCR_H :: (NAT_SCR_W / 4) * 3

SCALE :: 1
SCR_W :: NAT_SCR_W * SCALE
SCR_H :: NAT_SCR_H * SCALE

FPS       :: 60
VFPS      :: 60
VFPS_FREQ :: FPS / VFPS


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


  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  font := rl.LoadFontEx("res/fonts/Px437_DOS-V_re_ANK16.ttf", 16, nil, 0)
  gui.init(font, base_unit=4) 

  cursor := rl.LoadTexture("res/img/cursor.png")

  bliss := rl.LoadTexture("res/img/bliss.jpg")
  danta := rl.LoadTexture("res/img/danta.png")

  rl.SetTargetFPS(FPS)

  txt1 := gui.TextElement {
    txt="3D-printed construct marketing industrial grade physical footage military-grade augmented reality paranoid free-market long-chain hydrocarbons refrigerator decay Chiba film RAF urban. Nano-DIY singularity lights knife crypto-sprawl rebar. Tokyo Shibuya lights ablative Legba post-girl realism military-grade rebar hacker industrial grade shanty town cardboard. Soul-delay vinyl office nodality table tower concrete crypto-math-kanji Legba tiger-team film stimulate bridge. Footage physical tube augmented reality narrative car beef noodles film numinous systemic cardboard BASE jump receding. 8-bit franchise alcohol sub-orbital post-saturation point semiotics tower bridge drone uplink face forwards chrome. Disposable wonton soup ablative film cardboard decay systema futurity paranoid smart-gang. ",
    dims={min_size={100, 0}}
  }

  txt2 := gui.TextElement {
    txt="Fetishism footage nano-denim soul-delay city post-tattoo sprawl Chiba. Grenade dome voodoo god realism augmented reality narrative euro-pop denim face forwards hacker. Katana network Chiba dissident denim man city uplink towards faded skyscraper market paranoid. Augmented reality digital bicycle sentient tube spook industrial grade physical franchise. Savant franchise tattoo chrome dome systemic pen long-chain hydrocarbons post-shanty town. Camera systema grenade nodality Tokyo neural bicycle DIY. Savant silent beef noodles Tokyo marketing courier order-flow skyscraper free-market sprawl advert meta-motion wonton soup smart-disposable hacker. Free-market 8-bit boy Chiba narrative garage paranoid shanty town digital camera footage. Network fluidity BASE jump advert Kowloon RAF range-rover pre-neural rebar convenience store. "
  }

  img1 := gui.ImageElement {
    texture=danta,
    resize=.NONE,
  }

  img2 := gui.ImageElement {
    texture=danta,
    resize=.STRETCH
  }

  box1 := gui.BoxElement {
    content={&txt2, &img1},
    layout=.HORIZONTAL,
    header="BOX1"
  }

  box2 := gui.BoxElement {
    content={&txt1, &img2},
    header="BOX2"
  }

  win: gui.Window = {
    draggable=true,
    header="HEADER",
    content={&box2, &box1},
    layout=.HORIZONTAL,
  }
  win.box.rec.x = 10
  win.box.rec.y = 10

  wlist := []^gui.Window{ 
    &win
  }

  vfps_counter := 0

  /* ============================= MAIN LOOP ================================ */

  rl.HideCursor()

  for false == rl.WindowShouldClose()
  {
    mpos := rl.GetMousePosition()
    mpos.x = math.trunc(mpos.x / SCALE)
    mpos.y = math.trunc(mpos.y / SCALE)
    mpos.x = (mpos.x < 0) ? 0 : mpos.x
    mpos.y = (mpos.y < 0) ? 0 : mpos.y
    mpos.x = (NAT_SCR_W < mpos.x) ? NAT_SCR_W : mpos.x
    mpos.y = (NAT_SCR_H < mpos.y) ? NAT_SCR_H : mpos.y

    if rl.IsKeyPressed(.TAB)
    {
      if rl.IsKeyDown(.LEFT_SHIFT)
      {
        gui.move_window_index_to_index(wlist, 0, u32(len(wlist) - 1))
      }
      else
      {
        gui.move_window_index_to_index(wlist, u32(len(wlist) - 1), 0)
      }
    }

    vfps_counter = (vfps_counter + 1) % VFPS_FREQ

    mstate: gui.MouseState

    rl.BeginTextureMode(rtxr)

      mstate = gui.update_window_list(wlist, mpos, SCALE)
      if (0 == vfps_counter)
      {
        rl.DrawTexture(bliss, 0, 0, rl.WHITE)

        gui.draw_window_list(wlist)

      }
      mpos = rl.GetMousePosition()
      mpos.x = math.trunc(mpos.x / SCALE)
      mpos.y = math.trunc(mpos.y / SCALE)
      switch mstate
      {
      case .DEFAULT:
        rl.DrawTextureRec(cursor, { 0, 0, 16, 16}, mpos, rl.WHITE)
      case .DRAG:
        rl.DrawTextureRec(cursor, {16, 0, 16, 16}, mpos - 8, rl.WHITE)
      case .RESIZE:
        rl.DrawTextureRec(cursor, {32, 0, 16, 16}, mpos - 16, rl.WHITE)
      }

    rl.EndTextureMode()

    rl.BeginDrawing()
      rl.ClearBackground(rl.BLACK)
      rl.DrawTexturePro(
        rtxr.texture,
        { 0, 0, NAT_SCR_W, -NAT_SCR_H },
        { 0, 0, SCR_W, SCR_H },
        0,
        0,
        rl.WHITE)
    rl.EndDrawing()
  }
    rl.UnloadTexture(danta)
    rl.UnloadTexture(bliss)
    rl.UnloadTexture(cursor)
    rl.UnloadFont(font)
    rl.UnloadRenderTexture(rtxr)

    rl.CloseWindow()
}