package common

import rl "vendor:raylib"

is_v2_within_rec :: #force_inline proc(
  v2: rl.Vector2,
  rec: rl.Rectangle) -> bool
{
  return(!((v2.x < rec.x || (rec.x + rec.width) < v2.x) ||
          (v2.y < rec.y || (rec.y + rec.height) < v2.y)))
}
