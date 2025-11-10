package dungeon

import      "core:encoding/json"
import      "core:log"
import      "core:math"
import      "core:os"
import path "core:path/filepath"
import str  "core:strings"

import rl   "vendor:raylib"
import      "vendor:raylib/rlgl"

import      "../common"
import      "../gui"
import cur  "../gui/cursor"
import inp  "../input"

MINIMAP_BLOCK_SIZE  :: 5
PERSPECTIVE_STRETCH :: 2

CURSOR_FIELD_ID :: "dungeon"

@(private)
cfg: struct {
  maps_dir : string,
  img_dir  : string,
}

@(private)
st: struct {
  faces  : map[string]Face,
  blocks : map[string]Block,
  bmap   : BlockMap,
  player : PlayerState,
}

@(private)
draw_texture_skewed :: proc(
  txr            : rl.Texture,
  tl, bl, br, tr : rl.Vector2,
  angle          : Angle,
  color          : rl.Color,
  ) {
  coords: [4]rl.Vector2
  switch angle
  {
  case .V0:   coords = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 1, 0 } }
  case .H90:  coords = { { 0, 1 }, { 1, 1 }, { 1, 0 }, { 0, 0 } }
  case .V180: coords = { { 1, 1 }, { 1, 0 }, { 0, 0 }, { 0 ,1 } }
  case .H270: coords = { { 1, 0 }, { 0, 0 }, { 0 ,1 }, { 1, 1 } }
  }

  rlgl.SetTexture(txr.id)
  rlgl.Begin(rlgl.QUADS)
  {
    rlgl.Color4ub(color.r, color.g, color.b, color.a)
    rlgl.TexCoord2f(coords[0].x, coords[0].y); rlgl.Vertex2f(tl.x, tl.y)
    rlgl.TexCoord2f(coords[1].x, coords[1].y); rlgl.Vertex2f(bl.x, bl.y)
    rlgl.TexCoord2f(coords[2].x, coords[2].y); rlgl.Vertex2f(br.x, br.y)
    rlgl.TexCoord2f(coords[3].x, coords[3].y); rlgl.Vertex2f(tr.x, tr.y)
  }
  rlgl.End()
  rlgl.SetTexture(0)
}

@(private)
free_block_map :: proc()
{
  for layer in st.bmap
  {
    for row in layer
    {
      delete(row)
    }
    delete(layer)
  }
  delete(st.bmap)
}

@(private)
set_dgn_cursor_state :: #force_inline proc(state: CursorState)
{
  cur.set_state(CURSOR_FIELD_ID, int(state))
}

set_player_state :: #force_inline proc(player: PlayerState)
{
  st.player = player
}

get_player_state :: #force_inline proc() -> PlayerState
{
  return st.player
}

