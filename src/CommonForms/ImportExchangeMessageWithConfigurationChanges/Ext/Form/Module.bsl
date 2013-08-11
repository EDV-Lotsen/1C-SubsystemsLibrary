////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	InfoBaseNode = ExchangePlans.MasterNode();
	
	If InfoBaseNode = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	// Getting the default node exchange message transport kind.
	// If the default value is not specified, setting it to FILE.
	ExchangeMessageTransportKind = InformationRegisters.ExchangeTransportSettings.DefaultExchangeMessageTransportKind(InfoBaseNode);
	If Not ValueIsFilled(ExchangeMessageTransportKind) Then
		ExchangeMessageTransportKind = Enums.ExchangeMessageTransportKinds.FILE;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExecuteDataImport(Command)
	
	Cancel = False;
	
	Status(NStr("en = 'Importing data...'"));
	
	// Importing data
	DataExchangeServer.ExecuteDataExchangeForInfoBaseNode(Cancel, InfoBaseNode, True, False, ExchangeMessageTransportKind);
	
	If Cancel Then
		
		NString = NStr("en = 'Error importing data.
							|Do you want to open the event log?'");
		//
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
		If Response = DialogReturnCode.Yes Then
			
			DataExchangeClient.GoToDataEventLogModally(InfoBaseNode, ThisForm, "DataImport");
			
		EndIf;
		
	Else
		
		DoMessageBox(NStr("en = 'Data import completed successfully.'"), 30);
		
		Close(True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(InfoBaseNode, ThisForm, "DataImport");
	
EndProcedure
