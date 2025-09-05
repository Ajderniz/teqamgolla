/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import     "core:math"     // trunc
import str "core:strings"

import rl  "vendor:raylib"

Box :: struct {
	rec             : rl.Rectangle,

	flags           : bit_set[enum{ DRAGGABLE, RESIZABLE }],
	drag_mode       : enum{ NONE, DRAG, RESIZE },

	header          : string,
	content         : union { string, rl.Texture },

	appearance_mode : enum { GLOBAL, CUSTOM },
	font            : rl.Font,
	padding         : f32,
	txt_color       : rl.Color,
	line_color      : rl.Color,
	bg_color        : rl.Color,
	line_thick      : f32
}

@(private) g_font       : rl.Font
@(private) g_padding    : f32
@(private) g_txt_color  : rl.Color
@(private) g_line_color : rl.Color
@(private) g_bg_color   : rl.Color
@(private) g_line_thick : f32

@(private)
is_vector_within_rectangle :: proc(v2: rl.Vector2, rec: rl.Rectangle) -> bool
{
	return(!((v2.x < rec.x || (rec.x + rec.width) < v2.x) ||
			    (v2.y < rec.y || (rec.y + rec.height) < v2.y)))
}

@(private)
are_rectangles_overlapping :: proc(
	rec1: rl.Rectangle, 
	rec2: rl.Rectangle
	) -> bool
{
	return(!(((rec1.x + rec1.width) < rec2.x || (rec2.x + rec2.width) < rec1.x) ||
			   ((rec1.y + rec1.height) < rec2.y || (rec2.y + rec2.height) < rec1.y)))
}

@(private)
draw_box :: proc(
	rec        :  rl.Rectangle,
	line_color := g_line_color,
	bg_color   := g_bg_color,
	line_thick := g_line_thick,
) {
	rl.DrawRectangleRec(rec, bg_color)
	rl.DrawRectangleLinesEx(rec, line_thick, line_color)
}

@(private)
draw_text :: proc(
	rec       : rl.Rectangle,
	txt       : string,
	font      : rl.Font,
	padding   : f32,
	txt_color : rl.Color,
) {
	max_c_width := 
		int(math.trunc((rec.width - (padding * 2)) / font.recs[0].width))

	max_c_height :=
		int(math.trunc((rec.height - (padding * 2)) / f32((font.baseSize + 2))))

	lines := [dynamic]string{}
	defer delete(lines)

	start := 0
	for i := 1; i <= max_c_height; i += 1
	{
		end := start + max_c_width
		line: string
		ok: bool
		if end < (str.rune_count(txt) - 1)
		{
			line, ok = str.substring(txt, start, end)
		}
		else
		{
			end = str.rune_count(txt)
			line, ok = str.substring(txt, start, end)
			append(&lines, line)
			break
		}

		has_spaces := str.contains_any(line, " \t\r\n")
		if has_spaces && ok
		{
			limit := str.last_index_any(line, " \t\r\n")
			ko: bool // unused
			line, ko = str.substring_to(line, limit)

			limit -= len(line) - str.rune_count(line)
			line, ko = str.substring_to(line, limit)

			end = start + limit
		}
		if 0 < len(line)
		{
			append(&lines, line)
		}
		start = end + 1 if has_spaces else end
	}

	printed_msg := str.join(lines[:], "\n")
	printed_msg_cstring := str.clone_to_cstring(printed_msg)
	defer delete(printed_msg)
	defer delete(printed_msg_cstring)

	rl.DrawTextEx(
		font,
		printed_msg_cstring,
		{rec.x + padding, rec.y + g_padding},
		cast(f32)g_font.baseSize,
		0,
		txt_color,
	)
}

init :: proc(
	font       :  rl.Font,
	padding    : f32 = 12,
	txt_color  := rl.WHITE,
	line_color := rl.WHITE,
	bg_color   := rl.BLACK,
	line_thick : f32 = 1,
) {
	g_font       = font
	g_padding    = padding
	g_txt_color  = txt_color
	g_line_color = line_color
	g_bg_color   = bg_color
	g_line_thick = line_thick
}

