////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
// OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
EndProcedure

// OnLoadDataFromSettingsAtServer event handler.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterAccountingPeriod 	= Settings.Get("FilterAccountingPeriod"); 
	
	_DemoPayrollAndHRServer.ChangeListFilterElement(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
    _DemoPayrollAndHRServer.ChangeListFilterElement(List, "AccountingPeriod", FilterAccountingPeriod, ValueIsFilled(FilterAccountingPeriod));
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ATTRIBUTE EVENT HANDLERS

&AtClient
// FilterCompany input field OnChange event handler.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	_DemoPayrollAndHRClient.ChangeListFilterElement(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
// FilterAccountingPeriod input field OnChange event handler.
// Overrides the corresponding form parameter.
//
Procedure FilterAccountingPeriodOnChange(Item)
	FilterAccountingPeriod = BegOfMonth(FilterAccountingPeriod);
	_DemoPayrollAndHRClient.ChangeListFilterElement(List, "AccountingPeriod", FilterAccountingPeriod, ValueIsFilled(FilterAccountingPeriod));
EndProcedure
