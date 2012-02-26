

&AtClient
Procedure LoadClassifier(Command)
	AddressClassifierClient.LoadAddressClassifier();
EndProcedure

&AtClient
Procedure ClearClassifierExecute(Command)
	
	AddressClassifierClient.ClearClassifier();
	RefreshDataRepresentation();
	
EndProcedure
	
&AtClient
Procedure CheckUpdate(Command)
	
	AddressClassifierClient.CheckAddressClassifierUpdate();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AddressClassifierUpdate" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure
