
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
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

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure TestFILEConnection(Command)
	
	TestConnection("FILE");
	
EndProcedure

&AtClient
Procedure TestFTPConnection(Command)
	
	TestConnection("FTP");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure TestConnection(TransportKindString)
	
	Cancel = False;
	
	ClearMessages();
	
	TestConnectionAtServer(Cancel, TransportKindString);
	
	WarningText = ?(Cancel, NStr("en = 'Cannot establish the connection.'"), NStr("en = 'The connection is established.'"));
	ShowMessageBox(, WarningText);
	
EndProcedure

&AtServer
Procedure TestConnectionAtServer(Cancel, TransportKindString)
	
	DataExchangeServer.TestExchangeMessageTransportDataProcessorConnection(Cancel, Record, Enums.ExchangeMessageTransportKinds[TransportKindString]);
	
EndProcedure

&AtServer
Procedure SetFormItemVisibility()
	
	UsedTransports = New Array;
	UsedTransports.Add(Enums.ExchangeMessageTransportKinds.FILE);
	UsedTransports.Add(Enums.ExchangeMessageTransportKinds.FTP);
	
	Items.DefaultExchangeMessageTransportKind.ChoiceList.Clear();
	
	For Each Item In UsedTransports Do
		
		Items.DefaultExchangeMessageTransportKind.ChoiceList.Add(Item, String(Item));
		
	EndDo;
	
EndProcedure

#EndRegion