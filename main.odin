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
  gui.init(font, font_color = rl.BLACK, boder_color = rl.BLACK, background_color = rl.WHITE)

  bliss := rl.LoadTexture("res/img/bliss.jpg")

  rtxr := rl.LoadRenderTexture(NAT_SCR_W, NAT_SCR_H)

  blist := []^gui.Box{ 
    &{rec={0,0,200,200},
      flags={.DRAGGABLE, .RESIZABLE},
      content="Draggable & Resizeable"
    },
    &{rec={200,0,200,200},
      flags={},
      content="Still"
    },
    &{rec={0,200,100,100},
      flags={.DRAGGABLE},
      content="Draggable"
    },
    &{rec={200,200,200,200},
      flags={.DRAGGABLE, .RESIZABLE},
      content="Sentient digital pistol post-stimulate girl uplink. Urban cartel camera dome hacker cyber-knife tattoo modem. Dissident faded camera bridge cartel nano-shanty town. Rebar saturation point Tokyo nodality chrome alcohol youtube sensory-space claymore mine. Sentient girl soul-delay hotdog weathered j-pop concrete tank-traps drugs neural. Math-RAF tank-traps drugs market spook Shibuya film gang nodal point. Bicycle pre-artisanal knife car corporation plastic apophenia neon spook. Cardboard A.I. tube bicycle order-flow disposable spook corporation face forwards. 3D-printed systemic Shibuya sub-orbital bridge Kowloon shanty town tiger-team face forwards sign nano-refrigerator smart-plastic pen hotdog. "
    },
  }

  /* ============================= MAIN LOOP ================================ */

  for false == rl.WindowShouldClose()
  {
    rl.BeginTextureMode(rtxr)

      rl.DrawTexture(bliss, 0, 0, rl.WHITE)

      gui.update_box_list(blist)
      gui.draw_box_list(blist)
      //gui.draw_text_box(&box1, "En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero, adarga antigua, rocín flaco y galgo corredor. Una olla de algo más vaca que carnero, salpicón las más noches, duelos y quebrantos los sábados, lantejas los viernes, algún palomino de añadidura los domingos, consumían las tres partes de su hacienda. El resto della concluían sayo de velarte, calzas de velludo para las fiestas, con sus pantuflos de lo mesmo, y los días de entresemana se honraba con su vellorí de lo más fino. Tenía en su casa una ama que pasaba de los cuarenta, y una sobrina que no llegaba a los veinte, y un mozo de campo y plaza, que así ensillaba el rocín como tomaba la podadera. Frisaba la edad de nuestro hidalgo con los cincuenta años; era de complexión recia, seco de carnes, enjuto de rostro, gran madrugador y amigo de la caza. Quieren decir que tenía el sobrenombre de Quijada, o Quesada, que en esto hay alguna diferencia en los autores que deste caso escriben; aunque por conjeturas verosímiles se deja entender que se llamaba Quijana. Pero esto importa poco a nuestro cuento: basta que en la narración dél no se salga un punto de la verdad.")

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