package gui

import rl "vendor:raylib"

ImageItem :: struct {
  texture : rl.Texture,
  resize  : enum { NONE, CENTER, STRETCH },
}

@(private)
draw_image_item :: proc(imgi: ImageItem, rec: rl.Rectangle)
{
  switch imgi.resize
  {
  case .NONE:
    rl.DrawTextureV(imgi.texture, {rec.x, rec.y}, rl.WHITE)
  case .CENTER:
    rl.DrawTextureV(
      imgi.texture,
      {
        rec.x + (rec.width - f32(imgi.texture.width)) / 2,
        rec.y + (rec.height - f32(imgi.texture.height)) / 2
      },
      rl.WHITE)
  case .STRETCH:
    rl.DrawTexturePro(
      imgi.texture,
      { 0, 0, f32(imgi.texture.width), f32(imgi.texture.height) },
      rec,
      { 0, 0 },
      0,
      rl.WHITE)
  }
}