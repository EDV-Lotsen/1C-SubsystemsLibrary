#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var ErrorMessageStringField; // String - error message string

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Performs the following actions on data exchange creation:
//   creates or updates nodes of the current exchange plan
//   loads data conversion rules from the template of the current exchange plan (if infobase is not a DIB)
//   loads data registration rules from the template of the current exchange plan
//   loads exchange message transport settings
//   sets the infobase prefix constant value (if it is not set)
//   registers all data on the current exchange plan node according to object registration rules.
//
// Parameters:
//  Cancel - Boolean - cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure SetUpNewDataExchange(Cancel,
	NodeFilterStructure,
	NodeDefaultValues,
	RecordDataForExport = True,
	UseTransportSettings = True) Export
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfobasePrefix);
	NewNodeCode = ?(WizardRunVariant = "ContinueDataExchangeSetup", SecondInfobaseNewNodeCode, DataExchangeServer.ExchangePlanNodeCodeString(TargetInfobasePrefix));
	
	SetUpDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode, RecordDataForExport, UseTransportSettings);
	
EndProcedure

// Sets up a new data exchange for SaaS mode.
//
Procedure SetupNewDataExchangeSaaS(Cancel,
	NodeFilterStructure,
	NodeDefaultValues,
	Val ThisNodeCode,
	Val NewNodeCode) Export
	
	NodeFilterStructure = GetFilterSettingsValues(NodeFilterStructure);
	NodeDefaultValues   = GetFilterSettingsValues(NodeDefaultValues);
	
	SetUpDataExchange(Cancel, NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
	
EndProcedure

// Sets up a new data exchange in both Infobases.
//
Procedure SetUpNewDataExchangeOverWebServiceInTwoBases(Cancel,
	NodeFilterStructure,
	LongAction,
	DataExchangeCreationActionID) Export
	
	SetPrivilegedMode(True);
	
	NodeDefaultValues = New Structure;
	
	ErrorMessageStringField      = Undefined;
	ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.WS;
	UseTransportParametersCOM    = False;
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfobasePrefix);
	NewNodeCode  = GetCorrespondentNodeCode();
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, ThisObject);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionParameters);
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
		
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
		
		// Creating a node
		CreateUpdateExchangePlanNodes(NodeFilterStructure.NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Loading message transport settings
		UpdateExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not SourceInfobasePrefixIsSet Then
			
			UpdateInfobasePrefixConstantValue();
			
		EndIf;
		
		// Exporting wizard parameters into a string
		WizardParameterStringXML = ExecuteWizardParameterExport(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Error creating exchange settings in the second infobase.'");
		EndIf;
		
		// {Handler: OnSendSenderData} Beginning
		ExchangePlans[ExchangePlanName].OnSendSenderData(NodeFilterStructure, False);
		// {Handler: OnSendSenderData} End
		
		If CorrespondentVersion_2_1_1_7 Then
			
			Serializer = New XDTOSerializer(WSProxy.XDTOFactory);
			
			WSProxy.CreateExchange(ExchangePlanName, 
							WizardParameterStringXML, 
							Serializer.WriteXDTO(EscapeEnumerations(NodeFilterStructure.CorrespondentInfobaseNodeFilterSetup)),
							Serializer.WriteXDTO(EscapeEnumerations(NodeDefaultValues)));
			
		ElsIf CorrespondentVersion_2_0_1_6 Then
			
			Serializer = New XDTOSerializer(WSProxy.XDTOFactory);
			
			WSProxy.CreateExchange(ExchangePlanName,
							WizardParameterStringXML,
							Serializer.WriteXDTO(NodeFilterStructure.CorrespondentInfobaseNodeFilterSetup),
							Serializer.WriteXDTO(NodeDefaultValues));
			
		Else
			
			WSProxy.CreateExchange(ExchangePlanName,
							WizardParameterStringXML,
							ValueToStringInternal(NodeFilterStructure.CorrespondentInfobaseNodeFilterSetup),
							ValueToStringInternal(NodeDefaultValues));
			
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
	
	// Registering changes of catalogs and charts of characteristic types only
	Try
		DataExchangeServer.RegisterOnlyCatalogsForInitialExport(InfobaseNode);
	Except
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
	// Registering changes in the second infobase
	WSProxy.RegisterOnlyCatalogData(
			ExchangePlanName,
			DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
			LongAction,
			DataExchangeCreationActionID);
	
EndProcedure

// Sets up a new data exchange over an external connection.
//
Procedure SetUpNewDataExchangeOverExternalConnection(Cancel,
	NodeFilterStructure,
	NodeDefaultValues,
	CorrespondentInfobaseNodeFilterSetup,
	CorrespondentInfobaseNodeDefaultValues) Export
	
	ErrorMessageStringField      = Undefined;
	ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.COM;
	UseTransportParametersCOM    = True;
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfobasePrefix);
	NewNodeCode  = DataExchangeServer.ExchangePlanNodeCodeString(TargetInfobasePrefix);
	
	// Creating an external connection
	Connection              = DataExchangeServer.EstablishExternalConnectionWithInfobase(ThisObject);
	ErrorMessageStringField = Connection.DetailedErrorDetails;
	ExternalConnection      = Connection.Connection;
	
	If ExternalConnection = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating a node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Loading message transport settings
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not SourceInfobasePrefixIsSet Then
			
			UpdateInfobasePrefixConstantValue();
			
		EndIf;
		
		// Exporting wizard parameters into a string
		WizardParameterStringXML = ExecuteWizardParameterExport(Cancel);
		
		If Cancel Then
			Raise NStr("en = 'Error creating exchange settings in the second infobase.'");
		EndIf;
		
		// Creating an instance of exchange setup wizard data processor
		DataExchangeCreationWizard = ExternalConnection.DataProcessors.DataExchangeCreationWizard.Create();
		DataExchangeCreationWizard.ExchangePlanName = ExchangePlanName;
		
		// Loading wizard parameters from a string to the wizard data processor
		DataExchangeCreationWizard.ExternalConnectionImportWizardParameters(Cancel, WizardParameterStringXML);
		
		If Cancel Then
			Message = NStr("en = 'Errors occurred in the second infobase during the data exchange setup: %1'");
			Message = StringFunctionsClientServer.SubstituteParametersInString(Message, DataExchangeCreationWizard.ErrorMessageString());
			Raise Message;
		EndIf;
		
		// Creating exchange settings in the second infobase via an external connection
		If CorrespondentVersion_2_1_1_7 Or CorrespondentVersion_2_0_1_6 Then
			
			DataExchangeCreationWizard.ExternalConnectionSetUpNewDataExchange_2_0_1_6(Cancel,
														CommonUse.ValueToXMLString(CorrespondentInfobaseNodeFilterSetup),
														CommonUse.ValueToXMLString(CorrespondentInfobaseNodeDefaultValues),
														TargetInfobasePrefixIsSet,
														TargetInfobasePrefix);
			
		Else
			
			DataExchangeCreationWizard.ExternalConnectionSetUpNewDataExchange(Cancel,
														ValueToStringInternal(CorrespondentInfobaseNodeFilterSetup),
														ValueToStringInternal(CorrespondentInfobaseNodeDefaultValues),
														TargetInfobasePrefixIsSet,
														TargetInfobasePrefix);
			
		EndIf;
		
		If Cancel Then
			Message = NStr("en = 'Errors occurred in the second infobase during the data exchange setup: %1'");
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
	
	// Registering changes for an exchange plan node
	RecordChangesForExchange(Cancel);
	
	// Registering changes in the second infobase via the external connection
	DataExchangeCreationWizard.ExternalConnectionRecordChangesForExchange();
	
EndProcedure

// Updates data exchange settings.
//
Procedure UpdateDataExchangeSettings(Cancel,
	NodeDefaultValues,
	CorrespondentInfobaseNodeDefaultValues,
	LongAction,
	DataExchangeCreationActionID) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageStringField = Undefined;
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, ThisObject);
	
	If CorrespondentVersion_2_1_1_7 Then
		
		WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionParameters);
		
	ElsIf CorrespondentVersion_2_0_1_6 Then
			
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
		
		// Updating settings for the node
		InfobaseNodeObject = InfobaseNode.GetObject();
		
		// Setting default values 
		DataExchangeEvents.SetNodeDefaultValues(InfobaseNodeObject, NodeDefaultValues);
		
		InfobaseNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		InfobaseNodeObject.Write();
		
		If CorrespondentVersion_2_1_1_7 Or CorrespondentVersion_2_0_1_6 Then
			
			Serializer = New XDTOSerializer(WSProxy.XDTOFactory);
			
			WSProxy.UpdateExchange(
								ExchangePlanName,
								DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
								Serializer.WriteXDTO(EscapeEnumerations(CorrespondentInfobaseNodeDefaultValues)));
		Else
			
			WSProxy.UpdateExchange(
								ExchangePlanName,
								DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
								ValueToStringInternal(CorrespondentInfobaseNodeDefaultValues));
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
	Try
		DataExchangeServer.RegisterAllDataExceptCatalogsForInitialExport(InfobaseNode);
	Except
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
	// Registering changes in the second infobase
	WSProxy.RegisterAllDataExceptCatalogs(
			ExchangePlanName,
			DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName),
			LongAction,
			DataExchangeCreationActionID);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working via an external connection.

