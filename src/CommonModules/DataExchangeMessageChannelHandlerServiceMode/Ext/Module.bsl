////////////////////////////////////////////////////////////////////////////////
// DataExchangeMessageChannelHandlerServiceMode.
//
////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Retrieves the list of message handlers that are present in the subsystem.
// 
// Parameters:
//  Handlers - ValueTable - see MessageExchange.NewMessageHandlerTable for table field details.
// 
Procedure GetMessageChannelHandlers(Handlers) Export
	
	AddMessageChannelHandler("DataExchange\Application\ExchangeCreation", DataExchangeMessageChannelHandlerServiceMode, Handlers);
	AddMessageChannelHandler("DataExchange\Application\ExchangeDeletion", DataExchangeMessageChannelHandlerServiceMode, Handlers);
	AddMessageChannelHandler("DataExchange\Application\SetDataAreaPrefix", DataExchangeMessageChannelHandlerServiceMode, Handlers);
	
EndProcedure

// Handles the body of the message from the channel according to the current message
// channel algorithm.
//
// Parameters:
//  MessageChannel - String (mandatory) - ID of the message channel from where the 
//                   message was received.
//  Body           - Arbitrary (mandatory) - body of the message to be handled.
//  Sender         - ExchangePlanRef.MessageExchange (mandatory) - end point that is
//                   a message sender.
//
Procedure ProcessMessage(MessageChannel, Body, Sender) Export
	
	SetDataArea(Body.DataArea);
	
	If MessageChannel = "DataExchange\Application\ExchangeCreation" Then
		
		CreateDataExchangeInInfoBase(
								Sender,
								Body.Settings,
								Body.NodeFilterStructure,
								Body.NodeDefaultValues,
								Body.ThisNodeCode,
								Body.NewNodeCode
		);
		
	ElsIf MessageChannel = "DataExchange\Application\ExchangeDeletion" Then
		
		DeleteDataExchangeFromInfoBase(Sender, Body.ExchangePlanName, Body.NodeCode);
		
	ElsIf MessageChannel = "DataExchange\Application\SetDataAreaPrefix" Then
		
		SetDataAreaPrefix(Body.Prefix);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure CreateDataExchangeInInfoBase(Sender, Settings, NodeFilterStructure, NodeDefaultValues, ThisNodeCode, NewNodeCode)
	
	SetPrivilegedMode(True);
	
	// Creating the message exchange catalog, if necessary
	Directory = New File(Settings.FILEDataExchangeDirectory);
	
	If Not Directory.Exist() Then
		
		Try
			CreateDirectory(Directory.FullName);
		Except
			
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
			
			// Sending a message about the operation execution error to the managing application
			SendErrorCreatingExchangeMessage(Number(ThisNodeCode), Number(NewNodeCode), ErrorMessageString, Sender);
			
			WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,,, ErrorMessageString);
			Return;
		EndTry;
	EndIf;
	
	If GetFunctionalOption("UseDataExchange") <> True Then
		Constants.UseDataExchange.Set(True);
	EndIf;
	
	Settings.Insert("ExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.Combi);
	Settings.Insert("CombiExchangeMessageTransportKind", Enums.ExchangeMessageTransportKinds.FILE);
	Settings.Insert("WizardRunMode", "");
	Settings.Insert("ExchangeMessageArchivePassword", "");
	Settings.Insert("UseTransportParametersEMAIL", False);
	Settings.Insert("UseTransportParametersFILE", False);
	Settings.Insert("UseTransportParametersFTP", False);
	Settings.Insert("FILECompressOutgoingMessageFile", False);
	Settings.Insert("SourceInfoBasePrefixIsSet", ValueIsFilled(GetFunctionalOption("InfoBasePrefix")));
	Settings.Insert("IsDistributedInfoBaseSetup", False);
	
	DataExchangeCreationWizard = DataProcessors.DataExchangeCreationWizard.Create();
	
	FillPropertyValues(DataExchangeCreationWizard, Settings);
	
	Cancel = False;
	
	ThisNodeCodeInService = DataExchangeServiceMode.ExchangePlanNodeCodeInService(Number(ThisNodeCode));
	NewNodeCodeInService = DataExchangeServiceMode.ExchangePlanNodeCodeInService(Number(NewNodeCode));
	
	DataExchangeCreationWizard.SetUpNewServiceModeDataExchange(
		Cancel,
		NodeFilterStructure,
		NodeDefaultValues,
		ThisNodeCodeInService,
		NewNodeCodeInService
	);
	
	If Cancel Then
		
		ErrorMessageString = DataExchangeCreationWizard.ErrorMessageString();
		
			// Sending a message about the operation execution error to the managing application
		SendErrorCreatingExchangeMessage(Number(ThisNodeCode), Number(NewNodeCode), ErrorMessageString, Sender);
		
		WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
			// Sending a message about successful operation completion to the managing application
	SendMessageActionSuccessful(Number(ThisNodeCode), Number(NewNodeCode), Sender);
	
EndProcedure

Procedure DeleteDataExchangeFromInfoBase(Sender, ExchangePlanName, NodeCode)
	
	SetPrivilegedMode(True);
	
	// Searching for the node by the S00000123 code format
	InfoBaseNode = ExchangePlans[ExchangePlanName].FindByCode(DataExchangeServiceMode.ExchangePlanNodeCodeInService(Number(NodeCode)));
	
	If InfoBaseNode.IsEmpty() Then
		
	// Searching for the node by the 0000123 (old) code format
		InfoBaseNode = ExchangePlans[ExchangePlanName].FindByCode(NodeCode);
		
	EndIf;
	
	ThisNodeCode = DataExchangeCached.GetThisNodeCodeForExchangePlan(ExchangePlanName);
	ThisNodeCode = DataExchangeServer.DataAreaNumberByExchangePlanNodeCode(ThisNodeCode);
	
	If InfoBaseNode.IsEmpty() Then
		
			// Sending a message about successful operation completion to the managing application
		SendMessageActionSuccessful(ThisNodeCode, Number(NodeCode), Sender);
		
		Return; // exchange settings are not found (perhaps, they were deleted previously)
	EndIf;
	
	// Deleting the node reference from all data exchange scripts
	QueryText = "
	|SELECT DISTINCT
	|	DataExchangeScenarioExchangeSettings.Ref AS DataExchangeScenario
	|FROM
	|	Catalog.DataExchangeScenarios.ExchangeSettings AS DataExchangeScenarioExchangeSettings
	|WHERE
	|	DataExchangeScenarioExchangeSettings.InfoBaseNode = &InfoBaseNode
	|";
	
	Query = New Query;
	Query.SetParameter("InfoBaseNode", InfoBaseNode);
	Query.Text = QueryText;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Choose();
		
		While Selection.Next() Do
			
			DataExchangeScenario = Selection.DataExchangeScenario.GetObject();
			
			Catalogs.DataExchangeScenarios.DeleteExportFromDataExchangeScenario(DataExchangeScenario, InfoBaseNode);
			Catalogs.DataExchangeScenarios.DeleteImportFromDataExchangeScenario(DataExchangeScenario, InfoBaseNode);
			
			Try
				
				DataExchangeScenario.Write();
				
				If DataExchangeScenario.ExchangeSettings.Count() = 0 Then
					
					DataExchangeScenario.Delete();
					
				EndIf;
				
			Except
				
				ErrorMessageString = DetailErrorDescription(ErrorInfo());
				
				// Sending a message about the operation execution error to the managing application
				SendErrorDeletingExchangeMessage(ThisNodeCode, Number(NodeCode), ErrorMessageString, Sender);
				
				WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,,, ErrorMessageString);
				Return;
			EndTry;
			
		EndDo;
		
	EndIf;
	
	// Deleting the exchange directory
	FILEDataExchangeDirectory = InformationRegisters.ExchangeTransportSettings.DataExchangeDirectoryName(Enums.ExchangeMessageTransportKinds.FILE, InfoBaseNode);
	
	Try
		DeleteFiles(FILEDataExchangeDirectory);
	Except
	EndTry;
	
	// Deleting the node
	Try
		InfoBaseNode.GetObject().Delete();
	Except
		
		ErrorMessageString = DetailErrorDescription(ErrorInfo());
		
		// Sending a message about the operation execution error to the managing application
		SendErrorDeletingExchangeMessage(ThisNodeCode, Number(NodeCode), ErrorMessageString, Sender);
		
		WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndTry;
	
	// Disabling the data exchange, if necessary
	IsDataExchangeUsed = DataExchangeServer.GetUsedExchangePlans().Count() > 0;
	
	If Not IsDataExchangeUsed Then
		
		Constants.UseDataExchange.Set(False);
		
	EndIf;
	
	// Sending a message about successful operation completion to the managing application
	SendMessageActionSuccessful(ThisNodeCode, Number(NodeCode), Sender);
	
