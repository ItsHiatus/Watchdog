--!strict
export type List = {[number] : string}
export type Data = {[any] : any}
export type DataDict = {[string] : Data}
export type User = Player | number
export type LogCategory = "Notes" | "Bans" | "Kicks"
export type KickMsgFormat = "error" | "sus" | "none"
export type Subscription = "UpdateMods" | "KickPlayer"
export type MessageType = "normal" | "error"

return {
	-- Watchdog Settings
	DefaultMods = {
		[-1] = "Server", -- id -1 is reserved for game
		[12545525] = "Im_Hiatus", -- put your id and name like this
	},
	
	LogCategories = {
		"notes", "kicks", "bans"
	},
	
	KickMessageFormats = {
		error = "\n%s. \n(If this problem persists, please contact support)",
		sus = "Suspicious activity detected: %s.",
		none = "%s"
	},
	
	DefaultReasons = {
		Kick = "None",
		Ban = "None",
		Unban = "None"
	},
	
	TimeIntervals = { -- duration : seconds
		{Value = 604800, Name = "weeks"},
		{Value = 86400, Name = "days"},
		{Value = 3600, Name = "hrs"},
		{Value = 60, Name = "mins"},
		{Value = 0, Name = "secs"},
	},
	
	-- ChatCmd Settings
	ChatName = "Server", -- [Server]: message...
	Prefix = ";",
	
	ChatReplyColors = {
		normal = Color3.fromRGB(222, 221, 209),
		error = Color3.fromRGB(255, 218, 67)
	},
	
	MSG_BRACKETS = { -- supported brackets in chat cmd arg parser e.g.
		["'"] = "'",  -- msg: ;kick Roblox 'idk why'  => args: "Roblox", "idk why"
		['"'] = '"',  -- msg: ;kick Roblox idk why    => args: "Roblox", "idk", "why"
		["<"] = ">",
		["{"] = "}",
		["["] = "]",
		["("] = ")",
	},
	
	ClientErrorMessages = {
		INVALID_KEY = "Please provide a valid key!",
		INVALID_TOPIC = "Please provide a valid topic to publish to!",
		INVALID_USER = "Please provide a valid Player or UserId!",
		INVALID_USERID = "Please provide a valid UserId!",
		INVALID_MOD = "%s does not have mod perms!",
		INVALID_MOD_TARGET = "%s is already a mod!",
		INVALID_UNMOD_TARGET = "%s is a default mod! They cannot be removed with this function.",
		INVALID_NOTE = "Please provide a valid note!",
		INVALID_BAN_DURATION = "Please provide a valid duration (seconds)!",
		INVALID_UNBAN_TARGET = "Player is already unbanned!",
		INVALID_LOG_CATEGORY = "Please provide a valid log category! (notes/kicks/bans)",
		INVALID_LOG_NUMBER = "Please provide a valid log number!",
		INVALID_REASON = "Please provide a valid reason!",
		INVALID_DURATION = "Please provide a valid ban duration. Duration is in seconds (-1 for indefinite bans)",
		
		INVALID_CMD = "Could not find command %s",
		INVALID_TARGET = "Please provide a valid target (UserId or Name of a player in the server)!",
		INVALID_SINGLE_TARGET = "More than one target found with name %s!",
	},
	
	ChatCmds = {
		{"cmds", "void"},
		{"verify", "user"},
		{"updatemods", "void"},
		{"getmods", "void"},
		{"addmod", "mod"},
		{"removemod", "mod"},
		{"getlogs", "category", "log_number"},
		{"note", "user", "note"},
		{"kick", "user", "reason", "format"},
		{"ban", "user", "duration", "reason"},
		{"unban", "user", "reason"}
	},
	
	TargetingCmds = { -- add function names that require a target as 1st arg
		verify = true, -- put function name in lower case
		addmod = true,
		removemod = true,
		getlogs = true,
		note = true,
		kick = true,
		ban = true,
		unban = true
	},
	
	LoggingCmds = { -- add function names here that require the moderator as 2nd arg (e.g. for logging purposes)
		note = true, -- put function name in lower case
		kick = true,
		ban = true,
		unban = true
	},
	
	TableResultTypes = { -- add function names that return a table
		cmds = true,      -- put function name in lower case
		getmods = true,
		getlogs = true
	},
	
	BooleanResultTypes = { -- add function names that return a boolean
		verify = true,      -- put function name in lower case
		updatemods = true,
		addmod = true,
		removemod = true,
		note = true,
		kick = true,
		ban = true,
		unban = true
	}
}
