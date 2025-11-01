package gui

import rl "vendor:raylib"

@(private)
draw_texture_item :: proc(txri: TextureItem, rec: rl.Rectangle)
{
  src_rec : rl.Rectangle = { 
    0,
    0,
    f32(txri.texture.width),
    f32(txri.texture.height)
  }
  src_rec.height = (.IS_FRAMEBUFFER in txri.options) ? -src_rec.height : 
                                                       src_rec.height

  switch txri.resize
  {
  case .NONE:
    rl.DrawTexturePro(
      txri.texture, 
      src_rec, 
      {rec.x, rec.y, f32(txri.texture.width), f32(txri.texture.height)},
      {0,0},
      0,
      rl.WHITE
      )
  case .CENTER:
    rl.DrawTexturePro(
      txri.texture,
      src_rec,
      {
        rec.x + (rec.width - f32(txri.texture.width)) / 2,
        rec.y + (rec.height - f32(txri.texture.height)) / 2,
        f32(txri.texture.width),
        f32(txri.texture.height)
      },
      {0,0},
      0,
      rl.WHITE)
  case .STRETCH:
    rl.DrawTexturePro(
      txri.texture,
      src_rec,
      rec,
      {0,0},
      0,
      rl.WHITE)
  }
}