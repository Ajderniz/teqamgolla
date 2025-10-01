package gui

import rl "vendor:raylib"

ImageElement :: struct {
  texture : rl.Texture,
  resize  : enum { NONE, CENTER, STRETCH },
}

@(private)
draw_image_element :: proc(imge: ImageElement, rec: rl.Rectangle)
{
  switch imge.resize
  {
  case .NONE:
    rl.DrawTextureV(imge.texture, {rec.x, rec.y}, rl.WHITE)
  case .CENTER:
    rl.DrawTextureV(
      imge.texture,
      {
        rec.x + (rec.width - f32(imge.texture.width)) / 2,
        rec.y + (rec.height - f32(imge.texture.height)) / 2
      },
      rl.WHITE)
  case .STRETCH:
    rl.DrawTexturePro(
      imge.texture,
      { 0, 0, f32(imge.texture.width), f32(imge.texture.height) },
      rec,
      { 0, 0 },
      0,
      rl.WHITE)
  }
}