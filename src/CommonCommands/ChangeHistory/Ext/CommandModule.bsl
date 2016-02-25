////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS 

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandParameter = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		If CommandParameter.Count() = 0 Then
			Return;
		EndIf;
		ObjectRef = CommandParameter[0];
	Else
		ObjectRef = CommandParameter;
	EndIf;
	
	OpenForm("InformationRegister.ObjectVersions.Form.SelectStoredVersions",
								New Structure("Ref", ObjectRef),
								CommandExecuteParameters.Source,
								CommandExecuteParameters.Uniqueness,
								CommandExecuteParameters.Window);
	
EndProcedure



