--!strict

-- Settings
local DefaultModerators : {string} = {
	[-1] = "Server", -- id -1 is reserved for game
	[12545525] = "Im_Hiatus",
}

local KickMessageFormats = {
	error = "\n%s. \n(If this problem persists, please contact support)",
	sus = "Suspicious activity detected: %s.",
	none = "%s"
}

local DEFAULT_KICK_REASON = "None"
local DEFAULT_BAN_REASON = "None"
local DEFAULT_UNBAN_REASON = "No reason given"

local MAX_PCALL_ATTEMPTS = 10
type Subscription = "UpdateMods" | "KickPlayer" -- for MessagingService

local MODS_DS_KEY = "Mods_1_"
local BANS_DS_KEY = "Bans_1_"
local KICKS_DS_KEY = "Kicks_1_"
local NOTES_DS_KEY = "Notes_1_"

-- CLIENT ERROR MESSAGES
local INVALID_KEY = "Please provide a valid key!"
local INVALID_TOPIC = "Please provide a valid topic to publish to!"
local INVALID_USER = "Please provide a valid Player or UserId!"
local INVALID_USERID = "Please provide a valid UserId!"
local INVALID_MOD = "%s does not have mod perms!"
local INVALID_NOTE = "Please provide a valid note!"
local INVALID_BAN_DURATION = "Please provide a valid duration!"
local INVALID_BAN_TARGET = "Player is already banned!"
local INVALID_UNBAN_TARGET = "Player is already unbanned!"

local FAILED_DATA_RETRIEVAL = "Failed to retrieve data from Roblox servers. Please try again later.\nProblem: %s"
local FAILED_DATA_WRITE = "Failed to write data to Roblox servers. Please try again later.\nProblem: %s"
local FAILED_PUBLISH_TO_TOPIC = "Failed to publish to %s. Please try again later.\nError: %s"

local NO_MOD_LIST = "Mod list has not been fetched yet (Call UpdateMods())"
--

type Data = {[any] : any}
type List = {string}
type Message = {Data : any, Sent : number}

type User = Player | number
type LogCategory = "Notes"|"Bans"|"Kicks"

local GenerateMessage = require(script.Parent.ChatCmds.GenerateMessage)

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ServerId = (game:GetService("RunService"):IsStudio()) and "Studio" or game.JobId

local ModerationStore : DataStore = game:GetService("DataStoreService"):GetDataStore("Moderation_1")
local Moderators : List

local function SendMsgToClient(ChatMod : Player?, message : string, msg_type : ("error"|"normal")?)
	if not ChatMod then return end
	GenerateMessage.fromResult(ChatMod :: Player, message, msg_type or "error")
end

local function FetchData(key : string, ChatMod : Player?) : (boolean, Data)
	if not key then
		SendMsgToClient(ChatMod, INVALID_KEY)
		warn(INVALID_KEY)
		return false, {}
	end

	local success, result

	for attempt = 1, MAX_PCALL_ATTEMPTS do
		success, result = pcall(function()
			return ModerationStore:GetAsync(key)
		end)

		if success then return success, result or {} end
	end
	
	local error_msg = string.format(FAILED_DATA_RETRIEVAL, result)
	SendMsgToClient(ChatMod, error_msg)
	warn(error_msg) 
	return false, {}
end

local function WriteToData(key : string, data : Data, ChatMod: Player?) : boolean
	if not key then
		SendMsgToClient(ChatMod, INVALID_KEY)
		warn(INVALID_KEY) 
		return false
	end

	local success, msg

	for attempt = 1, MAX_PCALL_ATTEMPTS do
		success, msg = pcall(function()
			return ModerationStore:UpdateAsync(key, function(old)
				return data
			end)
		end)

		if success then return success end
	end

	local error_msg = string.format(FAILED_DATA_WRITE, msg)
	SendMsgToClient(ChatMod, error_msg)
	warn(error_msg)
	return false
end