EndProcedure

Procedure SetDataAreaPrefix(Val Prefix)
	
	SetPrivilegedMode(True);
	
	If IsBlankString(Constants.DistributedInfoBaseNodePrefix.Get()) Then
		
		Constants.DistributedInfoBaseNodePrefix.Set(Format(Prefix, "ND=2; NLZ=; NG=0"));
		
	EndIf;
	
EndProcedure

Procedure SetDataArea(Val DataArea)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
EndProcedure

Procedure SendMessageActionSuccessful(Code1, Code2, EndPoint)
	
	BeginTransaction();
	Try
		
		Body = New Structure("Code1, Code2", Code1, Code2);
		
		MessageExchange.SendMessage("DataExchange\Application\Response\ActionSuccessful", Body, EndPoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Sending messages'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SendErrorCreatingExchangeMessage(Code1, Code2, ErrorString, EndPoint)
	
	BeginTransaction();
	Try
		
		Body = New Structure("Code1, Code2, ErrorString", Code1, Code2, ErrorString);
		
		MessageExchange.SendMessage("DataExchange\Application\Response\ErrorCreatingExchange", Body, EndPoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Sending messages'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure SendErrorDeletingExchangeMessage(Code1, Code2, ErrorString, EndPoint)
	
	BeginTransaction();
	Try
		
		Body = New Structure("Code1, Code2, ErrorString", Code1, Code2, ErrorString);
		
		MessageExchange.SendMessage("DataExchange\Application\Response\ErrorDeletingExchange", Body, EndPoint);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(NStr("en = 'Sending messages'"), 
			EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers)
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure
