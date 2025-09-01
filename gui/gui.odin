/*******************************************************************************
 * 
 * Basic GUI system for Teqamgolla
 *
 ******************************************************************************/

package gui

import "core:math" //trunc
import str "core:strings"

import rl "vendor:raylib"

// This is used to determine the state of a given 'Box'.
BoxDragMode :: enum {
	NONE,
	DRAG,
	RESIZE
}

// This specifies the options for the 'BoxFlags' bit_set
BoxFlag :: enum {
	DRAGGABLE,
	RESIZEABLE
}

// This struct is used as the basis for all other composite GUI elements.
Box :: struct {
	rec: rl.Rectangle,		 
	flags: bit_set[BoxFlag], // Drag & resize can be enabled or disabled here.
	drag_mode: BoxDragMode,  
	mouse_offset: rl.Vector2 // Distance between 0,0 and the mouse's postiion.
}

// These values will be used by default, and must be set when invoking 'init'.
@(private)
g_font: rl.Font
@(private)
g_padding: f32 // Pixel offset which separates the box and the text.
@(private)
g_font_color: rl.Color
@(private)
g_border_color: rl.Color
@(private)
g_background_color: rl.Color
@(private)
g_border_thickness: f32

// Returns true if the given 'v2' vector is within the 'rec' rectangle.
@(private)
is_vector2_within_rectangle :: proc(v2: rl.Vector2, rec: rl.Rectangle) -> bool
{
	return !((v2.x < rec.x || (rec.x + rec.width) < v2.x) ||
				  (v2.y < rec.y || (rec.y + rec.height) < v2.y))
}

// Updates the box's values to reflect input according to its 'drag_mode'.
@(private)
update_box :: proc(box: ^Box, padding: f32)
{
	// A few paths will require knowing the mouse's position.
	mpos := rl.GetMousePosition()
	reset := false // Whether the box's 'drag_mode' must be reset to 'NONE'

	switch box.drag_mode
	{
	// If the state is NONE, there is only potential to enable another mode.
	case .NONE:
		if !is_vector2_within_rectangle(mpos, box.rec)
		{
			break
		}
		// For each mode, we must check if the box can perform the action.
		if .DRAGGABLE in box.flags && rl.IsMouseButtonPressed(.LEFT)
		{
			rl.SetMouseCursor(.RESIZE_ALL)
			// Calculate the offset between the mouse and the box's origin.
			box.mouse_offset = {
				(mpos.x - box.rec.x),
				(mpos.y - box.rec.y) }
			box.drag_mode = .DRAG
		}
		else if .RESIZEABLE in box.flags &&
				rl.IsMouseButtonPressed(.RIGHT)
		{
			// Place the cursor at the bottom-right corner of the box.
			rl.SetMousePosition(
				i32(box.rec.x + box.rec.width),
				i32(box.rec.y + box.rec.height))
			rl.SetMouseCursor(.RESIZE_NWSE)
			box.drag_mode = .RESIZE
		}
	// When dragging, we need to remember the mouse offset.
	case .DRAG:
		if rl.IsMouseButtonDown(.LEFT)
		{
			box.rec.x = mpos.x - box.mouse_offset.x
			box.rec.y = mpos.y - box.mouse_offset.y
		}
		else
		{
			reset = true
		}
	// When resizing, restrict the minimum size the box can have.
	case .RESIZE:
		if rl.IsMouseButtonDown(.RIGHT)
		{
			double_padding := padding * 2
			box.rec.width = mpos.x - box.rec.x if double_padding <= mpos.x - box.rec.x else double_padding
			box.rec.height = mpos.y - box.rec.y if double_padding <= mpos.y - box.rec.y else double_padding
		}
		else
		{
			reset = true
		}
	}
	// If any mode triggered the reset, we set the box's mode back to DEFAULT.
	if reset
	{
		rl.SetMouseCursor(.DEFAULT)
		box.drag_mode = .NONE
	}
}

/*
	Draws a simple box with an outline.

	rec:			  			box's dimensions
	border_color:	  	outline color
	background_color: box body color
	border_thickness: pixel size of the outline
*/
@(private)
draw_box :: proc(
	rec: rl.Rectangle,
	border_color := g_border_color,
	background_color := g_background_color,
	border_thickness := g_border_thickness)
{
	rl.DrawRectangleRec(rec, background_color)
	rl.DrawRectangleLinesEx(rec, border_thickness, border_color)
}