local function SubscribeToMessage(topic : Subscription, callback : (any) -> ()) : (RBXScriptConnection?, boolean)
	if not topic or type(topic) ~= "string" then
		warn("Please send a valid topic to subscribe to! Sent:", topic)
		return nil, false
	end

	local success, result

	for attempt = 1, MAX_PCALL_ATTEMPTS do
		success, result = pcall(function()
			return MessagingService:SubscribeAsync(topic, callback)
		end)

		if success then return result, success end
	end

	warn(string.format("Failed to subscribe to %s. Please try again later. Error: %s", topic, result))
	return nil, false
end

local function PublishMessage(topic : Subscription, message : any, ChatMod : Player?) : boolean
	if not topic or type(topic) ~= "string" then
		SendMsgToClient(ChatMod, INVALID_TOPIC)
		warn(INVALID_TOPIC, "Sent:", topic) 
		return false
	end

	local success, result

	for attempt = 1, MAX_PCALL_ATTEMPTS do
		success, result = pcall(function()
			return MessagingService:PublishAsync(topic, message)
		end)

		if success then return true end
	end
	
	local error_message = string.format(FAILED_PUBLISH_TO_TOPIC, topic, result)
	SendMsgToClient(ChatMod, error_message)
	warn(error_message)
	return false
end

local function GetId(user : User, ChatMod : Player?) : number?
	local id : number = if typeof(user) == "Instance" and user:IsA("Player") then user.UserId else user
	
	if type(id) == "number" then
		return id
	end
	
	if ChatMod then
		GenerateMessage.fromResult(ChatMod, "Must send a valid Player or UserId!", "error")
	end
	warn("Must send a Player or UserId! Sent:", user) return
end

local function IsModerator(moderator : User, ChatMod : Player?) : string?
	if not Moderators then
		SendMsgToClient(ChatMod, NO_MOD_LIST)
		warn(NO_MOD_LIST)
		return 
	end
	if not moderator then
		SendMsgToClient(ChatMod, INVALID_USER)
		warn(INVALID_USER)
		return
	end

	local id = GetId(moderator) :: number
	if not id then return end
	
	if not Moderators[id] then
		local error_message = string.format(INVALID_MOD, tostring(id))
		SendMsgToClient(ChatMod, error_message)
		warn(error_message)
		return
	end

	return Moderators[id]
end

local Moderation = {}

function Moderation.Verify(user : User, ChatMod : Player?) : boolean?
	local id = GetId(user, ChatMod)
	if not id then return end

	local key = BANS_DS_KEY .. tostring(id)
	local fetch_success, ban_logs = FetchData(key, ChatMod)
	if not fetch_success then return end
	
	local latest_log = ban_logs[1]

	if not latest_log or not latest_log.Banned then
		return true
	elseif latest_log.Duration > 0 and os.time() > latest_log.TimeOfBan + latest_log.Duration then
		Moderation.Unban(id :: number, -1, "Ban duration finished")
		return true
	elseif typeof(user) == "Instance" and user:IsA("Player") then
		user:Kick(string.format("You are banned from this experience. Reason: %s", latest_log.Reason))
	end

	return false
end

function Moderation.UpdateMods(ChatMod: Player?) : boolean
	local new_mod_list = {}

	for id, name in pairs(DefaultModerators) do -- fill in the default mods (server setup)
		if new_mod_list[id] then continue end
		new_mod_list[id] = name
	end

	local fetch_success, added_mods = FetchData(MODS_DS_KEY, ChatMod)
	if not fetch_success then return false end
	
	for id, name in pairs(added_mods) do
		new_mod_list[tonumber(id) :: number] = name -- keys saved as strings cos they're not in numerical order
	end

	Moderators = new_mod_list
	return true
end

function Moderation.GetMods(ChatMod : Player?) : List
	if not Moderators then Moderation.UpdateMods(ChatMod) end
	return Moderators
end

