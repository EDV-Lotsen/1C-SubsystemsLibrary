&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandParameter = Undefined Then
		Return;
	EndIf;
	
	FormParametersEditValueProperties = New Structure("Ref", CommandParameter);
	OpenForm("CommonForm.PropertyValueEditing", FormParametersEditValueProperties, , CommandParameter);
	
EndProcedure
