

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If ObjectAttributesLocking.CheckThereAreRefsToObjectsInIB(Parameters.Ref) Then
		Items.GroupPages.CurrentPage = Items.PageRefsFound;
		Items.AllowEdit.DefaultButton = True;
	Else
		Items.GroupPages.CurrentPage = Items.PageRefsNotFound;
		Items.OK.DefaultButton = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowEdit(Command)
	
	Result = New Array;
	Result.Add("ValueType");
	Close(Result);
	
EndProcedure
