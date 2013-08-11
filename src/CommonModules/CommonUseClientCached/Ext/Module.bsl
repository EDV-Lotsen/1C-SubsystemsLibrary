////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
// Common use client procedures and functions.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns True if this web client does not support the file system extension.
Function IsWebClientWithoutFileSystemExtension() Export
	
	SystemInfo = New SystemInfo;
	
	If Find(SystemInfo.UserAgentInformation, "Safari") <> 0 Then
		Return True;
	EndIf;
	
	If Find(SystemInfo.UserAgentInformation, "Chrome") <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns True if this is the Mac OS web client .
Function IsMacOSWebClient() Export
	
#If Not WebClient Then
	Return False; // This code works only at web client 		
#EndIf
	
	SystemInfo = New SystemInfo;
	If Find(SystemInfo.UserAgentInformation, "Macintosh") <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns a client platform type.
Function ClientPlatformType() Export
	SystemInfo = New SystemInfo;
	Return SystemInfo.PlatformType;
EndFunction