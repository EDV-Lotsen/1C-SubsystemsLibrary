////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	SynchronizeDataButtonPressed = False;
	
	RefreshFormDataAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	AttachIdleHandler("RefreshFormData", 15);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ExecuteCommand(Command)
	
	SynchronizeDataButtonPressed = True;
	
	InitDataExchange();
	
	RefreshAllOpenLists = False;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure RefreshFormData()
	
	RefreshFormDataAtServer();
	
	If RefreshAllOpenLists Then
		
		// Updating all opened dynamic lists
		DataExchangeClient.RefreshAllOpenDynamicLists();
		
		RefreshAllOpenLists = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshFormDataAtServer()
	
	ExecutingDataExchange = DataExchangeServiceMode.ExecutingDataExchange();
	
	If ExecutingDataExchange Then
		
		Items.LongActionProgressPages.CurrentPage = Items.LongActionProgressPageActive;
		Items.Execute.Enabled = False;
		
		Items.ExchangeStatePages.CurrentPage = Items.WaitPage;
		
	Else
		
		If SynchronizeDataButtonPressed Then
			
			RefreshAllOpenLists = True;
			
		EndIf;
		
		SynchronizeDataButtonPressed = False;
		
		Items.LongActionProgressPages.CurrentPage = Items.LongActionProgressInactive;
		Items.Execute.Enabled = True;
		
		Items.ExchangeStatePages.CurrentPage = Items.SuccessfulExecutionPage;
		
		LastSuccessfulImportDate = DataExchangeServiceMode.LastSuccessfulImportForAllInfoBaseNodesDate();
		LastSuccessfulImportDateString = Format(LastSuccessfulImportDate, "DLF=DDT");
		
		If LastSuccessfulImportDate = Undefined Then
			
			Items.LabelSuccess.Title = NStr("en = 'Data synchronization was not executed.'");
			
		Else
			
			Items.LabelSuccess.Title = NStr("en = 'Last data synchronization: %1'");
			Items.LabelSuccess.Title = StringFunctionsClientServer.SubstituteParametersInString(Items.LabelSuccess.Title, LastSuccessfulImportDateString);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure InitDataExchange()
	
	DataExchangeServiceMode.ExecuteDataExchangeWithAllSubscriberInfoBases();
	
	RefreshFormDataAtServer();
	
EndProcedure
