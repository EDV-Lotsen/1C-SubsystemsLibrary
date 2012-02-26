
// Handler of event OnCreate of form.
// Sets query parameter Endofperiod equal to the current date.
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	RateDate = BegOfDay(CurrentDate());
	Items.ExchangeRate.Title = "Exchange rate on " + Format(CurrentDate(), "DLF=DD");
	Items.ExchangeRate.ToolTip = Items.ExchangeRate.Title;
	List.Parameters.SetParameterValue ("Endofperiod", RateDate);
		
EndProcedure

// Handler of form event "choice processing"
// Currency choice processing on delection from ACC
//
&AtClient
Procedure ChoiceProcessing(ChoiceResult, ChoiceSource)
	
	If TypeOf(ChoiceResult) = Type("Structure") Then
		OpenForm("Catalog.Currencies.ObjectForm", ChoiceResult,ThisForm);
	EndIf;
	
EndProcedure

// Click handler of button "load rates".
// Gets and opens form of rates loading.
//
&AtClient
Procedure CommandLoadRatesExecute()
	
	OpenForm("DataProcessor.CurrencyRatesNB.Form.Form");
	
EndProcedure

// Click handler of button "Fill from ACC".
// Gets and opens form of curerncy selection from the ACC classifier.
//
&AtClient
Procedure CommandFillFromOKVExecute()
	
	OpenForm("Catalog.Currencies.Form.CurrencyFillFromClassifierForm",, ThisForm);
	
EndProcedure

// Handler of form event "notification processing".
// Recalculates the currency list.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "CurrencyRateUpdate" Then
		Items.Currencies.Refresh();
	EndIf;
	
EndProcedure
