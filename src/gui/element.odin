package gui

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

ElementBackground :: struct {
  color     : rl.Color,
  texture   : ^rl.Texture,
  draw_mode : enum { STRETCH, TILE }
}

ElementBorder :: struct {
    texture      : rl.Texture,
    draw_mode    : enum { STRETCH, TILE },
    corner_rec   : rl.Rectangle,
    line_rec     : rl.Rectangle
}


Element :: struct {
  data            : union { TextElement, ImageElement, BoxElement },

  using rec     : rl.Rectangle,
  min_size      : rl.Vector2,
  max_size      : rl.Vector2,
  non_resizable : struct { x, y: bool },

  font          : ^rl.Font,
  pad           : ^f32,
  fg_color      : ^rl.Color,
  bg            : ^ElementBackground,

  border_style  : enum { NONE, LINE, GLOBAL, CUSTOM },
  border        : ^ElementBorder
}

@(private)
get_element_under_mouse :: proc(
  element: ^Element,
  mouse_pos: rl.Vector2) -> ^Element
{
  if !is_v2_within_rec(mouse_pos, element.rec)
  {
    return nil
  }
  switch d in element.data
  {
  case TextElement, ImageElement:
    return element
  case BoxElement:
    for e in d.content
    {
      hovered := get_element_under_mouse(e, mouse_pos)
      if hovered != nil
      {
        return hovered
      }
    }
  }
  return nil
}

