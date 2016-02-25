#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Adds a record to the register by the passed structure values
Procedure AddRecord(RecordStructure) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		DataExchangeServer.AddRecordToInformationRegister(New Structure("Correspondent", RecordStructure.Node), "DataAreaExchangeTransportSettings");
	Else
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "ExchangeTransportSettings");
	EndIf;
	
EndProcedure

// Updates a register record based on the passed structure values
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "ExchangeTransportSettings");
	
EndProcedure

Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	TransportSettings = SavedTransportSettings();
	
	While TransportSettings.Next() Do
		
		RequestToUseExternalResources(PermissionRequests, TransportSettings);
		
	EndDo;
	
EndProcedure

Function SavedTransportSettings()
	
	Query = New Query;
	Query.Text = "SELECT
	|	ExchangeTransportSettings.Node,
	|	ExchangeTransportSettings.FTPConnectionPath,
	|	ExchangeTransportSettings.FILEDataExchangeDirectory,
	|	ExchangeTransportSettings.WSURL,
	|	ExchangeTransportSettings.COMInfobaseDirectory,
	|	ExchangeTransportSettings.COMInfobaseNameAtPlatformServer,
	|	ExchangeTransportSettings.FTPConnectionPath AS FTPConnectionPath,
	|	ExchangeTransportSettings.FTPConnectionPort AS FTPConnectionPort,
	|	ExchangeTransportSettings.WSURL AS WSURL,
	|	ExchangeTransportSettings.FILEDataExchangeDirectory AS FILEDataExchangeDirectory
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings";
	
	QueryResult = Query.Execute();
	Return QueryResult.Select();
	
EndFunction

Procedure RequestToUseExternalResources(PermissionRequests, Write, RequestCOM = True,
	RequestFILE = True, RequestWS = True, RequestFTP = True) Export
	
	Permissions = New Array;
	
	If RequestFTP And Not IsBlankString(Write.FTPConnectionPath) Then
		
		AddressStructure = CommonUseClientServer.URIStructure(Write.FTPConnectionPath);
		Permissions.Add(SafeMode.PermissionToUseInternetResource(
			AddressStructure.Schema, AddressStructure.Domain, Write.FTPConnectionPort));
		
	EndIf;
	
	If RequestFILE And Not IsBlankString(Write.FILEDataExchangeDirectory) Then
		
		Permissions.Add(SafeMode.PermissionToUseFileSystemDirectory(
			Write.FILEDataExchangeDirectory, True, True));
		
	EndIf;
	
	If RequestWS And Not IsBlankString(Write.WSURL) Then
		
		AddressStructure = CommonUseClientServer.URIStructure(Write.WSURL);
		Permissions.Add(SafeMode.PermissionToUseInternetResource(
			AddressStructure.Schema, AddressStructure.Domain, AddressStructure.Port));
		
	EndIf;
	
	If RequestCOM And (Not IsBlankString(Write.COMInfobaseDirectory)
		Or Not IsBlankString(Write.COMInfobaseNameAtPlatformServer)) Then
		
		COMConnectorName = CommonUse.COMConnectorName();
		Permissions.Add(SafeMode.PermissionToCreateCOMClass(
			COMConnectorName, CommonUse.COMConnectorID(COMConnectorName)));
		
	EndIf;
	
	// Permissions to perform synchronization by email are requested 
  // in the Email operations subsystem
	
	If Permissions.Count() > 0 Then
		
		PermissionRequests.Add(
			SafeMode.RequestToUseExternalResources(Permissions, Write.Node));
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving settings for an exchange plan node.

// Retrieves settings of the specified transport kind.
// If the transport kind is not specified (ExchangeTransportKind = Undefined), 
// the function retrieves settings of all transport kinds that are present in the infobase.
//
Function TransportSettings(Val Node, Val ExchangeTransportKind = Undefined) Export
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData() Then
		
		Return InformationRegisters["DataAreaExchangeTransportSettings"].TransportSettings(Node);
	Else
		
		Return ExchangeTransportSettings(Node, ExchangeTransportKind);
	EndIf;
	
EndFunction

Function TransportSettingsWS(Node, AuthenticationParameters = Undefined) Export
	
	SettingsStructure = GetSettingsStructure("WS");
	
	Result = GetRegisterDataByStructure(Node, SettingsStructure);
	
	If TypeOf(AuthenticationParameters) = Type("Structure") Then // Initializing exchange using the current user name
		
		If AuthenticationParameters.UseCurrentUser Then
			
			Result.WSUserName = InfobaseUsers.CurrentUser().Name;
			
		EndIf;
		
		Password = Undefined;
		
		If AuthenticationParameters.Property("Password", Password)
			And Password <> Undefined Then // The password is specified on the client
			
			Result.WSPassword = Password;
			
		Else // The password is not specified on the client
			
			Password = DataExchangeServer.DataSynchronizationPassword(Node);
			
			Result.WSPassword = ?(Password = Undefined, "", Password);
			
		EndIf;
		
	ElsIf TypeOf(AuthenticationParameters) = Type("String") Then
		
		Result.WSPassword = AuthenticationParameters;
		
	EndIf;
	
	Return Result;
EndFunction

Function DefaultExchangeMessageTransportKind(InfobaseNode) Export
	
	// Return value
	ExchangeMessageTransportKind = Undefined;
	
	QueryText = "
	|SELECT
	|	ExchangeTransportSettings.DefaultExchangeMessageTransportKind AS DefaultExchangeMessageTransportKind
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &InfobaseNode
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		ExchangeMessageTransportKind = Selection.DefaultExchangeMessageTransportKind;
		
	EndIf;
	
	Return ExchangeMessageTransportKind;
EndFunction

Function DataExchangeDirectoryName(ExchangeMessageTransportKind, InfobaseNode) Export
	
	// Return value
	Result = "";
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
		
		TransportSettings = TransportSettings(InfobaseNode);
		
		Result = TransportSettings["FILEDataExchangeDirectory"];
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP Then
		
		TransportSettings = TransportSettings(InfobaseNode);
		
		Result = TransportSettings["FTPConnectionPath"];
		
	EndIf;
	
	Return Result;
EndFunction

Function TransportSettingsPresentations(TransportKind) Export
	
	Result = New Structure;
	
	If TransportKind = Enums.ExchangeMessageTransportKinds.COM Then
		
		AddSettingPresentationItem(Result, "COMInfobaseOperationMode");
		AddSettingPresentationItem(Result, "COMPlatformServerName");
		AddSettingPresentationItem(Result, "COMInfobaseNameAtPlatformServer");
		AddSettingPresentationItem(Result, "COMInfobaseDirectory");
		AddSettingPresentationItem(Result, "COMOSAuthentication");
		AddSettingPresentationItem(Result, "COMUserName");
		AddSettingPresentationItem(Result, "COMUserPassword");
		
	ElsIf TransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
		
		AddSettingPresentationItem(Result, "FILEDataExchangeDirectory");
		AddSettingPresentationItem(Result, "FILECompressOutgoingMessageFile");
		
	ElsIf TransportKind = Enums.ExchangeMessageTransportKinds.FTP Then
		
		AddSettingPresentationItem(Result, "FTPConnectionPath");
		AddSettingPresentationItem(Result, "FTPConnectionPort");
		AddSettingPresentationItem(Result, "FTPConnectionUser");
		AddSettingPresentationItem(Result, "FTPConnectionPassword");
		AddSettingPresentationItem(Result, "FTPConnectionMaxMessageSize");
		AddSettingPresentationItem(Result, "FTPConnectionPassiveConnection");
		AddSettingPresentationItem(Result, "FTPCompressOutgoingMessageFile");
		
	ElsIf TransportKind = Enums.ExchangeMessageTransportKinds.EMAIL Then
		
		AddSettingPresentationItem(Result, "EMAILAccount");
		AddSettingPresentationItem(Result, "EMAILMaxMessageSize");
		AddSettingPresentationItem(Result, "EMAILCompressOutgoingMessageFile");
		
	ElsIf TransportKind = Enums.ExchangeMessageTransportKinds.WS Then
		
		AddSettingPresentationItem(Result, "WSURL");
		AddSettingPresentationItem(Result, "WSUserName");
		
	EndIf;
	
	Return Result;
EndFunction

Function NodeTransportSettingsAreSet(Node) Export
	
	QueryText = "
	|SELECT 1 FROM InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &Node
	|";
	
	Query = New Query;
	Query.SetParameter("Node", Node);
	Query.Text = QueryText;
	
	Return Not Query.Execute().IsEmpty();
EndFunction

