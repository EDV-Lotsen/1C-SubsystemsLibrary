
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.Counterparty.Title = _DemoGeneralFunctionsCached.GetCustomerName();
	
EndProcedure
