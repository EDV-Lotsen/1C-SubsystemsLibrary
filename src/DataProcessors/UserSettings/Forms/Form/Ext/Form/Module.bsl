
//////////////////////////////////////////////////////////////////////
// Commands handlers

&AtClient
Procedure Save()
	
	HandlingCommonSettingsStorage.SaveWorkingDirectory(WorkingDirectoryPath);
	HandlingCommonSettingsStorage.SaveTextHeaderApplicationsSummary(ShortCaption);
	If GetShortApplicationCaption() <> ShortCaption Then
		
		SetShortApplicationCaption(ShortCaption);
		
	EndIf;
	
	Close(True);
	
EndProcedure

//////////////////////////////////////////////////////////////////////
// Form events handlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	WorkingDirectoryPath = HandlingCommonSettingsStorage.GetWorkingDirectory();
	ShortCaption = HandlingCommonSettingsStorage.GetShortApplicationTitleText();
	
EndProcedure

//////////////////////////////////////////////////////////////////////
// The controls event handlers

&AtClient
Procedure PathToWorkingDirectoryStartChoice(Element, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If AttachFileSystemExtension() Then

		FileOpenDialog = New FileDialog(FileDialogMode.ChooseDirectory);
		FileOpenDialog.Title = NStr("en = 'Select temporary file storage directory'");
		If FileOpenDialog.Choose() Then
			WorkingDirectoryPath = FileOpenDialog.Directory;
		EndIf;
		
	Else
		
		ShowMessageBox(,NStr("en = 'This option is not available due to the file system extension is not attached.'"));
		
	EndIf;
	
EndProcedure
