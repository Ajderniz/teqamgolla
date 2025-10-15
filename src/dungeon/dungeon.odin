package dungeon

import    "core:log"
import    "core:math"

import rl "vendor:raylib"
import    "vendor:raylib/rlgl"

Vector3Int :: struct { x, y, z: int }
Vector2Int :: struct { x, y: int }
Move3      :: struct { side, forw, elev: int }

Angle     :: enum { 
  V0   = 0,
  H90  = 90,
  V180 = 180,
  H270 = 270,
}

Direction :: enum {
  NORTH = int(Angle.V0),
  EAST  = int(Angle.H90),
  SOUTH = int(Angle.V180),
  WEST  = int(Angle.H270),
}

Face :: struct {
  base : rl.Texture,
  side : map[Angle][enum{LESSER, EQUAL, GREATER}]^rl.Texture
}

Block :: struct {
  faces : [enum{TOP, NORTH, EAST, SOUTH, WEST, BOTTOM}]^Face
}

BlockMap :: [][][]^Block
@(private) BlockFOV :: [3][5][5]^Block

PlayerState :: struct {
  using pos: Vector3Int,
  dir: Direction,
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

@(private) BlockDrawOptions :: bit_set[enum{ FRONT, SIDE_V, SIDE_H }]
@(private)
draw_block_at_fov_position :: proc(
  block     : Block,
  dir       : Direction,

  pos       : Move3,
  options   : BlockDrawOptions,

  scr_size  : rl.Vector2,
  zero_size : rl.Vector2,
  stretch   : f32
  )
{
  if pos == { 0, 0 ,0 }
  {
    return
  }

  near_size := rl.Vector2 {
      math.trunc(zero_size.x / math.pow(stretch, f32(pos.forw))),
      math.trunc(zero_size.y / math.pow(stretch, f32(pos.forw))),
  }
  near_pos := rl.Vector2 {
    // Origin                                  +  Offset
    math.trunc((scr_size.x - near_size.x) / 2) + (near_size.x * f32(pos.side)),
    math.trunc((scr_size.y - near_size.y) / 2) + (near_size.y * f32(pos.elev))
  }

  color := rl.WHITE
  if 0 < pos.forw || pos.side != 0
  {
    color.r /= u8(math.abs(pos.side) + pos.forw + math.abs(pos.elev))
    color.g /= u8(math.abs(pos.side) + pos.forw + math.abs(pos.elev))
    color.b /= u8(math.abs(pos.side) + pos.forw + math.abs(pos.elev))
  }

  face: ^Face

  if .FRONT in options
  {
    switch dir
    {
    case .NORTH: face = block.faces[.SOUTH]
    case .EAST:  face = block.faces[.WEST]
    case .SOUTH: face = block.faces[.NORTH]
    case .WEST:  face = block.faces[.EAST]
    }
    if face != nil && rl.IsTextureValid(face.base)
    {
      rl.DrawTexturePro(
        face.base,
        { 0, 0, f32(face.base.width), f32(face.base.height) },
        { near_pos.x, near_pos.y, near_size.x, near_size.y },
        { 0, 0 },
        0,
        color
        )
    }
    else
    {
      rl.DrawRectangleLinesEx(
        {
          near_pos.x,
          near_pos.y,
          near_size.x,
          near_size.y,
        },
        1,
        color
        )
    }
  }

  side_faces:
  {
    if 0 == pos.side && 0 == pos.elev
    {
      break side_faces
    }

    far_size := rl.Vector2 {
        math.trunc(near_size.x / stretch),
        math.trunc(near_size.y / stretch) 
    }
    far_pos: rl.Vector2 = {
      // Origin                                 +  Offset
      math.trunc((scr_size.x - far_size.x) / 2) + (far_size.x * f32(pos.side)),
      math.trunc((scr_size.y - far_size.y) / 2) + (far_size.y * f32(pos.elev))
    }
    near_edg := rl.Vector2 { near_pos.x + near_size.x, near_pos.y + near_size.y}
    far_edg  := rl.Vector2 { far_pos.x  + far_size.x,   far_pos.y + far_size.y }

    points := make([^]rl.Vector2, 4)
    defer free(points)

    txr: ^rl.Texture

    if pos.side != 0 && .SIDE_V in options
    {
      rotation: f32
      face = nil

      points[0].y = near_pos.y
      points[1].y = far_pos.y
      points[2].y = far_edg.y
      points[3].y = near_edg.y

      if pos.side < 0
      {
        points[0].x = near_edg.x
        points[1].x = far_edg.x
        points[2].x = far_edg.x
        points[3].x = near_edg.x

        switch dir
        {
        case .NORTH: face = block.faces[.EAST]
        case .EAST:  face = block.faces[.SOUTH]
        case .SOUTH: face = block.faces[.WEST]
        case .WEST:  face = block.faces[.NORTH]
        }
        if face != nil
        {
          set := face.side[.H270]
          switch pos.elev
          {
          case -1: txr = set[.GREATER]
          case  1: txr = set[.LESSER]
          case:    txr = set[.EQUAL]
          }
        }
        rotation = 90
      }
      else
      {
        points[0].x = near_pos.x
        points[1].x = far_pos.x
        points[2].x = far_pos.x
        points[3].x = near_pos.x

        switch dir
        {
        case .NORTH: face = block.faces[.WEST]
        case .EAST:  face = block.faces[.NORTH]
        case .SOUTH: face = block.faces[.EAST]
        case .WEST:  face = block.faces[.SOUTH]
        }
        if face != nil
        {
          set := face.side[.H90]
          switch pos.elev
          {
          case -1: txr = set[.LESSER]
          case  1: txr = set[.GREATER]
          case:    txr = set[.EQUAL]
          }
        }
        rotation = 270
      }
      if face != nil
      {
        if txr != nil && rl.IsTextureValid(txr^)
        {
          center := rl.Vector2 { f32(txr.width / 2), f32(txr.height / 2) }
          rl.DrawTexturePro(
            txr^,
            { 0, 0, f32(txr.width), f32(txr.height) },
            { 
              (min(points[0].x, points[1].x) + center.x),
              (min(points[0].y, points[1].y) + center.y),
              abs(points[0].x - points[1].x),
              (points[3].y - points[0].y)
            },
            center,
            rotation,
            color)
        }
        else if rl.IsTextureValid(face.base)
        {
          tl, bl, br, tr: rl.Vector2
          if points[0].x < points[1].x
          {
            tl = points[0]
            bl = points[3]
            br = points[2]
            tr = points[1]
          }
          else
          {
            tl = points[1]
            bl = points[2]
            br = points[3]
            tr = points[0]
          }
          draw_texture_skewed(face.base, tl, bl, br, tr, Angle.V0, color)
        }
      }
      else
      {
        rl.DrawLineStrip(points, 4, color)
      }
    }

    if pos.elev != 0 && .SIDE_H in options
    {
      surf_color := color
      angle: Angle
      face = nil

      points[0].x = near_pos.x
      points[1].x = far_pos.x
      points[2].x = far_edg.x
      points[3].x = near_edg.x

      if pos.elev < 0
      {
        points[0].y = near_edg.y
        points[1].y = far_edg.y
        points[2].y = far_edg.y
        points[3].y = near_edg.y

        face = block.faces[.BOTTOM]

        surf_color.r = (50 <= surf_color.r) ? surf_color.r - 50 : 0
        surf_color.g = (50 <= surf_color.g) ? surf_color.g - 50 : 0
        surf_color.b = (50 <= surf_color.b) ? surf_color.b - 50 : 0
      }
      else
      {
        points[0].y = near_pos.y
        points[1].y = far_pos.y
        points[2].y = far_pos.y
        points[3].y = near_pos.y

        face = block.faces[.TOP]

        surf_color.r = (surf_color.r < 255) ? surf_color.r + 50 : 255
        surf_color.g = (surf_color.g < 255) ? surf_color.g + 50 : 255
        surf_color.b = (surf_color.b < 255) ? surf_color.b + 50 : 255
      }

      if face != nil
      {
        switch dir
        {
        case .NORTH: angle = .V0
        case .EAST:  angle = .H270
        case .SOUTH: angle = .V180
        case .WEST:  angle = .H90
        }
        {
          set := face.side[angle]
          switch pos.side
          {
          case -1: txr = set[.LESSER]
          case  1: txr = set[.GREATER]
          case:    txr = set[.EQUAL]
          }
        }
        if txr != nil && rl.IsTextureValid(txr^)
        {
          rl.DrawTexturePro(
            txr^,
            { 0, 0, f32(txr.width), f32(txr.height) },
            { 
              min(points[0].x, points[1].x),
              min(points[0].y, points[1].y),
              points[3].x - points[0].x,
              abs(points[0].y - points[1].y)
            },
            { 0, 0 },
            0,
            surf_color)
        }
        else
        {
          tl, bl, br, tr: rl.Vector2
          if points[0].y < points[1].y
          {
            tl = points[0]
            bl = points[1]
            br = points[2]
            tr = points[3]
          }
          else
          {
            tl = points[1]
            bl = points[0]
            br = points[3]
            tr = points[2]
          }
          draw_texture_skewed(face.base, tl, bl, br, tr, angle, surf_color)
        }
      }
      else
      {
        rl.DrawLineStrip(points, 4, surf_color)
      }
    }
  }
}

@(private)
is_block_visible :: proc(dst: Move3, fov: BlockFOV)-> bool
{
  dif_side := dst.side
  inc_side := 1
  if dst.side < 0
  {
    dif_side = -dif_side
    inc_side = -1
  }
  err_side := (2 * dif_side) - dst.forw

  dif_elev := dst.elev
  inc_elev := 1
  if dst.elev < 0
  {
    dif_elev = -dif_elev
    inc_elev = -1
  }
  err_elev := (2 * dif_elev) - dst.forw

  side, elev := 0, 0
  for forw in 0..<(dst.forw+1)
  {
    if side == dst.side && forw == dst.forw && elev == dst.elev
    {
      break
    }
    if fov[elev + (len(fov)/2)][forw][side + (len(fov[0][0])/2)] != nil
    {
      return false
    }

    if 0 < err_side
    {
      side     += inc_side
      err_side += 2 * (dif_side - dst.forw)
    }
    else
    {
      err_side += 2 * dif_side
    }

    if 0 < err_elev
    {
      elev     += inc_elev
      err_elev += 2 * (dif_elev - dst.forw)
    }
    else
    {
      err_elev += 2 * dif_elev
    }
  }
  return true
}

update_first_person :: proc(
  bmap    : BlockMap,
  player  : PlayerState,
  rtxr    : rl.RenderTexture,
  stretch : f32
  )
{
  fov: BlockFOV
  build_fov:
  {
    pos := player.pos
    dir := player.dir

    elev := -(len(fov) / 2)
    for &layer in fov
    {
      defer elev += 1

      z := pos.z + elev
      if z < 0 || len(bmap) <= z
      {
        continue
      }
      for &row, forw in layer
      {
        x, y: int

        switch dir
        {
        case .NORTH: y = pos.y - forw
        case .EAST:  x = pos.x + forw
        case .SOUTH: y = pos.y + forw
        case .WEST:  x = pos.x - forw
        }
        if y < 0 || len(bmap[0]) <= y || x < 0 || len(bmap[0][0]) <= x
        {
          continue
        }

        side := -(len(row) / 2)
        for &block in row
        {
          defer side += 1

          switch dir
          {
          case .NORTH: x = pos.x + side
          case .EAST:  y = pos.y + side
          case .SOUTH: x = pos.x - side
          case .WEST:  y = pos.y - side
          }

          if y < 0 || len(bmap[0]) <= y || x < 0 || len(bmap[0][0]) <= x
          {
            continue
          }

          block = bmap[z][y][x]
        }
      }
    }
  }


  rl.BeginTextureMode(rtxr)
  {
    rl.ClearBackground(rl.BLACK)

    zero_size := rl.Vector2 {
      f32(rtxr.texture.width)  * 1.5,
      f32(rtxr.texture.height) * 1.5
    }

    draw_layer :: proc(
      fov       : BlockFOV,
      elev, z   : int,
      rtxr_size : rl.Vector2,
      zero_size : rl.Vector2,
      dir       : Direction,
      stretch   : f32,
      )
    {
      layer := fov[z]

      #reverse for row, forw in layer
      {
        side := -(len(row) / 2)
        for block, x in row
        {
          defer side += 1

          if nil == block
          {
            continue
          }
          if 2 <= forw && (elev < -1 || 1 < elev) && 
             !is_block_visible({side, forw, elev}, fov)
          {
            continue
          }

          options: BlockDrawOptions

          if side < 0
          {
            options += (nil == row[x+1]) ? { .SIDE_V } : options
          }
          else if 0 < side
          {
            options += (nil == row[x-1]) ? { .SIDE_V } : options
          }

          if 0 < forw
          {
            options += (nil == layer[forw-1][x]) ? { .FRONT } : options
          }

          // Remember that for Z (just in this case), lower is higher
          if elev < 0
          {
            options += (nil == fov[z+1][forw][x]) ? {.SIDE_H } : options
          }
          else if 0 < elev
          {
            options += (nil == fov[z-1][forw][x]) ? {.SIDE_H } : options
          }

          draw_block_at_fov_position(
            block^,
            dir,
            { side, forw, -elev },
            options,
            rtxr_size,
            zero_size,
            stretch
            )
        }
      }
    }

    elev := -(len(fov) / 2)
    for layer, z in fov
    {
      defer elev += 1

      if 0 == elev
      {
        continue
      }

      draw_layer(
        fov,
        elev,
        z,
        {f32(rtxr.texture.width), f32(rtxr.texture.height)},
        zero_size,
        player.dir,
        stretch)
    }
    draw_layer(
      fov,
      0,
      len(fov)/2,
      {f32(rtxr.texture.width), f32(rtxr.texture.height)},
      zero_size,
      player.dir,
      stretch)
  }
  rl.EndTextureMode()
}

update_minimap :: proc(
  mm_size : int,
  bmap    : BlockMap,
  player  : PlayerState,
  rtxr    : rl.RenderTexture
  )
{
  block_size := f32(min(rtxr.texture.width, rtxr.texture.height) / i32(mm_size))
  half_mm_size := mm_size / 2

  rl.BeginTextureMode(rtxr)
  {
    rl.ClearBackground(rl.DARKPURPLE)

    color := rl.ORANGE
    color_step : u8 : 25
    {
      sub := u8(player.z + 1) * color_step
      color.r = (sub <= color.r) ? color.r - sub : 0
      color.g = (sub <= color.g) ? color.g - sub : 0
      color.b = (sub <= color.b) ? color.b - sub : 0
    }
    for bz := 0; bz <= player.z; bz += 1
    {
      by := player.y - half_mm_size
      for y := 0; y <= mm_size; y += 1
      {
        defer by += 1

        if by < 0 || (player.y + half_mm_size) < by || len(bmap[bz]) <= by
        {
          continue
        }

        bx := player.x - half_mm_size
        for x := 0; x <= mm_size; x += 1
        {
          defer bx += 1

          if bx < 0 || (player.x + half_mm_size) < bx || len(bmap[bz][by])<=bx||
             nil == bmap[bz][by][bx] {//||
             //(bz < player.z && bmap[bz+1][by][bx] != nil)
          //{
            continue
          }

          rl.DrawRectangleRec(
            { f32(x) * block_size, f32(y) * block_size, block_size, block_size},
            color)
        }
      }
      {
        limit :: 255 - color_step
        color.r = (color.r <= limit) ? color.r + color_step : 255
        color.g = (color.g <= limit) ? color.g + color_step : 255
        color.b = (color.b <= limit) ? color.b + color_step : 255
      }
    }

    half_block_size := block_size / 2
    pos : rl.Vector2 = f32(half_mm_size) * block_size
    edg := rl.Vector2 { pos.x + block_size, pos.y + block_size }

    points := make([^]rl.Vector2, 3)
    defer free(points)
    switch player.dir
    {
    case .NORTH:
      points[0] = { pos.x + half_block_size, pos.y }
      points[1] = { pos.x, edg.y }
      points[2] = { edg.x, edg.y }
    case .EAST:
      points[0] = { pos.x, pos.y }
      points[1] = { pos.x, edg.y }
      points[2] = { edg.x, pos.y + half_block_size }
    case .SOUTH:
      points[0] = { pos.x, pos.y }
      points[1] = { pos.x + half_block_size, edg.y }
      points[2] = { edg.x, pos.y }
    case .WEST:
      points[0] = { pos.x, pos.y + half_block_size }
      points[1] = { edg.x, edg.y }
      points[2] = { edg.x, pos.y } 
    }
    rl.DrawTriangleStrip(points, 3, rl.RED)
  }
  rl.EndTextureMode()
}