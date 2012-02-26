

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandParameter = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		If CommandParameter.Count() = 0 Then
			Return;
		EndIf;
		ObjectReference = CommandParameter[0];
	Else
		ObjectReference = CommandParameter;
	EndIf;
	
	VersionsList = OpenForm("InformationRegister.ObjectVersions.Form.StoredVersionsChoice",
								New Structure("Ref", ObjectReference),
								CommandExecuteParameters.Source,
								CommandExecuteParameters.Uniqueness,
								CommandExecuteParameters.Window);
	
EndProcedure