// Sets up a new data exchange over an external connection.
//
Procedure ExternalConnectionSetUpNewDataExchange(Cancel, 
									CorrespondentInfobaseNodeFilterSetup, 
									CorrespondentInfobaseNodeDefaultValues, 
									InfobasePrefixSet, 
									InfobasePrefix
	) Export
	
	DataExchangeServer.CheckUseDataExchange();
	
	NodeFilterStructure = GetFilterSettingsValues(ValueFromStringInternal(CorrespondentInfobaseNodeFilterSetup));
	NodeDefaultValues   = GetFilterSettingsValues(ValueFromStringInternal(CorrespondentInfobaseNodeDefaultValues));
	
	ErrorMessageStringField = Undefined;
	WizardRunVariant = "ContinueDataExchangeSetup";
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfobasePrefix);
	NewNodeCode  = SecondInfobaseNewNodeCode;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating a node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Loading message transport settings
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not InfobasePrefixSet Then
			
			ValueBeforeUpdate = GetFunctionalOption("InfobasePrefix");
			
			If ValueBeforeUpdate <> InfobasePrefix Then
				
				Constants.DistributedInfobaseNodePrefix.Set(TrimAll(InfobasePrefix));
				
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

// Sets up a new data exchange over an external connection.
//
Procedure ExternalConnectionSetUpNewDataExchange_2_0_1_6(Cancel, 
									CorrespondentInfobaseNodeFilterSetup, 
									CorrespondentInfobaseNodeDefaultValues, 
									InfobasePrefixSet, 
									InfobasePrefix
	) Export
	
	NodeFilterStructure = GetFilterSettingsValues(CommonUse.ValueFromXMLString(CorrespondentInfobaseNodeFilterSetup));
	NodeDefaultValues   = GetFilterSettingsValues(CommonUse.ValueFromXMLString(CorrespondentInfobaseNodeDefaultValues));
	
	ErrorMessageStringField = Undefined;
	WizardRunVariant = "ContinueDataExchangeSetup";
	
	ThisNodeCode = GetThisBaseNodeCode(SourceInfobasePrefix);
	NewNodeCode  = SecondInfobaseNewNodeCode;
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		DataExchangeServer.CheckUseDataExchange();
		
		// Creating a node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		// Loading message transport settings
		UpdateCOMExchangeMessageTransportSettings();
		
		// Updating the infobase prefix constant value
		If Not InfobasePrefixSet Then
			
			ValueBeforeUpdate = GetFunctionalOption("InfobasePrefix");
			
			If ValueBeforeUpdate <> InfobasePrefix Then
				
				Constants.DistributedInfobaseNodePrefix.Set(TrimAll(InfobasePrefix));
				
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

// Registers changes for an exchange plan node.
//
Procedure ExternalConnectionRecordChangesForExchange() Export
	
	// Registering changes for an exchange plan node
	RecordChangesForExchange(False);
	
EndProcedure

// Reads exchange wizard settings from the XML string.
//
Procedure ExternalConnectionImportWizardParameters(Cancel, XMLLine) Export
	
	ImportWizardParameters(Cancel, XMLLine);
	
EndProcedure

// Updates data exchange node settings over an external connection and sets default values.
//
Procedure ExternalConnectionRefreshExchangeSettingsData(NodeDefaultValues) Export
	
	BeginTransaction();
	Try
		
		// Updating settings for the node
		InfobaseNodeObject = InfobaseNode.GetObject();
		
		// Setting default values 
		DataExchangeEvents.SetNodeDefaultValues(InfobaseNodeObject, NodeDefaultValues);
		
		InfobaseNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		InfobaseNodeObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Sets up a new data exchange over a web service.
// See the detailed description in the SetUpNewDataExchange procedure.
//
Procedure SetUpNewDataExchangeWebService(Cancel, NodeFilterStructure, NodeDefaultValues) Export
	
	NodeFilterStructure = GetFilterSettingsValues(NodeFilterStructure);
	NodeDefaultValues   = GetFilterSettingsValues(NodeDefaultValues);
	
	// {Handler: OnGetSenderData} Beginning
	Try
		ExchangePlans[ExchangePlanName].OnGetSenderData(NodeFilterStructure, False);
	Except
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	// {Handler: OnGetSenderData} End
	
	SetUpNewDataExchange(Cancel,
													NodeFilterStructure,
													NodeDefaultValues,
													False,
													False);
	
