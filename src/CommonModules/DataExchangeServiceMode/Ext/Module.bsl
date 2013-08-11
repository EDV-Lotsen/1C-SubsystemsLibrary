////////////////////////////////////////////////////////////////////////////////
// DataExchangeServiceMode: data exchange mechanism.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// The AfterGetRecipients handler is called when objects are registered in
// the exchange plan.
// Sets up a constant that shows whether data has been changed and sends a message about
// changes with the current data area number to the service manager.
//
// Parameters:
//  Data            - CatalogObject or DocumentObject - object to get attribute values  
//                    and other properties.
// Recipients       - Array of ExchangePlanRef.<Name> - exchange plan nodes.
// ExchangePlanName - String.
//
Procedure AfterGetRecipients(Data, Recipients, ExchangePlanName) Export
	
	If Data.DataExchange.Load Then
		Return;
	ElsIf Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	ElsIf Recipients.Count() = 0 Then // there is no need to register this object
		Return;
	ElsIf Not DataExchangeServiceModeCached.ExchangePlanUsedInServiceMode(ExchangePlanName) Then
		Return;
	ElsIf GetFunctionalOption("DataChangesRecorded") Then
		Return;
	EndIf;
	
	If CommonUseCached.DataSeparationEnabled()
		And CommonUseCached.SessionWithoutSeparator() Then
		
		SetDataChangeFlag();
	Else
		
		BackgroundJobs.Execute("DataExchangeServiceMode.SetDataChangeFlag",, "1");
	EndIf;
	
EndProcedure

