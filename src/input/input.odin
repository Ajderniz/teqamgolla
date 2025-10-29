package common

import rl "vendor:raylib"

InputState :: struct {
  key_pressed          : rl.KeyboardKey,
  mouse_button_pressed : rl.MouseButton,
  mouse_wheel_move     : f32,
  mouse_pos            : rl.Vector2,
}

get_mouse_button_pressed :: proc() -> rl.MouseButton
{
  if rl.IsMouseButtonPressed(.LEFT)
  {
    return .LEFT
  }
  else if rl.IsMouseButtonPressed(.RIGHT)
  {
    return .RIGHT
  }
  else if rl.IsMouseButtonPressed(.MIDDLE)
  {
    return .MIDDLE
  }
  return .BACK
}

get_input_state :: proc() -> InputState
{
  state: InputState
  state.mouse_pos            = rl.GetMousePosition()
  state.mouse_button_pressed = get_mouse_button_pressed()
  state.mouse_wheel_move     = rl.GetMouseWheelMove()
  state.key_pressed          = rl.GetKeyPressed()
  return state
}