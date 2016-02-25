
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	RateDate = BegOfDay(CurrentSessionDate());
	Items.Rate.Title = 
		StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Rate on %1"),
			Format(CurrentSessionDate(), "DLF=DD"));
	Items.Rate.ToolTip = Items.Rate.Title;
	List.Parameters.SetParameterValue ("EndOfPeriod", RateDate);
	
	Items.Currencies.ChoiceMode = Parameters.ChoiceMode;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ChoiceResult, ChoiceSource)
	
	Items.Currencies.Refresh();
	Items.Currencies.CurrentRow = ChoiceResult;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_CurrencyRates"
		Or EventName = "Write_CurrencyRateImport" Then
		Items.Currencies.Refresh();
	EndIf;
	
EndProcedure

#EndRegion

#Region CurrencyFormTableItemEventHandlers

&AtClient
Procedure CurrenciesBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	Text = NStr("en = 'Currencies can be picked from the classifier.
	|Pick?'");
	Notification = New NotifyDescription("CurrenciesBeforeAddRowStartEnd", ThisObject);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.No);
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure PickFromCurrencyClassifier(Command)
	
	OpenForm("Catalog.Currencies.Form.PickCurrenciesFromClassifier",, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportCurrencyRates(Command)
	FormParameters = New Structure("OpenFromList");
	OpenForm("DataProcessor.CurrencyRateImport.Form", FormParameters);
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure CurrenciesBeforeAddRowStartEnd(QuestionResult, AdditionalParameters) Export
	 
	If QuestionResult = DialogReturnCode.Yes Then
		OpenForm("Catalog.Currencies.Form.PickCurrenciesFromClassifier", , ThisObject);
	Else
		OpenForm("Catalog.Currencies.ObjectForm");
	EndIf;

EndProcedure

#EndRegion