EndProcedure

// Exports wizard parameters to the temporary storage to continue exchange setup in the second infobase.
//
// Parameters:
//  Cancel             – Boolean – cancellation flag. It is set to True if errors occur during 
//                       the procedure execution.
//  TempStorageAddress – String – temporary storage address is passed to this parameter
//                       if the XML file with settings is imported successfully. Data
//                       from this file will be available on the server and on the client.
// 
Procedure ExportWizardParametersToTempStorage(Cancel, TempStorageAddress) Export
	
	SetPrivilegedMode(True);
	
	// Getting the temporary file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	Try
		TextWriter = New TextWriter(TempFileName, TextEncoding.UTF8);
	Except
		DataExchangeServer.ReportError(BriefErrorDescription(ErrorInfo()), Cancel);
		Return;
	EndTry;
	
	XMLLine = ExecuteWizardParameterExport(Cancel);
	
	If Not Cancel Then
		
		TextWriter.Write(XMLLine);
		
	EndIf;
	
	TextWriter.Close();
	TextWriter = Undefined;
	
	TempStorageAddress = PutToTempStorage(New BinaryData(TempFileName));
	
	DeleteTempFile(TempFileName);
	
EndProcedure

// Exports wizard parameters into a constant to continue exchange setup in the in the subordinate DIB node.
//
// Parameters:
//  Cancel - Boolean - cancellation flag. It is set to True if errors occur during the procedure execution.
// 
Procedure ExecuteWizardParameterExportToConstant(Cancel) Export
	
	SetPrivilegedMode(True);
	
	XMLLine = ExecuteWizardParameterExport(Cancel);
	
	If Not Cancel Then
		
		Constants.SubordinateDIBNodeSettings.Set(XMLLine);
		
		ExchangePlans.RecordChanges(InfobaseNode, Metadata.Constants.SubordinateDIBNodeSettings);
		
	EndIf;
	
EndProcedure

// Imports wizard parameters to the temporary storage to continue exchange setup in the second infobase.
//
// Parameters:
//  Cancel             – Boolean – cancellation flag. It is set to True if errors occur during 
//                       the procedure execution.
//  TempStorageAddress – String – address of the temporary storage that contains XML 
//                       file data to be imported.
//
Procedure ExecuteWizardParameterImportFromTempStorage(Cancel, TempStorageAddress) Export
	
	SetPrivilegedMode(True);
	
	BinaryData = GetFromTempStorage(TempStorageAddress);
	
	// Getting the temporary file name in the local file system on the server
	TempFileName = GetTempFileName("xml");
	
	// Getting a file to be read
	BinaryData.Write(TempFileName);
	
	TextReader = New TextReader(TempFileName, TextEncoding.UTF8);
	
	XMLLine = TextReader.Read();
	
	// Deleting the temporary file
	DeleteTempFile(TempFileName);
	
	ImportWizardParameters(Cancel, XMLLine);
	
EndProcedure

// Imports wizard parameters into a constant to continue exchange setup in the in the subordinate DIB node.
//
// Parameters:
//  Cancel - Boolean - cancellation flag. It is set to True if errors occur during the procedure execution.
//
Procedure ExecuteWizardParameterImportFromConstant(Cancel) Export
	
	SetPrivilegedMode(True);
	
	XMLLine = Constants.SubordinateDIBNodeSettings.Get();
	
	ImportWizardParameters(Cancel, XMLLine);
	
EndProcedure

// Initializes exchange node settings.
//
Procedure Initialization(Node) Export
	
	InfobaseNode = Node;
	InfobaseNodeParameters = CommonUse.ObjectAttributeValues(Node, "Code, Description");
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(InfobaseNode);
	
	ThisInfobaseDescription   = CommonUse.ObjectAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Description");
	SecondInfobaseDescription = InfobaseNodeParameters.Description;
	
	TargetInfobasePrefix = InfobaseNodeParameters.Code;
	
	TransportSettings = InformationRegisters.ExchangeTransportSettings.TransportSettings(Node);
	
	FillPropertyValues(ThisObject, TransportSettings);
	
	ExchangeMessageTransportKind = TransportSettings.DefaultExchangeMessageTransportKind;
	
	UseTransportParametersCOM   = False;
	UseTransportParametersEMAIL = False;
	UseTransportParametersFILE  = False;
	UseTransportParametersFTP   = False;
	
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

// Returns the data exchange error message string.
//
// Returns:
//  String - data exchange error message string.
//
Function ErrorMessageString() Export
	
	If TypeOf(ErrorMessageStringField) <> Type("String") Then
		
		ErrorMessageStringField = "";
		
	EndIf;
	
	Return ErrorMessageStringField;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary internal procedures and functions.

Procedure SetUpDataExchange(
		Cancel, 
		NodeFilterStructure, 
		NodeDefaultValues, 
		ThisNodeCode, 
		NewNodeCode, 
		RecordDataForExport = True, 
		UseTransportSettings = True)
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating/updating the exchange plan node
		CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode);
		
		If UseTransportSettings Then
			
			// Loading message transport settings
			UpdateExchangeMessageTransportSettings();
			
		EndIf;
		
		// Updating the infobase prefix constant value
		If Not SourceInfobasePrefixIsSet Then
			
			UpdateInfobasePrefixConstantValue();
			
		EndIf;
		
		If IsDistributedInfobaseSetup
			And WizardRunVariant = "ContinueDataExchangeSetup" Then
			
			// Importing rules because exchange rules are not migrated to DIB
			DataExchangeServer.UpdateDataExchangeRules();
			
			Constants.SubordinateDIBNodeSetupCompleted.Set(True);
			Constants.UseDataSynchronization.Set(True);
			Constants.DontUseSeparationByDataAreas.Set(True);
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
	// Updating cached values of the object registration mechanism
	DataExchangeServerCall.CheckObjectChangeRecordMechanismCache();
	
	If RecordDataForExport
		And Not IsDistributedInfobaseSetup Then
		
		// Registering changes for an exchange plan node
		RecordChangesForExchange(Cancel);
		
	EndIf;
	
