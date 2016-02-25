
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	NotifyDescription = New NotifyDescription("ImportRatesClient", ThisObject);
	ShowQueryBox(NotifyDescription, 
		NStr("en = 'A file containing comprehensive information on currency rates will be imported from the service manager.
              |Currency rates that are marked in the Import from the Internet data areas will be replaced in a background job. Do you want to continue?'"), 
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure ImportRatesClient(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.No Then
		Return;
	EndIf;
	
	ImportRates();
	
	ShowUserNotification(
		NStr("en = 'Import is scheduled.'"), ,
		NStr("en = 'The rates will soon be imported in the background mode.'"),
		PictureLib.Information32);
	
EndProcedure

&AtServer
Procedure ImportRates()
	
	CurrencyRatesInternalSaaS.ImportRates();
	
EndProcedure
