
// Returns text constant for generating the messages.
// Is used for localization purposes.
//
Function TextForAdministrator() Export
	
	Return NStr("en = 'For administrator:'");
	
EndFunction

// Returns user text of sessions lock message.
//
Function ExtractLockMessage(Val Message) Export
	
	MarkerIndex = Find(Message, TextForAdministrator());
	Return ?(MarkerIndex > 0, Mid(Message, 1, MarkerIndex - 3), Message);
	
EndFunction

