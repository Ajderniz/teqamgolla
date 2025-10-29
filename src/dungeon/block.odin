package dungeon

import    "core:math"
import    "core:log"

import rl "vendor:raylib"

@(private)
draw_block_at_fov_position :: proc(
  block     : Block,

  pos       : Move3,
  options   : BlockDrawOptions,

  scr_size  : rl.Vector2,
  zero_size : rl.Vector2,
  )
{
  if pos == { 0, 0 ,0 }
  {
    return
  }

  near_size := rl.Vector2 {
      math.trunc(zero_size.x / math.pow(PERSPECTIVE_STRETCH, f32(pos.forw))),
      math.trunc(zero_size.y / math.pow(PERSPECTIVE_STRETCH, f32(pos.forw))),
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
    switch st.player.dir
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
        math.trunc(near_size.x / PERSPECTIVE_STRETCH),
        math.trunc(near_size.y / PERSPECTIVE_STRETCH) 
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

        switch st.player.dir
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

        switch st.player.dir
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
        switch st.player.dir
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

