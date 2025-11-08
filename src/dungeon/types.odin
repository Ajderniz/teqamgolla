package dungeon

import rl "vendor:raylib"

Vector3Int :: struct { x, y, z: int }
Move3      :: struct { side, forw, elev: int }

Angle     :: enum { V0, H90, V180, H270 }

Direction :: enum { NORTH, EAST, SOUTH, WEST }

CursorState :: enum
{
  FRONT,
  BACK,
  STRAFE_LEFT,
  STRAFE_RIGHT,
  TURN_LEFT, 
  TURN_RIGHT, 
  COUNT
}

PlayerMovement :: enum {
  NONE,
  FRONT, 
  BACK, 
  STRAFE_LEFT, 
  STRAFE_RIGHT, 
  TURN_LEFT, 
  TURN_RIGHT, 
  UP, 
  DOWN 
}

PlayerState :: struct {
  using pos: Vector3Int,
  dir: Direction,
}

SideAnglePosition :: enum { LESSER, EQUAL, GREATER }
Face :: struct {
  base : rl.Texture,
  side : [Angle][SideAnglePosition]^rl.Texture
}

FaceDirection :: enum { TOP, NORTH, EAST, SOUTH, WEST, BOTTOM }
Block :: struct {
  faces : [FaceDirection]^Face
}

BlockMap :: [][][]^Block

@(private) BlockFOV :: [5][5][5]^Block
@(private) BlockDrawOptions :: bit_set[enum{ FRONT, SIDE_V, SIDE_H }]
