Var ErrorMessageStringField; // String - error message string

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Performs the following actions on data exchange creation:
// - creates or updates nodes of the current exchange plan;
// - loads data conversion rules from the template of the current exchange plan (if
//   infobase is not a DIB);
// - loads data registration rules from the template of the current exchange plan;
// - loads exchange message transport settings;
// - sets the infobase prefix constant value (if it is not set);
// - registers all data on the current exchange plan node according to object 
//   registration rules.
//
// Parameters:
//  Cancel – Boolean – cancel flag. It is set to True if errors occur during the
//                     procedure execution.
// 
Procedure SetUpNewDataExchange(Cancel,
	NodeFilterStructure,
	NodeDefaultValues,
	RecordDataForExport = True) Export
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfoBasePrefix);
	NewNodeCode = ?(WizardRunVariant = "ContinueDataExchangeSetup", SecondInfoBaseNewNodeCode, DataExchangeServer.ExchangePlanNodeCodeString(TargetInfoBasePrefix));
	
	SetUpDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode, RecordDataForExport);
	
EndProcedure

Procedure SetupNewServiceModeDataExchange(Cancel,
	NodeFilterStructure,
	NodeDefaultValues,
	Val ThisNodeCode,
	Val NewNodeCode) Export
	
	NodeFilterStructure  = GetFilterSettingsValues(NodeFilterStructure);
	NodeDefaultValues = GetFilterSettingsValues(NodeDefaultValues);
	
	SetUpDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
	
EndProcedure

