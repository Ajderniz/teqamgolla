package gui

import rl  "vendor:raylib"

@(private)
draw_button_item :: proc(
  buti     : ButtonItem,
  rec      : rl.Rectangle,
  font     : rl.Font,
  fg_color : rl.Color,
  bg       : ItemBackground,
  ) {
  draw_item_background(
    bg,
    rec)

  bi: ButtonItem

  if buti.label != ""
  {
    size := get_text_size(buti.label, font)
    draw_text_label(
      buti.label,
      {rec.x + ((rec.width - size.x) / 2), rec.y + ((rec.height - size.y) / 2)},
      rec.width,
      font,
      fg_color
      )
  }
}