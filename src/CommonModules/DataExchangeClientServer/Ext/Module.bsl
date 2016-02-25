////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// For internal use
//
Procedure CheckProhibitedCharsInWSProxyUserName(Val UserName) Export
	
	If StringContainsCharacter(UserName, ProhibitedCharsInWSProxyUserName()) Then
		
		MessageString = NStr("en = 'Username %1 contains illegal characters:
			| %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString,
			UserName, ProhibitedCharsInWSProxyUserName());
		Raise MessageString;
	EndIf;
	
EndProcedure

// For internal use
//
Function ProhibitedCharsInWSProxyUserName() Export
	
	Return ":";
	
EndFunction

// For internal use
//
Function StringContainsCharacter(Val String, Val CharacterString)
	
	For Index = 1 To StrLen(CharacterString) Do
		
		Char = Mid(CharacterString, Index, 1);
		
		If Find(String, Char) <> 0 Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

#EndRegion
