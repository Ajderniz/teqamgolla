package gui

import     "core:math"
import str "core:strings"

import rl  "vendor:raylib"

@(private)
draw_text_label :: proc(
  txt       : string,
  pos       : rl.Vector2,
  max_width : f32,
  font      : rl.Font,
  fg_color  : rl.Color,
  ) {

  len      := str.rune_count(txt)
  max_cols := int(math.trunc(max_width / font.recs[0].width))

  ok: bool // unused
  line: string
  must_add_tilde := (max_cols <= len)
  if must_add_tilde
  {
    line, ok = str.substring_to(txt, max_cols - 1)
  }
  else
  {
    line, ok = str.substring_to(txt, len)
  }

  line_cstring := str.clone_to_cstring(line)
  defer delete(line_cstring)

  if must_add_tilde
  {
    rl.DrawTextEx(
      font,
      rl.TextFormat("%s~", line_cstring),
      pos,
      f32(font.baseSize),
      0,
      fg_color)
  }
  else
  {
    rl.DrawTextEx(font, line_cstring, pos, f32(font.baseSize), 0, fg_color)
  }
}

@(private)
update_text_item_buffer :: proc(
  txti : ^TextItem,
  size : rl.Vector2,
  font : rl.Font
  ) {
  {
    glyph_pad    := f32(font.glyphPadding) / 2
    max_height   := size.y + glyph_pad
    glyph_height := f32(font.baseSize) + glyph_pad
    txti.glyph_size.y = math.trunc(max_height / glyph_height)

    new_width := math.trunc(size.x / font.recs[0].width)
    if txti.glyph_size.x != new_width
    {
      txti.glyph_size.x = new_width
      txti.offset = 0
    }
    else 
    {
      return
    }
  }

  if txti._buffer != nil
  {
    clear(&txti._buffer)
  }

  start := 0

  for i := 1;; i += 1
  {
    end := start + int(txti.glyph_size.x)
    line: string
    ok: bool

    if end < (str.rune_count(txti.txt)  )
    {
      line, ok = str.substring(txti.txt, start, end)
    }
    else
    {
      end = str.rune_count(txti.txt)
      line, ok = str.substring(txti.txt, start, end)
      append(&txti._buffer, line)
      break
    }

    line = str.trim_space(line)

    has_spaces := str.contains_any(line, " \t\r\n")
    if has_spaces && ok
    {
      limit: int
      if str.contains_any(line, "\r\n")
      {
        limit = str.index_any(line, "\r\n")
        i += 1
      }
      else
      {
        limit = str.last_index_any(line, " \t")
      }

      ko: bool // unused
      line, ko = str.substring_to(line, limit)

      limit -= len(line) - str.rune_count(line)
      line, ko = str.substring_to(line, limit)

      end = start + limit
    }
    if 0 < len(line)
    {
      append(&txti._buffer, line)
    }
    start = (has_spaces) ? (end + 1) : end
  }
}

@(private)
scroll_text_item :: proc(txti: ^TextItem, dir: enum{PREV, NEXT})
{
  if .VERTICAL == txti.scroll_type
  {
    if .NEXT == dir
    {
      limit := len(txti._buffer) - int(txti.glyph_size.y)
      limit =  (limit < 0) ? 0 : limit
      txti.offset += (txti.offset < uint(limit)) ? 1 : 0
    }
    else
    {
      txti.offset -= (0 < txti.offset) ? 1 : 0
    }
  }
  else // PAGED
  {
    if .NEXT == dir
    {
      new_offset := txti.offset + uint(txti.glyph_size.y)
      new_offset -= (new_offset < uint(len(txti._buffer))) ? 1 : 0
      new_offset -= (0 < new_offset)                      ? 1 : 0
      txti.offset =(uint(len(txti._buffer)-1)<=new_offset)?txti.offset:new_offset
    }
    else
    {
      new_offset := int(txti.offset) - (int(txti.glyph_size.y))
      new_offset += (new_offset < len(txti._buffer)) ? 1 : 0
      new_offset += (0 < new_offset)                ? 1 : 0
      txti.offset = (new_offset < 0) ? 0 : uint(new_offset)
    }
  }
}

@(private)
draw_text_item :: proc(
  txti     : TextItem,
  rec      : rl.Rectangle,
  font     : rl.Font,
  fg_color : rl.Color
  ) {
  start := txti.offset
  end   := txti.offset + uint(txti.glyph_size.y)

  draw_triangles: {

    start += (0 < txti.offset)              ? 1 : 0
    end   -= (end < uint(len(txti._buffer))) ? 1 : 0

    after_text := rec.y + rec.height - f32(font.baseSize)
    if .VERTICAL == txti.scroll_type
    {
      center := rec.x + math.trunc(rec.width / 2)
      half_font_width := f32(font.recs[0].width / 2)

      if 0 < txti.offset
      {
        plus_height := rec.y + f32(font.baseSize)
        rl.DrawTriangle(
          {center,                   rec.y},
          {center - half_font_width, plus_height},
          {center + half_font_width, plus_height},
          fg_color
          )
      }
      if end < uint(len(txti._buffer))
      {
        rl.DrawTriangle(
          {center + half_font_width, after_text},
          {center - half_font_width, after_text},
          {center,                   after_text + f32(font.baseSize)},
          fg_color
          )
      }
    }
    else // PAGED
    {
      font_width       := f32(font.recs[0].width)
      half_font_height := f32(font.baseSize / 2)
      if 0 < txti.offset
      {
        plus_width := rec.x + font_width
        rl.DrawTriangle(
          {plus_width, rec.y},
          {rec.x,      rec.y + half_font_height},
          {plus_width, rec.y + f32(font.baseSize)},
          fg_color)
      }
      if end < uint(len(txti._buffer))
      {
        right_of_text := rec.x + rec.width - font_width
        rl.DrawTriangle(
          {right_of_text,              after_text},
          {right_of_text,              after_text + f32(font.baseSize)},
          {right_of_text + font_width, after_text + half_font_height},
          fg_color)
      }
    }
  }
  end = (uint(len(txti._buffer)) < end) ? len(txti._buffer) : end
  start = (end < start) ? end : start

  joined_txt := str.join(txti._buffer[start:end], "\n")
  joined_txt_cstring := str.clone_to_cstring(joined_txt)
  defer delete(joined_txt)
  defer delete(joined_txt_cstring)

  txt_pos := rl.Vector2{rec.x, rec.y}
  txt_pos.y += (0 < txti.offset)?f32(font.baseSize)+f32(font.glyphPadding/2) : 0

  rl.DrawTextEx(
    font,
    joined_txt_cstring,
    txt_pos,
    f32(font.baseSize),
    0,
    fg_color)
}

delete_text_item :: #force_inline proc(item: ^TextItem)
{
  delete(item._buffer)
}
