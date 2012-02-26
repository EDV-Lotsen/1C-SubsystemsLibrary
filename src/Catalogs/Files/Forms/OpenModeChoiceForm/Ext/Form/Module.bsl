

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	DoNotAskAnyMore = False;	
EndProcedure

&AtClient
Procedure OK(Command)
	ReturnStructure = New Structure("DoNotAskAnyMore, HowToOpen", 
		DoNotAskAnyMore, HowToOpen);
	Close(ReturnStructure);
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close(DialogReturnCode.Cancel);
EndProcedure