Procedure SetUpNewDataExchangeOverWebServiceInTwoBases(Cancel,
	NodeFilterStructure,
	LongAction,
	DataExchangeCreationActionID) Export
	
	SetPrivilegedMode(True);
	
	NodeDefaultValues = New Structure;
	
	ErrorMessageStringField = Undefined;
	ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS;
	UseTransportParametersCOM = False;
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfoBasePrefix);
	NewNodeCode = GetCorrespondentNodeCode();
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, ThisObject);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters);
	Else
		WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		// Creating a new node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Setting the initial data export flag for the node
		InformationRegisters.CommonInfoBaseNodeSettings.SetInitialDataExportFlag(InfoBaseNode);
		
		// Loading message transport settings
		UpdateExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not SourceInfoBasePrefixIsSet Then
			
			UpdateInfoBasePrefixConstantValue();
			
		EndIf;
		
		// Unload wizard parameters into a string
		WizardParameterStringXML = ExecuteWizardParameterExport(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Error creating exchange settings in the second infobase.'");
		EndIf;
		
		If CorrespondentVersion_2_0_1_6 Then
			
			Serializer = New XDTOSerializer(WSProxy.XDTOFactory);
			
			WSProxy.CreateExchange(ExchangePlanName, 
							WizardParameterStringXML, 
							Serializer.WriteXDTO(NodeFilterStructure), 
							Serializer.WriteXDTO(NodeDefaultValues)
			);
			
		Else
			
			WSProxy.CreateExchange(ExchangePlanName, 
							WizardParameterStringXML, 
							ValueToStringInternal(NodeFilterStructure), 
							ValueToStringInternal(NodeDefaultValues)
			);
			
		EndIf;
		
	Except
		
		InformAboutError(ErrorInfo(), Cancel);
		
	EndTry;
	
	If Cancel Then
		
		RollbackTransaction();
		
		Return;
		
	Else
		CommitTransaction();
	EndIf;
	
	// Updating cached values of the object registration mechanism
	DataExchangeServer.RefreshORMCachedValuesIfNecessary();
	
	// Registering changes of catalogs and charts of characteristic types only.
	RecordCatalogChanges(Cancel);
	
	// Registering changes in the second infobase
	WSProxy.RegisterOnlyCatalogData(
			ExchangePlanName,
			DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
			LongAction,
			DataExchangeCreationActionID
	);
	
EndProcedure

Procedure SetUpNewDataExchangeOverExternalConnection(Cancel,
	NodeFilterStructure,
	NodeDefaultValues,
	CorrespondentInfoBaseNodeFilterSetup,
	CorrespondentInfoBaseNodeDefaultValues) Export
	
	ErrorMessageStringField = Undefined;
	ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM;
	UseTransportParametersCOM = True;
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfoBasePrefix);
	NewNodeCode = DataExchangeServer.ExchangePlanNodeCodeString(TargetInfoBasePrefix);
	
	// Creating an external connection
	ExternalConnection = DataExchangeServer.EstablishExternalConnection(ThisObject, ErrorMessageStringField);
	
	If ExternalConnection = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Create a new node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Setting the initial data export flag for the node
		InformationRegisters.CommonInfoBaseNodeSettings.SetInitialDataExportFlag(InfoBaseNode);
		
		// Loading message transport settings
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not SourceInfoBasePrefixIsSet Then
			
			UpdateInfoBasePrefixConstantValue();
			
		EndIf;
		
		// Unload wizard parameters into a string
		WizardParameterStringXML = ExecuteWizardParameterExport(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Error creating exchange settings in the second infobase.'");
		EndIf;
		
		// Getting the data processor of the exchange setup wizard in the second base
		DataExchangeCreationWizard = ExternalConnection.DataProcessors.DataExchangeCreationWizard.Create();
		DataExchangeCreationWizard.ExchangePlanName = ExchangePlanName;
		
		// Loading wizard parameters from the string into the wizard data processor
		DataExchangeCreationWizard.ExternalConnectionImportWizardParameters(Cancel, WizardParameterStringXML);
		
		If Cancel Then
			Message = NStr("en = 'The following errors occur during exchange settings creation in the second infobase: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataExchangeCreationWizard.ErrorMessageString());
			Raise Message;
		EndIf;
		
		// Creating exchange settings in the second infobase via an external connection
		If CorrespondentVersion_2_0_1_6 Then
			
			DataExchangeCreationWizard.ExternalConnectionSetUpNewDataExchange_2_0_1_6(Cancel,
														CommonUse.ValueToXMLString(CorrespondentInfoBaseNodeFilterSetup),
														CommonUse.ValueToXMLString(CorrespondentInfoBaseNodeDefaultValues),
														TargetInfoBasePrefixIsSet,
														TargetInfoBasePrefix
			);
			
		Else
			
			DataExchangeCreationWizard.ExternalConnectionSetUpNewDataExchange(Cancel,
														ValueToStringInternal(CorrespondentInfoBaseNodeFilterSetup),
														ValueToStringInternal(CorrespondentInfoBaseNodeDefaultValues),
														TargetInfoBasePrefixIsSet,
														TargetInfoBasePrefix
			);
			
		EndIf;
		
		If Cancel Then
			Message = NStr("en = 'The following errors occur during exchange settings creation in the second infobase: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataExchangeCreationWizard.ErrorMessageString());
			Raise Message;
		EndIf;
		
	Except
		
		InformAboutError(ErrorInfo(), Cancel);
		
	EndTry;
	
	If Cancel Then
		
		RollbackTransaction();
		
		Return;
		
	Else
		CommitTransaction();
	EndIf;
	
	// Updating cached values of the object registration mechanism
	DataExchangeServer.RefreshORMCachedValuesIfNecessary();
	
	// Registering changes on the exchange plan note
	RecordChangesForExchange(Cancel);
	
	// Registering changes in the second infobase via the external connection
	DataExchangeCreationWizard.ExternalConnectionRecordChangesForExchange();
	
EndProcedure

Procedure UpdateDataExchangeSettings(Cancel,
	NodeDefaultValues,
	CorrespondentInfoBaseNodeDefaultValues,
	LongAction,
	DataExchangeCreationActionID) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageStringField = Undefined;
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, ThisObject);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters);
	Else
		WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		// Update settings for the node
		InfoBaseNodeObject = InfoBaseNode.GetObject();
		
		// Setting default values  
		SetNodeDefaultValues(InfoBaseNodeObject, NodeDefaultValues);
		
		InfoBaseNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		InfoBaseNodeObject.Write();
		
		// Setting the initial data export flag for the node
		InformationRegisters.CommonInfoBaseNodeSettings.SetInitialDataExportFlag(InfoBaseNode);
		
		If CorrespondentVersion_2_0_1_6 Then
			
			Serializer = New XDTOSerializer(WSProxy.XDTOFactory);
			
			WSProxy.UpdateExchange(
								ExchangePlanName,
								DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
								Serializer.WriteXDTO(CorrespondentInfoBaseNodeDefaultValues)
			);
		Else
			
			WSProxy.UpdateExchange(
								ExchangePlanName,
								DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
								ValueToStringInternal(CorrespondentInfoBaseNodeDefaultValues)
			);
		EndIf;
		
	Except
		
		InformAboutError(ErrorInfo(), Cancel);
		
	EndTry;
	
	If Cancel Then
		
		RollbackTransaction();
		
		Return;
		
	Else
		CommitTransaction();
	EndIf;
	
	// Registering changes of all data except catalogs and charts of characteristic types
	RecordAllChangesExceptCatalogs(Cancel);
	
	// Registering changes in the second infobase
	WSProxy.RegisterAllDataExceptCatalogs(
			ExchangePlanName,
			DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
			LongAction,
			DataExchangeCreationActionID
	);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working via an external connection.

Procedure ExternalConnectionSetUpNewDataExchange(Cancel, 
									CorrespondentInfoBaseNodeFilterSetup, 
									CorrespondentInfoBaseNodeDefaultValues, 
									InfoBasePrefixSet, 
									InfoBasePrefix
	) Export
	
	NodeFilterStructure  = GetFilterSettingsValues(ValueFromStringInternal(CorrespondentInfoBaseNodeFilterSetup));
	NodeDefaultValues = GetFilterSettingsValues(ValueFromStringInternal(CorrespondentInfoBaseNodeDefaultValues));
	
	ErrorMessageStringField = Undefined;
	WizardRunVariant = "ContinueDataExchangeSetup";
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfoBasePrefix);
	NewNodeCode = SecondInfoBaseNewNodeCode;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		If GetFunctionalOption("UseDataExchange") = False Then
			
			Constants.UseDataExchange.Set(True);
			
		EndIf;
		
		// Create a new node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Setting the initial data export flag for the node
		InformationRegisters.CommonInfoBaseNodeSettings.SetInitialDataExportFlag(InfoBaseNode);
		
		// Loading message transport settings
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not InfoBasePrefixSet Then
			
			ValueBeforeUpdate = GetFunctionalOption("InfoBasePrefix");
			
			If ValueBeforeUpdate <> InfoBasePrefix Then
				
				Constants.DistributedInfoBaseNodePrefix.Set(TrimAll(InfoBasePrefix));
				
			EndIf;
			
		EndIf;
		
	Except
		
		InformAboutError(ErrorInfo(), Cancel);
		
	EndTry;
	
	If Cancel Then
		
		RollbackTransaction();
		
		Return;
		
	Else
		CommitTransaction();
	EndIf;
	
EndProcedure

Procedure ExternalConnectionSetUpNewDataExchange_2_0_1_6(Cancel, 
									CorrespondentInfoBaseNodeFilterSetup, 
									CorrespondentInfoBaseNodeDefaultValues, 
									InfoBasePrefixSet, 
									InfoBasePrefix
	) Export
	
	NodeFilterStructure  = GetFilterSettingsValues(CommonUse.ValueFromXMLString(CorrespondentInfoBaseNodeFilterSetup));
	NodeDefaultValues = GetFilterSettingsValues(CommonUse.ValueFromXMLString(CorrespondentInfoBaseNodeDefaultValues));
	
	ErrorMessageStringField = Undefined;
	WizardRunVariant = "ContinueDataExchangeSetup";
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfoBasePrefix);
	NewNodeCode = SecondInfoBaseNewNodeCode;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		If GetFunctionalOption("UseDataExchange") = False Then
			
			Constants.UseDataExchange.Set(True);
			
		EndIf;
		
		// Create a new node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Setting the initial data export flag for the node
		InformationRegisters.CommonInfoBaseNodeSettings.SetInitialDataExportFlag(InfoBaseNode);
		
		// Loading message transport settings
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not InfoBasePrefixSet Then
			
			ValueBeforeUpdate = GetFunctionalOption("InfoBasePrefix");
			
			If ValueBeforeUpdate <> InfoBasePrefix Then
				
				Constants.DistributedInfoBaseNodePrefix.Set(TrimAll(InfoBasePrefix));
				
			EndIf;
			
		EndIf;
		
	Except
		
		InformAboutError(ErrorInfo(), Cancel);
		
	EndTry;
	
	If Cancel Then
		
		RollbackTransaction();
		
		Return;
		
	Else
		CommitTransaction();
	EndIf;
	
EndProcedure

Procedure ExternalConnectionRecordChangesForExchange() Export
	
	// Updating cached values of the object registration mechanism
	DataExchangeServer.RefreshORMCachedValuesIfNecessary();
	
	// Registering changes on the exchange plan node
	RecordChangesForExchange(False);
	
EndProcedure

Procedure ExternalConnectionImportWizardParameters(Cancel, XMLString) Export
	
	ImportWizardParameters(Cancel, XMLString);
	
EndProcedure

Procedure ExternalConnectionRefreshExchangeSettingsData(NodeDefaultValues) Export
	
	NodeDefaultValues = GetFilterSettingsValues(NodeDefaultValues);
	
	BeginTransaction();
	Try
		
		// Update settings for the node
		InfoBaseNodeObject = InfoBaseNode.GetObject();
		
		// Setting default values 
		SetNodeDefaultValues(InfoBaseNodeObject, NodeDefaultValues);
		
		InfoBaseNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		InfoBaseNodeObject.Write();
		
		// Setting the initial data export flag for the node
		InformationRegisters.CommonInfoBaseNodeSettings.SetInitialDataExportFlag(InfoBaseNode);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure



Procedure SetUpNewWebServiceModeDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues) Export
	
	NodeFilterStructure  = GetFilterSettingsValues(NodeFilterStructure);
	NodeDefaultValues = GetFilterSettingsValues(NodeDefaultValues);
	
	SetUpNewDataExchange(Cancel,
													NodeFilterStructure,
													NodeDefaultValues,
													False
	);
	
EndProcedure

// Exports wizard parameters to the temporary storage to continue exchange setup in the
// second infobase.
//
// Parameters:
//  Cancel             – Boolean – cancel flag. It is set to True if errors occur during 
//                       the procedure execution.
//  TempStorageAddress – String – temporary storage address is passed to this parameter
//                       if the XML file with settings is unloaded successfully. Data
//                       from this file will be available on the server and on the client.
// 
Procedure ExportWizardParametersToTempStorage(Cancel, TempStorageAddress) Export
	
	SetPrivilegedMode(True);
	
	// Getting the name of the temporary file on the local file system or on the server
	TempFileName = GetTempFileName("xml");
	
	Try
		TextWriter = New TextWriter(TempFileName, TextEncoding.UTF8);
	Except
		DataExchangeServer.ReportError(BriefErrorDescription(ErrorInfo()), Cancel);
		Return;
	EndTry;
	
	XMLString = ExecuteWizardParameterExport(Cancel);
	
	If Not Cancel Then
		
		TextWriter.Write(XMLString);
		
	EndIf;
	
	TextWriter.Close();
	TextWriter = Undefined;
	
	TempStorageAddress = PutToTempStorage(New BinaryData(TempFileName));
	
	DeleteTempFile(TempFileName);
	
EndProcedure

// Exports wizard parameters into a constant to continue exchange setup in the in the
// subordinate DIB node.
//
// Parameters:
//  Cancel – Boolean – cancel flag; It is set to True if errors occur during the
//           procedure execution.
// 
Procedure ExecuteWizardParameterExportToConstant(Cancel) Export
	
	SetPrivilegedMode(True);
	
	XMLString = ExecuteWizardParameterExport(Cancel);
	
	If Not Cancel Then
		
		Constants.SubordinateDIBNodeSettings.Set(XMLString);
		
		ExchangePlans.RecordChanges(InfoBaseNode, Metadata.Constants.SubordinateDIBNodeSettings);
		
	EndIf;
	
EndProcedure

// Imports wizard parameters to the temporary storage to continue exchange setup in the
// second infobase.
//
// Parameters:
//  Cancel             – Boolean – cancel flag. It is set to True if errors occur during 
//                       the procedure execution.
//  TempStorageAddress – String – address of the temporary storage that contains XML 
//                       file data to be imported.
//
Procedure ExecuteWizardParameterImportFromTempStorage(Cancel, TempStorageAddress) Export
	
	SetPrivilegedMode(True);
	
	BinaryData = GetFromTempStorage(TempStorageAddress);
	
	// Getting the name of the temporary file on the local file system or on the server
	TempFileName = GetTempFileName("xml");
	
	// Getting a file to be read
	BinaryData.Write(TempFileName);
	
	TextReader = New TextReader(TempFileName, TextEncoding.UTF8);
	
	XMLString = TextReader.Read();
	
	// Deleting the temporary file
	DeleteTempFile(TempFileName);
	
	ImportWizardParameters(Cancel, XMLString);
	
EndProcedure

// Imports wizard parameters into a constant to continue exchange setup in the in the
// subordinate DIB node.
//
// Parameters:
//  Cancel – Boolean – cancel flag. It is set to True if errors occur during the
//           procedure execution.
//
Procedure ExecuteWizardParameterImportFromConstant(Cancel) Export
	
	SetPrivilegedMode(True);
	
	XMLString = Constants.SubordinateDIBNodeSettings.Get();
	
	ImportWizardParameters(Cancel, XMLString);
	
EndProcedure

Procedure Initialization(Node) Export
	
	InfoBaseNode = Node;
	InfoBaseNodeParameters = CommonUse.GetAttributeValues(Node, "Code, Description");
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfoBaseNode);
	
	ThisInfoBaseDescription = CommonUse.GetAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Description");
	SecondInfoBaseDescription = InfoBaseNodeParameters.Description;
	
	TargetInfoBasePrefix = InfoBaseNodeParameters.Code;
	
	TransportSettings = InformationRegisters.ExchangeTransportSettings.GetNodeTransportSettings(Node);
	
	FillPropertyValues(ThisObject, TransportSettings);
	
	ExchangeMessageTransportKind = TransportSettings.DefaultExchangeMessageTransportKind;
	
	UseTransportParametersCOM = False;
	UseTransportParametersEMAIL = False;
	UseTransportParametersFILE = False;
	UseTransportParametersFTP = False;
	
	If ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE Then
		
		UseTransportParametersFILE = True;
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FTP Then
		
		UseTransportParametersFTP = True;
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.EMAIL Then
		
		UseTransportParametersEMAIL = True;
		
	ElsIf ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM Then
		
		UseTransportParametersCOM = True;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Return the data exchange error message string. 
//
// Returns:
//  String.
//
Function ErrorMessageString() Export
	
	If TypeOf(ErrorMessageStringField) <> Type("String") Then
		
		ErrorMessageStringField = "";
		
	EndIf;
	
	Return ErrorMessageStringField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary internal procedures and functions.

Procedure SetUpDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode, RecordDataForExport = True)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating/updating the exchange plan node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Setting the initial data export flag for the node
		If Not IsDistributedInfoBaseSetup Then
			
			InformationRegisters.CommonInfoBaseNodeSettings.SetInitialDataExportFlag(InfoBaseNode);
			
		EndIf;
		
		
		// Loading message transport settings	
		UpdateExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not SourceInfoBasePrefixIsSet Then
			
			UpdateInfoBasePrefixConstantValue();
			
		EndIf;
		
		If IsDistributedInfoBaseSetup
			And WizardRunVariant = "ContinueDataExchangeSetup" Then
			
			Constants.SubordinateDIBNodeSetupCompleted.Set(True);
			
		EndIf;
		
	Except
		
		InformAboutError(ErrorInfo(), Cancel);
		
	EndTry;
	
	If Cancel Then
		
		RollbackTransaction();
		
		Return;
		
	Else
		CommitTransaction();
	EndIf;
	
	If RecordDataForExport Then
		
		// Updating cached values of the object registration mechanism
		DataExchangeServer.RefreshORMCachedValuesIfNecessary();
		
		If Not IsDistributedInfoBaseSetup Then
			
			// Registering changes on the exchange plan node
			RecordChangesForExchange(Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode)
	
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	// UPDATING THIS NODE, IF NECESSARY
	
	// Getting references to this exchange plan node
	ThisNode = ExchangePlanManager.ThisNode();
	
	If IsBlankString(CommonUse.GetAttributeValue(ThisNode, "Code")) Then
		
		ThisNodeObject = ThisNode.GetObject();
		ThisNodeObject.Code = ThisNodeCode;
		ThisNodeObject.Description = ThisInfoBaseDescription;
		ThisNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		ThisNodeObject.Write();
		
	EndIf;
	
	// GETTING THE NODE FOR EXCHANGE
	
	If IsDistributedInfoBaseSetup
		And WizardRunVariant = "ContinueDataExchangeSetup" Then
		
		MasterNode = ExchangePlans.MasterNode();
		
		If MasterNode = Undefined Then
			
			Raise NStr("en = 'The master node for the current infobase is not defined.
							|Perhaps, the infobase is not a subordinated node of the distributed infobase.'"
			);
		EndIf;
		
		NewNode = MasterNode.GetObject();
		
	Else
		
		// CREATING/UPDATING THE NODE
		NewNode = ExchangePlanManager.FindByCode(NewNodeCode);
		
		If NewNode.IsEmpty() Then
			NewNode = ExchangePlanManager.CreateNode();
			NewNode.Code = NewNodeCode;
		Else
			NewNode = NewNode.GetObject();
		EndIf;
		
		NewNode.Description = SecondInfoBaseDescription;
		
	EndIf;
	
	// Setting filter values for the new node
	SetNodeFilterValues(NewNode, NodeFilterStructure);
	
	// Setting default values for the new node
	SetNodeDefaultValues(NewNode, NodeDefaultValues);
	
	// Resetting message counters
	NewNode.SentNo     = 0;
	NewNode.ReceivedNo = 0;
	
	NewNode.AdditionalProperties.Insert("GettingExchangeMessage");
	NewNode.Write();
	
	InfoBaseNode = NewNode.Ref;
	
