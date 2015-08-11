////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds the record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "ExchangeTransportSettings");
	
EndProcedure

// Updates the record in the register by the passed structure values.
Procedure UpdateRecord(RecordStructure) Export
	
	DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "ExchangeTransportSettings");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving settings for an exchange plan node.

// Retrieves settings of the specified transport kind.
// If the transport kind is not specified (ExchangeTransportKind = Undefined),
// the function retrieves settings of all transport kinds that are present in the system.
//  
// Returns:
//  Structure.
//  
Function GetNodeTransportSettings(Node, ExchangeTransportKind = Undefined) Export
	
	SettingsStructure = New Structure;
	
	// Common settings for all transport kinds
	SettingsStructure.Insert("DefaultExchangeMessageTransportKind");
	SettingsStructure.Insert("ExchangeMessageArchivePassword");
	SettingsStructure.Insert("ExchangeLogFileName");
	SettingsStructure.Insert("ExecuteExchangeInDebugMode");
	SettingsStructure.Insert("DataExportTransactionItemCount");
	SettingsStructure.Insert("DataImportTransactionItemCount");
	
	If ExchangeTransportKind = Undefined Then
		
		For Each TransportKind In Enums.ExchangeMessageTransportKinds Do
			
			TransportSettingsStructure = GetSettingsStructure(CommonUse.EnumValueName(TransportKind));
			
			SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
			
		EndDo;
		
	Else
		
		TransportSettingsStructure = GetSettingsStructure(CommonUse.EnumValueName(ExchangeTransportKind));
		
		SettingsStructure = MergeCollections(SettingsStructure, TransportSettingsStructure);
		
	EndIf;
	
	Return GetRegisterDataByStructure(Node, SettingsStructure);
	
EndFunction

Function GetWSTransportSettings(Node) Export
	
	SettingsStructure = GetSettingsStructure("WS");
	
	Return GetRegisterDataByStructure(Node, SettingsStructure);
	
EndFunction

Function DefaultExchangeMessageTransportKind(InfoBaseNode) Export
	
	// Return value
	ExchangeMessageTransportKind = Undefined;
	
	QueryText = "
	|SELECT
	|	ExchangeTransportSettings.DefaultExchangeMessageTransportKind AS DefaultExchangeMessageTransportKind
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &InfoBaseNode
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		ExchangeMessageTransportKind = Selection.DefaultExchangeMessageTransportKind;
		
	EndIf;
	
	Return ExchangeMessageTransportKind;
EndFunction

Function DataExchangeDirectoryName(ExchangeMessageTransportKind, InfoBaseNode) Export
	
	// Return value
	Result = "";
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
		
		TransportSettings = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(InfoBaseNode);
		
		Result = TransportSettings["FILEDataExchangeDirectory"];
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP Then
		
		TransportSettings = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(InfoBaseNode);
		
		Result = TransportSettings["FTPConnectionPath"];
		
	EndIf;
	
	Return Result;
EndFunction

Function TransportSettingsPresentations(TransportKind) Export
	
	Result = New Structure;
	
	If TransportKind = Enums.ExchangeMessageTransportKinds.COM Then
		
		AddSettingPresentationItem(Result, "COMInfoBaseOperationMode");
		AddSettingPresentationItem(Result, "COMPlatformServerName");
		AddSettingPresentationItem(Result, "COMInfoBaseNameAtPlatformServer");
		AddSettingPresentationItem(Result, "COMInfoBaseDirectory");
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

Function DataImportTransactionItemCount(Node) Export
	
	// Return value
	Result = 0;
	
	QueryText = "
	|SELECT
	|	ExchangeTransportSettings.DataImportTransactionItemCount AS TransactionItemCount
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &Node
	|";
	
	Query = New Query;
	Query.SetParameter("Node", Node);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		Result = Selection.TransactionItemCount;
		
	EndIf;
	
	Return Result;
EndFunction

Function DataExportTransactionItemCount(Node) Export
	
	// Return value
	Result = 0;
	
	QueryText = "
	|SELECT
	|	ExchangeTransportSettings.DataExportTransactionItemCount AS TransactionItemCount
	|FROM
	|	InformationRegister.ExchangeTransportSettings AS ExchangeTransportSettings
	|WHERE
	|	ExchangeTransportSettings.Node = &Node
	|";
	
	Query = New Query;
	Query.SetParameter("Node", Node);
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		
		Result = Selection.TransactionItemCount;
		
	EndIf;
	
	Return Result;
EndFunction

Function ConfiguredTransportTypes(InfoBaseNode) Export
	
	Result = New Array;
	
	TransportSettings = GetNodeTransportSettings(InfoBaseNode);
	
	If ValueIsFilled(TransportSettings.COMInfoBaseDirectory) 
		Or ValueIsFilled(TransportSettings.COMInfoBaseNameAtPlatformServer) Then
		
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

Function GetRegisterDataByStructure(Node, SettingsStructure)
	
	If Not ValueIsFilled(Node) Then
		Return SettingsStructure;
	EndIf;
	
	If SettingsStructure.Count() = 0 Then
		Return SettingsStructure;
	EndIf;
	
	// Generating a text query by the required fields only 
	// (by parameters of the specified transport kinds).
	QueryText = "SELECT ";
	
	For Each SettingItem In SettingsStructure Do
		
		QueryText = QueryText + SettingItem.Key + ", ";
		
	EndDo;
	
	// Deleting the last , character from the query text
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
	
	// Filling the structure if settings for the node are filled.
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
