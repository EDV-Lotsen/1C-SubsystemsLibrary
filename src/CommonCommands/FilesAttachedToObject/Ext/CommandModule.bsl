////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("FileOwner",  CommandParameter);
	FormParameters.Insert("ReadOnly", CommandExecuteParameters.Source.ReadOnly);
	
	OpenForm("CommonForm.AttachedFiles",
	             FormParameters,
	             CommandExecuteParameters.Source,
	             CommandExecuteParameters.Uniqueness,
	             CommandExecuteParameters.Window);
	
EndProcedure
