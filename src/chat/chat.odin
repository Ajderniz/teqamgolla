package chat

import      "core:encoding/json"
import      "core:log"
import      "core:mem/virtual"
import      "core:os"
import path "core:path/filepath"

@(private)
Option :: struct { 
  triggers : []cstring,
  txt      : cstring,
  next     : string
}

@(private)
OptionList :: distinct []Option

@(private)
Message :: struct {
  keys : []cstring,
  txt  : cstring,
  next : union { string, OptionList }
}

@(private) START_KEY       :: "start"

@(private) DEFAULT_MSG_TXT :: "..."
@(private) CHAT_NEXT_TXT   :: "Continue"
@(private) CHAT_END_TXT    :: "End"

@(private)
cfg : struct {
  dir: string,
}

@(private)
st : struct {
  arena   : virtual.Arena,
  chat    : map[string]Message,
  current : ^Message,
}

init :: proc(dir: string)
{
  cfg.dir = dir
}

fini :: proc()
{
  virtual.arena_destroy(&st.arena)
  st.current = nil
}

load :: proc(filename: string) -> (ok: bool)
{
  data: []byte
  {
    chat_path, aerr := path.join({cfg.dir, filename})
    err: os.Error
    data, err = os.read_entire_file(chat_path, context.allocator)
    delete(chat_path)
    if !ok
    {
      log.errorf("Could not open chat file '%v'", filename)
      return false
    }
  }
  defer delete(data)

  alloc := virtual.arena_allocator(&st.arena)

  clear(&st.chat)
  {
    err := json.unmarshal(data, &st.chat, allocator = alloc)
    if err != nil
    {
      log.errorf("Could not unmarshal JSON: '%v'", err)
      return false
    }
  }

  if START_KEY not_in st.chat
  {
    log.errorf("'%s' key not found", START_KEY)
    return false
  }

  for key, msg in st.chat
  {
    switch next in msg.next
    {
    case string:
      if next not_in st.chat
      {
        log.errorf("'%v':'next': key '%v' nonexistent", key, next)
        return false
      }
    case OptionList:
      for opt, i in next
      {
        if opt.next not_in st.chat
        {
          log.errorf("'%v':'next':%v: key '%v' nonexistent", key, i, opt.next)
          return false
        }
      }
    }
  }

  return true
}

choose :: proc(next: string) -> (ok: bool)
{
  if next not_in st.chat
  {
    log.errorf("Key '%v' nonexistent", next)
    return false
  }
  st.current = &st.chat[next]
  return true
}

get_current_message :: #force_inline proc() -> ^Message
{
  return st.current
}