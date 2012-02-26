

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	Information = Parameters.Information;
	Title		=  Parameters.Title;
EndProcedure

&AtClient
Procedure Yes(Command)
	ReturnStructure = New Structure("ApplyToAll, ReturnCode", 
		ApplyToAll, DialogReturnCode.Yes);
	Close(ReturnStructure);
EndProcedure

&AtClient
Procedure None(Command)
	ReturnStructure = New Structure("ApplyToAll, ReturnCode", 
		ApplyToAll, DialogReturnCode.No);
	Close(ReturnStructure);
EndProcedure