configure_element_min_size :: proc(element: ^Element, p_font:rl.Font, p_pad:f32)
{
  font := (element.font != nil) ? element.font^ : p_font

  switch data in element.data
  {
  case TextElement:
    glyph_size := rl.Vector2 {
      font.recs[0].width,
      f32(font.baseSize) + math.trunc(f32(font.glyphPadding / 2)) }
    element.min_size.x =
      (element.min_size.x < glyph_size.x) ? glyph_size.x : element.min_size.x
    element.min_size.y =
      (element.min_size.y<(glyph_size.y*3))? (glyph_size.y*3):element.min_size.y

  case ImageElement:
    og_size := rl.Vector2{ f32(data.texture.width),f32(data.texture.height) }
    element.min_size.x =
      (element.min_size.x < og_size.x) ? og_size.x : element.min_size.x
    element.min_size.y =
      (element.min_size.y < og_size.y) ? og_size.y : element.min_size.y

  case BoxElement:

    pad := (element.pad != nil) ? element.pad^ : p_pad
    double_pad := pad * 2

    if len(data.content) <= 0
    {
      element.min_size.x =  font.recs[0].width + double_pad
      element.min_size.y =  f32(font.baseSize) + double_pad
      element.min_size.y += (data.header != "") ? g_header_height : 0
      return
    }

    min_size: rl.Vector2

    for e in data.content
    {
      configure_element_min_size(e, font, pad)

      this_min_size := e.min_size
      switch d in e.data
      {
      case TextElement, ImageElement:
        this_min_size.x += (.VERTICAL == data.layout) ? double_pad : pad
        this_min_size.y += (.VERTICAL == data.layout) ? pad : double_pad

      case BoxElement:
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

    element.min_size.x =
      (element.min_size.x < min_size.x) ? min_size.x : element.min_size.x
    element.min_size.y =
      (element.min_size.y < min_size.y) ? min_size.y : element.min_size.y
  }
  if .NONE == element.border_style ||
     .LINE == element.border_style ||
     (.CUSTOM == element.border_style && nil == element.border)
  {
    return
  }
  #partial switch element.border_style
  {
  case .GLOBAL:
    element.min_size += g_border.line_rec.height * 2
  case .CUSTOM:
    element.min_size += element.border.line_rec.height * 2
  }
}

@(private)
draw_element_background :: proc(
  bg       : ElementBackground,
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
draw_element :: proc(
  element    :  ^Element,
  p_font     :  rl.Font,
  p_pad      :  f32,
  p_fg_color :  rl.Color,
  p_bg       :  ElementBackground,
  highlight  := false)
{
  if nil == element
  {
    return
  }
  font     := (element.font     != nil) ? element.font^     : p_font
  pad      := (element.pad      != nil) ? element.pad^      : p_pad
  fg_color := (element.fg_color != nil) ? element.fg_color^ : p_fg_color
  bg       := (element.bg       != nil) ? element.bg^       : p_bg

  border: ^ElementBorder
  #partial switch element.border_style
  {
  case .GLOBAL:
    border = &g_border
  case .CUSTOM:
    border = element.border
  }

  draw_element:
  {
    rec := element.rec
    #partial switch data in element.data
    {
    case TextElement, ImageElement:
      if border != nil
      {
        rec.x      += border.line_rec.height
        rec.y      += border.line_rec.height
        rec.width  -= border.line_rec.height * 2
        rec.height -= border.line_rec.height * 2
      }
    }

    switch data in element.data
    {
    case TextElement:
      draw_text_element(data, rec, font, fg_color)
    case ImageElement:
      draw_image_element(data, rec)
    case BoxElement:
      draw_box_element(data, rec, font, pad, fg_color, bg, border, highlight)
    }
  }

  draw_border:
  {
    if .NONE == element.border_style
    {
      return
    }

    rec := element.rec
    #partial switch data in element.data
    {
    case BoxElement:
      if data.header != ""
      {
        rec.y      += g_header_height
        rec.height -= g_header_height
      }
    }

    if nil == border
    {
      rl.DrawRectangleLinesEx(rec, g_line_thick, fg_color)
      return
    }

    draw_lines:
    {
      if .STRETCH == border.draw_mode
      {
        rl.DrawTexturePro(
          border.texture,
          border.line_rec,
          { rec.x, rec.y, rec.width, border.line_rec.height },
          { 0, 0 },
          0,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          border.line_rec,
          { rec.x + rec.width, rec.y, rec.height, border.line_rec.height },
          { 0, 0 },
          90,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          border.line_rec,
          { rec.x+rec.width, rec.y+rec.height,rec.width,border.line_rec.height},
          { 0, 0 },
          180,
          fg_color)
        rl.DrawTexturePro(
          border.texture,
          border.line_rec,
          { rec.x, rec.y + rec.height, rec.height, border.line_rec.height },
          { 0, 0 },
          270,
          fg_color)
      }
      else
      {
        for x := rec.x + border.corner_rec.width;
            x <  (rec.x + rec.width - border.corner_rec.width);
            x += border.line_rec.width
        {
          rl.DrawTextureRec(border.texture, border.line_rec, {x,rec.y},fg_color)
        }
        for y := rec.y + border.corner_rec.width;
            y <  (rec.y + rec.height - border.corner_rec.width);
            y += border.line_rec.width
        {
          rl.DrawTexturePro(
            border.texture,
            border.line_rec,
            { rec.x+rec.width, y, border.line_rec.width,border.line_rec.height},
            { 0, 0 },
            90,
            fg_color)
        }
        for x := rec.x + (border.corner_rec.width * 2);
            x <  (rec.x + rec.width);
            x += border.line_rec.width
        {
          rl.DrawTexturePro(
            border.texture,
            border.line_rec,
            { x, rec.y+rec.height,border.line_rec.width,border.line_rec.height},
            { 0, 0 },
            180,
            fg_color)
        }
        for y := rec.y + (border.corner_rec.width * 2);
            y <  (rec.y + rec.height);
            y += border.line_rec.width
        {
          rl.DrawTexturePro(
            border.texture,
            border.line_rec,
            { rec.x, y, border.line_rec.width, border.line_rec.height },
            { 0, 0 },
            270,
            fg_color)
        }
      }
    }
    draw_corners:
    {
      draw_element_background(
        bg,
        { rec.x, rec.y, border.corner_rec.width, border.corner_rec.height })
      rl.DrawTextureRec(border.texture,border.corner_rec,{rec.x,rec.y},fg_color)

      draw_element_background(
        bg,
        {
          rec.x + rec.width - border.corner_rec.width,
          rec.y,
          border.corner_rec.width,
          border.corner_rec.height
        })
      rl.DrawTexturePro(
        border.texture,
        border.corner_rec,
        {
          rec.x + rec.width,
          rec.y,
          border.corner_rec.width,
          border.corner_rec.height
        },
        { 0, 0 },
        90,
        fg_color)

      draw_element_background(
        bg,
        {
          rec.x + rec.width - border.corner_rec.width,
          rec.y + rec.height - border.corner_rec.height,
          border.corner_rec.width,
          border.corner_rec.height
        })
      rl.DrawTexturePro(
        border.texture,
        border.corner_rec,
        {
          rec.x + rec.width,
          rec.y + rec.height,
          border.corner_rec.width,
          border.corner_rec.height
        },
        { 0, 0 },
        180,
        fg_color)

      draw_element_background(
        bg,
        {
          rec.x,
          rec.y + rec.height - border.corner_rec.height,
          border.corner_rec.width,
          border.corner_rec.height
        })
      rl.DrawTexturePro(
        border.texture,
        border.corner_rec,
        {
          rec.x,
          rec.y + rec.height,
          border.corner_rec.width,
          border.corner_rec.height
        },
        { 0, 0 },
        270,
        fg_color)
    }
  }
}
