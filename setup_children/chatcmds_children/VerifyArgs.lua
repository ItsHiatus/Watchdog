--!strict
local GenerateMessage = require(script.Parent.GenerateMessage)
local Settings = require(script.Parent.Parent.Settings)
local CLIENT_ERROR_MSGS = Settings.ClientErrorMessages

type Args = {any}

return {
	getlogs = function(player : Player, args : Args) : boolean
		if not args[2] or not table.find(Settings.LogCategories, args[2]) then -- must specify category and log number with chat cmd, otherwise floods chat
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_LOG_CATEGORY, "error") return false
		elseif not args[3] or type(args[3]) ~= "number" then
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_LOG_NUMBER, "error") return false
		end
		return true
	end,
	
	getlocalnotes = function(player : Player, args : Args) : boolean
		if not args[2] or type(args[2]) ~= "number" then -- must specify category and log number with chat cmd, otherwise floods chat
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_LOG_NUMBER, "error") return false
		end
		return true
	end,
	
	note = function(player : Player, args : Args) : boolean
		if not args[3] then -- must provide a valid note
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_NOTE, "error") return false
		end
		return true
	end,
	
	removenote = function(player : Player, args : Args) : boolean
		if not args[2] or type(args[2]) ~= "number" then -- must specify note id to remove
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_NOTE_NUMBER, "error") return false
		end
		return true
	end,
	
	localnote = function(player : Player, args : Args) : boolean
		if not args[3] then -- must provide a valid note
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_NOTE, "error") return false
		end
		return true
	end,
	
	kick = function(player : Player, args : Args) : boolean
		if not args[3] then -- must provide reason
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_REASON, "error") return false
		elseif not args[4] then
			table.insert(args, "none")
		end
		return true
	end,
	
	ban = function(player : Player, args : Args) : boolean
		if not args[3] or type(args[3]) ~= "number" then -- must provide duration and reason
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_DURATION, "error") return false
		elseif not args[4] then
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_REASON, "error") return false
		end
		return true
	end,
	
	unban = function(player : Player, args : Args) : boolean
		if not args[3] then
			GenerateMessage.fromResult(player, CLIENT_ERROR_MSGS.INVALID_REASON, "error") return false
		end
		return true
	end,
}
