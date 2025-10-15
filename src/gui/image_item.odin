package gui

import rl "vendor:raylib"

ImageItem :: struct {
  texture : rl.Texture,
  resize  : enum { NONE, CENTER, STRETCH },
  is_rtxr : bool,
}

@(private)
draw_image_item :: proc(imgi: ImageItem, rec: rl.Rectangle)
{
  src_rec : rl.Rectangle = { 
    0,
    0,
    f32(imgi.texture.width),
    f32(imgi.texture.height)
  }
  src_rec.height = (imgi.is_rtxr) ? -src_rec.height : src_rec.height

  switch imgi.resize
  {
  case .NONE:
    rl.DrawTexturePro(
      imgi.texture, 
      src_rec, 
      {rec.x, rec.y, f32(imgi.texture.width), f32(imgi.texture.height)},
      {0,0},
      0,
      rl.WHITE
      )
  case .CENTER:
    rl.DrawTexturePro(
      imgi.texture,
      src_rec,
      {
        rec.x + (rec.width - f32(imgi.texture.width)) / 2,
        rec.y + (rec.height - f32(imgi.texture.height)) / 2,
        f32(imgi.texture.width),
        f32(imgi.texture.height)
      },
      {0,0},
      0,
      rl.WHITE)
  case .STRETCH:
    rl.DrawTexturePro(
      imgi.texture,
      src_rec,
      rec,
      {0,0},
      0,
      rl.WHITE)
  }
}