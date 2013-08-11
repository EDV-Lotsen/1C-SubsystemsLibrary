
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SetupFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataExchangeServer.NodesSetupFormOnCreateAtServer(ThisForm, Cancel);
	
	// Filling default values
	If Not ValueIsFilled(DocumentExportStartDate) Then
		DocumentExportStartDate = BegOfYear(CurrentSessionDate());
	EndIf;
	
	If Not ValueIsFilled(ItemsExportMode) Then
		ItemsExportMode = Enums.ExchangeObjectExportModes.UnloadAlways;
	EndIf;
	
	If Not ValueIsFilled(CounterpartyExportMode) Then
		CounterpartyExportMode = Enums.ExchangeObjectExportModes.UnloadAlways;
	EndIf;
	
	GetContextDetails();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure WriteAndClose(Command)
	
	UseFilterByCompanies = Not DataExchangeClient.AllRowsMarkedInTable(Companies);
	
	GetContextDetails();
	
	DataExchangeClient.NodeSettingsFormCloseFormCommand(ThisForm);
	
EndProcedure

&AtClient
Procedure EnableAllCompanies(Command)
	
	EnableDisableAllItemsInTable(True, "Companies");

EndProcedure

&AtClient
Procedure DisableAllCompanies(Command)

	EnableDisableAllItemsInTable(False, "Companies");

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SERVICE PROCEDURES AND FUNCTIONS

&AtClient
Procedure EnableDisableAllItemsInTable(Enable, TableName)
	
	For Each CollectionItem In ThisForm[TableName] Do
		
		CollectionItem.Use = Enable;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure GetContextDetails()
	
	// document export start date
	If ValueIsFilled(DocumentExportStartDate) Then
		DocumentExportStartDateDetails = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Data will be synchronized starting from %1.'"),
			Format(DocumentExportStartDate, "DLF=DD")
		);
	Else
		DocumentExportStartDateDetails = NStr("en = 'Data will be synchronized without of filtering by date.'");
	EndIf;
	
	// filter by companies
	If UseFilterByCompanies Then
		CompanyDetails = NStr("en = 'By selected companies:'") + Chars.LF + UsedItems("Companies");
	Else
		CompanyDetails = NStr("en = 'By all companies.'");
	EndIf;
	
	ContextDetails = (""
		+ DocumentExportStartDateDetails
		+ Chars.LF
		+ Chars.LF
		+ CompanyDetails);
		
EndProcedure

&AtServer
Function UsedItems(TableName)
	
	Return StringFunctionsClientServer.GetStringFromSubstringArray(
			ThisForm[TableName].Unload(New Structure("Use", True)).UnloadColumn("Presentation"),
			Chars.LF);
	
EndFunction