function Moderation.AddMod(new_moderator : User, ChatMod : Player?) : boolean?
	local id : number
	local name : string

	if typeof(new_moderator) == "number" then
		id = new_moderator
		name = tostring(id)
	elseif typeof(new_moderator) == "Instance" then
		id = GetId(new_moderator, ChatMod) :: number
		if not id then return end
		name = new_moderator.Name
	else
		return warn(INVALID_USER, "Sent:", new_moderator)
	end
	
	local fetch_success, added_mods = FetchData(MODS_DS_KEY, ChatMod)
	if not fetch_success then return end

	added_mods[tostring(id)] = name -- store string to avoid datastore mixed keys rule (unordered number keys)
	Moderators[id] = name

	local update_success = WriteToData(MODS_DS_KEY, added_mods, ChatMod)
	if not update_success then return end

	local publish_success = PublishMessage("UpdateMods", {
		Action = "Add",
		Mod = {Id = id, Name = name},
		Server = ServerId
	}, ChatMod)
	
	return true
end

function Moderation.RemoveMod(old_moderator : User, ChatMod : Player?) : boolean?
	local id = GetId(old_moderator, ChatMod) :: number
	
	if not Moderators[id] then
		local error_message = string.format(INVALID_MOD, tostring(id))
		SendMsgToClient(ChatMod, error_message)
		return warn(error_message)
	end
	
	local fetch_success, added_mods = FetchData(MODS_DS_KEY, ChatMod)
	if not fetch_success then return end
	
	added_mods[tostring(id)] = nil -- keys saved as strings cos they're not in numerical order
	Moderators[id] = nil

	local update_success = WriteToData(MODS_DS_KEY, added_mods, ChatMod)
	if not update_success then return end

	PublishMessage("UpdateMods", {
		Action = "Remove",
		Mod = {Id = id},
		Server = ServerId
	}, ChatMod)

	return true
end

function Moderation.GetLogs(user : User, category : LogCategory?, number: number?, ChatMod : Player?) : (Data | {[string] : Data})?
	local id = GetId(user, ChatMod) :: number
	if not id then return end
	
	local category_lowercase = string.lower(tostring(category))
	local fetch_success, logs
	
	if category_lowercase == "notes" then
		fetch_success, logs = FetchData(NOTES_DS_KEY .. id, ChatMod)
	elseif category_lowercase == "kicks" then
		fetch_success, logs = FetchData(KICKS_DS_KEY .. id, ChatMod)
	elseif category_lowercase == "bans" then
		fetch_success, logs = FetchData(BANS_DS_KEY .. id, ChatMod)
	elseif not category then
		local n_success, notes = FetchData(NOTES_DS_KEY .. id, ChatMod)
		local k_success, kicks = FetchData(KICKS_DS_KEY .. id, ChatMod)
		local b_success, bans = FetchData(BANS_DS_KEY .. id, ChatMod)
		
		fetch_success = n_success and k_success and b_success
		if fetch_success then
			logs = {
				Notes = notes,
				Kicks = kicks,
				Bans = bans
			}
		end
	end
	
	if fetch_success and logs then
		return if number then logs[number] else logs
	end
	return nil
end

function Moderation.Note(user : User, moderator : User, note : string, ChatMod : Player?) : boolean?
	if not note or (type(note) ~= "string" and type(note) ~= "number") then warn(INVALID_NOTE) return end

	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	local id = GetId(user, ChatMod) :: number
	if not id then return end

	local key = NOTES_DS_KEY .. tostring(id)

	local fetch_success, notes = FetchData(key, ChatMod)
	if not fetch_success then return end
	
	table.insert(notes, 1, {
		Date = os.date(),
		Note = note,
		Moderator = mod :: string,
		Traceback = debug.traceback()
	})

	WriteToData(key, notes, ChatMod)
	return true
end

function Moderation.Kick(user : User, moderator : User, reason : string?, format : string?, ChatMod : Player?) : boolean?
	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	local id = GetId(user, ChatMod)
	if not id then return end
	
	reason = reason or DEFAULT_KICK_REASON
	format = format or "none"
	
	local key = KICKS_DS_KEY .. tostring(id)
	local fetch_success, kick_logs = FetchData(key, ChatMod)
	if not fetch_success then return end
	
	table.insert(kick_logs, 1, {
		Date = os.date(),
		Reason = string.format("%s (%s)", reason :: string, format :: string),
		Moderator = mod :: string,
		Traceback = debug.traceback()
	})

	WriteToData(key, kick_logs, ChatMod)

	local player = Players:GetPlayerByUserId(id)
	if player then
		player:Kick(string.format(KickMessageFormats[format] or "%s", reason))
	else
		SendMsgToClient(ChatMod, "Finding player other servers...", "normal")
		PublishMessage("KickPlayer", {
			UserId = id,
			Reason = reason,
			Format = format
		})
	end
	return true
