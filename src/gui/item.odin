package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

ItemBackground :: struct {
  color     : rl.Color,
  texture   : ^rl.Texture,
  draw_mode : enum { STRETCH, TILE }
}

ItemBorderRectangles :: struct {
  corner_rec : struct {
    using default : rl.Rectangle,
    tl            : ^rl.Rectangle,
    tr            : ^rl.Rectangle,
    bl            : ^rl.Rectangle,
    br            : ^rl.Rectangle,
  },
  line_rec   : struct {
    using default : rl.Rectangle,
    top           : ^rl.Rectangle,
    bot           : ^rl.Rectangle,
    left          : ^rl.Rectangle,
    right         : ^rl.Rectangle,
  }
}

ItemBorder :: struct {
  texture    : rl.Texture,
  draw_mode  : enum { STRETCH, TILE },
  using recs : ItemBorderRectangles
}

Item :: struct {
  data            : union { TextItem, ImageItem, ButtonItem , BoxItem, },

  using rec     : rl.Rectangle,
  min_size      : rl.Vector2,
  max_size      : rl.Vector2,
  non_resizable : struct { x, y: bool },

  font          : ^rl.Font,
  pad           : ^f32,
  fg_color      : ^rl.Color,
  bg            : ^ItemBackground,

  border_style  : enum { NONE, LINE, GLOBAL, CUSTOM },
  border        : ^ItemBorder
}

