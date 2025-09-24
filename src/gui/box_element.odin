package gui

import    "core:log"
import    "core:math"
import    "core:sort"

import rl "vendor:raylib"

BoxElement :: struct {
  header   : string,
  content  : []^Element,
  layout   : enum{ VERTICAL, HORIZONTAL },

  font     : ^rl.Font,
  pad      : ^f32,
  fg_color : ^rl.Color,
  bg_color : ^rl.Color,
}

@(private)
configure_box_element_size :: proc(parent: ^Element)
{
  #partial switch d in parent.data
  {
  case TextElement, ImageElement:
    return
  }
  box := parent.data.(BoxElement)

  min_size: rl.Vector2

  pad  := (box.pad  != nil) ? box.pad^  : g_pad
  font := (box.font != nil) ? box.font^ : g_font

  double_pad  := pad * 2
  glyph_width  := f32(font.recs[0].width)
  glyph_height := f32(font.baseSize + (font.glyphPadding / 2))

  if len(box.content) <= 0 {
    bare_min: rl.Vector2

    bare_min.x = glyph_width + double_pad

    bare_min.y =  glyph_height + double_pad
    bare_min.y += (box.header != "") ? g_header_height : 0

    parent.min_size = bare_min
    return
  }

  for e, i in box.content
  {
    switch d in e.data
    {
    case TextElement:
      e.min_size.x = (e.min_size.x < glyph_width)  ? glyph_width  : e.min_size.x
      e.min_size.y=(e.min_size.y<(glyph_height*3))?(glyph_height*3):e.min_size.y

    case ImageElement:
      og_size: rl.Vector2 = { f32(d.texture.width), f32(d.texture.height) }
      e.min_size.x = (e.min_size.x < og_size.x) ? og_size.x : e.min_size.x
      e.min_size.y = (e.min_size.y < og_size.y) ? og_size.y : e.min_size.y

    case BoxElement:
      configure_box_element_size(e)
    }

    this_min_size := e.min_size
    switch d in e.data
    {
    case TextElement, ImageElement:
      this_min_size.x += (.VERTICAL == box.layout) ? double_pad : pad
      this_min_size.y += (.VERTICAL == box.layout) ? pad        : double_pad

    case BoxElement:
      this_min_size.x -= (.VERTICAL == box.layout) ? 0   : pad
      this_min_size.y -= (.VERTICAL == box.layout) ? pad : 0
    }

    if .VERTICAL == box.layout
    {
      min_size.x=(min_size.x < this_min_size.x)?this_min_size.x:min_size.x
      min_size.y += this_min_size.y
    }
    else
    {
      min_size.x += this_min_size.x
      min_size.y=(min_size.y < this_min_size.y)?this_min_size.y:min_size.y
    }
  }
  min_size.x += (.VERTICAL == box.layout) ? 0   : pad
  min_size.y += (.VERTICAL == box.layout) ? pad : 0
  min_size.y += (box.header != "") ? g_header_height : 0
  parent.min_size.x=(parent.min_size.x<min_size.x)? min_size.x:parent.min_size.x
  parent.min_size.y=(parent.min_size.y<min_size.y)? min_size.y:parent.min_size.y

  if parent.min_size.x<=parent.max_size.x|| parent.min_size.y<=parent.max_size.y
  {
    set_max_size_recursively :: proc(
      p: ^Element,
      max_size: rl.Vector2,
      p_pad: f32
      ) {
      p.max_size.x=((0==p.max_size.x)||(max_size.x<p.max_size.x)) ? max_size.x :
                                                                    p.max_size.x
      p.max_size.y=((0==p.max_size.y)||(max_size.y<p.max_size.y)) ? max_size.y :
                                                                    p.max_size.y
      #partial switch d in p.data
      {
      case BoxElement:
        for e in d.content
        {
          set_max_size_recursively(e, max_size, (d.pad != nil) ? d.pad^ : g_pad)
        }
      }
    }
    set_max_size_recursively(parent, parent.max_size, pad)
  }
}

