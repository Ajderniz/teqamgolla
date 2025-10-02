package gui

import str "core:strings"

import rl  "vendor:raylib"

ButtonItem :: struct {
  label     : string,
  //icon  : ^rl.Texture,
  highlight : bool
}

@(private)
get_button_item_label_size :: proc(buti: ButtonItem, font: rl.Font) -> rl.Vector2
{
  label_cstring := str.clone_to_cstring(buti.label)
  defer delete(label_cstring)
  return rl.MeasureTextEx(font, label_cstring, f32(font.baseSize), 0)
}

@(private)
draw_button_item :: proc(
  buti     : ButtonItem,
  rec       : rl.Rectangle,
  font      : rl.Font,
  fg_color  : rl.Color,
  bg        : ItemBackground,
  ) {
  draw_item_background(
    bg,
    rec)

  if buti.label != ""
  {
    size := get_button_item_label_size(buti, font)
    draw_text_label(
      buti.label,
      {rec.x + ((rec.width - size.x) / 2), rec.y + ((rec.height - size.y) / 2)},
      rec.width,
      font,
      fg_color
      )
  }
}