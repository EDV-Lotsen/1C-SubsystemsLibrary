////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("Catalog.EmailAccounts.ObjectForm", 
						New Structure("Key", EmailOperations.GetSystemAccount()),,,,, Undefined, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure
