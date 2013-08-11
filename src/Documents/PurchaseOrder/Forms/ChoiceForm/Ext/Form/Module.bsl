
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Set counterparty name title (Vendor)
	Items.Counterparty.Title = _DemoGeneralFunctionsCached.GetVendorName();
	
EndProcedure
