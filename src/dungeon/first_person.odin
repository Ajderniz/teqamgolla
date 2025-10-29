package dungeon

import    "core:log"

import rl "vendor:raylib"

update_first_person_rtxr :: proc(rtxr: rl.RenderTexture)
{
  if len(st.bmap) <= 0
  {
    return
  }

  fov: BlockFOV
  build_fov:
  {
    pos := st.player.pos
    dir := st.player.dir

    elev := -(len(fov) / 2)
    for &layer in fov
    {
      defer elev += 1

      z := pos.z + elev
      if z < 0 || len(st.bmap) <= z
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
        if y < 0 || len(st.bmap[0]) <= y || x < 0 || len(st.bmap[0][0]) <= x
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

          if y < 0 || len(st.bmap[0]) <= y || x < 0 || len(st.bmap[0][0]) <= x
          {
            continue
          }

          block = st.bmap[z][y][x]
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
            { side, forw, -elev },
            options,
            rtxr_size,
            zero_size
            )
        }
      }
    }

    half_depth := len(fov) / 2

    for elev := -half_depth; elev <= 1; elev +=1
    {
      draw_layer(
        fov,
        elev,
        elev + half_depth,
        {f32(rtxr.texture.width), f32(rtxr.texture.height)},
        zero_size
        )
    }
    for elev := half_depth; 1 <= elev; elev -=1
    {
      draw_layer(
        fov,
        elev,
        elev + half_depth,
        {f32(rtxr.texture.width), f32(rtxr.texture.height)},
        zero_size
        )
    }
    draw_layer(
      fov,
      0,
      half_depth,
      {f32(rtxr.texture.width), f32(rtxr.texture.height)},
      zero_size,
      )
  }
  rl.EndTextureMode()
}
