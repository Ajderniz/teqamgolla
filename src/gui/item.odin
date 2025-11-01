package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"


@(private)
get_sub_item_under_mouse :: proc(
  item: ^Item,
  mouse_pos: rl.Vector2) -> ^Item
{
  if !is_v2_within_rec(mouse_pos, item.rec)
  {
    return nil
  }
  switch f in item.form
  {
  case TextItem, TextureItem, ButtonItem:
    return item

  case BoxItem:
    for e in f.content
    {
      hovered := get_sub_item_under_mouse(e, mouse_pos)
      if hovered != nil
      {
        return hovered
      }
    }
  }
  return nil
}

configure_item_min_size :: proc(item: ^Item, p_font:rl.Font, p_pad:f32)
{
  font := (item.font != nil) ? item.font^ : p_font
  pad  := (item.pad != nil)  ? item.pad^  : p_pad

  switch form in item.form
  {
  case TextItem:
    glyph_size := rl.Vector2 {
      font.recs[0].width,
      f32(font.baseSize) + math.trunc(f32(font.glyphPadding / 2))
    }
    item.min_size.x=(item.min_size.x<glyph_size.x)? glyph_size.x:item.min_size.x
    item.min_size.y =
      (item.min_size.y<(glyph_size.y*3))? (glyph_size.y*3):item.min_size.y

  case TextureItem:
    og_size := rl.Vector2{ f32(form.texture.width),f32(form.texture.height) }
    item.min_size.x = (item.min_size.x < og_size.x)? og_size.x : item.min_size.x
    item.min_size.y = (item.min_size.y < og_size.y)? og_size.y : item.min_size.y

  case ButtonItem:
    item.min_size = get_text_size(form.label, font)
    if form.icon != nil
    {
      item.min_size.x += f32(form.icon.width) + pad
      icon_height := f32(form.icon.height)
      item.min_size.y =  (item.min_size.y < icon_height) ? icon_height :
                                                           item.min_size.y
    }

  case BoxItem:

    double_pad := pad * 2

    if len(form.content) <= 0
    {
      item.min_size.x =  font.recs[0].width + double_pad
      item.min_size.y =  f32(font.baseSize) + double_pad
      item.min_size.y += (form.header != "") ? cfg.header_height : 0
      return
    }

    min_size: rl.Vector2

    for e in form.content
    {
      configure_item_min_size(e, font, pad)

      this_min_size := e.min_size
      switch f in e.form
      {
      case TextItem, TextureItem, ButtonItem:
        this_min_size.x += (.VERTICAL == form.layout) ? double_pad : pad
        this_min_size.y += (.VERTICAL == form.layout) ? pad : double_pad

      case BoxItem:
        this_min_size.x -= (.VERTICAL == form.layout) ? 0 : pad
        this_min_size.y -= (.VERTICAL == form.layout) ? pad : 0
      }

      if .VERTICAL == form.layout
      {
        min_size.x =  (min_size.x < this_min_size.x)? this_min_size.x:min_size.x
        min_size.y += this_min_size.y
      }
      else
      {
        min_size.x += this_min_size.x
        min_size.y =  (min_size.y < this_min_size.y)? this_min_size.y:min_size.y
      }
    }
    min_size.x += (.VERTICAL == form.layout) ? 0 : pad
    min_size.y += (.VERTICAL == form.layout) ? pad : 0
    min_size.y += (form.header != "") ? cfg.header_height : 0

    item.min_size.x =
      (item.min_size.x < min_size.x) ? min_size.x : item.min_size.x
    item.min_size.y =
      (item.min_size.y < min_size.y) ? min_size.y : item.min_size.y
  }
  if .NONE == item.border_style ||
     .LINE == item.border_style ||
     (.CUSTOM == item.border_style && nil == item.border)
  {
    return
  }

  border: ^ItemBorder
  #partial switch item.border_style
  {
  case .GLOBAL:
    border = &cfg.border
  case .CUSTOM:
    border = item.border
  }
  line_rec := &border.line_rec

  left  := line_rec.custom[.LEFT]
  right := line_rec.custom[.RIGHT]
  top   := line_rec.custom[.TOP]
  bot   := line_rec.custom[.BOT]
  item.min_size.x += (left  != nil) ? left.height  : line_rec.height
  item.min_size.x += (right != nil) ? right.height : line_rec.height
  item.min_size.y += (top   != nil) ? top.height   : line_rec.height
  item.min_size.y += (bot   != nil) ? bot.height   : line_rec.height
}