@(private)
get_item_under_mouse :: proc(
  item: ^Item,
  mouse_pos: rl.Vector2) -> ^Item
{
  if !is_v2_within_rec(mouse_pos, item.rec)
  {
    return nil
  }
  switch d in item.data
  {
  case TextItem, ImageItem, ButtonItem:
    return item

  case BoxItem:
    for e in d.content
    {
      hovered := get_item_under_mouse(e, mouse_pos)
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

  switch data in item.data
  {
  case TextItem:
    glyph_size := rl.Vector2 {
      font.recs[0].width,
      f32(font.baseSize) + math.trunc(f32(font.glyphPadding / 2))
    }
    item.min_size.x=(item.min_size.x<glyph_size.x)? glyph_size.x:item.min_size.x
    item.min_size.y =
      (item.min_size.y<(glyph_size.y*3))? (glyph_size.y*3):item.min_size.y

  case ImageItem:
    og_size := rl.Vector2{ f32(data.texture.width),f32(data.texture.height) }
    item.min_size.x = (item.min_size.x < og_size.x)? og_size.x : item.min_size.x
    item.min_size.y = (item.min_size.y < og_size.y)? og_size.y : item.min_size.y

  case ButtonItem:
    item.min_size = get_text_size(data.label, font)

  case BoxItem:

    pad := (item.pad != nil) ? item.pad^ : p_pad
    double_pad := pad * 2

    if len(data.content) <= 0
    {
      item.min_size.x =  font.recs[0].width + double_pad
      item.min_size.y =  f32(font.baseSize) + double_pad
      item.min_size.y += (data.header != "") ? g_header_height : 0
      return
    }

    min_size: rl.Vector2

    for e in data.content
    {
      configure_item_min_size(e, font, pad)

      this_min_size := e.min_size
      switch d in e.data
      {
      case TextItem, ImageItem, ButtonItem:
        this_min_size.x += (.VERTICAL == data.layout) ? double_pad : pad
        this_min_size.y += (.VERTICAL == data.layout) ? pad : double_pad

      case BoxItem:
        this_min_size.x -= (.VERTICAL == data.layout) ? 0 : pad
        this_min_size.y -= (.VERTICAL == data.layout) ? pad : 0
      }

      if .VERTICAL == data.layout
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
    min_size.x += (.VERTICAL == data.layout) ? 0 : pad
    min_size.y += (.VERTICAL == data.layout) ? pad : 0
    min_size.y += (data.header != "") ? g_header_height : 0

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
    border = &g_border
  case .CUSTOM:
    border = item.border
  }
  line_rec := &border.line_rec

  item.min_size.x+=(line_rec.left!=nil)? line_rec.left.height:line_rec.height
  item.min_size.x += (line_rec.right != nil) ? line_rec.right.height :
                                                  line_rec.height
  item.min_size.y += (line_rec.top!=nil)? line_rec.top.height:line_rec.height
  item.min_size.y += (line_rec.bot != nil) ? line_rec.bot.height :
                                                   line_rec.height
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
    border = &g_border
  case .CUSTOM:
    border = item.border
  }

  border_recs: ItemBorderRectangles
  if border != nil
  {
    line_rec   := &border.line_rec
    corner_rec := &border.corner_rec
    border_recs = {
      line_rec = {
        default = line_rec.default,
        top     = (line_rec.top   != nil) ? line_rec.top   : &line_rec.default,
        bot     = (line_rec.bot   != nil) ? line_rec.bot   : &line_rec.default,
        left    = (line_rec.left  != nil) ? line_rec.left  : &line_rec.default,
        right   = (line_rec.right != nil) ? line_rec.right : &line_rec.default,
      },
      corner_rec = {
        default = corner_rec.default,
        tl      = (corner_rec.tl != nil) ? corner_rec.tl : &corner_rec.default,
        tr      = (corner_rec.tr != nil) ? corner_rec.tr : &corner_rec.default,
        bl      = (corner_rec.bl != nil) ? corner_rec.bl : &corner_rec.default,
        br      = (corner_rec.br != nil) ? corner_rec.br : &corner_rec.default,
      }
    }
  }

  draw_item:
  {
    rec := item.rec
    #partial switch data in item.data
    {
    case TextItem, ImageItem:
      if border != nil
      {
        line_rec := &border_recs.line_rec

        rec.x      += line_rec.left.height
        rec.y      += line_rec.right.height

        rec.width  -= line_rec.left.height
        rec.width  -= line_rec.right.height

        rec.height -= line_rec.top.height
        rec.height -= line_rec.bot.height
      }
    }

    switch &data in item.data
    {
    case TextItem:
      draw_text_item(data, rec, font, fg_color)
    case ImageItem:
      draw_image_item(data, rec)
    case ButtonItem:
      tmp_fg_color := fg_color
      tmp_bg_color := bg.color
      fg_color = (data.highlight) ? tmp_bg_color : tmp_fg_color
      bg.color = (data.highlight) ? tmp_fg_color : tmp_bg_color
      draw_button_item(data, rec, font, fg_color, bg)
      data.highlight = false
    case BoxItem:
      draw_box_item(data, rec, font, pad, fg_color, bg, border, box_highlight)
    }
  }

  draw_border:
  {
    if .NONE == item.border_style
    {
      return
    }

    rec := item.rec
    #partial switch data in item.data
    {
    case BoxItem:
      if data.header != ""
      {
        rec.y      += g_header_height
        rec.height -= g_header_height
      }
    }

    if nil == border || !rl.IsTextureValid(border.texture)
    {
      rl.DrawRectangleLinesEx(rec, g_line_thick, fg_color)
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
          line_rec.top^,
          { rec.x, rec.y, rec.width, line_rec.top.height },
          { 0, 0 },
          0,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          line_rec.right^,
          { rec.x + rec.width, rec.y, rec.height, line_rec.right.height },
          { 0, 0 },
          90,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          line_rec.bot^,
          { rec.x+rec.width, rec.y+rec.height, rec.width, line_rec.bot.height },
          { 0, 0 },
          180,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          line_rec.left^,
          { rec.x, rec.y + rec.height, rec.height, line_rec.left.height },
          { 0, 0 },
          270,
          fg_color)
      }
      else
      {
        for x := rec.x + corner_rec.tl.width;
            x <  (rec.x + rec.width - corner_rec.tr.height);
            x += line_rec.top.width
        {
          rl.DrawTextureRec(border.texture, line_rec.top^, {x, rec.y}, fg_color)
        }
        for y := rec.y + corner_rec.tr.width;
            y <  (rec.y + rec.height - corner_rec.br.height);
            y += line_rec.right.width
        {
          rl.DrawTexturePro(
            border.texture,
            line_rec.right^,
            { rec.x+rec.width, y, line_rec.right.width, line_rec.right.height },
            { 0, 0 },
            90,
            fg_color)
        }
        for x := rec.x + (corner_rec.bl.width * 2);
            x <  (rec.x + rec.width);
            x += line_rec.bot.width
        {
          rl.DrawTexturePro(
            border.texture,
            line_rec.bot^,
            { x, rec.y + rec.height, line_rec.bot.width, line_rec.bot.height },
            { 0, 0 },
            180,
            fg_color)
        }
        for y := rec.y + (corner_rec.tl.width * 2);
            y <  (rec.y + rec.height);
            y += line_rec.left.width
        {
          rl.DrawTexturePro(
            border.texture,
            line_rec.left^,
            { rec.x, y, line_rec.left.width, line_rec.left.height },
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
        { rec.x, rec.y, corner_rec.tl.width, corner_rec.tl.height })
      rl.DrawTextureRec(border.texture, corner_rec.tl^, {rec.x,rec.y}, fg_color)

      draw_item_background(
        bg,
        {
          rec.x + rec.width - corner_rec.tr.width,
          rec.y,
          corner_rec.tr.width,
          corner_rec.tr.height
        })
      rl.DrawTexturePro(
        border.texture,
        corner_rec.tr^,
        { rec.x + rec.width, rec.y, corner_rec.tr.width, corner_rec.tr.height },
        { 0, 0 },
        90,
        fg_color)

      draw_item_background(
        bg,
        {
          rec.x + rec.width - corner_rec.br.width,
          rec.y + rec.height - corner_rec.br.height,
          corner_rec.br.width,
          corner_rec.br.height
        })
      rl.DrawTexturePro(
        border.texture,
        corner_rec.br^,
        {
          rec.x + rec.width,
          rec.y + rec.height,
          corner_rec.br.width,
          corner_rec.br.height
        },
        { 0, 0 },
        180,
        fg_color)

      draw_item_background(
        bg,
        {
          rec.x,
          rec.y + rec.height - corner_rec.bl.height,
          corner_rec.bl.width,
          corner_rec.bl.height
        })
      rl.DrawTexturePro(
        border.texture,
        corner_rec.bl^,
        {
          rec.x,
          rec.y + rec.height,
          corner_rec.bl.width,
          corner_rec.bl.height
        },
        { 0, 0 },
        270,
        fg_color)
    }
  }
}