process_input :: proc(
  input     : inp.InputState, 
  win_id    : uint,
  rtxr_rec  : rl.Rectangle,
  scr_scale : f32) -> (changed: bool)
{
  if len(st.bmap) <= 0
  {
    return false
  }

  potential_move : PlayerMovement = nil
  move           : PlayerMovement = nil

  set_potential_move:
  if gui.can_window_capure_input(win_id, input.mouse_pos) &&
     common.is_v2_within_rec(input.mouse_pos, rtxr_rec)
  {
    if input.mouse_wheel_move != 0
    {
      if input.mouse_wheel_move < 0
      {
        move = .DOWN
      }
      else
      {
        move = .UP
      }
      break set_potential_move
    }

    rel_mpos: rl.Vector2 = { 
      input.mouse_pos.x - rtxr_rec.x,
      input.mouse_pos.y - rtxr_rec.y
    }
    third_width := (rtxr_rec.width / 3)
    half_height := (rtxr_rec.height / 2)

    if rel_mpos.x < third_width
    {
      if rel_mpos.y < half_height
      {
        potential_move = .TURN_LEFT
        set_dgn_cursor_state(.TURN_LEFT)
      }
      else
      {
        potential_move = .STRAFE_LEFT
        set_dgn_cursor_state(.STRAFE_LEFT)
      }
    }
    else if rel_mpos.x < (third_width * 2)
    {
      if rel_mpos.y < half_height
      {
        potential_move = .FRONT
        set_dgn_cursor_state(.FRONT)
      }
      else
      {
        potential_move = .BACK
        set_dgn_cursor_state(.BACK)
      }
    }
    else
    {
      if rel_mpos.y < half_height
      {
        potential_move = .TURN_RIGHT
        set_dgn_cursor_state(.TURN_RIGHT)
      }
      else
      {
        potential_move = .STRAFE_RIGHT
        set_dgn_cursor_state(.STRAFE_RIGHT)
      }
    }
  }
  
  set_move:
  {
    if potential_move != nil && .LEFT == input.mouse_button_pressed
    {
      move = potential_move
      break set_move
    }

    #partial switch input.key_pressed
    {
    case .W: move = .FRONT
    case .S: move = .BACK
    case .A: move = .STRAFE_LEFT
    case .D: move = .STRAFE_RIGHT
    case .Q: move = .TURN_LEFT
    case .E: move = .TURN_RIGHT
    case .R: move = .UP
    case .F: move = .DOWN
    }
  }

  player  := st.player

  switch move
  {
  case .NONE:
    return false

  case .FRONT:
    switch player.dir
    {
    case .NORTH: player.y -= (0        < player.y)                 ? 1 : 0
    case .EAST:  player.x += (player.x < (len(st.bmap[0][0]) - 1)) ? 1 : 0
    case .SOUTH: player.y += (player.y < (len(st.bmap[0]) - 1))    ? 1 : 0
    case .WEST:  player.x -= (0        < player.x)                 ? 1 : 0
    }
  case .BACK:
    switch player.dir
    {
    case .NORTH: player.y += (player.y < (len(st.bmap[0]) - 1))    ? 1 : 0
    case .EAST:  player.x -= (0        < player.x)                 ? 1 : 0
    case .SOUTH: player.y -= (0        < player.y)                 ? 1 : 0
    case .WEST:  player.x += (player.x < (len(st.bmap[0][0]) - 1)) ? 1 : 0
    }
  case .STRAFE_LEFT:
    switch player.dir
    {
    case .NORTH: player.x -= (0        < player.x)                 ? 1 : 0
    case .EAST:  player.y -= (0        < player.y)                 ? 1 : 0
    case .SOUTH: player.x += (player.x < (len(st.bmap[0][0]) - 1)) ? 1 : 0
    case .WEST:  player.y += (player.y < (len(st.bmap[0]) - 1 ))   ? 1 : 0
    }
  case .STRAFE_RIGHT:
    switch player.dir
    {
    case .NORTH: player.x += (player.x < (len(st.bmap[0][0]) - 1)) ? 1 : 0
    case .EAST:  player.y += (player.y < (len(st.bmap[0]) - 1 ))   ? 1 : 0
    case .SOUTH: player.x -= (0        < player.x)                 ? 1 : 0
    case .WEST:  player.y -= (0        < player.y)                 ? 1 : 0
    }
  case .TURN_LEFT:
    switch player.dir
    {
    case .NORTH: player.dir = .WEST
    case .EAST:  player.dir = .NORTH
    case .SOUTH: player.dir = .EAST
    case .WEST:  player.dir = .SOUTH
    }
  case .TURN_RIGHT:
    switch player.dir
    {
    case .NORTH: player.dir = .EAST
    case .EAST:  player.dir = .SOUTH
    case .SOUTH: player.dir = .WEST
    case .WEST:  player.dir = .NORTH
    }
  case .UP:    player.z += (player.z < (len(st.bmap) - 1)) ? 1 : 0
  case .DOWN:    player.z -= (0        < player.z)           ? 1 : 0
  }

  if st.player != player
  {
    st.player  = player
    return true
  }
  return false
}

