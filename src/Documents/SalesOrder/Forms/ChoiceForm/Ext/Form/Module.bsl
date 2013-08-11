
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Set counterparty name title (Customer)
	Items.Counterparty.Title = _DemoGeneralFunctionsCached.GetCustomerName();
	
EndProcedure
