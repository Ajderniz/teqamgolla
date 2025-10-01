package gui

import    "core:log"
import    "core:math"
import    "core:sort"

import rl "vendor:raylib"

BoxItem :: struct {
  header   : string,
  content  : []^Item,
  layout   : enum{ VERTICAL, HORIZONTAL },
}

@(private)
update_box_item_content_sizes :: proc(
  boxi      : ^BoxItem,
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
    for bi, i in boxi.content
    {
      size := (.VERTICAL == boxi.layout) ? bi.min_size.y : bi.min_size.x
      switch d in bi.data
      {
      case TextItem, ImageItem:
        size += p_pad
      case BoxItem:
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

  remaining_items := len(boxi.content)

  available_space: f32
  if .VERTICAL == boxi.layout
  {
    available_space = size.y
    available_space -= (boxi.header != "") ? g_header_height : 0
  }
  else
  {
    available_space = size.x
  }
  available_space -= 
    (p_pad * (f32(remaining_items) + 1)) - (double_pad * f32(box_count))

  constrained_count: int

  distribute_space:
  for isp in isp_list
  {
    e := boxi.content[isp.index]

    if e.non_resizable.x && e.non_resizable.y
    {
      e.width  = e.min_size.x
      e.height = e.min_size.y
      available_space -= (.VERTICAL == boxi.layout) ? e.height : e.width
      remaining_items -= 1
      constrained_count += 1

      continue
    }

    is_constrained: bool

    share := math.trunc(available_space / f32(remaining_items))

    update_width:
    {
      if e.non_resizable.x
      {
        e.width = e.min_size.x
        is_constrained = (.HORIZONTAL == boxi.layout) ? true : false
        break update_width
      }

      if .VERTICAL == boxi.layout
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
      case TextItem, ImageItem:
        e.width  -= (.VERTICAL == boxi.layout) ? double_pad : 0
      }
    }

    update_height:
    {
      if e.non_resizable.y
      {
        e.height = e.min_size.y
        is_constrained = (.VERTICAL == boxi.layout) ? true : false
        break update_height
      }

      if .VERTICAL == boxi.layout
      {
        e.height = (share < e.min_size.y) ? e.min_size.y : share
      }
      else
      {
        e.height = size.y
        e.height -= (boxi.header != "") ? g_header_height : 0
      }

      if e.min_size.y <= e.max_size.y
      {
        e.height = (e.max_size.y < e.height) ? e.max_size.y : e.height
        is_constrained = true
      }

      #partial switch d in e.data
      {
      case TextItem, ImageItem:
        e.height -= (.VERTICAL == boxi.layout) ? 0 : double_pad
      }
    }

    constrained_count += (is_constrained) ? 1 : 0

    available_space -= (.VERTICAL == boxi.layout) ? e.height : e.width
    remaining_items -= 1
  }

  adjust_for_unused_space:
  if 0 < available_space
  {
    unconstrained_count := len(boxi.content) - constrained_count
    if unconstrained_count <= 0
    {
      break adjust_for_unused_space
    }

    share := math.trunc(available_space / f32(unconstrained_count))
    for e, i in boxi.content
    {
      if e.min_size.x <= e.max_size.x || e.min_size.y <= e.max_size.y
      {
        continue
      }
      if .VERTICAL == boxi.layout
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
  for e in boxi.content
  {
    border: ^ItemBorder
    #partial switch e.border_style
    {
    case .GLOBAL:
      border = &g_border
    case .CUSTOM:
      border = e.border
    }

    e_size := rl.Vector2{ e.width, e.height }
    if border != nil
    {
      line_rec := &border.line_rec

      e_size.x -= (line_rec.left != nil)? line_rec.left.height : line_rec.height
      e_size.x -= (line_rec.right!= nil)? line_rec.right.height: line_rec.height

      e_size.y -= (line_rec.top  != nil)? line_rec.top.height  : line_rec.height
      e_size.y -= (line_rec.bot  != nil)? line_rec.bot.height  : line_rec.height
    }

    #partial switch &d in e.data
    {
    case TextItem:
      update_text_item_buffer(&d, e_size, ((e.font != nil) ? e.font^:p_font))
    case BoxItem:
      update_box_item_content_sizes(
        &d,
        e_size,
        ((e.font != nil) ? e.font^ : p_font),
        ((e.pad  != nil) ? e.pad^  : p_pad))
    }
  }
}

@(private)
draw_box_item :: proc(
  boxi        :  BoxItem,
  rec        :  rl.Rectangle,
  p_font     :  rl.Font,
  p_pad      :  f32,
  p_fg_color :  rl.Color,
  p_bg       :  ItemBackground,
  border     : ^ItemBorder,
  highlight  := false,
  ) {

  double_pad := p_pad * 2

  // HEADER ====================================================================

  header_offset: f32
  if boxi.header != ""
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
      boxi.header,
      {header_rec.x, header_rec.y},
      header_rec.width,
      g_font,
      header_fg_color)
  }

  // CONTENT ===================================================================

  content_rec        := rec
  content_rec.y      += header_offset
  content_rec.height -= header_offset

  draw_item_background(p_bg, content_rec)

  if border != nil
  {
    content_rec.x += border.line_rec.height
    content_rec.y += border.line_rec.height
  }

  content_offset: f32
  for e, i in boxi.content
  {
    e.x =  content_rec.x
    e.x += (.VERTICAL == boxi.layout) ? 0 : content_offset

    e.y =  content_rec.y
    e.y += (.VERTICAL == boxi.layout) ? content_offset : 0

    switch d in e.data
    {
    case TextItem, ImageItem:
      must_add_pad := false
      if 0 == i
      {
        must_add_pad = true
      }
      else if 1 <= i
      {
        #partial switch pd in boxi.content[i-1].data
        {
        case TextItem, ImageItem:
          must_add_pad = true
        }
      }
      if .VERTICAL == boxi.layout
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

    case BoxItem:
      if 1 <= i
      {
        #partial switch d in boxi.content[i-1].data
        {
        case BoxItem:
          e.y -= (.VERTICAL == boxi.layout) ? p_pad : 0
          e.x -= (.VERTICAL == boxi.layout) ? 0   : p_pad
        }
      }
    }
    content_offset += (.VERTICAL == boxi.layout) ? e.height : e.width

    draw_item(e, p_font, p_pad, p_fg_color, p_bg)
  }
}