/*
	Draws a string of text, adjusting its lines to a rectangular boundary.

	rec:				dimensions to be used by the message box.
	txt:				text to be displayed within the box.
	font:				font used to render the text.
	padding:		pixel space between the content and the border.
	font_color: color used by the text.
*/
@(private)
draw_text :: proc(
	rec: rl.Rectangle,
	txt: cstring,
	font: rl.Font,
	padding: f32,
	font_color: rl.Color
	)
{
	/* 
		First, we must calculate the maximum amount of characters that can
		possibly fit within the message box. For both dimensions, we must
		divide the corresponding width and height value of the greater box
		(taking into consideration the padding value at each side) by the
		width or height of each glyph.
	*/
	max_c_width :=
		int(math.trunc((rec.width - (padding * 2)) / font.recs[0].width))
	max_c_height :=
		int(math.trunc((rec.height - (padding * 2)) /
						f32((font.baseSize + 2))))

	// The amount of lines is unpredictable, so we will need a dynamic array.
	lines := [dynamic]string{}
	defer delete(lines)

	/*
		- We will iterate through every potential line.
		- Before that, initialize the 'start' index to 0.
		- To prevent the text from rendering lines beyond the Y limit, we should
			stop when the 'i' counter reaches it.
	*/
	start := 0
	for i := 1 ; i <= max_c_height; i += 1
	{
		// First we get the chunk of text that fits within the box.
		end := start + max_c_width
		line, ok := str.substring(string(txt), start, end)

		// Then, to avoid cutting words in half, we check if the current line
		// has any spaces in it. If so, more work is needed.
		has_spaces := str.contains_any(line, " \t\r\n")
		if has_spaces && ok
		{
			// The actual limit of this line will have to be its last space.
			limit := str.last_index_any(line, " \t\r\n")
			ko: bool // This value is unused. 'substring_to' needs to assign it.
			line, ko = str.substring_to(line, limit)

			// We trim the line yet again, making up for any rune differences.
			limit -= len(line) - str.rune_count(line)
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
			We'll want to break out of the loop if the indexes used for extracting the
			initial substring were out of bounds for the original message string.
			This is determined by the 'ok' value, returned by the first 'substring'
			call in this loop.
		*/
		if !ok
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

	// And here you go. A nice string adjusted to its bounds!
	rl.DrawTextEx(
		font, 
		printed_msg_cstring, 
		{ rec.x + padding, rec.y + g_padding }, 
		cast(f32)g_font.baseSize, 
		0, 
		font_color)
}

/*
	Initializer procedure. MUST be invoked before using the drawing procedures.

	font:							font to be used by default
	padding:					pixel offset between the box and the text
	font_color:				text color 
	border_color:			outine color
	background_color:	box body color
	border_thickness:	pixel size of the outline
*/
init :: proc(
	font: rl.Font,
	padding: f32 = 12,
	font_color := rl.WHITE,
	boder_color := rl.WHITE,
	background_color := rl.BLACK,
	border_thickness: f32 = 1)
{
	g_font = font
	g_padding = padding
	g_font_color = font_color
	g_border_color = boder_color
	g_background_color = background_color
	g_border_thickness = border_thickness
}

/*
	Draws a box with text content adjusted to its size.

	box:			  			box structure to render and update
	txt:			  			text string to render within the box
	font:			  			font used to render the text
	padding:		  		space between the border and the text content
	font_color:		  	color for the font only
	border_color:     outline color
	background_color: box body color
	border_thickness: pixel size of the outline
*/
draw_text_box :: proc(
	box: ^Box, 
	txt: cstring,
	font := g_font,
	padding := g_padding,
	font_color := g_font_color,
	border_color := g_border_color,
	background_color := g_background_color,
	border_thickness := g_border_thickness)
{
	// If the box is neither of these, the 'update_box' call is unnecessary.
	if .DRAGGABLE in box.flags || .RESIZEABLE in box.flags
	{
		update_box(box, padding)
	}
	draw_box(box.rec, border_color, background_color, border_thickness)
	draw_text(box.rec, txt, font, padding, font_color)
}

/*
	Draws a short line of text within a box adjusted to its size.
	
	pos: 							X and Y position for the label
	txt: 							text to be displayed within the box
	font:							font to render the text with
	padding:					pixel space between the border and the text content
	font_color:				color to draw the text with
	border_color:			color to draw the outline with
	background_color: color to draw the box body with
	border_thickness: pixel size of the outline
*/
draw_label :: proc(
	pos: rl.Vector2,
	txt: cstring,
	font := g_font,
	padding := g_padding,
	font_color := g_font_color,
	border_color := g_border_color,
	background_color := g_background_color,
	border_thickness := g_border_thickness)
{
	// We use Raylib's handy 'MeasureTextEx' function to measure the text.
	// The rest is history.
	meas := rl.MeasureTextEx(font, txt, f32(font.baseSize), 0)
	rec := rl.Rectangle { 
		pos.x,
		pos.y,
		meas.x + (padding * 2),
		meas.y + (padding * 2) }

	draw_box(rec, border_color, background_color, border_thickness)
	rl.DrawTextEx(
		font, 
		txt, 
		{ rec.x + padding, rec.y + padding }, 
		cast(f32)font.baseSize, 
		0, 
		font_color)
}