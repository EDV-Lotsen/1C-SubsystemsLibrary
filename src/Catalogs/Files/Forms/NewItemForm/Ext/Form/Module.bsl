

&AtClient
Procedure CreateFileExecute()
	Close(DialogReturnCode.Yes);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	If Parameters.Property("CommandScanAvailable") Then
		If Parameters.CommandScanAvailable Then
			Items.CreationMode.ChoiceList.Add(3, "From scanner");
		EndIf;	
	EndIf;
EndProcedure
