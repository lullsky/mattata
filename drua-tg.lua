-- Based on JuanPotato's lua-tg (https://github.com/juanpotato/lua-tg) Copyright (c) 2015-2016 Juan Potato Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
local SOCKET = require('socket')
local command_table = {
 add = { 'chat_add_user %s %s', 'channel_invite %s %s' },
 kick = { 'chat_del_user %s %s', 'channel_kick %s %s' },
 rename = { 'rename_chat %s "%s"', 'rename_channel %s "%s"' },
 link = { 'export_chat_link %s', 'export_channel_link %s' },
 photo_set = { 'chat_set_photo %s %s', 'channel_set_photo %s %s' },
 photo_get = { [0] = 'load_user_photo %s', 'load_chat_photo %s', 'load_channel_photo %s' },
 info = { [0] = 'user_info %s', 'chat_info %s', 'channel_info %s' }
}
local format_target = function(target)
 target = tonumber(target)
 if target < -1000000000000 then
  target = 'channel#' .. math.abs(target) - 1000000000000
  return target, 2
 elseif target < 0 then
  target = 'chat#' .. math.abs(target)
  return target, 1
 else
  target = 'user#' .. target
  return target, 0
 end
end
local escape = function(text)
 text = text:gsub('\\', '\\\\')
 text = text:gsub('\n', '\\n')
 text = text:gsub('\t', '\\t')
 text = text:gsub('"', '\\"')
 return text
end
local mattata = {
 IP = 'localhost',
 PORT = 4570
}
mattata.send = function(command, do_receive)
 local s = SOCKET.connect(mattata.IP, mattata.PORT)
 assert(s, '\nUnable to connect to tg session.')
 s:send(command..'\n')
 local output
 if do_receive then
  output = string.match(s:receive('*l'), 'ANSWER (%d+)')
  output = s:receive(tonumber(output)):gsub('\n$', '')
 end
 s:close()
 return output
end
mattata.message = function(target, text)
 target = format_target(target)
 text = escape(text)
 local command = 'msg %s "%s"'
 command = command:format(target, text)
 return mattata.send(command)
end
mattata.send_photo = function(target, photo)
 target = format_target(target)
 local command = 'send_photo %s %s'
 command = command:format(target, photo)
 return mattata.send(command)
end
mattata.add_user = function(chat, target)
 local a
 chat, a = format_target(chat)
 target = format_target(target)
 local command = command_table.add[a]:format(chat, target)
 return mattata.send(command)
end
mattata.kick_user = function(chat, target)
 mattata.get_info(chat)
 local a
 chat, a = format_target(chat)
 target = format_target(target)
 local command = command_table.kick[a]:format(chat, target)
 return mattata.send(command)
end
mattata.rename_chat = function(chat, name)
 local a
 chat, a = format_target(chat)
 local command = command_table.rename[a]:format(chat, name)
 return mattata.send(command)
end
mattata.export_link = function(chat)
 local a
 chat, a = format_target(chat)
 local command = command_table.link[a]:format(chat)
 return mattata.send(command, true)
end
mattata.get_photo = function(chat)
 local a
 chat, a = format_target(chat)
 local command = command_table.photo_get[a]:format(chat)
 local output = mattata.send(command, true)
 if output:match('FAIL') then
  return false
 else
  return output:match('Saved to (.+)')
 end
end
mattata.set_photo = function(chat, photo)
 local a
 chat, a = format_target(chat)
 local command = command_table.photo_set[a]:format(chat, photo)
 return mattata.send(command)
end
mattata.get_info = function(target)
 local a
 target, a = format_target(target)
 local command = command_table.info[a]:format(target)
 return mattata.send(command, true)
end
mattata.channel_set_admin = function(chat, user, rank)
 chat = format_target(chat)
 user = format_target(user)
 local command = 'channel_set_admin %s %s %s'
 command = command:format(chat, user, rank)
 return mattata.send(command)
end
mattata.channel_set_about = function(chat, text)
 chat = format_target(chat)
 text = escape(text)
 local command = 'channel_set_about %s "%s"'
 command = command:format(chat, text)
 return mattata.send(command)
end
mattata.block = function(user)
 return mattata.send('block_user user#' .. user)
end
mattata.unblock = function(user)
 return mattata.send('unblock_user user#' .. user)
end