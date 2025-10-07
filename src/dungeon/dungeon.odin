package dungeon

import    "core:log"
import    "core:math"

import rl "vendor:raylib"

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

Vector3Int :: struct { x, y, z: int }

Face :: struct {
  texture : rl.Texture,
  angles  : map[Angle]^rl.Texture
}

Block :: struct {
  faces : map[Direction]^Face,
  floor : ^Face,
  ceil  : ^Face,
}

BlockMap :: [][][]^Block

PlayerState :: struct {
  using pos: Vector3Int,
  dir: Direction,
}

@(private)
draw_block_at_fov_position :: proc(
  pos       : struct { side, forw, elev: int },
  scr_size  : rl.Vector2,
  zero_size : rl.Vector2,
  stretch   : f32
  )
{
  near_size := rl.Vector2 {
      math.trunc(zero_size.x / math.pow(stretch, f32(pos.forw))),
      math.trunc(zero_size.y / math.pow(stretch, f32(pos.forw))),
  }
  near_pos := rl.Vector2 {
    // Origin                                  +  Offset
    math.trunc((scr_size.x - near_size.x) / 2) + (near_size.x * f32(pos.side)),
    math.trunc((scr_size.y - near_size.y) / 2) + (near_size.y * f32(pos.elev))
  }

  color := rl.ORANGE
  if 0 < pos.forw || pos.side != 0
  {
    color.r /= u8(pos.forw + math.abs(pos.side) )
    color.g /= u8(pos.forw + math.abs(pos.side) )
    color.b /= u8(pos.forw + math.abs(pos.side) )
  }

  rl.DrawRectangleLinesEx(
    {
      near_pos.x,
      near_pos.y,
      near_size.x,
      near_size.y,
    },
    1,
    color)

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

    if pos.side != 0
    {
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
      }
      else
      {
        points[0].x = near_pos.x
        points[1].x = far_pos.x
        points[2].x = far_pos.x
        points[3].x = near_pos.x
      }
      rl.DrawLineStrip(points, 4, color)
    }
    if pos.elev != 0
    {
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
      }
      else
      {
        points[0].y = near_pos.y
        points[1].y = far_pos.y
        points[2].y = far_pos.y
        points[3].y = near_pos.y
      }
      rl.DrawLineStrip(points, 4, color)
    }
  }
}

update_first_person :: proc(
  bmap    : BlockMap,
  player  : PlayerState,
  rtxr    : rl.RenderTexture,
  stretch : f32
  )
{
  fov: [3][5][3]^Block
  set_fov:
  {
    pos := player.pos
    dir := player.dir

    elev := -(len(fov) / 2)
    for &layer in fov
    {
      z := pos.z + elev
      elev += 1
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
          switch dir
          {
          case .NORTH: x = pos.x + side
          case .EAST:  y = pos.y + side
          case .SOUTH: x = pos.x - side
          case .WEST:  y = pos.y - side
          }
          side += 1
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

    z := len(fov) / 2
    for layer in fov
    {
      #reverse for row, y in layer
      {
        x := -(len(row) / 2)
        for block in row
        {
          if nil == block
          {
            x += 1
            continue
          }
          draw_block_at_fov_position(
            { x, y, z },
            { f32(rtxr.texture.width), f32(rtxr.texture.height) },
            zero_size,
            stretch
            )

          x += 1
        }
      }
      z -= 1
    }
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
    for bz := player.z; 0 <= bz; bz -= 1
    {
      by := player.y - half_mm_size
      for y := 0; y <= mm_size; y += 1
      {
        if by < 0 || player.y + (mm_size/2) < by || len(bmap[bz]) <= by
        {
          by += 1
          continue
        }
        bx := player.x - half_mm_size
        for x := 0; x <= mm_size; x += 1
        {
          if bx < 0 || player.x + half_mm_size < bx || len(bmap[bz][by]) <= bx||
             nil == bmap[bz][by][bx] ||
             (bz < player.z && bmap[bz+1][by][bx] != nil)
          {
            bx += 1
            continue
          }
          rl.DrawRectangleRec(
            { f32(x) * block_size, f32(y) * block_size, block_size, block_size},
            color)

          bx += 1
        }
        by += 1
      }
      color.r -= (25 <= color.r) ? 25 : 0
      color.g -= (25 <= color.g) ? 25 : 0
      color.b -= (25 <= color.b) ? 25 : 0
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