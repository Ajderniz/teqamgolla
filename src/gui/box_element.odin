package gui

import    "core:log"
import    "core:math"
import    "core:sort"

import rl "vendor:raylib"

BoxElement :: struct {
  header   : string,
  content  : []^Element,
  layout   : enum{ VERTICAL, HORIZONTAL },
}

@(private)
update_box_element_content_sizes :: proc(
  box      : ^BoxElement,
  size     : rl.Vector2,
  p_font   : rl.Font,
  p_pad    : f32,
  ) {
  IndexSizePair :: struct { index: int, size: f32 }
  isp_list: [dynamic]IndexSizePair
  defer delete(isp_list)

  double_pad := p_pad * 2

  box_count: int

  collect_info:
  {
    for e, i in box.content
    {
      size := (.VERTICAL == box.layout) ? e.min_size.y : e.min_size.x
      switch d in e.data
      {
      case TextElement, ImageElement:
        size += p_pad
      case BoxElement:
        size -= p_pad
        box_count += 1
      }
      append(&isp_list, IndexSizePair{i, size})
    }
    sort.quick_sort_proc(
      isp_list[:],
      proc(left, right: IndexSizePair) -> int
      {
        if left.size < right.size
        {
          return 1
        }
        else if right.size < left.size
        {
          return -1
        }
        else
        {
          return 0
        }
      })
  }

  remaining_elements := len(box.content)

  available_space: f32
  if .VERTICAL == box.layout
  {
    available_space = size.y
    available_space -= (box.header != "") ? g_header_height : 0
  }
  else
  {
    available_space = size.x
  }
  available_space -= 
    (p_pad * (f32(remaining_elements) + 1)) - (double_pad * f32(box_count))

  constrained_count: int

  distribute_space:
  for isp in isp_list
  {
    e := box.content[isp.index]

    if e.non_resizable.x && e.non_resizable.y
    {
      e.width  = e.min_size.x
      e.height = e.min_size.y
      available_space -= (.VERTICAL == box.layout) ? e.height : e.width
      remaining_elements -= 1
      constrained_count += 1

      continue
    }

    is_constrained: bool

    share := math.trunc(available_space / f32(remaining_elements))

    update_width:
    {
      if e.non_resizable.x
      {
        e.width = e.min_size.x
        is_constrained = (.HORIZONTAL == box.layout) ? true : false
        break update_width
      }

      if .VERTICAL == box.layout
      {
        e.width =  size.x
      }
      else
      {
        e.width = (share < e.min_size.x) ? e.min_size.x : share
      }

      if e.min_size.x <= e.max_size.x
      {
        e.width = (e.max_size.x < e.width) ? e.max_size.x : e.width
        is_constrained = true
      }

      #partial switch d in e.data
      {
      case TextElement, ImageElement:
        e.width  -= (.VERTICAL == box.layout) ? double_pad : 0
      }
    }

    update_height:
    {
      if e.non_resizable.y
      {
        e.height = e.min_size.y
        is_constrained = (.VERTICAL == box.layout) ? true : false
        break update_height
      }

      if .VERTICAL == box.layout
      {
        e.height = (share < e.min_size.y) ? e.min_size.y : share
      }
      else
      {
        e.height = size.y
        e.height -= (box.header != "") ? g_header_height : 0
      }

      if e.min_size.y <= e.max_size.y
      {
        e.height = (e.max_size.y < e.height) ? e.max_size.y : e.height
        is_constrained = true
      }

      #partial switch d in e.data
      {
      case TextElement, ImageElement:
        e.height -= (.VERTICAL == box.layout) ? 0 : double_pad
      }
    }

    constrained_count += (is_constrained) ? 1 : 0

    available_space -= (.VERTICAL == box.layout) ? e.height : e.width
    remaining_elements -= 1
  }

  adjust_for_unused_space:
  if 0 < available_space
  {
    unconstrained_count := len(box.content) - constrained_count
    if unconstrained_count <= 0
    {
      break adjust_for_unused_space
    }

    share := math.trunc(available_space / f32(unconstrained_count))
    for e, i in box.content
    {
      if e.min_size.x <= e.max_size.x || e.min_size.y <= e.max_size.y
      {
        continue
      }
      if .VERTICAL == box.layout
      {
        e.height += (!e.non_resizable.y) ? share : e.height
      }
      else
      {
        e.width  += (!e.non_resizable.x) ? share : e.width
      }
    }
  }

  update_contents:
  for e in box.content
  {
    e_size := rl.Vector2{ e.width, e.height }
    #partial switch e.border_style
    {
    case .GLOBAL:
      e_size.x -= g_border.line_rec.height * 2
      e_size.y -= g_border.line_rec.height * 2
    case .CUSTOM:
      if nil == e.border
      {
        break
      }
      e_size.x -= e.border.line_rec.height * 2
      e_size.y -= e.border.line_rec.height * 2
    }

    #partial switch &d in e.data
    {
    case TextElement:
      update_text_element_buffer(&d, e_size, ((e.font != nil) ? e.font^:p_font))
    case BoxElement:
      update_box_element_content_sizes(
        &d,
        e_size,
        ((e.font != nil) ? e.font^ : p_font),
        ((e.pad  != nil) ? e.pad^  : p_pad))
    }
  }
}

