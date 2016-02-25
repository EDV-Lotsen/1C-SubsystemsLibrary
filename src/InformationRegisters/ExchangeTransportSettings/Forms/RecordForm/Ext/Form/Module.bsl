&AtClient
Var ExternalResourcesAllowed;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	SetFormItemVisibility();
	
	If ValueIsFilled(Record.DefaultExchangeMessageTransportKind) Then
		
		PageName = "TransportSettings[TransportKind]";
		PageName = StrReplace(PageName, "[TransportKind]"
		, CommonUse.EnumValueName(Record.DefaultExchangeMessageTransportKind));
		
		If Items[PageName].Visible Then
			
			Items.TransportKindPages.CurrentPage = Items[PageName];
			
		EndIf;
		
	EndIf;
	
	EventLogMessageTextEstablishingConnectionToWebService 
		= DataExchangeServer.EventLogMessageTextEstablishingConnectionToWebService();
	
	If CommonUse.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.InternetAccessParameters.Visible  = True;
		Items.InternetAccessParameters1.Visible = True;
	Else
		Items.InternetAccessParameters.Visible  = False;
		Items.InternetAccessParameters1.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	InfobaseRunModeOnChange();
	
	OSAuthenticationOnChange();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingNotification = New NotifyDescription("AllowExternalResourceCompletion", ThisObject, WriteParameters);
		Queries = CreateRequestForUseExternalResources(Record, True, True, True, True);
		SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
		
		Cancel = True;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FILEDataExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "FILEDataExchangeDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FILEDataExchangeDirectoryOpen(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "FILEDataExchangeDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "COMInfobaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure COMInfobaseDirectoryOpen(Item, StandardProcessing)

DataExchangeClient.FileOrDirectoryOpenHandler(Record, "COMInfobaseDirectory", StandardProcessing)

EndProcedure

&AtClient
Procedure COMInfobaseRunModeOnChange(Item)
	
	InfobaseRunModeOnChange();
	
EndProcedure

&AtClient
Procedure COMOSAuthenticationOnChange(Item)
	
	OSAuthenticationOnChange();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TestCOMConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestCOMConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Record, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure TestWSConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestWSConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Record,,, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure TestFILEConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestFILEConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Record,, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure TestFTPConnection(Command)
	
	ClosingNotification = New NotifyDescription("TestFTPConnectionCompletion", ThisObject);
	Queries = CreateRequestForUseExternalResources(Record,,,, True);
	SafeModeClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
	
EndProcedure

&AtClient
Procedure TestEMAILConnection(Command)
	
	TestConnection("EMAIL");
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParameterForm();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);

EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure TestConnection(TransportKindString)
	
	Cancel = False;
	
	ClearMessages();
	
	TestConnectionAtServer(Cancel, TransportKindString);
	
	NotifyUserAboutConnectionResult(Cancel);
	
EndProcedure

&AtServer
Procedure TestConnectionAtServer(Cancel, TransportKindString)
	
	DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel, Record, Enums.ExchangeMessageTransportKinds[TransportKindString]);
	
EndProcedure

&AtServer
Procedure TestExternalConnection(Cancel)
	
	DataExchangeServerCall.TestExternalConnection(Cancel, Record);
	
EndProcedure

&AtServer
Procedure TestWSConnectionEstablished(Cancel)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	FillPropertyValues(ConnectionParameters, Record);
	
	UserMessage = "";
	If Not DataExchangeServer.CorrespondentConnectionEstablished(Record.Node, ConnectionParameters, UserMessage) Then
		CommonUseClientServer.MessageToUser(UserMessage,,,, Cancel);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemVisibility()
	
	UsedTransports = New Array;
	
	If ValueIsFilled(Record.Node) Then
		
		UsedTransports = DataExchangeCached.UsedExchangeMessageTransports(Record.Node);
		
	EndIf;
	
	For Each TransportTypePage In Items.TransportKindPages.ChildItems Do
		
		TransportTypePage.Visible = False;
		
	EndDo;
	
	Items.DefaultExchangeMessageTransportKind.ChoiceList.Clear();
	
	For Each Item In UsedTransports Do
		
		FormItemName = "TransportSettings[TransportKind]";
		FormItemName = StrReplace(FormItemName, "[TransportKind]", CommonUse.EnumValueName(Item));
		
		Items[FormItemName].Visible = True;
		
		Items.DefaultExchangeMessageTransportKind.ChoiceList.Add(Item, String(Item));
		
	EndDo;
	
	If UsedTransports.Count() = 1 Then
		
		Items.TransportKindPages.PagesRepresentation = FormPagesRepresentation.None;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotifyUserAboutConnectionResult(Val AttachingError)
	
	WarningText = ?(AttachingError, NStr("en = 'Cannot establish connection.'"),
											   NStr("en = 'Connection established.'"));
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtClient
Procedure InfobaseRunModeOnChange()
	
	CurrentPage = ?(Record.COMInfobaseOperationMode = 0, Items.FileModePage, Items.ClientServerModePage);
	
	Items.InfobaseRunModes.CurrentPage = CurrentPage;
	
EndProcedure

&AtClient
Procedure OSAuthenticationOnChange()
	
	Items.COMUserName.Enabled     = Not Record.COMOSAuthentication;
	Items.COMUserPassword.Enabled = Not Record.COMOSAuthentication;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceCompletion(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateRequestForUseExternalResources(Val Record, RequestCOM = False,
	RequestFILE = False, RequestWS = False, RequestFTP = False)
	
	PermissionRequests = New Array;
	InformationRegisters.ExchangeTransportSettings.RequestToUseExternalResources(PermissionRequests,
		Record, RequestCOM, RequestFILE, RequestWS, RequestFTP);
	Return PermissionRequests;
	
EndFunction

&AtClient
Procedure TestFILEConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		TestConnection("FILE");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestFTPConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		TestConnection("FTP");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestWSConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Cancel = False;
		
		ClearMessages();
		
		TestWSConnectionEstablished(Cancel);
		
		NotifyUserAboutConnectionResult(Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TestCOMConnectionCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		Cancel = False;
		
		ClearMessages();
		
		If StandardSubsystemsClientCached.ClientParameters().FileInfobase Then
			
			CommonUseClient.RegisterCOMConnector(False);
			
		EndIf;
		
		TestExternalConnection(Cancel);
		
		NotifyUserAboutConnectionResult(Cancel);
		
	EndIf;
	
EndProcedure

#EndRegion