local messaging = {}
local HTTPS = require('ssl.https')
local HTTP = require('socket.http')
local URL = require('socket.url')
local ltn12 = require('ltn12')
local JSON = require('dkjson')
local mattata = require('mattata')
local redis = require('mattata-redis')

function messaging:init(configuration)
	messaging.arguments = 'statistics'
	messaging.commands = { '' }
end

function getUserName(user)
	if user.name then
		return user.name
	end
	local text = ''
	if user.first_name then
		text = user.first_name .. ' '
	end
	if user.last_name then
		text = text .. user.last_name
	end
	return text
end

function getUserMessages(id, chat)
	local info = {}
	local userHash = 'user:' .. id
	local user = redis:hgetall(userHash)
	local userMessagesHash = 'messages:' .. id .. ':' .. chat
	info.messages = tonumber(redis:get(userMessagesHash) or 0)
	info.name = getUserName(user)
	return info
end

function commaValue(amount)
	local formatted = amount
	while true do  
		formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')
		if (k==0) then
			break
		end
	end
	return formatted
end

function round(num, idp)
	local mult = 10^(idp or 0)
	return math.floor(num * mult + 0.5) / mult
end

function isempty(s)
	return s == nil or s == ''
end

function chatStatistics(chat)
	local hash = 'chat:' .. chat .. ':users'
	local users = redis:smembers(hash)
	local chatUserInfo = {}
	for i = 1, #users do
		local id = users[i]
		local user = getUserMessages(id, chat)
		table.insert(chatUserInfo, user)
	end
	local totalMessages = 0
	for n, user in pairs(chatUserInfo) do
		local messageCount = chatUserInfo[n].messages
		totalMessages = totalMessages + messageCount
	end
	table.sort(chatUserInfo, function(a, b) 
		if a.messages and b.messages then
			return a.messages > b.messages
		end
	end)
	local text = ''
	for k, v in pairs(chatUserInfo) do
    	local messageCount = v.messages
		local percent = tostring(round(messageCount / totalMessages * 100, 1))
    	text = text .. '*' .. v.name:gsub('%*', '\\*') .. ':* ' .. commaValue(messageCount) .. ' `[`' .. percent .. '%`]`\n'
	end
	if isempty(text) then
		return 'No messages have been sent in this group!'
	end
	local text = '*Message Statistics*\n\n' .. text .. '\n*Total messages sent*: ' .. commaValue(totalMessages)
	return text
end

function messaging:processMessage(message)
	if message.left_chat_member then
		local hash = 'chat:' .. message.chat.id .. ':users'
		local userIdLeft = message.left_chat_member.id
		redis:srem(hash, userIdLeft)
		return message
	end
	if message.from then
		local hash = 'user:' .. message.from.id
		if message.from.name then
			redis:hset(hash, 'name', message.from.name)
		end
		if message.from.first_name then
			redis:hset(hash, 'first_name', message.from.first_name)
		end
		if message.from.last_name then
			redis:hset(hash, 'last_name', message.from.last_name)
		end
		if message.chat.type ~= 'private' then
			local hash = 'chat:' .. message.chat.id .. ':users'
			redis:sadd(hash, message.from.id)
		end
		local hash = 'messages:' .. message.from.id .. ':' .. message.chat.id
		redis:incr(hash)
		return message
	end
	return
end

function messaging:onMessageReceive(message, configuration)
	if message.reply_to_message then
		if message.photo then
			if message.reply_to_message.from.id == self.info.id then
				mattata.sendChatAction(message.chat.id, 'typing')
				local getFile = mattata.getFile(message.photo[1].file_id)
				local url = 'https://api.telegram.org/file/bot' .. configuration.botToken .. '/' .. getFile.result.file_path
				local filePath = configuration.fileDownloadLocation .. os.time() .. url:match('.+/(.-)$')
				local body = {}
				local protocol = HTTP
				local redirect = true
				if url:match('^https') then
					protocol = HTTPS
					redirect = false
				end
				local _, res = protocol.request {
					url = url,
					sink = ltn12.sink.table(body),
					redirect = redirect
				}
				if res ~= 200 then
					mattata.sendMessage(message.chat.id, configuration.errors.connection, nil, true, false, message.message_id)
					return
				end
				local file = io.open(filePath, 'w+')
				file:write(table.concat(body))
				file:close()
				local output = io.popen('./plugins/captionbotai.sh "' .. filePath .. '"'):read('*all')
				os.remove(filePath)
				mattata.sendMessage(message.chat.id, output, nil, true, false, message.message_id)
				return
			end
		end
		if message.text then
			if not string.match(message.text, configuration.commandPrefix) then
				if message.reply_to_message.from.id == self.info.id then
					local jstr, res = HTTPS.request(configuration.messaging.url .. URL.escape(message.text_lower))
					if res ~= 200 then
						return
					end
					local jdat = JSON.decode(jstr)
					mattata.sendChatAction(message.chat.id, 'typing')
					mattata.sendMessage(message.chat.id, jdat.clever, nil, true, false, message.message_id, nil)
					return
				end
			end
		end
	end
	if message.chat.type ~= 'private' then
		if message.text_lower == configuration.commandPrefix .. 'statistics' or string.match(message.text_lower, 'how many messages have been sent') then
			local chatId = message.chat.id
			mattata.sendMessage(message.chat.id, chatStatistics(chatId), 'Markdown', true, false, message.message_id)
			return
		end
		if configuration.announceMigration then
			if message.migrate_from_chat_id then
				mattata.sendMessage(message.chat.id, message.chat.title .. ' was upgraded to a supergroup. The old ID was ' .. message.migrate_from_chat_id .. ', and the new ID is ' .. message.chat.id .. '.', nil, true, false, message.message_id)
				return
			end
		end
		if message.text then
			if string.match(message.text_lower, self.info.first_name .. ' ') and not string.match(message.text, configuration.commandPrefix) then
				local jstr, res = HTTPS.request(configuration.messaging.url .. URL.escape(message.text))
				if res ~= 200 then
					return
				end
				local jdat = JSON.decode(jstr)
				mattata.sendChatAction(message.chat.id, 'typing')
				mattata.sendMessage(message.chat.id, jdat.clever, nil, true, false, message.message_id)
				return
			end
			if string.match(message.text, '^WHAT THE FUCK%?$') then
				mattata.sendMessage(message.chat.id, 'YEAH, WTF??', nil, true, false, message.message_id)
				return
			end
		end
	else
		if not string.match(message.text_lower, configuration.commandPrefix) then
			local jstr, res = HTTPS.request(configuration.messaging.url .. URL.escape(message.text_lower))
			if res ~= 200 then
				return
			end
			local jdat = JSON.decode(jstr)
			mattata.sendChatAction(message.chat.id, 'typing')
			mattata.sendMessage(message.chat.id, jdat.clever, nil, true, false, message.message_id)
			return
		end
	end
end

return messaging
