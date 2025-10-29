package dungeon

import rl "vendor:raylib"

update_minimap_rtxr :: proc(
  rtxr    : rl.RenderTexture,
  mm_size : int,
  ) {
  
  if len(st.bmap) <= 0
  {
    return
  }

  block_size := f32(min(rtxr.texture.width, rtxr.texture.height) / i32(mm_size))
  half_mm_size := mm_size / 2

  rl.BeginTextureMode(rtxr)
  {
    rl.ClearBackground(rl.DARKPURPLE)

    color := rl.ORANGE
    color_step : u8 : 25
    {
      sub := u8(st.player.z + 1) * color_step
      color.r = (sub <= color.r) ? color.r - sub : 0
      color.g = (sub <= color.g) ? color.g - sub : 0
      color.b = (sub <= color.b) ? color.b - sub : 0
    }
    for bz := 0; bz <= st.player.z; bz += 1
    {
      by := st.player.y - half_mm_size
      for y := 0; y <= mm_size; y += 1
      {
        defer by += 1

        if by < 0 ||
           (st.player.y + half_mm_size) < by ||
           len(st.bmap[bz]) <= by
        {
          continue
        }

        bx := st.player.x - half_mm_size
        for x := 0; x <= mm_size; x += 1
        {
          defer bx += 1

          if bx < 0 || (st.player.x + half_mm_size) < bx ||
             len(st.bmap[bz][by]) <= bx || nil == st.bmap[bz][by][bx]
          {
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
    switch st.player.dir
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

