package gui

import    "core:math"

import rl "vendor:raylib"

Element :: struct {
  data          : union { TextElement, ImageElement, BoxElement },

  using rec     : rl.Rectangle,
  min_size      : rl.Vector2,
  max_size      : rl.Vector2,
  non_resizable : struct { x, y: bool },

  font          : ^rl.Font,
  pad           : ^f32,
  fg_color      : ^rl.Color,
  bg_color      : ^rl.Color,
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

@(private)
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
}

/*
IS THIS EVEN NECESSARY?

@(private)
configure_element_max_size :: proc(
  element: ^Element,
  max_size: rl.Vector2,
  p_pad: f32)
{
  if 0 <= element.max_size.x || max_size.x < element.max_size.x
  {
    element.max_size.x = max_size.x
  }
  if 0 <= element.max_size.y || max_size.y < element.max_size.y
  {
    element.max_size.y = max_size.y
  }
  #partial switch data in element.data
  {
  case BoxElement:
    for e in data.content
    {
      configure_element_max_size(e, e.max_size, (data.pad!=nil)?data.pad^:p_pad)
    }
  }
}
*/