move_box_index_to_index :: proc(
	list  : []^Box,
	src_index : u32,
	dst_index : u32
	) {
	cap := u32(len(list) - 1)
	if cap < src_index || cap < dst_index
	{
		return
	}

	box := list[src_index]	

	if dst_index < src_index
	{
		for i := src_index; 0 < i; i -= 1
		{
			list[i] = list[i-1]
		}
		list[dst_index] = box
	}
	else if src_index < dst_index
	{
		for i := src_index; i < dst_index; i += 1
		{
			list[i] = list[i+1]
		}
	}
	list[dst_index] = box
}

draw_label :: proc(
	pos        :  rl.Vector2,
	txt        :  cstring,
	font       := g_font,
	padding    := g_padding,
	txt_color  := g_txt_color,
	line_color := g_line_color,
	bg_color   := g_bg_color,
	line_thick := g_line_thick,
) {
	meas := rl.MeasureTextEx(font, txt, f32(font.baseSize), 0)
	rec := rl.Rectangle{
		pos.x,
		pos.y,
		meas.x + (padding * 2),
		meas.y + (padding * 2)}

	draw_box(rec, line_color, bg_color, line_thick)
	rl.DrawTextEx(
		font,
		txt,
		{rec.x + padding, rec.y + padding},
		cast(f32)font.baseSize,
		0,
		txt_color,
	)
}

draw_box_list :: proc(list: []^Box)
{
	@(static) mouse_offset: rl.Vector2

	mouse_pos := rl.GetMousePosition()

	new_top_index := -1
	outer: for box, i in list
	{
		reset := false

		mode: switch box.drag_mode
		{
		case .NONE:
			if !is_vector_within_rectangle(mouse_pos, box.rec)
			{
				continue
			}
			for j in 0..<i
			{
				if is_vector_within_rectangle(mouse_pos, list[j].rec)
				{
					continue outer
				}
			}

			button_pressed := rl.MouseButton.BACK
			if rl.IsMouseButtonPressed(.LEFT)
			{
				button_pressed = .LEFT
			}
			else if rl.IsMouseButtonPressed(.RIGHT)
			{
				button_pressed = .RIGHT
			}

			if .DRAGGABLE in box.flags && .LEFT == button_pressed
			{
				rl.SetMouseCursor(.RESIZE_ALL)
				mouse_offset = {
					(mouse_pos.x - box.rec.x), 
					(mouse_pos.y - box.rec.y)
				}
				box.drag_mode = .DRAG
			} 
			else if .RESIZABLE in box.flags && .RIGHT == button_pressed
			{
				rl.SetMousePosition(
					i32(box.rec.x + box.rec.width),
					i32(box.rec.y + box.rec.height)
					)
				rl.SetMouseCursor(.RESIZE_NWSE)
				box.drag_mode = .RESIZE
			}
			else if .LEFT == button_pressed || .RIGHT == button_pressed
			{
				break 
			}
			else
			{
				continue
			}
		case .DRAG:
			if rl.IsMouseButtonDown(.LEFT)
			{
				box.rec.x = mouse_pos.x - mouse_offset.x
				box.rec.y = mouse_pos.y - mouse_offset.y
			}
			else
			{
				reset = true
			}
		case .RESIZE:
			if rl.IsMouseButtonDown(.RIGHT)
			{
				double_padding := g_padding * 2

				box.rec.width = mouse_pos.x - box.rec.x if
					double_padding <= mouse_pos.x - box.rec.x else double_padding

				box.rec.height = mouse_pos.y - box.rec.y if
					double_padding <= mouse_pos.y - box.rec.y else double_padding
			}
			else
			{
				reset = true
			}
		}
		if reset
		{
			rl.SetMouseCursor(.DEFAULT)
			box.drag_mode = .NONE
			continue
		}
		new_top_index = i if i != 0 else -1
		break
	}
	if 0 < new_top_index
	{
		move_box_index_to_index(list, u32(new_top_index), 0)
	}

	#reverse for box in list
	{
		draw_box(box.rec)
		switch content in box.content
		{
		case string:
			draw_text(box.rec, content, g_font, g_padding, g_txt_color)

		case rl.Texture:
			rl.DrawTextureV(
				content,
				{ box.rec.x + g_padding, box.rec.y + g_padding},
				rl.WHITE)
		}
	}
}