Function ConfiguredTransportTypes(InfobaseNode) Export
	
	Result = New Array;
	
	TransportSettings = TransportSettings(InfobaseNode);
	
	If ValueIsFilled(TransportSettings.COMInfobaseDirectory) 
		Or ValueIsFilled(TransportSettings.COMInfobaseNameAtPlatformServer) Then
		
		Result.Add(Enums.ExchangeMessageTransportKinds.COM);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.EMAILAccount) Then
		
		Result.Add(Enums.ExchangeMessageTransportKinds.EMAIL);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.FILEDataExchangeDirectory) Then
		
		Result.Add(Enums.ExchangeMessageTransportKinds.FILE);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.FTPConnectionPath) Then
		
		Result.Add(Enums.ExchangeMessageTransportKinds.FTP);
		
	EndIf;
	
	If ValueIsFilled(TransportSettings.WSURL) Then
		
		Result.Add(Enums.ExchangeMessageTransportKinds.WS);
		
	EndIf;
	
	Return Result;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// Retrieves settings of the specified transport kind.
// If the transport kind is not specified (ExchangeTransportKind = Undefined), 
// the function retrieves settings of all transport kinds that are present in the infobase.
//
Function ExchangeTransportSettings(Node, ExchangeTransportKind)
	
	SettingsStructure = New Structure;
	
	// Common settings for all transport kinds
	SettingsStructure.Insert("DefaultExchangeMessageTransportKind");
	SettingsStructure.Insert("ExchangeMessageArchivePassword");
	
	If ExchangeTransportKind = Undefined Then
		
		For Each TransportKind In Enums.ExchangeMessageTransportKinds Do
			
			TransportSettingsStructure = GetSettingsStructure(CommonUse.EnumValueName(TransportKind));
			
			SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
			
		EndDo;
		
	Else
		
		TransportSettingsStructure = GetSettingsStructure(CommonUse.EnumValueName(ExchangeTransportKind));
		
		SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
		
	EndIf;
	
	Result = GetRegisterDataByStructure(Node, SettingsStructure);
	Result.Insert("UseTempDirectoryForSendingAndReceivingMessages", True);
	DataExchangeServer.AddTransactionItemCountToTransportSettings(Result);
	
	Return Result;
EndFunction

Function GetRegisterDataByStructure(Node, SettingsStructure)
	
	If Not ValueIsFilled(Node) Then
		Return SettingsStructure;
	EndIf;
	
	If SettingsStructure.Count() = 0 Then
		Return SettingsStructure;
	EndIf;
	
	// Generating a text query by the required fields only
	// (by parameters of the specified transport kinds)
	QueryText = "SELECT ";
	
	For Each SettingItem In SettingsStructure Do
		
		QueryText = QueryText + SettingItem.Key + ", ";
		
	EndDo;
	
	// Deleting the last ", " character from the query text
	StringFunctionsClientServer.DeleteLastCharsInString(QueryText, 2);
	
	QueryText = QueryText + "
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &Node
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Node", Node);
	
	Selection = Query.Execute().Select();
	
	// Filling the structure if settings for the node are specified
	If Selection.Next() Then
		
		For Each SettingItem In SettingsStructure Do
			
			SettingsStructure[SettingItem.Key] = Selection[SettingItem.Key];
			
		EndDo;
		
	EndIf;
	
	Return SettingsStructure;
	
EndFunction

Function GetSettingsStructure(SearchSubstring)
	
	TransportSettingsStructure = New Structure();
	
	RegisterMetadata = Metadata.InformationRegisters.ExchangeTransportSettings;
	
	For Each Resource In RegisterMetadata.Resources Do
		
		If Find(Resource.Name, SearchSubstring) <> 0 Then
			
			TransportSettingsStructure.Insert(Resource.Name, Resource.Synonym);
			
		EndIf;
		
	EndDo;
	
	Return TransportSettingsStructure;
EndFunction

Function MergeCollections(Structure1, Structure2)
	
	ResultStructure = New Structure;
	
	SupplementCollection(Structure1, ResultStructure);
	SupplementCollection(Structure2, ResultStructure);
	
	Return ResultStructure;
EndFunction

Procedure SupplementCollection(Source, Target)
	
	For Each Item In Source Do
		
		Target.Insert(Item.Key, Item.Value);
		
	EndDo;
	
EndProcedure

Procedure AddSettingPresentationItem(Structure, SettingName)
	
	Structure.Insert(SettingName, Metadata.InformationRegisters.ExchangeTransportSettings.Resources[SettingName].Presentation());
	
EndProcedure

#EndRegion

#EndIf