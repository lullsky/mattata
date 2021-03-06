local report = {}
local mattata = require('mattata')

function report:init(configuration)
	report.arguments = 'report <text>'
	report.commands = mattata.commands(self.info.username, configuration.commandPrefix):c('report'):c('ops').table
	report.help = configuration.commandPrefix .. 'report <text> - Notifies all administrators of an issue. Alias: ' .. configuration.commandPrefix .. 'ops.'
end

function report:onMessageReceive(message, configuration)
	if message.chat.type == 'supergroup' then
		local input = mattata.input(message.text)
		local adminlist = {}
		local admins = mattata.getChatAdministrators(message.chat.id)
		for n in pairs(admins.result) do
			if admins.result[n].user.username then
				table.insert(adminlist, '@' .. mattata.markdownEscape(admins.result[n].user.username))
			end
		end
		table.sort(adminlist)
		local output = '*' .. message.from.first_name .. ' needs help!*\n' .. table.concat(adminlist, ', ')
		if input then
			output = output .. '\nArguments: `' .. mattata.markdownEscape(input) .. '`'
		end
		mattata.sendMessage(message.chat.id, output, 'Markdown', true, false, message.message_id)
		return
	end
end

return report