EndProcedure

Procedure UpdateExchangeMessageTransportSettings()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Node",                                InfoBaseNode);
	RecordStructure.Insert("DefaultExchangeMessageTransportKind", ExchangeMessageTransportKind);
	
	RecordStructure.Insert("DataExportTransactionItemCount", 200);
	RecordStructure.Insert("DataImportTransactionItemCount", 200);
	
	RecordStructure.Insert("WSUseLargeDataTransfer", True);
	
	SupplementStructureWithAttributeValue(RecordStructure, "CombiExchangeMessageTransportKind");
	SupplementStructureWithAttributeValue(RecordStructure, "EMAILMaxMessageSize");
	SupplementStructureWithAttributeValue(RecordStructure, "EMAILCompressOutgoingMessageFile");
	SupplementStructureWithAttributeValue(RecordStructure, "EMAILAccount");
	SupplementStructureWithAttributeValue(RecordStructure, "FILEDataExchangeDirectory");
	SupplementStructureWithAttributeValue(RecordStructure, "FILECompressOutgoingMessageFile");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPCompressOutgoingMessageFile");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionMaxMessageSize");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPassword");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPassiveConnection");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionUser");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPort");
	SupplementStructureWithAttributeValue(RecordStructure, "FTPConnectionPath");
	SupplementStructureWithAttributeValue(RecordStructure, "WSURL");
	SupplementStructureWithAttributeValue(RecordStructure, "WSUserName");
	SupplementStructureWithAttributeValue(RecordStructure, "WSPassword");
	SupplementStructureWithAttributeValue(RecordStructure, "ExchangeMessageArchivePassword");
	
	// Adding the record to the information register
	InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

Procedure UpdateCOMExchangeMessageTransportSettings()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Node",                                InfoBaseNode);
	RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.COM);
	
	RecordStructure.Insert("DataExportTransactionItemCount", 200);
	RecordStructure.Insert("DataImportTransactionItemCount", 200);
	
	SupplementStructureWithAttributeValue(RecordStructure, "COMOSAuthentication");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfoBaseOperationMode");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfoBaseNameAtPlatformServer");
	SupplementStructureWithAttributeValue(RecordStructure, "COMUserName");
	SupplementStructureWithAttributeValue(RecordStructure, "COMPlatformServerName");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfoBaseDirectory");
	SupplementStructureWithAttributeValue(RecordStructure, "COMUserPassword");
	
	// Adding the record to the information register
	InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

Procedure SupplementStructureWithAttributeValue(RecordStructure, AttributeName)
	
	RecordStructure.Insert(AttributeName, ThisObject[AttributeName]);
	
EndProcedure

Procedure UpdateInfoBasePrefixConstantValue()
	
	ValueBeforeUpdate = GetFunctionalOption("InfoBasePrefix");
	
	If IsBlankString(ValueBeforeUpdate)
		And ValueBeforeUpdate <> SourceInfoBasePrefix Then
		
		Constants.DistributedInfoBaseNodePrefix.Set(TrimAll(SourceInfoBasePrefix));
		
	EndIf;
	
EndProcedure

Procedure FillExchangePlanNodeTable(Node, TabularSectionStructure, TableName)
	
	NodeTable = Node[TableName];
	
	NodeTable.Clear();
	
	For Each Item In TabularSectionStructure Do
		
		SetTableRowCount(NodeTable, Item.Value.Count());
		
		NodeTable.LoadColumn(Item.Value, Item.Key);
		
	EndDo;
	
EndProcedure

Procedure RecordChangesForExchange(Cancel, Data = Undefined)
	
	Try
		DataExchangeServer.RegisterDataForInitialExport(InfoBaseNode, Data);
	Except
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
EndProcedure

Procedure RecordCatalogChanges(Cancel)
	
	Data = DataExchangeServer.ExchangePlanCatalogs(ExchangePlanName);
	
	If Data.Count() > 0 Then
		
		RecordChangesForExchange(Cancel, Data);
		
	EndIf;
	
EndProcedure

