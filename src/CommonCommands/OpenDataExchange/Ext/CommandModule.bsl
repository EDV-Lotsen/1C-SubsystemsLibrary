
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm("CommonForm.DataExchanges", , 
					CommandExecuteParameters.Source,
					CommandExecuteParameters.Uniqueness,
					CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
