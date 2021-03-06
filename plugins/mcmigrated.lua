local mcmigrated = {}
local HTTPS = require('ssl.https')
local JSON = require('dkjson')
local mattata = require('mattata')

function mcmigrated:init(configuration)
	mcmigrated.arguments = 'mcmigrated <username>'
	mcmigrated.commands = mattata.commands(self.info.username, configuration.commandPrefix):c('mcmigrated').table
	mcmigrated.help = configuration.commandPrefix .. 'mcmigrated <username> - Tells you if a Minecraft username has been migrated to a Mojang account.'
end

function mcmigrated:onMessageReceive(message, configuration)
	local input = mattata.input(message.text)
	if not input then
		mattata.sendMessage(message.chat.id, mcmigrated.help, nil, true, false, message.message_id, nil)
		return
	end
	local url = configuration.apis.mcmigrated .. input
	local jstr, res = HTTPS.request(url)
	if res ~= 200 then
		mattata.sendMessage(message.chat.id, configuration.errors.connection, nil, true, false, message.message_id, nil)
		return
	end
	local output = ''
	if string.match(jstr, 'true') then
		output = 'This username has been migrated to a Mojang account!'
	else
		output = 'This username either does not exist, or it just hasn\'t been migrated to a Mojang account.'
	end
	mattata.sendMessage(message.chat.id, output, nil, true, false, message.message_id, nil)
end

return mcmigrated