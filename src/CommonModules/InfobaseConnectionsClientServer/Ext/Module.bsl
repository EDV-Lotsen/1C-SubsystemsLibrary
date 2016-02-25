////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Deletes all infobase sessions except the current one.
//
Procedure DeleteAllSessionsExceptCurrent(AdministrationParameters) Export
	
	CurrentSessionNumber = InfobaseConnectionsServerCallCached.SessionTerminationParameters().InfobaseSessionNumber;
	
	AllExceptCurrent = New Structure;
	AllExceptCurrent.Insert("Property", "Number");
	AllExceptCurrent.Insert("ComparisonType", ComparisonType.NotEqual);
	AllExceptCurrent.Insert("Value", CurrentSessionNumber);
	
	Filter = New Array;
	Filter.Add(AllExceptCurrent);

	ClusterAdministrationClientServer.DeleteInfobaseSessions(AdministrationParameters,, Filter);
	
EndProcedure

// Gets the infobase connection string if a custom server cluster port is set.
//
// Parameters
//  ServerClusterPort - Number - custom server cluster port.
//
// Returns:
//   String - infobase connection string.
//
Function GetInfobaseConnectionString(Val ServerClusterPort = 0) Export

	Result = InfobaseConnectionString();
	If FileInfobase() Or (ServerClusterPort = 0) Then
		Return Result;
	EndIf;
	
#If AtClient Then
	If CommonUseClient.ClientConnectedViaWebServer() Then
		Return Result;
	EndIf;
#EndIf
	
	ConnectionStringSubstrings  = StringFunctionsClientServer.SplitStringIntoSubstringArray(Result, ";");
	ServerName = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[0], 7));
	InfobaseName      = StringFunctionsClientServer.RemoveDoubleQuotationMarks(Mid(ConnectionStringSubstrings[1], 6));
	Result  = "Srvr=" + """" + ServerName + 
		?(Find(ServerName, ":") > 0, "", ":" + Format(ServerClusterPort, "NG=0")) + """;" + 
		"Ref=" + """" + InfobaseName + """;";
	Return Result;

EndFunction

// Returns the full path to the infobase (connection string).
//
// Parameters
//  FileModeFlag      - Boolean - output parameter. 
//                                True if the current infobase is file-based,
//                                False if the infobase is of client/server type.
//  ServerClusterPort - Number  - input parameter. 
//                                Used if a custom server cluster port is set.
//                                The default value is 0 (meaning the default server cluster port is set).
//
// Returns:
//   String - infobase connection string.
//
Function InfobasePath(FileModeFlag = Undefined, Val ServerClusterPort = 0) Export
	
	ConnectionString = GetInfobaseConnectionString(ServerClusterPort);
	
	SearchPosition = Find(Upper(ConnectionString), "FILE=");
	
	If SearchPosition = 1 Then // File infobase
		
		PathToInfobase = Mid(ConnectionString, 6, StrLen(ConnectionString) - 6);
		FileModeFlag = True;
		
	Else
		FileModeFlag = False;
		
		SearchPosition = Find(Upper(ConnectionString), "SRVR=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		SemicolonPosition = Find(ConnectionString, ";");
		CopyStartPosition = 6 + 1;
		CopyingEndPosition = SemicolonPosition - 2;
		
		ServerName = Mid(ConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		ConnectionString = Mid(ConnectionString, SemicolonPosition + 1);
		
		// Server name position
		SearchPosition = Find(Upper(ConnectionString), "REF=");
		
		If Not (SearchPosition = 1) Then
			Return Undefined;
		EndIf;
		
		CopyStartPosition = 6;
		SemicolonPosition = Find(ConnectionString, ";");
		CopyingEndPosition = SemicolonPosition - 2;
		
		InfobaseNameAtServer = Mid(ConnectionString, CopyStartPosition, CopyingEndPosition - CopyStartPosition + 1);
		
		PathToInfobase = """" + ServerName + "\" + InfobaseNameAtServer + """";
	EndIf;
	
	Return PathToInfobase;
	
EndFunction

// Returns a text constant used to generate messages.
// The function is used for localization purposes.
//
// Returns:
//   String - text intended for the administrator.
//
Function TextForAdministrator() Export
	
	Return NStr("en = 'For administrator:'");
	
EndFunction

// Returns the session lock message text.
// 
// Parameters:
//   Message - String - full message.
// 
// Returns:
//   String - lock message.
//
Function ExtractLockMessage(Val Message) Export
	
	MarkerIndex = Find(Message, TextForAdministrator());
	If MarkerIndex = 0  Then
		Return Message;
	ElsIf MarkerIndex >= 3 Then
		Return Mid(Message, 1, MarkerIndex - 3);
	Else
		Return "";
	EndIf;
		
EndFunction

// Returns a string constant for the generation of event log messages.
//
// Returns:
//   String - event name for the event log.
//
Function EventLogMessageText() Export
	
	Return NStr("en = 'User sessions'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

// Returns the flag specifying whether the infobase is file-based.
//
// Returns:
//   Boolean - True if the infobase is file-based.
//
Function FileInfobase()
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Result = CommonUse.FileInfobase();
#Else
	Result = StandardSubsystemsClientCached.ClientParameters().FileInfobase;
#EndIf
	Return Result;
EndFunction

#EndRegion
