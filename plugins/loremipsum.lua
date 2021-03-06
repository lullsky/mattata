local loremipsum = {}
local mattata = require('mattata')
local HTTP = require('socket.http')

function loremipsum:init(configuration)
	loremipsum.arguments = 'loremipsum'
	loremipsum.commands = mattata.commands(self.info.username, configuration.commandPrefix):c('loremipsum').table
	loremipsum.help = configuration.commandPrefix .. 'loremipsum - Generates a few Lorem Ipsum sentences!'
end

function loremipsum:onMessageReceive(message, configuration)
	local output, res = HTTP.request(configuration.apis.loremipsum)
	if res ~= 200 then
		mattata.sendMessage(message.chat.id, configuration.errors.connection, nil, true, false, message.message_id, nil)
		return
	end
	mattata.sendMessage(message.chat.id, output, nil, true, false, message.message_id, nil)
end

return loremipsum