

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	File 	= Parameters.File;
	Message = Parameters.Message;
	
	FileCreationMode = 1;
EndProcedure

&AtClient
Procedure OK(Command)
	Close(FileCreationMode);
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	FileOperationsClient.OpenExplorerWithFile(File);
EndProcedure
