# Watchdog
*Add security to your code with ease*

This module is supposed to be used to note down problems with server code e.g. when an event is fired and things don't add up.
You can note the problem down easily and kick/ban if you have to, so it's nothing like HD admin or anything similar.

The structure is supposed to look like this:

![image](https://github.com/ItsHiatus/Watchdog/assets/87611306/55d7da93-b9c7-40c6-a17e-d904f8e39930)

(you can get the model which has it all set up for you: https://www.roblox.com/library/11089010539/Watchdog)

### Important Notes:
- You must call `Watchdog.Verify(player)` on every player that joins. This ensures that banned players are kicked from the game, and players whose ban duration is up, are unbanned. However, this is done for you in the Server Setup script.

- Moderators can be added by adding them to the DefaultModerator table located in **Settings** or by calling `Watchdog.AddMod(new_mod)`
			
- To remove moderators, either remove them from the DefaultModerator list (if they were added there) or by calling `Watchdog.RemoveMod(old_mod)`.
				
- `Watchdog.UpdateMods()` must be called at least once when the server starts. This is done for you at the bottom of the module.

- `Note`, `Kick`, `Ban` and `Unban` commands take a moderator as the second argument. This is required for logging purposes. This is provided automatically with the set up ChatCmds.
	
- Ban duration unit is seconds. For indefinite bans, set the duration to -1.
	
- Make sure commands that write to datastores are not used on a particular User in a real game setting; otherwise, a lot of datastore requests will be made, doing the exact same thing.
			
- ChatMod arg is for ChatCmds only. It is used to update the client on the result of their cmd usage. You do not need to pass it when using the function (it is done for you in the ChatCmd setup).

- Client script (handles chat cmd replies) is cloned to the moderator's PlayerGui when their Character spawns, so you don't have to move it yourself.
### API:

```
-- Types --

User : UserId|Player
LogCategory : "Notes" | "Kicks" | "Bans"
Format : "error" | "sus"
Data : {[any] : any}
DataDict : {[string] : Data}
List : {[string] : number}
```

```lua
Watchdog.Verify(user : User): boolean
--	Checks if user has access to the game (false = banned)
```

```lua
Watchdog.UpdateMods() : boolean
--	Resyncs the 'Moderators' table with the 'DefaultModerators' and the moderators added 
--	using Watchdog.AddMod()
```

```lua
Watchdog.AddMod(new_moderator : User) : boolean
```

```lua
Watchdog.RemoveMod(old_moderator : User) : boolean
```

```lua
Watchdog.GetLogs(user : User, category : LogCategory?, log_number : number?) : (Data | DataDict)?
--	Returns a list of ordered logs (newest to oldest) for the specified category.
--	If no category is specified, it will return a dictionary containing all ordered logs.
--	If 'log_number' is provided, that log will be returned instead of the whole log list.
```

```lua
Watchdog.Note(user : User, moderator : User, note : string) : boolean
```

```lua
Watchdog.RemoveNote(user : User, note_id : number) : boolean
```

```lua
Watchdog.Kick(user : User, moderator : User, reason : string?, format : Format?) : boolean
--[[	'reason' will default to "None" when nil (changeable)
	'format' will reformat the reason to display a better kick message to the player.
		This makes it easier to write descriptive kick messages:
			- [error]  reason .. "If this problem persists, please contact support."
			- [sus]    "Suspicious activity detected:" .. reason
			- [nil]    reason (no extra message)
							
			(you can add more formats to the KickMessageFormat table)
]]--
```

```lua
Watchdog.Ban(user : User, moderator : User, duration : number, reason : string?) : boolean
--	'duration' is in seconds (set to -1 for indefinite)
--	'reason' will default to "None" when nil (changeable)
```

```lua
Watchdog.Unban(user : User, moderator : User, reason : string?) : boolean
--	'reason' will default to "None" when nil (changeable)
```

```lua
Watchdog.LocalNote(user : User, moderator : User, note : string) : boolean
--[[
	Creates a note on the server. It will not be stored on any datastore and will disappear
	when the server closes.
	To see LocalNotes, use Watchdog.GetLocalNotes()
]]
```

```lua
Watchdog.GetLocalNotes(user : User, note_id : number)
--	Returns the note with the specified id stored on the server (or all if not specified).
```

```lua
Watchdog.Cmds() : {List}
```