@(private)
draw_item_background :: proc(
  bg       : ItemBackground,
  rec      : rl.Rectangle
  ) {
  if nil == bg.texture
  {
    rl.DrawRectangleRec(rec, bg.color)
    return
  }

  if .STRETCH == bg.draw_mode
  {
    rl.DrawTexturePro(
      bg.texture^,
      { 0, 0, f32(bg.texture.width), f32(bg.texture.height) },
      rec,
      { 0, 0 },
      0,
      bg.color)
  }
  else
  {
    step  := rl.Vector2 { f32(bg.texture.width), f32(bg.texture.height) }
    limit := rl.Vector2 { rec.x + rec.width, rec.y + rec.height }
    for y := rec.y; y < limit.y; y += step.y
    {
      for x := rec.x; x < limit.x; x += step.x
      {
        diff := rl.Vector2 { limit.x - x, limit.y - y }
        rl.DrawTextureRec(
          bg.texture^,
          {
            0,
            0,
            (diff.x <= step.x) ? diff.x : step.x,
            (diff.y <= step.y) ? diff.y : step.y,
          },
          { x, y },
          bg.color)
      }
    }
  }
}

@(private)
draw_item :: proc(
  item       :  ^Item,
  p_font     :  rl.Font,
  p_pad      :  f32,
  p_fg_color :  rl.Color,
  p_bg       :  ItemBackground,
  box_highlight  := false)
{
  if nil == item
  {
    return
  }
  font     := (item.font     != nil) ? item.font^     : p_font
  pad      := (item.pad      != nil) ? item.pad^      : p_pad
  fg_color := (item.fg_color != nil) ? item.fg_color^ : p_fg_color
  bg       := (item.bg       != nil) ? item.bg^       : p_bg

  border: ^ItemBorder
  #partial switch item.border_style
  {
  case .GLOBAL:
    border = &cfg.border
  case .CUSTOM:
    border = item.border
  }

  border_recs: ItemBorderRectangles
  if border != nil
  {
    line_rec   := &border.line_rec
    corner_rec := &border.corner_rec
    border_recs = {
      line_rec = { default = line_rec.default },
      corner_rec = { default = corner_rec.default }
    }
    for rec, i in line_rec.custom
    {
      if rec != nil
      {
        border_recs.line_rec.custom[i] = rec
      }
    }
    for rec, i in corner_rec.custom
    {
      if rec != nil
      {
        border_recs.corner_rec.custom[i] = rec
      }
    }
  }

  draw_item:
  {
    rec := item.rec
    #partial switch form in item.form
    {
    case TextItem, TextureItem:
      if border != nil
      {
        line_rec := &border_recs.line_rec

        rec.x      += line_rec.custom[.LEFT].height
        rec.y      += line_rec.custom[.RIGHT].height

        rec.width  -= line_rec.custom[.LEFT].height
        rec.width  -= line_rec.custom[.RIGHT].height

        rec.height -= line_rec.custom[.TOP].height
        rec.height -= line_rec.custom[.BOT].height
      }
    }

    switch &form in item.form
    {
    case TextItem:
      draw_text_item(form, rec, font, fg_color)
    case TextureItem:
      draw_texture_item(form, rec)
    case ButtonItem:
      tmp_fg_color := fg_color
      tmp_bg_color := bg.color
      fg_color = (form.hovered) ? tmp_bg_color : tmp_fg_color
      bg.color = (form.hovered) ? tmp_fg_color : tmp_bg_color
      draw_button_item(form, rec, font, fg_color, bg)
      form.hovered = false
    case BoxItem:
      draw_box_item(form, rec, font, pad, fg_color, bg, border, box_highlight)
    }
  }

  draw_border:
  {
    if .NONE == item.border_style
    {
      return
    }

    rec := item.rec
    #partial switch form in item.form
    {
    case BoxItem:
      if form.header != ""
      {
        rec.y      += cfg.header_height
        rec.height -= cfg.header_height
      }
    }

    if nil == border || !rl.IsTextureValid(border.texture)
    {
      rl.DrawRectangleLinesEx(rec, cfg.line_thick, fg_color)
      return
    }

    corner_rec := &border_recs.corner_rec

    draw_lines:
    {
      line_rec := &border_recs.line_rec

      if .STRETCH == border.draw_mode
      {
        rl.DrawTexturePro(
          border.texture,
          line_rec.custom[.TOP]^,
          { rec.x, rec.y, rec.width, line_rec.custom[.TOP].height },
          { 0, 0 },
          0,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          line_rec.custom[.RIGHT]^,
          { 
            rec.x + rec.width,
            rec.y,
            rec.height,
            line_rec.custom[.RIGHT].height
          },
          { 0, 0 },
          90,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          line_rec.custom[.BOT]^,
          { 
            rec.x+rec.width, 
            rec.y+rec.height,
            rec.width,
            line_rec.custom[.BOT].height
          },
          { 0, 0 },
          180,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          line_rec.custom[.LEFT]^,
          {
            rec.x,
            rec.y + rec.height,
            rec.height,
            line_rec.custom[.LEFT].height
          },
          { 0, 0 },
          270,
          fg_color)
      }
      else
      {
        for x := rec.x + corner_rec.custom[.TL].width;
            x <  (rec.x + rec.width - corner_rec.custom[.TR].height);
            x += line_rec.custom[.TOP].width
        {
          rl.DrawTextureRec(
            border.texture,
            line_rec.custom[.TOP]^,
            {x, rec.y},
            fg_color
            )
        }
        for y := rec.y + corner_rec.custom[.TR].width;
            y <  (rec.y + rec.height - corner_rec.custom[.BR].height);
            y += line_rec.custom[.RIGHT].width
        {
          rl.DrawTexturePro(
            border.texture,
            line_rec.custom[.RIGHT]^,
            {
              rec.x+rec.width,
              y,
              line_rec.custom[.RIGHT].width,
              line_rec.custom[.RIGHT].height
            },
            { 0, 0 },
            90,
            fg_color)
        }
        for x := rec.x + (corner_rec.custom[.BL].width * 2);
            x <  (rec.x + rec.width);
            x += line_rec.custom[.BOT].width
        {
          rl.DrawTexturePro(
            border.texture,
            line_rec.custom[.BOT]^,
            { 
              x,
              rec.y + rec.height,
              line_rec.custom[.BOT].width,
              line_rec.custom[.BOT].height },
            { 0, 0 },
            180,
            fg_color)
        }
        for y := rec.y + (corner_rec.custom[.TL].width * 2);
            y <  (rec.y + rec.height);
            y += line_rec.custom[.LEFT].width
        {
          rl.DrawTexturePro(
            border.texture,
            line_rec.custom[.LEFT]^,
            { 
              rec.x,
              y,
              line_rec.custom[.LEFT].width,
              line_rec.custom[.LEFT].height
            },
            { 0, 0 },
            270,
            fg_color)
        }
      }
    }

    draw_corners:
    {
      draw_item_background(
        bg,
        {
          rec.x,
          rec.y,
          corner_rec.custom[.TL].width,
          corner_rec.custom[.TL].height
        })
      rl.DrawTextureRec(
        border.texture,
        corner_rec.custom[.TL]^,
        {rec.x,rec.y},
        fg_color
        )

      draw_item_background(
        bg,
        {
          rec.x + rec.width - corner_rec.custom[.TR].width,
          rec.y,
          corner_rec.custom[.TR].width,
          corner_rec.custom[.TR].height
        })
      rl.DrawTexturePro(
        border.texture,
        corner_rec.custom[.TR]^,
        { 
          rec.x + rec.width,
          rec.y, 
          corner_rec.custom[.TR].width, 
          corner_rec.custom[.TR].height },
        { 0, 0 },
        90,
        fg_color)

      draw_item_background(
        bg,
        {
          rec.x + rec.width - corner_rec.custom[.BR].width,
          rec.y + rec.height - corner_rec.custom[.BR].height,
          corner_rec.custom[.BR].width,
          corner_rec.custom[.BR].height
        })
      rl.DrawTexturePro(
        border.texture,
        corner_rec.custom[.BR]^,
        {
          rec.x + rec.width,
          rec.y + rec.height,
          corner_rec.custom[.BR].width,
          corner_rec.custom[.BR].height
        },
        { 0, 0 },
        180,
        fg_color)

      draw_item_background(
        bg,
        {
          rec.x,
          rec.y + rec.height - corner_rec.custom[.BL].height,
          corner_rec.custom[.BL].width,
          corner_rec.custom[.BL].height
        })
      rl.DrawTexturePro(
        border.texture,
        corner_rec.custom[.BL]^,
        {
          rec.x,
          rec.y + rec.height,
          corner_rec.custom[.BL].width,
          corner_rec.custom[.BL].height
        },
        { 0, 0 },
        270,
        fg_color)
    }
  }
}