Procedure RecordAllChangesExceptCatalogs(Cancel)
	
	Data = DataExchangeServer.AllExchangePlanDataExceptCatalogs(ExchangePlanName);
	
	If Data.Count() > 0 Then
		
		RecordChangesForExchange(Cancel, Data);
		
	EndIf;
	
EndProcedure

Procedure SetNodeFilterValues(ExchangePlanNode, Settings)
	
	FilterSettings = ExchangePlans[ExchangePlanName].NodeFilterStructure();
	
	For Each Item In FilterSettings Do
		
		FilterKey = Item.Key;
		Value = Undefined;
		
		If Settings.Property(FilterKey, Value) Then
			
			If TypeOf(Value) = Type("Array") Then
				
				AttributeData = GetReferenceTypeFromFirstExchangePlanTabularSectionAttribute(ExchangePlanName, FilterKey);
				
				If AttributeData = Undefined Then
					Continue;
				EndIf;
				
				NodeTable = ExchangePlanNode[FilterKey];
				
				NodeTable.Clear();
				
				For Each TableRow In Value Do
					
					If TableRow.Use Then
						
						ObjectManager = CommonUse.ObjectManagerByRef(AttributeData.Type.AdjustValue());
						
						AttributeValue = ObjectManager.GetRef(New UUID(TableRow.RefUUID));
						
						NodeTable.Add()[AttributeData.Name] = AttributeValue;
						
					EndIf;
					
				EndDo;
				
			ElsIf TypeOf(Value) = Type("Structure") Then
				
				FillExchangePlanNodeTable(ExchangePlanNode, Value, FilterKey);
				
			Else // Primitive types
				
				ExchangePlanNode[FilterKey] = Value;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure SetNodeDefaultValues(ExchangePlanNode, NodeDefaultValues)
	
	For Each Setup In NodeDefaultValues Do
		
		ExchangePlanNode[Setup.Key] = Setup.Value;
		
	EndDo;
	
EndProcedure

Procedure SetTableRowCount(Table, LineCount)
	
	While Table.Count() < LineCount Do
		
		Table.Add();
		
	EndDo;
	
EndProcedure

Function ExecuteWizardParameterExport(Cancel)
	
	Try
		
		XMLWriter = New XMLWriter;
		XMLWriter.SetString("UTF-8");
		XMLWriter.WriteXMLDeclaration();
		
		XMLWriter.WriteStartElement("SettingsParameters");
		XMLWriter.WriteAttribute("FormatVersion", ExchangeDataSettingsFileFormatVersion());
		
		XMLWriter.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
		XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
		XMLWriter.WriteNamespaceMapping("v8", "http://v8.1c.ru/data");
		
		// Exporting wizard parameters
		XMLWriter.WriteStartElement("MainExchangeParameters");
		ExportWizardParameters(XMLWriter);
		XMLWriter.WriteEndElement(); // MainExchangeParameters
		
		If UseTransportParametersEMAIL Then
			
			XMLWriter.WriteStartElement("EmailAccount");
			WriteXML(XMLWriter, ?(ValueIsFilled(EMAILAccount), EMAILAccount.GetObject(), Undefined));
			XMLWriter.WriteEndElement(); // EmailAccount
			
		EndIf;
		
		XMLWriter.WriteEndElement(); // SettingsParameters
		
	Except
		DataExchangeServer.ReportError(BriefErrorDescription(ErrorInfo()), Cancel);
		Return "";
	EndTry;
	
	Return XMLWriter.Close();
	
EndFunction

