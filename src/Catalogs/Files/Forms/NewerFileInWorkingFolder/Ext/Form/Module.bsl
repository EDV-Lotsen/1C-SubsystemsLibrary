
&AtClient
Procedure OpenExisting(Command)
	Close(DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure Overwrite(Command)
	Close(DialogReturnCode.No);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	InWorkingDirectory 			= Parameters.InWorkingDirectory;
	ModificationTimeOnServer 	= Parameters.ModificationTimeOnServer;
	File 						= Parameters.File;
	Message 					= Parameters.Message;
	Title 						= Parameters.Title;
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	FileOperationsClient.OpenExplorerWithFile(File);
EndProcedure