// Sets up a constant that shows whether data has been changed and sends a message about
// changes with the current data area number to the service manager.
//
Procedure SetDataChangeFlag() Export
	
	SetPrivilegedMode(True);
	
	DataArea = CommonUse.SessionSeparatorValue();
	
	BeginTransaction();
	Try
		MessageExchange.SendMessage("DataExchange\ManagementApplication\DataChangeFlag",
						New Structure("NodeCode", DataExchangeServer.ExchangePlanNodeCodeString(DataArea)),
						ServiceModeCached.ServiceManagerEndPoint()
		);
		
		Constants.DataChangesRecorded.Set(True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Adds update handlers required by this subsystem to
// the Handlers list.
//
// Parameters:
// Handlers - ValueTable - see the InfoBaseUpdate.NewUpdateHandlerTable function for details. 
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.0.1.2";
	Handler.Procedure = "DataExchangeServiceMode.SetPredefinedNodeCodes";
	
EndProcedure

// Determines and sets a code and a predefined node name for each exchange plan that is 
// used in the service mode.
// The code is generated based on a separator value.
// The description is the application caption or, if the caption is empty, is generated
// based on the current data area presentation from InformationRegister.DataAreas.
//
Procedure SetPredefinedNodeCodes() Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	For Each ExchangePlan In Metadata.ExchangePlans Do
		
		If ExchangePlan.DistributedInfoBase Then
			Continue;
		EndIf;
		
		ExchangePlanUsedInServiceMode = False;
		
		Try
			ExchangePlanUsedInServiceMode = ExchangePlans[ExchangePlan.Name].ExchangePlanUsedInServiceMode();
		Except
			ExchangePlanUsedInServiceMode = False;
		EndTry;
		
		If ExchangePlanUsedInServiceMode Then
			
			ThisNode = ExchangePlans[ExchangePlan.Name].ThisNode();
			
			If IsBlankString(CommonUse.GetAttributeValue(ThisNode, "Code")) Then
				
				Description = "";
				
				Parameters = New Structure;
				StandardSubsystemsServer.AddClientParameters(Parameters);
				
				Description = Parameters.ApplicationCaption;
				
				If IsBlankString(Description) Then
					
					If Parameters.Property("DataAreaPresentation") Then
						
						Description = Parameters.DataAreaPresentation;
						
					Else
						
						Description = Metadata.Synonym;
						
					EndIf;
					
				EndIf;
				
				If Not IsBlankString(Description) Then
					
					ThisNodeObject = ThisNode.GetObject();
					ThisNodeObject.Code = ExchangePlanNodeCodeInService(ServiceMode.SessionSeparatorValue());
					ThisNodeObject.Description = TrimAll(Description);
					ThisNodeObject.Write();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Performs data exchange with all subscriber infobases in the following steps:
//  - generating scripts;
//  - starting the exchange.
//
Procedure ExecuteDataExchangeWithAllSubscriberInfoBases() Export
	
	SetPrivilegedMode(True);
	
	ServiceManagerVersions = ServiceManagerVersions();
	
	If ServiceManagerVersions.Find("1.0.6.5") <> Undefined Then
		
		WSServiceProxy = DataExchangeServiceModeCached.GetExchangeServiceWSProxy_1_0_6_5();
		
		DataExchangeScenarioXDTO = XDTOSerializer.WriteXDTO(New ValueTable);
		
		// Getting the exchange script from the managing application and locking the exchange
		Try
			WSServiceProxy.GetExchangeScenario(CommonUse.SessionSeparatorValue(), DataExchangeScenarioXDTO);
		Except
			WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		DataExchangeScenario = XDTOSerializer.ReadXDTO(DataExchangeScenarioXDTO);
		
	Else
		
		WSServiceProxy = DataExchangeServiceModeCached.GetExchangeServiceWSProxy();
		
		DataExchangeScenarioString = "";
		
		// Getting the exchange script from the managing application and locking the exchange
		Try
			WSServiceProxy.GetExchangeScenario(CommonUse.SessionSeparatorValue(), DataExchangeScenarioString);
		Except
			WriteLogEvent(NStr("en = 'Data exchange'"), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		DataExchangeScenario = ValueFromStringInternal(DataExchangeScenarioString);
		
	EndIf;
	
	If DataExchangeScenario.Count() > 0 Then
		
		DataExchangeScenario.Columns.Add("InitiatedByUser");
		DataExchangeScenario.FillValues(True, "InitiatedByUser");
		
		// Starting the exchange script
		ExecuteDataExchangeScenarioActionInFirstInfoBase(0, DataExchangeScenario);
		
	EndIf;
	
EndProcedure

// Initiates the data exchange between two infobases.
//
// Parameters:
//  DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchange(DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	// Resetting the data change accumulation flag
	Constants.DataChangesRecorded.Set(False);
	
	If DataExchangeScenario.Count() > 0 Then
		
		// Starting the exchange script
		ExecuteDataExchangeScenarioActionInFirstInfoBase(0, DataExchangeScenario);
		
	EndIf;
	
EndProcedure

// Executes the exchange script action that is specified by the table row for the first infobase.
//
// Parameters:
//  ScenarioRowIndex     - Number - index of the row from the DataExchangeScenario table.
//  DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchangeScenarioActionInFirstInfoBase(ScenarioRowIndex, DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	If ScenarioRowIndex > DataExchangeScenario.Count() - 1 Then
		Return; // Ending script execution
	EndIf;
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	If ScenarioRow.InfoBaseNumber = 1 Then
		
		InfoBaseNode = FindInfoBaseNode(ScenarioRow.ExchangePlanName, ScenarioRow.InfoBaseNodeCode);
		
		DataExchangeServer.ExecuteInfoBaseNodeExchangeAction(False, InfoBaseNode, GetOnExchangeAction(ScenarioRow.CurrentAction), Enums.ExchangeMessageTransportKinds.Combi);
		
		// Going to the next script step
		ExecuteDataExchangeScenarioActionInFirstInfoBase(ScenarioRowIndex + 1, DataExchangeScenario);
		
	ElsIf ScenarioRow.InfoBaseNumber = 2 Then
		
		InfoBaseNode = FindInfoBaseNode(ScenarioRow.ExchangePlanName, ScenarioRow.ThisNodeCode);
		
		CorrespondentVersions = CorrespondentVersions(InfoBaseNode);
		
		If CorrespondentVersions.Find("2.0.1.6") <> Undefined Then
			
			WSProxy = DataExchangeServiceModeCached.GetCorrespondentWSProxy_2_0_1_6(InfoBaseNode);
			
			If WSProxy = Undefined Then
				
				// Going to the next script step
				ExecuteDataExchangeScenarioActionInFirstInfoBase(ScenarioRowIndex + 1, DataExchangeScenario);
				Return;
			EndIf;
			
			WSProxy.StartExchangeExecutionInSecondDataBase(ScenarioRowIndex, XDTOSerializer.WriteXDTO(DataExchangeScenario));
			
		Else
			
			WSProxy = DataExchangeServiceModeCached.GetCorrespondentWSProxy(InfoBaseNode);
			
			If WSProxy = Undefined Then
				
				// Going to the next script step
				ExecuteDataExchangeScenarioActionInFirstInfoBase(ScenarioRowIndex + 1, DataExchangeScenario);
				Return;
			EndIf;
			
			WSProxy.StartExchangeExecutionInSecondDataBase(ScenarioRowIndex, ValueToStringInternal(DataExchangeScenario));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Executes the exchange script action that is specified by the table row for the second infobase.
//
// Parameters:
// ScenarioRowIndex - Number - index of the row from the DataExchangeScenario table.
// DataExchangeScenario - ValueTable.
//
Procedure ExecuteDataExchangeScenarioActionInSecondInfoBase(ScenarioRowIndex, DataExchangeScenario) Export
	
	SetPrivilegedMode(True);
	
	ScenarioRow = DataExchangeScenario[ScenarioRowIndex];
	
	InfoBaseNode = FindInfoBaseNode(ScenarioRow.ExchangePlanName, ScenarioRow.InfoBaseNodeCode);
	
	If ScenarioRow.ExecutionOrderNumber = 1 Then
		// Resetting the data change accumulation flag
		Constants.DataChangesRecorded.Set(False);
	EndIf;
	
	DataExchangeServer.ExecuteInfoBaseNodeExchangeAction(False, InfoBaseNode, GetOnExchangeAction(ScenarioRow.CurrentAction), Enums.ExchangeMessageTransportKinds.Combi);
	
	// Ending script execution
	If ScenarioRowIndex = DataExchangeScenario.Count() - 1 Then
		
		ServiceManagerVersions = ServiceManagerVersions();
		
		If ServiceManagerVersions.Find("1.0.6.5") <> Undefined Then
			
			// Sending a message about the exchange completion to the managing application
			WSServiceProxy = DataExchangeServiceModeCached.GetExchangeServiceWSProxy_1_0_6_5();
			WSServiceProxy.CommitExchange(XDTOSerializer.WriteXDTO(DataExchangeScenario));
			
		Else
			
			// Sending a message about the exchange completion to the managing application
			WSServiceProxy = DataExchangeServiceModeCached.GetExchangeServiceWSProxy();
			WSServiceProxy.CommitExchange(ValueToStringInternal(DataExchangeScenario));
			
		EndIf;
		
		Return;
	EndIf;
	
	CorrespondentVersions = CorrespondentVersions(InfoBaseNode);
	
	If CorrespondentVersions.Find("2.0.1.6") <> Undefined Then
		
		WSProxy = DataExchangeServiceModeCached.GetCorrespondentWSProxy_2_0_1_6(InfoBaseNode);
		
		If WSProxy <> Undefined Then
			
			WSProxy.StartExchangeExecutionInFirstDataBase(ScenarioRowIndex + 1, XDTOSerializer.WriteXDTO(DataExchangeScenario));
			
		EndIf;
		
	Else
		
		WSProxy = DataExchangeServiceModeCached.GetCorrespondentWSProxy(InfoBaseNode);
		
		If WSProxy <> Undefined Then
			
			WSProxy.StartExchangeExecutionInFirstDataBase(ScenarioRowIndex + 1, ValueToStringInternal(DataExchangeScenario));
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks whether the exchange is locked to determine whether it is being executed.
//
// Returns:
//  Boolean. 
//
Function ExecutingDataExchange() Export
	
	SetPrivilegedMode(True);
	
	WSServiceProxy = DataExchangeServiceModeCached.GetExchangeServiceWSProxy();
	
	Return WSServiceProxy.ExchangeBlockIsSet(CommonUse.SessionSeparatorValue());
	
EndFunction

// Returns a date of the last successful import of the current data area for all infobase nodes.
// Returns Undefined if no synchronization was executed.
//
// Returns:
//  Date; Undefined. 
//
Function LastSuccessfulImportForAllInfoBaseNodesDate() Export
	
	QueryText =
	"SELECT
	|	MIN(SuccessfulDataExchangeStates.EndDate) AS EndDate
	|FROM
	|	InformationRegister.SuccessfulDataExchangeStates AS SuccessfulDataExchangeStates
	|WHERE
	|	SuccessfulDataExchangeStates.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|	AND SuccessfulDataExchangeStates.InfoBaseNode.DataArea = &DataArea
	|	AND SuccessfulDataExchangeStates.InfoBaseNode.Code LIKE ""S%""";
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("DataArea", ServiceMode.SessionSeparatorValue());
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	Return ?(ValueIsFilled(Selection.EndDate), Selection.EndDate, Undefined);
	
EndFunction

// Generates an exchange plan node code for the specified data area.
//
// Parameters:
//  DataAreaNumber - Number - separator value. 
//
// Returns:
//  String - exchange plan node code for the specified data area. 
//
Function ExchangePlanNodeCodeInService(Val DataAreaNumber) Export
	
	If TypeOf(DataAreaNumber) <> Type("Number") Then
		Raise NStr("en = 'The type of the parameter #1 is incorrect.'");
	EndIf;
	
	Result = "S0[DataAreaNumber]";
	
	Return StrReplace(Result, "[DataAreaNumber]", Format(DataAreaNumber, "ND=7; NLZ=; NG=0"));
	
EndFunction



Procedure ExecuteDataExchangeScenarioActionInFirstInfoBaseFromSharedSession(
																		ScenarioRowIndex,
																		DataExchangeScenario,
																		DataArea
	) Export
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(True, DataArea);
	SetPrivilegedMode(False);
	
	ExecuteDataExchangeScenarioActionInFirstInfoBase(ScenarioRowIndex, DataExchangeScenario);
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(False);
	SetPrivilegedMode(False);
	
EndProcedure

Procedure ExecuteDataExchangeScenarioActionInSecondInfoBaseFromSharedSession(
																		ScenarioRowIndex,
																		DataExchangeScenario,
																		DataArea
	) Export
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(True, DataArea);
	SetPrivilegedMode(False);
	
	ExecuteDataExchangeScenarioActionInSecondInfoBase(ScenarioRowIndex, DataExchangeScenario);
	
	SetPrivilegedMode(True);
	CommonUse.SetSessionSeparation(False);
	SetPrivilegedMode(False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function GetOnExchangeAction(ValueString)
	
	Return Enums.ActionsOnExchange[ValueString];
	
EndFunction

Function FindInfoBaseNode(Val ExchangePlanName, Val NodeCode)
	
	NodeCodeWithPrefix = ExchangePlanNodeCodeInService(Number(NodeCode));
	
	// Searching for the node by the S00000123 code format
	Result = DataExchangeCached.FindExchangePlanNodeByCode(ExchangePlanName, NodeCodeWithPrefix);
	
	If Result = Undefined Then
		
		// Searching for the node by the 0000123 (old) code format
		Result = DataExchangeCached.FindExchangePlanNodeByCode(ExchangePlanName, NodeCode);
		
	EndIf;
	
	If Result = Undefined Then
		Message = NStr("en = 'The exchange plan node named %1 with the %2 or %3 node code is not  found.'");
		Message = StringFunctionsClientServer.SubstituteParametersInString(Message, ExchangePlanName, NodeCode, NodeCodeWithPrefix);
		Raise Message;
	EndIf;
	
	Return Result;
EndFunction

Function CorrespondentVersions(Val InfoBaseNode)
	
	SettingsStructure = InformationRegisters.ExchangeTransportSettings.GetWSTransportSettings(InfoBaseNode);
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUserName);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "DataExchangeServiceMode");
EndFunction

Function ServiceManagerVersions()
	
	UserName       = Constants.AuxiliaryServiceManagerUserName.Get();
	UserPassword   = Constants.AuxiliaryServiceManagerUserPassword.Get();
	ServiceAddress = Constants.DataExchangeWebServiceURL.Get();
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      ServiceAddress);
	ConnectionParameters.Insert("UserName", UserName);
	ConnectionParameters.Insert("Password", UserPassword);
	
	Return CommonUse.GetInterfaceVersions(ConnectionParameters, "ManagementApplicationDataExchange");
EndFunction







