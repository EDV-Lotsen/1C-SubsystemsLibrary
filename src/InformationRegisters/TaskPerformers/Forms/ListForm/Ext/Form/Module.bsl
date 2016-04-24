
#Region FormEventHandlers

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_RoleAddressing" Then
		Items.List.Refresh();
 	EndIf;
EndProcedure

#EndRegion
