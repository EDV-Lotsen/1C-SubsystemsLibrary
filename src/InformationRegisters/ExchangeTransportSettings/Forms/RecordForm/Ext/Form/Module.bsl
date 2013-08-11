////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
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
	
	Items.FixExternalConnectionErrors.Visible = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	InfoBaseRunModeOnChange();
	
	OSAuthenticationOnChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure FILEDataExchangeDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "FILEDataExchangeDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure FILEDataExchangeDirectoryOpen(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "FILEDataExchangeDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMInfoBaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(Record, "COMInfoBaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure COMInfoBaseDirectoryOpen(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "COMInfoBaseDirectory", StandardProcessing)
	
EndProcedure

&AtClient
Procedure ExchangeLogFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileChoiceHandler(Record, "ExchangeLogFileName", StandardProcessing, NStr("en = 'Text document (*.txt)|*.txt'"), False);
	
EndProcedure

&AtClient
Procedure ExchangeLogFileNameOpen(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "ExchangeLogFileName", StandardProcessing)
	
EndProcedure

&AtClient
Procedure COMInfoBaseRunModeOnChange(Item)
	
	InfoBaseRunModeOnChange();
	
EndProcedure

&AtClient
Procedure COMOSAuthenticationOnChange(Item)
	
	OSAuthenticationOnChange();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure FixExternalConnectionErrors(Command)
	
	CommonUseClient.RegisterCOMConnector();
	
EndProcedure

&AtClient
Procedure CheckCOMConnection(Command)
	
	Cancel = False;
	
	ClearMessages();
	
	CheckExternalConnection(Cancel);
	
	If Cancel Then
		DoMessageBox(NStr("en = 'Failed to establish the connection.'"));
	Else
		DoMessageBox(NStr("en = 'The connection was successfully established.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckWSConnection(Command)
	
	Cancel = False;
	
	ClearMessages();
	
	CheckWSConnectionEstablished(Cancel);
	
	If Cancel Then
		
		NString = NStr("en = 'Error establishing the connection.
		                     |Do you want to open the event log?'"
		);
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.Yes Then
			
			Filter = New Structure;
			Filter.Insert("EventLogMessageText", EventLogMessageTextEstablishingConnectionToWebService);
			OpenFormModal("DataProcessor.EventLogMonitor.Form", Filter, ThisForm);
			
		EndIf;
		
	Else
		DoMessageBox(NStr("en = 'The connection was successfully established.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckFILEConnection(Command)
	
	CheckConnection("FILE");
	
EndProcedure

&AtClient
Procedure CheckFTPConnection(Command)
	
	CheckConnection("FTP");
	
EndProcedure

&AtClient
Procedure CheckEMAILConnection(Command)
	
	CheckConnection("EMAIL");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure CheckConnection(TransportKindString)
	
	Cancel = False;
	
	ClearMessages();
	
	CheckConnectionAtServer(Cancel, TransportKindString);
	
	If Cancel Then
		DoMessageBox(NStr("en = 'Failed to establish the connection.'"));
	Else
		DoMessageBox(NStr("en = 'The connection was successfully established.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckConnectionAtServer(Cancel, TransportKindString)
	
	CheckExchangeLogFileAvailability(Cancel);
	
	DataExchangeServer.CheckExchangeMessageTransportDataProcessorConnection(Cancel, Record, Enums.ExchangeMessageTransportKinds[TransportKindString]);
	
EndProcedure

&AtServer
Procedure CheckExternalConnection(Cancel)
	
	CheckExchangeLogFileAvailability(Cancel);
	
	ErrorAttachingAddIn = False;
	
	DataExchangeServer.CheckExternalConnection(Cancel, Record, ErrorAttachingAddIn);
	
	If ErrorAttachingAddIn And CommonUse.FileInfoBase() Then
		
		Items.FixExternalConnectionErrors.Visible = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckWSConnectionEstablished(Cancel)
	
	CheckExchangeLogFileAvailability(Cancel);
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(ConnectionParameters, Record);
	
	WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters);
	
	If WSProxy = Undefined Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemVisibility()
	
	UsedTransports = New Array;
	
	If ValueIsFilled(Record.Node) Then
		
		UsedTransports = DataExchangeCached.UsedExchangeMessageTransports(Record.Node);
		
	EndIf;
	
	For Each TransportKindPage In Items.TransportKindPages.ChildItems Do
		
		TransportKindPage.Visible = False;
		
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
Procedure InfoBaseRunModeOnChange()
	
	CurrentPage = ?(Record.COMInfoBaseOperationMode = 0, Items.FileModePage, Items.ClientServerModePage);
	
	Items.InfobaseRunModes.CurrentPage = CurrentPage;
	
EndProcedure

&AtClient
Procedure OSAuthenticationOnChange()
	
	Items.COMUserName.Enabled     = Not Record.COMOSAuthentication;
	Items.COMUserPassword.Enabled = Not Record.COMOSAuthentication;
	
EndProcedure

&AtServer
Procedure CheckExchangeLogFileAvailability(Cancel)
	
	FileNameStructure = CommonUseClientServer.SplitFullFileName(Record.ExchangeLogFileName);
	LogFileName = FileNameStructure.BaseName;
	CheckDirectoryName	 = FileNameStructure.Path;
	CheckDirectory = New File(CheckDirectoryName);
	CheckFileName = "test.tmp";
	
	If Not ValueIsFilled(LogFileName) Then
		Return;
	ElsIf Not CheckDirectory.Exist() Then
		
		MessageString = NStr("en = '%1 exchange protocol file directory is not found.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not CreateCheckFile(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("en = 'Failed to create a file in the %1 exchange protocol directory.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not DeleteCheckFile(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("en = 'Failed to delete the file from the %1 exchange protocol directory.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	Else 
		Return;
	EndIf;
	
	CommonUseClientServer.MessageToUser(MessageString,,,, Cancel);
	WriteLogEvent(NStr("en = 'Exchange message transport'"), EventLogLevel.Error,,, MessageString);
	
EndProcedure

&AtServer
Function CreateCheckFile(CheckDirectoryName, CheckFileName)
	
	TextDocument = New TextDocument;
	TextDocument.AddLine(NStr("en = 'Temporary test file'"));
	
	Try
		TextDocument.Write(CheckDirectoryName + "" + CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

&AtServer
Function DeleteCheckFile(CheckDirectoryName, CheckFileName)
	
	Try
		DeleteFiles(CheckDirectoryName, CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction







