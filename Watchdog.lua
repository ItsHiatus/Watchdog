--!strict
-- Settings
local Settings = require(script.Parent.Watchdog_Setup.Settings)

local DefaultModerators = Settings.DefaultMods
local KickMessageFormats = Settings.KickMessageFormats

local DEFAULT_KICK_REASON = Settings.DefaultReasons.Kick
local DEFAULT_BAN_REASON = Settings.DefaultReasons.Ban
local DEFAULT_UNBAN_REASON = Settings.DefaultReasons.Unban

local MAX_PCALL_ATTEMPTS = 10
type Subscription = Settings.Subscription

local MODS_DS_KEY = "Mods_1_"
local BANS_DS_KEY = "Bans_1_"
local KICKS_DS_KEY = "Kicks_1_"
local NOTES_DS_KEY = "Notes_1_"

-- Client Error Messages
local ClientErrorMessages = Settings.ClientErrorMessages
local NO_MOD_LIST = "No mod list! (Call UpdateMods())"
local FAILED_DATA_RETRIEVAL = "Failed to fetch data from Roblox servers. Please try again later.\nReason: %s"
local FAILED_DATA_UPDATE = "Failed to update data on Roblox servers. Please try again later.\nReason: %s"
local FAILED_PUBLISH_TO_TOPIC = "Failed to publish to %s. Please try again later. Error: %s"
--

type List = Settings.List
type Data = Settings.Data
type DataDict = Settings.DataDict
type Message = {Data : any, Sent : number}

type User = Settings.User
type LogCategory = Settings.LogCategory

local GenerateMessage = require(script.Parent.Watchdog_Setup.ChatCmds.GenerateMessage)

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ServerId = (game:GetService("RunService"):IsStudio()) and "Studio" or game.JobId

local WatchdogStore : DataStore = game:GetService("DataStoreService"):GetDataStore("Watchdog_1")
local Moderators : List

local LogCategories = {
	notes = NOTES_DS_KEY,
	bans = BANS_DS_KEY,
	kicks = KICKS_DS_KEY
}

local function SendMsgToClient(ChatMod : Player?, message : string, msg_type : ("error"|"normal")?)
	if not ChatMod then return end
	GenerateMessage.fromResult(ChatMod :: Player, message, msg_type or "error")
end

local function FetchData(key : string, ChatMod : Player?) : (boolean, Data)
	if not key then
		SendMsgToClient(ChatMod, ClientErrorMessages.INVALID_KEY)
		warn(ClientErrorMessages.INVALID_KEY)
		return false, {}
	end

	local success, result

	for attempt = 1, MAX_PCALL_ATTEMPTS do
		success, result = pcall(function()
			return WatchdogStore:GetAsync(key)
		end)

		if success then return success, result or {} end
	end
	
	local error_message = string.format(FAILED_DATA_RETRIEVAL, result)
	SendMsgToClient(ChatMod, error_message)
	warn(error_message) 
	return false, {}
end

local function WriteToData(key : string, data_to_add : Data, ChatMod: Player?) : boolean
	if not key then
		SendMsgToClient(ChatMod, ClientErrorMessages.INVALID_KEY)
		warn(ClientErrorMessages.INVALID_KEY) 
		return false
	end

	local success, msg

	for attempt = 1, MAX_PCALL_ATTEMPTS do
		success, msg = pcall(function()
			return WatchdogStore:UpdateAsync(key, function(old)
				old = old or {}
				
				for key, value in pairs(data_to_add) do
					if type(key) == "number" then
						table.insert(old, key, value)
					else
						old[key] = (value ~= false) and value or nil -- set values to false to remove them from data
					end
				end
				
				return old
			end)
		end)

		if success then return success end
	end
	
	local error_message = string.format(FAILED_DATA_UPDATE, msg)
	SendMsgToClient(ChatMod, error_message)
	warn(error_message)
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
		SendMsgToClient(ChatMod, ClientErrorMessages.INVALID_TOPIC)
		warn(ClientErrorMessages.INVALID_TOPIC, "Sent:", topic) 
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
	
	SendMsgToClient(ChatMod, ClientErrorMessages.INVALID_USER)
	warn(ClientErrorMessages.INVALID_USER) return
end

local function IsModerator(moderator : User, ChatMod : Player?) : string?
	if not Moderators then
		SendMsgToClient(ChatMod, NO_MOD_LIST)
		warn(NO_MOD_LIST) return 
	end
	if not moderator then
		SendMsgToClient(ChatMod, ClientErrorMessages.INVALID_USER)
		warn(ClientErrorMessages.INVALID_USER) return
	end

	local id = GetId(moderator) :: number
	if not id then return end
	
	if not Moderators[id] then
		local error_message = string.format(ClientErrorMessages.INVALID_MOD, tostring(id))
		SendMsgToClient(ChatMod, error_message)
		warn(error_message) return
	end

	return Moderators[id]
end

local function GetRemainingBanDuration(duration : number) : string
	local remaining = duration
	local result = ""
	
	for index, interval in ipairs(Settings.TimeIntervals) do
		local value = math.floor(remaining / math.max(interval.Value, 1))
		if value < 1 then continue end
		
		if #result > 0 then
			result = result .. ", "
		end
		
		result = string.format("%s%d %s", result, value, (value ~= 1) and interval.Name or string.sub(interval.Name, 1, #interval.Name - 1))
		remaining -= value * interval.Value
	end
	
	return result
end

local Watchdog = {}

function Watchdog.Verify(user : User, ChatMod : Player?) : boolean?
	local id = GetId(user, ChatMod)
	if not id then return end

	local key = BANS_DS_KEY .. tostring(id)
	local fetch_success, ban_logs = FetchData(key, ChatMod)
	if not fetch_success then return end
	
	local latest_log = ban_logs[1]

	if not latest_log or not latest_log.Banned then
		return true
	elseif latest_log.Duration > 0 and os.time() > latest_log.TimeOfBan + latest_log.Duration then
		Watchdog.Unban(id :: number, -1, "Ban duration finished")
		return true
	elseif typeof(user) == "Instance" and user:IsA("Player") then
		user:Kick(string.format("You are banned from this experience. Reason: %s. \n(%s)", latest_log.Reason, GetRemainingBanDuration(latest_log.TimeOfBan + latest_log.Duration - os.time())))
	end

	return false
end

function Watchdog.UpdateMods(ChatMod: Player?) : boolean
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

function Watchdog.GetMods(ChatMod : Player?) : List
	if not Moderators then Watchdog.UpdateMods(ChatMod) end
	return Moderators
end

function Watchdog.AddMod(new_moderator : User, ChatMod : Player?) : boolean?
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
		return warn(ClientErrorMessages.INVALID_USER, "Sent:", new_moderator)
	end
	
	if Moderators[id] then
		local error_message = string.format(ClientErrorMessages.INVALID_MOD_TARGET, tostring(id))
		SendMsgToClient(ChatMod, error_message)
		return warn(error_message)
	end
	
	local mods_to_add = {[tostring(id)] = name} -- store key as string to avoid datastore mixed keys rule (unordered number keys)
	Moderators[id] = name
	
	local update_success = WriteToData(MODS_DS_KEY, mods_to_add, ChatMod)
	if not update_success then return end

	local publish_success = PublishMessage("UpdateMods", {
		Action = "Add",
		Mod = {Id = id, Name = name},
		Server = ServerId
	}, ChatMod)
	
	return true
end

function Watchdog.RemoveMod(old_moderator : User, ChatMod : Player?) : boolean?
	local id = GetId(old_moderator, ChatMod) :: number
	
	if not Moderators[id] or DefaultModerators[id] then
		local msg = (DefaultModerators[id]) and ClientErrorMessages.INVALID_UNMOD_TARGET or ClientErrorMessages.INVALID_MOD
		local error_message = string.format(msg, tostring(id))
		SendMsgToClient(ChatMod, error_message)
		return warn(error_message)
	end
	
	local mods_to_remove = {[tostring(id)] = false} -- keys saved as strings cos they're not in numerical order
	-- set to false so function knows to remove them from data
	Moderators[id] = nil

	local update_success = WriteToData(MODS_DS_KEY, mods_to_remove, ChatMod)
	if not update_success then return end

	PublishMessage("UpdateMods", {
		Action = "Remove",
		Mod = {Id = id},
		Server = ServerId
	}, ChatMod)

	return true
end

function Watchdog.GetLogs(user : User, category : LogCategory?, number: number?, ChatMod : Player?) : (Data | {[string] : Data})?
	local id = GetId(user, ChatMod) :: number
	if not id then return end
	
	local category_lowercase = string.lower(tostring(category))
	local fetch_success, logs
	
	if category and LogCategories[category_lowercase] then
		fetch_success, logs = FetchData(LogCategories[category_lowercase] :: string .. id, ChatMod)
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

function Watchdog.Note(user : User, moderator : User, note : string, ChatMod : Player?) : boolean?
	if not note or (type(note) ~= "string" and type(note) ~= "number") then warn(ClientErrorMessages.INVALID_NOTE) return end

	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	local id = GetId(user, ChatMod) :: number
	if not id then return end
	
	local new_log = {
		{
			Date = os.date(),
			Note = note,
			Moderator = mod :: string,
			Server = ServerId,
			Traceback = debug.traceback()
		}
	}

	return WriteToData(NOTES_DS_KEY .. tostring(id), new_log, ChatMod)
end

function Watchdog.Kick(user : User, moderator : User, reason : string?, format : string?, ChatMod : Player?) : boolean?
	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	local id = GetId(user, ChatMod)
	if not id then return end
	
	reason = reason or DEFAULT_KICK_REASON
	format = format or "none"
	
	local new_log = {
		{
			Date = os.date(),
			Reason = string.format("%s (%s)", reason :: string, format :: string),
			Moderator = mod :: string,
			Server = ServerId,
			Traceback = debug.traceback()
		}
	}

	WriteToData(KICKS_DS_KEY .. tostring(id), new_log, ChatMod)

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

function Watchdog.Ban(user : User, moderator : User, duration : number, reason : string?, ChatMod : Player?) : boolean?
	-- duration : seconds
	if not duration or type(duration) ~= "number" then return warn(ClientErrorMessages.INVALID_BAN_DURATION, duration) end

	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	local id = GetId(user, ChatMod)
	if not id then return end

	reason = reason or DEFAULT_BAN_REASON
	
	local new_log = {
		{
			Banned = true,
			Date = os.date(),
			Reason = reason,
			Moderator = mod :: string,
			Server = ServerId,
			Traceback = debug.traceback(),
			TimeOfBan = os.time(),
			Duration = math.round(duration),
		}
	}
	
	if duration >= 0 then
		reason = string.format("%s \n(%s)", reason :: string, GetRemainingBanDuration(duration))
	end
	
	WriteToData(BANS_DS_KEY .. tostring(id), new_log, ChatMod)
	Watchdog.Kick(id :: number, -1, reason, nil, ChatMod)
	return true
end

function Watchdog.Unban(id : number, moderator : User, reason : string?, ChatMod : Player?) : boolean?
	if type(id) ~= "number" then return warn(ClientErrorMessages.INVALID_USERID) end

	local mod = IsModerator(moderator, ChatMod)
	if not mod then return end

	reason = reason or DEFAULT_UNBAN_REASON
	
	local key = BANS_DS_KEY .. tostring(id)
	local fetch_success, ban_logs = FetchData(key, ChatMod)
	if not fetch_success then return end
	
	if ban_logs[1] and not ban_logs[1].Banned then
		SendMsgToClient(ChatMod, ClientErrorMessages.INVALID_UNBAN_TARGET)
		warn(ClientErrorMessages.INVALID_UNBAN_TARGET) return
	end
	
	local new_log = {
		{
			Banned = false,
			Date = os.date(),
			Reason = reason,
			Moderator = mod :: string,
			Server = ServerId,
			Traceback = debug.traceback()
		}
	}

	return WriteToData(BANS_DS_KEY .. tostring(id), new_log, ChatMod)
end

function Watchdog.Cmds() : {List}
	return Settings.ChatCmds
end

-- Required
Watchdog.UpdateMods()
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
	
	if type(id) ~= "number" then warn(ClientErrorMessages.INVALID_USERID, "Sent:", id) return end
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

return Watchdog
