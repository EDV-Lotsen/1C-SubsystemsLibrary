
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed	
If Parameters.Property("Autotest") Then 		
Return;
	EndIf;
	
	FillPropertyValues(
		ThisObject,
		Parameters,
		"ChangeDateInWorkingDirectory,
		|ChangeDateInFileStorage,
		|FullFileNameInWorkingDirectory,
		|SizeInWorkingDirectory,
		|SizeInFileStorage,
		|Message,
		|Title");
	
	If Parameters.FileOperation = "PlaceInFileStorage" Then
		
		Items.FormOpenExistingFile.Visible = False;
		Items.FormTakeFromStorage.Visible  = False;
		Items.FormPut.DefaultButton   = True;
		
	ElsIf Parameters.FileOperation = "OpenInWorkingDirectory" Then
		
		Items.FormPut.Visible     = False;
		Items.FormDontPut.Visible = False;
		Items.FormOpenExistingFile.DefaultButton = True;
	Else
		Raise NStr("en = 'Unknown file operation'");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenExistingFile(Command)
	
	Close("OpenExistingFile");
	
EndProcedure

&AtClient
Procedure Put(Command)
	
	Close("Put");
	
EndProcedure

&AtClient
Procedure TakeFromStorage(Command)
	
	Close("TakeFromStorageAndOpen");
	
EndProcedure

&AtClient
Procedure DontPut(Command)
	
	Close("DontPut");
	
EndProcedure

&AtClient
Procedure OpenDirectory(Command)
	
	FileFunctionsInternalClient.OpenExplorerWithFile(FullFileNameInWorkingDirectory);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close("Cancel");
	
EndProcedure

#EndRegion