EndProcedure

Procedure CreateUpdateExchangePlanNodes(NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode)
	
	// Checking exchange plan content
	StandardSubsystemsServer.ValidateExchangePlanContent(ExchangePlanName);
	
	ExchangePlanManager = ExchangePlans[ExchangePlanName];
	
	// UPDATING THIS NODE, IF NECESSARY
	
	// Getting references to this exchange plan node
	ThisNode = ExchangePlanManager.ThisNode();
	
	If IsBlankString(CommonUse.ObjectAttributeValue(ThisNode, "Code")) Then
		
		ThisNodeObject = ThisNode.GetObject();
		ThisNodeObject.Code = ThisNodeCode;
		ThisNodeObject.Description = ThisInfobaseDescription;
		ThisNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		ThisNodeObject.Write();
		
	EndIf;
	
	// GETTING THE NODE FOR EXCHANGE
	
	If IsDistributedInfobaseSetup
		And WizardRunVariant = "ContinueDataExchangeSetup" Then
		
		MasterNode = DataExchangeServer.MasterNode();
		
		If MasterNode = Undefined Then
			
			Raise NStr("en = 'The master node for the current infobase is not defined.
							|Perhaps, the infobase is not a subordinated node of the distributed infobase.'");
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
		
		NewNode.Description = SecondInfobaseDescription;
		
	EndIf;
	
	// Setting filter values for the new node
	DataExchangeEvents.SetNodeFilterValues(NewNode, NodeFilterStructure);
	
	// Setting default values for the new node
	DataExchangeEvents.SetNodeDefaultValues(NewNode, NodeDefaultValues);
	
	// Resetting message counters
	NewNode.SentNo = 0;
	NewNode.ReceivedNo     = 0;
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.CanUseSeparatedData()
		And DataExchangeServer.IsSLSeparatedExchangePlan(ExchangePlanName) Then
		
		NewNode.RegisterChanges = True;
		
	EndIf;
	
	If RefNew <> Undefined Then
		NewNode.SetNewObjectRef(RefNew);
	EndIf;
	
	NewNode.AdditionalProperties.Insert("Import");
	NewNode.Write();
	
	InfobaseNode = NewNode.Ref;
	
EndProcedure

Procedure UpdateExchangeMessageTransportSettings()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Node",                                InfobaseNode);
	RecordStructure.Insert("DefaultExchangeMessageTransportKind", ExchangeMessageTransportKind);
	
	RecordStructure.Insert("WSUseLargeDataTransfer", True);
	
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
	SupplementStructureWithAttributeValue(RecordStructure, "WSRememberPassword");
	SupplementStructureWithAttributeValue(RecordStructure, "ExchangeMessageArchivePassword");
	
	// Adding information register record
	InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

Procedure UpdateCOMExchangeMessageTransportSettings()
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Node",                                InfobaseNode);
	RecordStructure.Insert("DefaultExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.COM);
	
	SupplementStructureWithAttributeValue(RecordStructure, "COMOSAuthentication");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfobaseOperationMode");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfobaseNameAtPlatformServer");
	SupplementStructureWithAttributeValue(RecordStructure, "COMUserName");
	SupplementStructureWithAttributeValue(RecordStructure, "COMPlatformServerName");
	SupplementStructureWithAttributeValue(RecordStructure, "COMInfobaseDirectory");
	SupplementStructureWithAttributeValue(RecordStructure, "COMUserPassword");
	
	// Adding information register record
	InformationRegisters.ExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

Procedure SupplementStructureWithAttributeValue(RecordStructure, AttributeName)
	
	RecordStructure.Insert(AttributeName, ThisObject[AttributeName]);
	
EndProcedure

Procedure UpdateInfobasePrefixConstantValue()
	
	ValueBeforeUpdate = GetFunctionalOption("InfobasePrefix");
	
	If IsBlankString(ValueBeforeUpdate)
		And ValueBeforeUpdate <> SourceInfobasePrefix Then
		
		Constants.DistributedInfobaseNodePrefix.Set(TrimAll(SourceInfobasePrefix));
		
	EndIf;
	
EndProcedure

Procedure RecordChangesForExchange(Cancel)
	
	Try
		DataExchangeServer.RegisterDataForInitialExport(InfobaseNode);
	Except
		InformAboutError(ErrorInfo(), Cancel);
		Return;
	EndTry;
	
EndProcedure

Function ExecuteWizardParameterExport(Cancel)
	
	Try
		
		XMLWriter = New XMLWriter;
		XMLWriter.SetString("UTF-8");
		XMLWriter.WriteXMLDeclaration();
		
		XMLWriter.WriteStartElement("SetupParameters");
		XMLWriter.WriteAttribute("FormatVersion", ExchangeDataSettingsFileFormatVersion());
		
		XMLWriter.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
		XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
		XMLWriter.WriteNamespaceMapping("v8",  "http://v8.1c.ru/data");
		
		// Exporting wizard parameters
		XMLWriter.WriteStartElement("MainExchangeParameters");
		ExportWizardParameters(XMLWriter);
		XMLWriter.WriteEndElement(); // MainExchangeParameters
		
		If UseTransportParametersEMAIL Then
			
			XMLWriter.WriteStartElement("EmailAccount");
			WriteXML(XMLWriter, ?(ValueIsFilled(EMAILAccount), EMAILAccount.GetObject(), Undefined));
			XMLWriter.WriteEndElement(); // EmailAccount
			
		EndIf;
		
		XMLWriter.WriteEndElement(); // SetupParameters
		
	Except
		DataExchangeServer.ReportError(BriefErrorDescription(ErrorInfo()), Cancel);
		Return "";
	EndTry;
	
	Return XMLWriter.Close();
	
EndFunction

Function GetThisBaseNodeCode(Val InfobasePrefixSpecifiedByUser)
	
	If WizardRunVariant = "ContinueDataExchangeSetup"
		And ExchangeDataSettingsFileFormatVersion = "1.0" Then
		
		Return PredefinedNodeCode;
		
	EndIf;
	
	Result = GetFunctionalOption("InfobasePrefix");
	
	If IsBlankString(Result) Then
		
		Result = InfobasePrefixSpecifiedByUser;
		
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
	
	Return DataExchangeServer.ExchangePlanNodeCodeString(TargetInfobasePrefix);
EndFunction

Procedure ReadParametersIntoStructure(Cancel, XMLLine, SettingsStructure)
	
	Try
		XMLReader = New XMLReader;
		XMLReader.SetString(XMLLine);
	Except
		Cancel = True;
		XMLReader = Undefined;
		Return;
	EndTry;
	
	Try
		
		XMLReader.Read(); // SetupParameters
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

// Reads exchange wizard settings from the XML string.
//
Procedure ImportWizardParameters(Cancel, XMLLine) Export
	
	Var SettingsStructure;
	
	ReadParametersIntoStructure(Cancel, XMLLine, SettingsStructure);
	
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
		
		EmailAccountVar = Undefined;
		
		If SettingsStructure.Property("EmailAccount", EmailAccountVar)
			And EmailAccountVar <> Undefined Then
			
			EmailAccountVar.Write();
			
		EndIf;
		
		// Supporting the exchange settings file of the 1.0 version format
		If ExchangeDataSettingsFileFormatVersion = "1.0" Then
			
			ThisObject.ThisInfobaseDescription   = NStr("en = 'This Infobase'");
			ThisObject.SecondInfobaseDescription = SettingsStructure.DataExchangeExecutionSettingsDescription;
			ThisObject.SecondInfobaseNewNodeCode = SettingsStructure.NewNodeCode;
			
		EndIf;
		
	EndIf;
	
	InfobasePrefix = GetFunctionalOption("InfobasePrefix");
	
	If Not IsBlankString(InfobasePrefix)
		And InfobasePrefix <> SourceInfobasePrefix Then
		
		ErrorMessageStringField = NStr("en = 'You specified the wrong prefix of the second infobase during the first setup stage.
				|Start the setup all over again.'");

		DataExchangeServer.ReportError(ErrorMessageString(), Cancel);
		
	EndIf;
	
EndProcedure

Function ReadDataToStructure(XMLReader)
	
	// Return value
	Structure = New Structure;
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Then
		
		Raise NStr("en = 'XML read error'");
		
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
	
	WriteXML(XMLWriter, ThisInfobaseDescription,   "SecondInfobaseDescription", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, SecondInfobaseDescription, "ThisInfobaseDescription", XMLTypeAssignment.Explicit);
	
	WriteXML(XMLWriter, CommonUse.ObjectAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Code"), "SecondInfobaseNewNodeCode", XMLTypeAssignment.Explicit);
	
	WriteXML(XMLWriter, TargetInfobasePrefix, "SourceInfobasePrefix", XMLTypeAssignment.Explicit);
	
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
		
		ConnectionParameters = CommonUseClientServer.GetConnectionParametersFromInfobaseConnectionString(InfobaseConnectionString());
		
		InfobaseOperationMode        = ConnectionParameters.InfobaseOperationMode;
		InfobaseNameAtPlatformServer = ConnectionParameters.InfobaseNameAtPlatformServer;
		PlatformServerName           = ConnectionParameters.PlatformServerName;
		InfobaseDirectory            = ConnectionParameters.InfobaseDirectory;
		
		IBUser = InfobaseUsers.CurrentUser();
		OSAuthentication = IBUser.OSAuthentication;
		UserName         = IBUser.Name;
		
		WriteXML(XMLWriter, InfobaseOperationMode,        "COMInfobaseOperationMode",        XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, InfobaseNameAtPlatformServer, "COMInfobaseNameAtPlatformServer", XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, PlatformServerName,           "COMPlatformServerName",           XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, InfobaseDirectory,            "COMInfobaseDirectory",            XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, OSAuthentication,             "COMOSAuthentication",             XMLTypeAssignment.Explicit);
		WriteXML(XMLWriter, UserName,                     "COMUserName",                     XMLTypeAssignment.Explicit);
		
	EndIf;
	
	AddXMLRecord(XMLWriter, "UseTransportParametersEMAIL");
	AddXMLRecord(XMLWriter, "UseTransportParametersFILE");
	AddXMLRecord(XMLWriter, "UseTransportParametersFTP");
	
	// Supporting the exchange settings file of the 1.0 version format
	WriteXML(XMLWriter, ThisInfobaseDescription, "DataExchangeExecutionSettingsDescription", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, CommonUse.ObjectAttributeValue(ExchangePlans[ExchangePlanName].ThisNode(), "Code"), "NewNodeCode", XMLTypeAssignment.Explicit);
	WriteXML(XMLWriter, CommonUse.ObjectAttributeValue(InfobaseNode, "Code"),                               "PredefinedNodeCode", XMLTypeAssignment.Explicit);
	
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

Function GetFilterSettingsValues(ExternalConnectionSettingsStructure)
	
	Return DataExchangeServer.GetFilterSettingsValues(ExternalConnectionSettingsStructure);
	
EndFunction

Function ExchangeDataSettingsFileFormatVersion()
	
	Return "1.1";
	
EndFunction

Function EscapeEnumerations(Settings)
	
	Result = New Structure;
	
	For Each SettingsItem In Settings Do
		
		If CommonUse.ReferenceTypeValue(SettingsItem.Value)
			And CommonUse.ObjectKindByRef(SettingsItem.Value) = "Enum" Then
			
			Result.Insert(SettingsItem.Key, GetPredefinedValueFullName(SettingsItem.Value));
			
		Else
			
			Result.Insert(SettingsItem.Key, SettingsItem.Value);
			
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndIf
