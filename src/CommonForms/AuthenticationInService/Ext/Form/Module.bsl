
&AtClient
Procedure OnOpen(Cancel)
	
	If FormOwner = Undefined Then
		WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	NotifyChoice(ServiceUserPassword);
	
EndProcedure


&AtClient
Procedure OK(Command)
	
	ServiceUserPassword = Password;
	Close(ServiceUserPassword);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure
