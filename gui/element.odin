package gui

import rl "vendor:raylib"

Element :: struct {
  data          : union { TextElement, ImageElement, BoxElement },

  using rec     : rl.Rectangle,
  min_size      : rl.Vector2,
  max_size      : rl.Vector2,
  non_resizable : bool
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
