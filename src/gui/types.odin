package gui

import rl "vendor:raylib"

BoxItem :: struct {
  header   : string,
  content  : []^Item,
  layout   : enum{ VERTICAL, HORIZONTAL },
}

ButtonItem :: struct {
  id      : uint,
  label   : string,
  icon    : ^rl.Texture,
  hovered : bool,
}

TextureItem :: struct {
  texture : rl.Texture,
  resize  : enum { NONE, CENTER, STRETCH },
  options : bit_set[enum{ IS_FRAMEBUFFER, CAPTURE_INPUT }]
}

ItemBackground :: struct {
  color     : rl.Color,
  texture   : ^rl.Texture,
  draw_mode : enum { STRETCH, TILE }
}

@(private)
ItemBorderRectangles :: struct {
  corner_rec : struct {
    using default : rl.Rectangle,
    custom        : [enum { TL, TR, BL, BR }]^rl.Rectangle,
  },
  line_rec   : struct {
    using default : rl.Rectangle,
    custom        : [enum {TOP, BOT, LEFT, RIGHT}]^rl.Rectangle,
  }
}

ItemBorder :: struct {
  texture    : rl.Texture,
  draw_mode  : enum { STRETCH, TILE },
  using recs : ItemBorderRectangles
}

Item :: struct {
  form          : union { TextItem, TextureItem, ButtonItem , BoxItem, },

  using rec     : rl.Rectangle,
  min_size      : rl.Vector2,
  max_size      : rl.Vector2,
  non_resizable : struct { x, y: bool },

  font          : ^rl.Font,
  pad           : ^f32,
  fg_color      : ^rl.Color,
  bg            : ^ItemBackground,

  border_style  : enum { NONE, LINE, GLOBAL, CUSTOM },
  border        : ^ItemBorder
}

TextItem :: struct {
  txt         : string,
  buffer      : [dynamic]string,
  glyph_size  : rl.Vector2,
  offset      : uint,
  scroll_type : enum { VERTICAL, PAGED }
}

ActionState :: enum {
  NONE,
  DRAG,
  RESIZE,
  SCROLL_UP,
  SCROLL_DOWN,
}

Window :: struct {
  _id        : uint,
  _act_state : ActionState,
  _saved_rec : rl.Rectangle,
  _maximized : bool,

  draggable  : bool,

  using item : ^Item
}

