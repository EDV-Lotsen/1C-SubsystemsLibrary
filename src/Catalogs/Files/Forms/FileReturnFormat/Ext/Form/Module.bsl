

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	File = Parameters.FileRef;
	
	If File.StoreVersions Then
		CreateNewVersion = True;
	Else
		CreateNewVersion = False;
		Items.CreateNewVersion.Enabled = False;
	EndIf;	
	
EndProcedure


&AtClient
Procedure OK(Command)
	ReturnStructure = New Structure("CommentToVersion, CreateNewVersion, ReturnCode", 
		CommentToVersion, CreateNewVersion, DialogReturnCode.OK);
	Close(ReturnStructure);
EndProcedure


&AtClient
Procedure Cancel(Command)
	ReturnStructure = New Structure("CommentToVersion, CreateNewVersion, ReturnCode", 
		CommentToVersion, CreateNewVersion, DialogReturnCode.Cancel);
	Close(ReturnStructure);
EndProcedure