Function GetFilterSettingsValues(ExternalConnectionSettingsStructure)
	
	Result = New Structure;
	
	// Object types
	For Each FilterSettings In ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSettings.Value) = Type("Structure") Then
			
			ResultNested = New Structure;
			
			For Each Item In FilterSettings.Value Do
				
				If Find(Item.Key, "_Key") > 0 Then
					
					FilterKey = StrReplace(Item.Key, "_Key", "");
					
					Array = New Array;
					
					For Each ArrayElement In Item.Value Do
						
						If Not IsBlankString(ArrayElement) Then
							
							Value = ValueFromStringInternal(ArrayElement);
							
							Array.Add(Value);
							
						EndIf;
						
					EndDo;
					
					ResultNested.Insert(FilterKey, Array);
					
				EndIf;
				
			EndDo;
			
			Result.Insert(FilterSettings.Key, ResultNested);
			
		Else
			
			If Find(FilterSettings.Key, "_Key") > 0 Then
				
				FilterKey = StrReplace(FilterSettings.Key, "_Key", "");
				
				Try
					If IsBlankString(FilterSettings.Value) Then
						Value = Undefined;
					Else
						Value = ValueFromStringInternal(FilterSettings.Value);
					EndIf;
				Except
					Value = Undefined;
				EndTry;
				
				Result.Insert(FilterKey, Value);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Primitive types
	For Each FilterSettings In ExternalConnectionSettingsStructure Do
		
		If TypeOf(FilterSettings.Value) = Type("Structure") Then
			
			ResultNested = Result[FilterSettings.Key];
			
			If ResultNested = Undefined Then
				
				ResultNested = New Structure;
				
			EndIf;
			
			For Each Item In FilterSettings.Value Do
				
				If Find(Item.Key, "_Key") <> 0 Then
					
					Continue;
					
				ElsIf FilterSettings.Value.Property(Item.Key + "_Key") Then
					
					Continue;
					
				EndIf;
				
				Array = New Array;
				
				For Each ArrayElement In Item.Value Do
					
					Array.Add(ArrayElement);
					
				EndDo;
				
				ResultNested.Insert(Item.Key, Array);
				
			EndDo;
			
		Else
			
			If Find(FilterSettings.Key, "_Key") <> 0 Then
				
				Continue;
				
			ElsIf ExternalConnectionSettingsStructure.Property(FilterSettings.Key + "_Key") Then
				
				Continue;
				
			EndIf;
			
			Result.Insert(FilterSettings.Key, FilterSettings.Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

Function GetThisBaseNodeCode(Val InfoBasePrefixSpecifiedByUser)
	
	If WizardRunVariant = "ContinueDataExchangeSetup"
		And ExchangeDataSettingsFileFormatVersion = "1.0" Then
		
		Return PredefinedNodeCode;
		
	EndIf;
	
	Result = GetFunctionalOption("InfoBasePrefix");
	
	If IsBlankString(Result) Then
		
		Result = InfoBasePrefixSpecifiedByUser;
		
		If IsBlankString(Result) Then
			
			Return "000";
			
		EndIf;
		
	EndIf;
	
	Return DataExchangeServer.ExchangePlanNodeCodeString(Result);
EndFunction

Function GetCorrespondentNodeCode()
	
	If Not IsBlankString(CorrespondentNodeCode) Then
		
		Return CorrespondentNodeCode;
		
	EndIf;
	
	Return DataExchangeServer.ExchangePlanNodeCodeString(TargetInfoBasePrefix);
EndFunction

Function GetReferenceTypeFromFirstExchangePlanTabularSectionAttribute(Val ExchangePlanName, Val TabularSectionName)
	
	TabularSection = Metadata.ExchangePlans[ExchangePlanName].TabularSections[TabularSectionName];
	
	For Each Attribute In TabularSection.Attributes Do
		
		Type = Attribute.Type.Types()[0];
		
		If CommonUse.IsReference(Type) Then
			
			Return New Structure("Name, Type", Attribute.Name, Attribute.Type);
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
EndFunction

Procedure ReadParametersIntoStructure(Cancel, XMLString, SettingsStructure)
	
	Try
		XMLReader = New XMLReader;
		XMLReader.SetString(XMLString);
	Except
		Cancel = True;
		XMLReader = Undefined;
		Return;
	EndTry;
	
	Try
		
		XMLReader.Read(); // SettingsParameters
		FormatVersion = XMLReader.GetAttribute("FormatVersion");
		ExchangeDataSettingsFileFormatVersion = ?(FormatVersion = Undefined, "1.0", FormatVersion);
		
		XMLReader.Read(); // MainExchangeParameters
		
		// Reading the MainExchangeParameters node
		SettingsStructure = ReadDataToStructure(XMLReader);
		
		If SettingsStructure.Property("UseTransportParametersEMAIL", UseTransportParametersEMAIL)
			And UseTransportParametersEMAIL Then
			
			// Reading the EmailAccount node
			XMLReader.Read(); // EmailAccount {StartElement}
			
			SettingsStructure.Insert("EmailAccount", ReadXML(XMLReader));
			
			XMLReader.Read(); // EmailAccount {EndElement}
			
		EndIf;
		
	Except
		Cancel = True;
	EndTry;
	
	XMLReader.Close();
	XMLReader = Undefined;
	
EndProcedure

Procedure ImportWizardParameters(Cancel, XMLString) Export
	
	Var SettingsStructure;
	
	ReadParametersIntoStructure(Cancel, XMLString, SettingsStructure);
	
	If SettingsStructure = Undefined Then
		Return;
	EndIf;
	
	// Verifying read from the file parameters
	If SettingsStructure.Property("ExchangePlanName")
		And SettingsStructure.ExchangePlanName <> ExchangePlanName Then
		
		ErrorMessageStringField = NStr("en = 'File contains exchange settings for another infobase.'");
		DataExchangeServer.ReportError(ErrorMessageString(), Cancel);
		
	EndIf;
	
	If Not Cancel Then
		
		// Filling data processor properties with values from the file
		FillPropertyValues(ThisObject, SettingsStructure);
		
		EmailAccount = Undefined;
		
		If SettingsStructure.Property("EmailAccount", EmailAccount)
			And EmailAccount <> Undefined Then
			
			EmailAccount.Write();
			
		EndIf;
		
		// Supporting the exchange settings file of the 1.0 version format
		If ExchangeDataSettingsFileFormatVersion = "1.0" Then
			
			ThisObject.ThisInfoBaseDescription = NStr("en = 'This infobase'");
			ThisObject.SecondInfoBaseDescription = SettingsStructure.DataExchangeExecutionSettingsDescription;
			ThisObject.SecondInfoBaseNewNodeCode = SettingsStructure.NewNodeCode;
			
		EndIf;
		
	EndIf;
	
	InfoBasePrefix = GetFunctionalOption("InfoBasePrefix");
	
	If Not IsBlankString(InfoBasePrefix)
		And InfoBasePrefix <> SourceInfoBasePrefix Then
		
		ErrorMessageStringField = NStr("en = 'You specified the wrong prefix of the second infobase during the first setup stage.
				|Start the setup all over again.'");
		
		DataExchangeServer.ReportError(ErrorMessageString(), Cancel);
		
	EndIf;
	
EndProcedure

Function ReadDataToStructure(XMLReader)
	
	// Return value
	Structure = New Structure;
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Then
		
		Raise NStr("en = 'Error reading the XML file.'");
		
	EndIf;
	
	XMLReader.Read();
	
	While XMLReader.NodeType <> XMLNodeType.EndElement Do
		
		NodeName = XMLReader.Name;
		
		Structure.Insert(NodeName, ReadXML(XMLReader));
		
	EndDo;
	
	XMLReader.Read();
	
	Return Structure;
	
EndFunction

Procedure ExportWizardParameters(XMLWriter)
	
	AddXMLRecord(XMLWriter, "ExchangePlanName");
	
	WriteXML(XMLWriter, ThisInfoBaseDescription,   "SecondInfoBaseDescription", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, SecondInfoBaseDescription, "ThisInfoBaseDescription", XMLTypeAssignment.Explicit);
	
	WriteXML(XMLWriter, CommonUse.GetAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Code"), "SecondInfoBaseNewNodeCode", XMLTypeAssignment.Explicit);
	
	WriteXML(XMLWriter, TargetInfoBasePrefix, "SourceInfoBasePrefix", XMLTypeAssignment.Explicit);
	
	// Exchange message transport settings
	AddXMLRecord(XMLWriter, "ExchangeMessageTransportKind");
	AddXMLRecord(XMLWriter, "ExchangeMessageArchivePassword");
	
	If UseTransportParametersEMAIL Then
		
		AddXMLRecord(XMLWriter, "EMAILMaxMessageSize");
		AddXMLRecord(XMLWriter, "EMAILCompressOutgoingMessageFile");
		AddXMLRecord(XMLWriter, "EMAILAccount");
		
	EndIf;
	
	If UseTransportParametersFILE Then
		
		AddXMLRecord(XMLWriter, "FILEDataExchangeDirectory");
		AddXMLRecord(XMLWriter, "FILECompressOutgoingMessageFile");
		
	EndIf;
	
	If UseTransportParametersFTP Then
		
		AddXMLRecord(XMLWriter, "FTPCompressOutgoingMessageFile");
		AddXMLRecord(XMLWriter, "FTPConnectionMaxMessageSize");
		AddXMLRecord(XMLWriter, "FTPConnectionPassword");
		AddXMLRecord(XMLWriter, "FTPConnectionPassiveConnection");
		AddXMLRecord(XMLWriter, "FTPConnectionUser");
		AddXMLRecord(XMLWriter, "FTPConnectionPort");
		AddXMLRecord(XMLWriter, "FTPConnectionPath");
		
	EndIf;
	
	If UseTransportParametersCOM Then
		
		ConnectionParameters = CommonUseClientServer.GetConnectionParametersFromInfoBaseConnectionString(InfoBaseConnectionString());
		
		InfoBaseOperationMode             = ConnectionParameters.InfoBaseOperationMode;
		InfoBaseNameAtPlatformServer = ConnectionParameters.InfoBaseNameAtPlatformServer;
		PlatformServerName                     = ConnectionParameters.PlatformServerName;
		InfoBaseDirectory                   = ConnectionParameters.InfoBaseDirectory;
		
		InfoBaseUser = InfoBaseUsers.CurrentUser();
		OSAuthentication = InfoBaseUser.OSAuthentication;
		UserName                   = InfoBaseUser.Name;
		
		WriteXML(XMLWriter, InfoBaseOperationMode, "COMInfoBaseOperationMode", XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, InfoBaseNameAtPlatformServer, "COMInfoBaseNameAtPlatformServer", XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, PlatformServerName, "COMPlatformServerName", XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, InfoBaseDirectory, "COMInfoBaseDirectory", XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, OSAuthentication, "COMOSAuthentication", XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, UserName, "COMUserName", XMLTypeAssignment.Explicit);
		
	EndIf;
	
	AddXMLRecord(XMLWriter, "UseTransportParametersEMAIL");
	AddXMLRecord(XMLWriter, "UseTransportParametersFILE");
	AddXMLRecord(XMLWriter, "UseTransportParametersFTP");
	
	// Supporting the exchange settings file of the 1.0 version format
	WriteXML(XMLWriter, ThisInfoBaseDescription, "DataExchangeExecutionSettingsDescription", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, CommonUse.GetAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Code"), "NewNodeCode", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, CommonUse.GetAttributeValue(InfoBaseNode, "Code"),                 "PredefinedNodeCode", XMLTypeAssignment.Explicit);
	
EndProcedure

Procedure AddXMLRecord(XMLWriter, AttributeName)
	
	WriteXML(XMLWriter, ThisObject[AttributeName], AttributeName, XMLTypeAssignment.Explicit);
	
EndProcedure

Procedure DeleteTempFile(TempFileName)
	
	Try
		
		If Not IsBlankString(TempFileName) Then
			
			DeleteFiles(TempFileName);
			
		EndIf;
		
	Except
	EndTry;
	
EndProcedure

Procedure InformAboutError(ErrorInfo, Cancel)
	
	ErrorMessageStringField = DetailErrorDescription(ErrorInfo);
	
	DataExchangeServer.ReportError(BriefErrorDescription(ErrorInfo), Cancel);
	
	WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(), EventLogLevel.Error,,, ErrorMessageString());
	
EndProcedure

Function ExchangeDataSettingsFileFormatVersion()
	
	Return "1.1";
	
EndFunction
