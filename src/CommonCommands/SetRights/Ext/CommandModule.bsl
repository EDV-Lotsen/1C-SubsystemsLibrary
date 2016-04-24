
&AtClient
Procedure CommandProcessing(ObjectRef, CommandExecuteParameters)
	
	If ObjectRef = Undefined Then 
		Return;
	EndIf;
	
	FormParameters = New Structure("ObjectRef", ObjectRef);
	OpenForm("CommonForm.ObjectRightsSettings", FormParameters, 
CommandExecuteParameters.Source);
	
EndProcedure