@(private)
draw_box_element :: proc(
  box        :  BoxElement,
  rec        :  rl.Rectangle,
  p_font     :  rl.Font,
  p_pad      :  f32,
  p_fg_color :  rl.Color,
  p_bg       :  ElementBackground,
  border     : ^ElementBorder,
  highlight  := false,
  ) {

  double_pad := p_pad * 2

  // HEADER ====================================================================

  header_offset: f32
  if box.header != ""
  {
    header_offset = g_header_height
    header_rec := rec
    header_rec.height = header_offset

    header_bg_color := (highlight) ? p_fg_color : p_bg.color
    header_fg_color := (highlight) ? p_bg.color : p_fg_color

    rl.DrawRectangleRec(header_rec, header_bg_color)
    rl.DrawRectangleLinesEx(header_rec, g_line_thick, g_fg_color)

    header_rec.x += p_pad
    header_rec.y += math.trunc(p_pad * 0.25)
    header_rec.width -= double_pad
    draw_text_label(
      box.header,
      {header_rec.x, header_rec.y},
      header_rec.width,
      g_font,
      header_fg_color)
  }

  // CONTENT ===================================================================

  content_rec        := rec
  content_rec.y      += header_offset
  content_rec.height -= header_offset

  draw_element_background(p_bg, content_rec)

  if border != nil
  {
    content_rec.x += border.line_rec.height
    content_rec.y += border.line_rec.height
  }

  content_offset: f32
  for e, i in box.content
  {
    e.x =  content_rec.x
    e.x += (.VERTICAL == box.layout) ? 0 : content_offset

    e.y =  content_rec.y
    e.y += (.VERTICAL == box.layout) ? content_offset : 0

    switch d in e.data
    {
    case TextElement, ImageElement:
      must_add_pad := false
      if 0 == i
      {
        must_add_pad = true
      }
      else if 1 <= i
      {
        #partial switch pd in box.content[i-1].data
        {
        case TextElement, ImageElement:
          must_add_pad = true
        }
      }
      if .VERTICAL == box.layout
      {
        e.x += p_pad
        e.y += (must_add_pad) ? p_pad : 0
      }
      else
      {
        e.x += (must_add_pad) ? p_pad : 0
        e.y += p_pad
      }
      content_offset += (must_add_pad) ? p_pad : 0

    case BoxElement:
      if 1 <= i
      {
        #partial switch d in box.content[i-1].data
        {
        case BoxElement:
          e.y -= (.VERTICAL == box.layout) ? p_pad : 0
          e.x -= (.VERTICAL == box.layout) ? 0   : p_pad
        }
      }
    }
    content_offset += (.VERTICAL == box.layout) ? e.height : e.width

    draw_element(e, p_font, p_pad, p_fg_color, p_bg)
  }
}
