local guidgen = {}
local HTTP = require('socket.http')
local JSON = require('dkjson')
local mattata = require('mattata')

function guidgen:init(configuration)
	guidgen.arguments = 'guidgen'
	guidgen.commands = mattata.commands(self.info.username, configuration.commandPrefix):c('guidgen').table
	guidgen.help = configuration.commandPrefix .. 'guidgen - Generates a random GUID.'
end

function guidgen:onMessageReceive(message, configuration)
	local jstr, res = HTTP.request(configuration.apis.guidgen)
	if res ~= 200 then
		mattata.sendMessage(message.chat.id, configuration.errors.connection, nil, true, false, message.message_id, nil)
		return
	end
	local jdat = JSON.decode(jstr)
	mattata.sendMessage(message.chat.id, jdat.char[1], nil, true, false, message.message_id, nil)
end

return guidgen