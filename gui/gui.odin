/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import "core:math" 			//trunc
import str "core:strings"

import rl "vendor:raylib"

// Private values ==============================================================

// This font will be used by default, and must be specified when invoking init.
@(private)
font: rl.Font

// This determines the pixel offset which separates the box and the text.
@(private)
padding: f32

/*
	Initializer procedure. MUST be invoked before using the drawing procedures.

	p_font: font to be used by default.
	p_padding: Pixel offset between the box and the text. 
*/
init :: proc(p_font: rl.Font, p_padding: f32)
{
	font = p_font
	padding = p_padding
}

/*
	Draws a message box, adjusting the text content to its size.
	At this point in time it supports ASCII characters only. This is because
	special characters use more spaces, causing indexing issues.

	p_rec: dimensions to be used by the message box.
	p_msg: text to be displayed within the box.
*/
draw_message_box :: proc(p_rec: rl.Rectangle, p_msg: cstring)
{
	/* 
		First, we must calculate the maximum amount of characters that can
		possibly fit within the message box. For both dimensions, we must
		divide the corresponding width and height value of the greater box
		(taking into consideration the padding value at each side) by the
		width or height of each glyph.
	*/
	max_c_width :=
		int(math.trunc((p_rec.width - (padding * 2)) / font.recs[0].width))
	max_c_height :=
		int(math.trunc((p_rec.height - (padding * 2)) /
						f32((font.baseSize + 2))))

	// The amount of lines is unpredictable, so we will need a dynamic array.
	lines := [dynamic]string{}
	defer delete(lines)

	// We will iterate through every potential line.
	// Before that, initialize the 'start' index to 0.
	start := 0
	for i := 1 ;; i += 1
	{
		// First we get the chunk of text that fits within the box.
		end := start + max_c_width
		line, ok := str.substring(string(p_msg), start, end)

		// Then, to avoid cutting words in half, we check if the current line
		// has any spaces in it. If so, more work is needed.
		has_spaces := str.contains_any(line, " \t\r\n")
		if has_spaces && ok
		{
			// The actual limit of this line will have to be its last space.
			limit := str.last_index_any(line, " \t\r\n")
			ko: bool // This value is unused. 'substring_to' needs to assign it.
			line, ko = str.substring_to(line, limit)
			// We update 'end' to reflect the real end index for this line.
			end = start + limit
		}
		// And that's that. We just add the line to the list, if it's not blank.
		if 0 < len(line) 
		{
			append(&lines, line)
		}
		/*
			We'll want to break out of the loop if any of this is true:
			- The indexes used for extracting the initial substring were out of
			  bounds for the original message string. This is determined by the
			  'ok' value, returned by the first 'substring' call in this loop.
			- The current line, determined by the 'i' counter initialized by the
			  for loop, has reached the maximum amount allowed by the boundaries
		*/
		if !ok || max_c_height <= i
		{
			break
		}
		/*
			Finally, we update the 'start' index for the next line, considering:
			- If this line had spaces in it, we want to trim the leading space
			  that was left for the next line, so we add one.
			- Otherwise, we don't want to do that since that will mean skipping
			  over a precious character.
		*/
		start = end + 1 if has_spaces else end
	}

	// Upon achieving the final list of lines, we join them into a single
	// string, separating it with newlines.
	printed_msg := str.join(lines[:], "\n")
	// Raylib doesn't use Odin's strings, so we want to use a cstring.
	printed_msg_cstring := str.clone_to_cstring(printed_msg)
	defer delete(printed_msg)
	defer delete(printed_msg_cstring)

	// And here you go. A nice little box with some text in it!
	rl.DrawRectangleRec(p_rec, rl.BLACK)
	rl.DrawRectangleLinesEx(p_rec, 1, rl.WHITE)
	rl.DrawTextEx(
		font, 
		printed_msg_cstring, 
		{ p_rec.x + padding, p_rec.y + padding }, 
		cast(f32)font.baseSize, 
		0, 
		rl.WHITE)
}

/*
	Draws a short text within a box adjusted to its size.
	
	p_pos: X and Y position for the label.
	p_lbl: text to be displayed within the box.
*/
draw_label :: proc(p_pos: rl.Vector2, p_lbl: cstring)
{
	// We use Raylib's handy 'MeasureTextEx' function to measure the text.
	// The rest is history.
	meas := rl.MeasureTextEx(font, p_lbl, f32(font.baseSize), 0)
	rec := rl.Rectangle { 
		p_pos.x,
		p_pos.y,
		meas.x + (padding * 2),
		meas.y + (padding * 2) }

	rl.DrawRectangleRec(rec, rl.BLACK)
	rl.DrawRectangleLinesEx(rec, 1, rl.WHITE)
	rl.DrawTextEx(
		font, 
		p_lbl, 
		{ rec.x + padding, rec.y + padding }, 
		cast(f32)font.baseSize, 
		0, 
		rl.WHITE)
}