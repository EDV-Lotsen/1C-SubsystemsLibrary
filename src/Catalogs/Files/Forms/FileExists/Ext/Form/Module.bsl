

&AtClient
Procedure OverwriteExecute()
	Close(DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure IgnoreExecute()
	Close(DialogReturnCode.Ignore);
EndProcedure

&AtClient
Procedure AbortExecute()
	Close(DialogReturnCode.Abort);
EndProcedure

&AtClient
Procedure SetDefaultsButton(ActionByDefault) Export
	If ActionByDefault = "" or ActionByDefault = DialogReturnCode.Ignore Then
		Items.Ignore.DefaultButton = True;
	ElsIf ActionByDefault = DialogReturnCode.Yes Then
		Items.Overwrite.DefaultButton = True;
	ElsIf ActionByDefault = DialogReturnCode.Abort Then
		Items.Abort.DefaultButton = True;
	EndIf;
EndProcedure // AssignDefaultButton()