@(private)
update_box_element_content_sizes :: proc(box: ^BoxElement, rec: rl.Rectangle)
{
  IndexSizePair :: struct { index: int, size: f32 }
  isp_list: [dynamic]IndexSizePair
  defer delete(isp_list)

  pad := (box.pad != nil) ? box.pad^ : g_pad
  double_pad := pad * 2

  box_count: int

  collect_info:
  {
    for e, i in box.content
    {
      size := (.VERTICAL == box.layout) ? e.min_size.y : e.min_size.x
      switch d in e.data
      {
      case TextElement, ImageElement:
        size += pad
      case BoxElement:
        size -= pad
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
    available_space = rec.height
    available_space -= (box.header != "") ? g_header_height : 0
  }
  else
  {
    available_space = rec.width
  }
  available_space -= 
    (pad * (f32(remaining_elements) + 1)) - (double_pad * f32(box_count))

  restrained_count: int

  distribute_space:
  for isp in isp_list
  {
    e := box.content[isp.index]

    if e.non_resizable
    {
      e.width  = e.min_size.x
      e.height = e.min_size.y
      available_space -= (.VERTICAL == box.layout) ? e.height : e.width
      remaining_elements -= 1
      restrained_count += 1

      continue
    }

    restrain_min_size:
    {
      share := math.trunc(available_space / f32(remaining_elements))

      if .VERTICAL == box.layout
      {
        e.width = rec.width
        e.height = (share < e.min_size.y) ? e.min_size.y : share
      }
      else
      {
        e.width = (share < e.min_size.x) ? e.min_size.x : share
        e.height = rec.height
        e.height -= (box.header != "") ? g_header_height : 0
      }
    }

    restrain_max_size:
    {
      has_max_width  := (e.min_size.x <= e.max_size.x)
      has_max_height := (e.min_size.y <= e.max_size.y)
      restrained_count += (has_max_width || has_max_height) ? 1 : 0
      if has_max_width
      {
        e.width = (e.max_size.x < e.width) ? e.max_size.x : e.width
      }
      if has_max_height
      {
        e.height = (e.max_size.y < e.height) ? e.max_size.y : e.height
      }
    }

    #partial switch d in e.data
    {
    case TextElement, ImageElement:
      e.width  -= (.VERTICAL == box.layout) ? double_pad : 0
      e.height -= (.VERTICAL == box.layout) ? 0 : double_pad
    }

    available_space -= (.VERTICAL == box.layout) ? e.height : e.width
    remaining_elements -= 1
  }

  adjust_for_unused_space:
  if 0 < available_space
  {
    unrestrained_count := len(box.content) - restrained_count
    if unrestrained_count <= 0
    {
      break adjust_for_unused_space
    }

    share := math.trunc(available_space / f32(unrestrained_count))
    for e, i in box.content
    {
      if e.min_size.x<=e.max_size.x||e.min_size.y<=e.max_size.y||e.non_resizable
      {
        continue
      }
      if .VERTICAL == box.layout
      {
        e.height += share
      }
      else
      {
        e.width += share
      }
    }
  }

  update_contents:
  for e in box.content
  {
    #partial switch &d in e.data
    {
    case TextElement:
      update_text_element_buffer(&d, e, ((box.font!=nil)?box.font^:g_font))
    case BoxElement:
      update_box_element_content_sizes(&d, e.rec)
    }
  }
}

@(private)
draw_box_element :: proc(box : BoxElement, rec: rl.Rectangle,highlight := false)
{
  font     := (box.font     != nil) ? box.font^     : g_font
  pad      := (box.pad      != nil) ? box.pad^      : g_pad
  fg_color := (box.fg_color != nil) ? box.fg_color^ : g_fg_color
  bg_color := (box.bg_color != nil) ? box.bg_color^ : g_bg_color

  double_pad := pad * 2

  // HEADER ====================================================================

  header_offset: f32
  if box.header != ""
  {
    header_offset = g_header_height
    header_rec := rec
    header_rec.height = header_offset

    header_bg_color := (highlight) ? fg_color : bg_color
    header_fg_color := (highlight) ? bg_color : fg_color

    rl.DrawRectangleRec(header_rec, header_bg_color)
    rl.DrawRectangleLinesEx(header_rec, g_line_thick, g_fg_color)

    header_rec.x += pad
    header_rec.y += math.trunc(pad * 0.25)
    header_rec.width -= double_pad
    draw_text_label(
      box.header,
      {header_rec.x, header_rec.y},
      header_rec.width,
      font,
      header_fg_color)
  }

  // CONTENT ===================================================================

  content_rec        := rec
  content_rec.y      += header_offset
  content_rec.height -= header_offset

  rl.DrawRectangleRec(content_rec, bg_color)

  content_offset: f32
  for e, i in box.content
  {
    e.x =  rec.x
    e.x += (.VERTICAL == box.layout) ? 0 : content_offset

    e.y =  rec.y + header_offset
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
        e.x += pad
        e.y += (must_add_pad) ? pad : 0
      }
      else
      {
        e.x += (must_add_pad) ? pad : 0
        e.y += pad
      }
      content_offset += (must_add_pad) ? pad : 0

    case BoxElement:
      if 1 <= i
      {
        #partial switch d in box.content[i-1].data
        {
        case BoxElement:
          e.y -= (.VERTICAL == box.layout) ? pad : 0
          e.x -= (.VERTICAL == box.layout) ? 0   : pad
        }
      }
    }
    content_offset += (.VERTICAL == box.layout) ? e.height : e.width

    switch d in e.data
    {
    case TextElement:
      draw_text_element(d, e.rec, font, fg_color)

    case ImageElement:
      switch d.resize
      {
      case .NONE:
        rl.DrawTextureV(d.texture, {e.x, e.y}, rl.WHITE)
      case .CENTER:
        rl.DrawTextureV(
          d.texture,
          {
            e.x + (e.width - f32(d.texture.width)) / 2,
            e.y + (e.height - f32(d.texture.height)) / 2
          },
          rl.WHITE)
      case .STRETCH:
        rl.DrawTexturePro(
          d.texture,
          { 0, 0, f32(d.texture.width), f32(d.texture.height) },
          e.rec,
          { 0, 0 },
          0,
          rl.WHITE)
      }

    case BoxElement:
      draw_box_element(d, e.rec)
    }
  }
}