load_block_map :: proc(bmap_filename: string) -> (success: bool)
{
  path_string:  string
  path_cstring: cstring

  path_string = path.join({cfg.maps_dir, bmap_filename}) 
  data: []byte
  {
    ok: bool
    data, ok = os.read_entire_file_from_filename(path_string)
    delete(path_string)
    if !ok
    {
      log.errorf("Could not open map file '%v'", bmap_filename)
      return false
    }
  }

  is_value_type :: proc(
    val: json.Value,
    exp: enum { NULL, INTEGER, FLOAT, BOOLEAN, STRING, ARRAY, OBJECT }) -> bool
  {
    #partial switch type in val
    {
    case json.Null:    return exp == .NULL
    case json.Integer: return exp == .INTEGER
    case json.Float:   return exp == .FLOAT
    case json.Boolean: return exp == .BOOLEAN
    case json.String:  return exp == .STRING
    case json.Array:   return exp == .ARRAY
    case json.Object:  return exp == .OBJECT
    }
    return false
  }

  root_val: json.Value
  root_obj: json.Object
  {
    err: json.Error
    root_val, err = json.parse(data, parse_integers = true)
    if err != .None
    {
      log.errorf("'%v': could not parse map JSON", bmap_filename)
      return false
    }
    delete(data)

    if !is_value_type(root_val, .OBJECT)
    {
      log.errorf("'%v': root not an object", bmap_filename)
      return false
    }
    root_obj = root_val.(json.Object)
  }
  defer json.destroy_value(root_val)

  width, length, depth: int
  {
    dims_val, exists := root_obj["dimensions"]
    if !exists
    {
      log.errorf("'%v': 'dimensions' field not found", bmap_filename)
      return false
    }
    if !is_value_type(dims_val, .OBJECT)
    {
      log.errorf("'%v': 'dimensions' field not an object", bmap_filename)
      return false
    }
    dims_obj := dims_val.(json.Object)

    for dim_key, dim_val in dims_obj
    {
      dim_ptr: ^int
      switch dim_key
      {
      case "width":  dim_ptr = &width
      case "length": dim_ptr = &length
      case "depth":  dim_ptr = &depth
      case:
        log.errorf("'%v':'dimensions': '%v' is not a valid dimension",
          bmap_filename, dim_key)
        continue
      }
      if !is_value_type(dim_val, .INTEGER)
      {
        log.errorf("'%v':'dimensions':'%v': not an integer",
          bmap_filename, dim_key)
        continue
      }
      dim_ptr^ = int(dim_val.(json.Integer))
    }
    if width <= 0 || length <= 0 || depth <= 0
    {
      log.errorf("'%v':'dimensions': one or more dimensions invalid",
        bmap_filename)
      return false
    }
  }

  res_obj: json.Object
  load_res_obj:
  {
    res_val, exists := root_obj["resources"]
    if !exists
    {
      log.warnf("'%v': 'resources' field not found", bmap_filename)
    }
    if !is_value_type(res_val, .OBJECT)
    {
      log.errorf("'%v':'resources': not an object")
      break load_res_obj
    }
    res_obj = res_val.(json.Object) 
  }

  faces_obj: json.Object
  load_faces_obj:
  {
    faces_val, exists := res_obj["faces"]
    if !exists
    {
      log.warnf("'%v':'resources': 'faces' field not found", bmap_filename)
    }
    if !is_value_type(faces_val, .OBJECT)
    {
      log.errorf("'%v':'resources':'faces': not an object")
      break load_faces_obj
    }
    faces_obj = faces_val.(json.Object)
  }

  read_faces:
  for face_key, face_val in faces_obj
  {
    face: Face

    if !is_value_type(face_val, .OBJECT)
    {
      log.errorf("'%v':'resources':'faces':'%v': not an object",
        bmap_filename, face_key)
      continue read_faces
    }
    face_obj := face_val.(json.Object)

    read_base:
    {
      base_val, exists := face_obj["base"]
      if !exists
      {
        log.errorf("'%v':'resources':'faces':'%v': 'base' field not found",
          bmap_filename, face_key)
        continue read_faces
      }
      if !is_value_type(base_val, .STRING)
      {
        log.errorf("'%v':'resources':'faces':'%v':'base': not a string",
          bmap_filename, face_key)
        continue read_faces
      }

      base_string := base_val.(json.String)

      path_string = path.join({cfg.img_dir, base_string})
      path_cstring = str.clone_to_cstring(path_string)
      delete(path_string)
      face.base = rl.LoadTexture(path_cstring)
      delete(path_cstring)
      if !rl.IsTextureValid(face.base)
      {
        log.errorf(
          "'%v':'resources':'faces':'%v':'base': error loading texture",
          bmap_filename, face_key)
        continue read_faces
      }
    }

    read_side:
    {
      side_val, exists := face_obj["side"]
      if !exists
      {
        log.infof("'%v':'resources':'faces':'%v': 'side' field not found",
          bmap_filename, face_key)
        break read_side
      }
      if !is_value_type(side_val, .OBJECT)
      {
        log.errorf("'%v':...:'%v':'side': not an object",
          bmap_filename, face_key)
        break read_side
      }

      read_angles:
      for angle_key, angle_val in side_val.(json.Object)
      {
        angle_index: Angle
        switch angle_key
        {
        case "v0":   angle_index = .V0
        case "h90":  angle_index = .H90
        case "v180": angle_index = .V180
        case "h270": angle_index = .H270
        case:
          log.errorf("'%v':...:'%v':'side': '%v' is not a valid angle key",
            bmap_filename, face_key, angle_key)
          continue read_angles
        }
        if !is_value_type(angle_val, .OBJECT)
        {
          log.errorf("'%v':...:'%v':'side':'%v': not an object",
            bmap_filename, face_key, angle_key)
          continue read_angles
        }

        read_pos:
        for pos_key, pos_val in angle_val.(json.Object)
        {
          pos_index: SideAnglePosition
          switch pos_key
          {
          case "lesser":  pos_index = .LESSER
          case "equal":   pos_index = .EQUAL
          case "greater": pos_index = .GREATER
          case:
            log.errorf(
              "'%v':...:'%v':'side':'%v': '%v' is not a valid position key",
              bmap_filename, face_key, angle_key, pos_key)
            continue read_pos
          }
          if !is_value_type(pos_val, .STRING)
          {
            log.errorf("'%v':...:'%v':'side':'%v':'%v': not a string",
              bmap_filename, face_key, angle_index, pos_key)
            continue read_pos
          }

          txr, err := new(rl.Texture)
          if err != .None
          {
            log.errorf(
              "'%v':...:'%v':'side':'%v':'%v': could not allocate texture",
              bmap_filename, face_key, angle_index, pos_index)
            continue read_pos
          }
          path_string = path.join({cfg.img_dir, pos_val.(json.String)})
          path_cstring = str.clone_to_cstring(path_string)
          delete(path_string)
          txr^ = rl.LoadTexture(path_cstring)
          delete(path_cstring)
          if !rl.IsTextureValid(txr^)
          {
            log.errorf(
              "'%v':...:'%v':'side':'%v':'%v': could not load texture",
              bmap_filename, face_key, angle_index, pos_index)
            free(txr)
            continue read_pos
          }

          face.side[angle_index][pos_index] = txr
        }
      }
    }
    st.faces[face_key] = face
  }

  blocks_obj: json.Object
  load_blocks_obj:
  {
    blocks_val, exists := res_obj["blocks"]
    if !exists
    {
      log.errorf("'%v':'resources': 'blocks' field not found", bmap_filename)
      break load_blocks_obj
    }
    if !is_value_type(blocks_val, .OBJECT)
    {
      log.errorf("'%v':'resources':'blocks': not an object", bmap_filename)
      break load_blocks_obj
    }
    blocks_obj = blocks_val.(json.Object)
  }

  read_blocks:
  for block_key, block_val in blocks_obj
  {
    block: Block

    if !is_value_type(block_val, .OBJECT)
    {
      log.errorf("'%v':'resources':'blocks':'%v': not an object",
        bmap_filename, block_key)
      continue read_blocks
    }

    read_fdirs:
    for fdir_key, face_key_val in block_val.(json.Object)
    {
      fdir_index: FaceDirection
      switch fdir_key
      {
      case "top":    fdir_index = .TOP
      case "north":  fdir_index = .NORTH
      case "east":   fdir_index = .EAST
      case "south":  fdir_index = .SOUTH
      case "west":   fdir_index = .WEST
      case "bottom": fdir_index = .BOTTOM
      case:
        log.errorf("'%v':...:'%v': '%v' is not a valid face direction key",
          bmap_filename, block_key, fdir_key)
        continue read_fdirs
      }
      if !is_value_type(face_key_val, .STRING)
      {
        log.errorf("'%v':...:'%v':'%v': not a string",
          bmap_filename, block_key, fdir_key)
        continue read_fdirs
      }
      exists: bool
      block.faces[fdir_index], exists = &st.faces[face_key_val.(json.String)]
      if !exists
      {
        log.errorf("'%v':...'%v':'%v': not in memory",
          bmap_filename, block_key, fdir_key)
        continue read_fdirs
      }
    }

    st.blocks[block_key] = block
  }

  read_layout:
  {
    free_block_map()

    layout_val, exists := root_obj["layout"]
    if !exists
    {
      log.errorf("'%v': 'layout' field not found")
      return false
    }
    if !is_value_type(layout_val, .ARRAY)
    {
      log.errorf("'%v':'layout': not an array")
      return false
    }

    layout_arr := layout_val.(json.Array)
    st.bmap = make(BlockMap, depth)

    actual_depth := len(layout_arr)
    if actual_depth != depth
    {
      log.warnf("'%v':'layout': 'depth' does not match", bmap_filename)
    }

    z_limit := min(depth, actual_depth)
    for z := 0; z < z_limit; z += 1
    {
      if !is_value_type(layout_arr[z], .ARRAY)
      {
        log.errorf("'%v':'layout':%v: not an aray", bmap_filename, z)
        free_block_map()
        return false
      }

      layer_arr := layout_arr[z].(json.Array)
      st.bmap[z] = make([][]^Block, length)

      actual_length := len(layer_arr)
      if actual_length != length
      {
        log.warnf("'%v':'layout':%v: length does not match", bmap_filename, z)
      }

      y_limit := min(length, actual_length)
      for y := 0; y < y_limit; y += 1
      {
        if !is_value_type(layer_arr[y], .ARRAY)
        {
          log.errorf("'%v':'layout':%v:%v: not an array", bmap_filename, z, y)
          free_block_map()
          return false
        }

        row_arr := layer_arr[y].(json.Array)
        st.bmap[z][y] = make([]^Block, width)

        actual_width := len(row_arr)
        if actual_width != width
        {
          log.warnf("'%v':'layout':%v:%v: width does not match",
            bmap_filename, z, y)
        }

        x_limit := min(width, actual_width)
        row_loop:
        for x := 0; x < x_limit; x += 1
        {
          block_key_val := row_arr[x]

          if is_value_type(block_key_val, .NULL)
          {
            continue row_loop
          }
          if !is_value_type(block_key_val, .STRING)
          {
            log.errorf("'%v':'layout':%v:%v:%v: not a string",
              bmap_filename, z, y, x)
            free_block_map()
            return false
          }

          block_key_string := block_key_val.(json.String)
          block_ptr, exists := &st.blocks[block_key_string]
          if !exists
          {
            log.errorf("'%v':'layout':%v:%v:%v: '%v' not in memory",
              bmap_filename, z, y, x, block_key_string)
            continue row_loop
          }

          st.bmap[z][y][x] = block_ptr
        }
      }
    }
  }
  return true
}

init :: proc(
  maps_dir     : string,
  img_dir      : string, 
  cur_txr_path : cstring, 
  cur_offsets  : []rl.Vector2
  ) -> bool
{
  cfg.maps_dir = maps_dir
  cfg.img_dir  = img_dir

  if len(cur_offsets) != int(CursorState.COUNT)
  {
    log.error("Offset array has an invalid size")
    return false
  }
  if !cur.add_field(CURSOR_FIELD_ID, cur_txr_path, cur_offsets)
  {
    log.error("Could not add cursor field")
    return false
  }

  return true
}

fini :: proc()
{
  free_block_map()

  delete(st.blocks)

  for key, &face in st.faces
  {
    rl.UnloadTexture(face.base)
    for angle in face.side
    {
      for disp in angle
      {
        //rl.UnloadTexture(disp^)
        free(disp)
      }
    }
  }
  delete(st.faces)
}