--[[

    Based on preview.lua, Copyright 2016 topkecleon <drew@otou.to>
    This code is licensed under the GNU AGPLv3.

]]--

local preview = {}
local HTTP = require('socket.http')
local mattata = require('mattata')

function preview:init(configuration)
	preview.arguments = 'preview <url>'
	preview.commands = mattata.commands(self.info.username, configuration.commandPrefix):c('preview').table
	preview.help = configuration.commandPrefix .. 'preview <link> - Sends an "unlinked" preview of the given URL.'
end

function preview:onMessageReceive(message)
	local input = mattata.input(message.text)
	if not input then
		mattata.sendMessage(message.chat.id, preview.help, nil, true, false, message.message_id, nil)
		return
	else
		input = mattata.getWord(input, 1)
	end
	if not input:match('^https?://.+') then
		input = 'http://' .. input
	end
	local res = HTTP.request(input)
	if not res then
		mattata.sendMessage(message.chat.id, 'Please provide a valid URL.', nil, true, false, message.message_id, nil)
	return
	end
	if res:len() == 0 then
		mattata.sendMessage(message.chat.id, 'Sorry, the URL you provided is not letting me generate a preview. Please check it\'s valid.', nil, true, false, message.message_id, nil)
		return
	end
	local output = '[​](' .. input .. ')'
	mattata.sendMessage(message.chat.id, output, 'Markdown', false, false, nil, nil)
end

return preview