end

function Moderation.Ban(user : User, moderator : User, duration : number, reason : string?, ChatMod : Player?) : boolean?
	-- duration : seconds
	if not duration or type(duration) ~= "number" then return warn(INVALID_BAN_DURATION, duration) end

	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	local id = GetId(user, ChatMod)
	if not id then return end

	reason = reason or DEFAULT_BAN_REASON
	
	local key = BANS_DS_KEY .. tostring(id)
	local fetch_success, ban_logs = FetchData(key, ChatMod)
	if not fetch_success then return end
	
	if ban_logs[1] and ban_logs[1].Banned then
		SendMsgToClient(ChatMod, INVALID_BAN_TARGET)
		warn(INVALID_BAN_TARGET)
		return
	end
	
	table.insert(ban_logs, 1, {
		Banned = true,
		Date = os.date(),
		Reason = reason,
		Moderator = mod :: string,
		Traceback = debug.traceback(),
		TimeOfBan = os.time(),
		Duration = math.round(duration),
	})

	WriteToData(key, ban_logs)
	Moderation.Kick(id :: number, -1, reason, nil, ChatMod)
	return true
end

function Moderation.Unban(id : number, moderator : User, reason : string?, ChatMod : Player?) : boolean?
	if type(id) ~= "number" then return warn(INVALID_USERID) end

	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	reason = reason or DEFAULT_UNBAN_REASON
	
	local key = BANS_DS_KEY .. tostring(id)
	local fetch_success, ban_logs = FetchData(key, ChatMod)
	if not fetch_success then return end
	
	if ban_logs[1] and not ban_logs[1].Banned then
		SendMsgToClient(ChatMod, INVALID_UNBAN_TARGET)
		warn(INVALID_UNBAN_TARGET)
		return
	end
	
	table.insert(ban_logs, 1, {
		Banned = false,
		Date = os.date(),
		Reason = reason,
		Moderator = mod :: string,
		Traceback = debug.traceback()
	})

	WriteToData(key, ban_logs, ChatMod)
	return true
end

function Moderation.Cmds() : List
	local cmds = {}
	for name in pairs(Moderation) do
		table.insert(cmds, name)
	end
	return cmds
end

-- Required
Moderation.UpdateMods()
SubscribeToMessage("UpdateMods", function(message : Message)
	if not message or type(message.Data) ~= "table" then warn("No valid update has been received:", message) return end
	if message.Data.Server == ServerId then return end
	
	local mod = message.Data.Mod
	
	if message.Data.Action == "Add" then
		Moderators[mod.Id] = mod.Name
	elseif message.Data.Action == "Remove" then
		Moderators[mod.Id] = nil
	end
end)

SubscribeToMessage("KickPlayer", function(message : Message)
	if not message or type(message.Data) ~= "table" then warn("Received no valid id to kick") return end
	
	local id = message.Data.UserId
	local reason = message.Data.Reason or DEFAULT_KICK_REASON
	local format = message.Data.Format
	
	if type(id) ~= "number" then warn(INVALID_USERID, "Sent:", id) return end
	if type(reason) ~= "string" then warn("Please send a valid reason! Sent:", reason) return end
	if format and type(format) ~= "string" then warn("Please send a valid format! Sent:", format) return end
	
	local player = Players:GetPlayerByUserId(id)
	if player then
		player:Kick(string.format(KickMessageFormats[format or "none"] or "%s", reason))
		print(player.UserId, "has been kicked from the game")
	else
		--print(string.format("could not find %d in this server (%s)", id, ServerId))
	end
end)
--

return Moderation
