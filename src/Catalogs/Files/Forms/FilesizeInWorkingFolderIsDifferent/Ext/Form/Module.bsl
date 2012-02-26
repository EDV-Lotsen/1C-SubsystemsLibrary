
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	SizeInWorkingDirectory 	= Parameters.SizeInWorkingDirectory;
	FilesizeOnServer 		= Parameters.FilesizeOnServer;
	File 					= Parameters.File;
	Message 				= Parameters.Message;
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	FileOperationsClient.OpenExplorerWithFile(File);
EndProcedure
