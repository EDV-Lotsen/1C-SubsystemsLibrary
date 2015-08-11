
&AtClient
Procedure PathToDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	BeginAttachingFileSystemExtension(New NotifyDescription("PathToDirectoryStartChoiceEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure PathToDirectoryStartChoiceEnd(Attached, AdditionalParameters) Export
	
	If Attached Then
		FileOpenDialog = New FileDialog(FileDialogMode.ChooseDirectory);
		FileOpenDialog.FullFileName = "";
		FileOpenDialog.Directory = DirrectoryForPrintDataSave;
		FileOpenDialog.Multiselect = False;
		FileOpenDialog.Title = NStr("en = 'Select path to the  directory of printing files'");
		If FileOpenDialog.Choose() Then
			DirrectoryForPrintDataSave = FileOpenDialog.Directory + "\";
		EndIf;
	Else
		ShowMessageBox(,NStr("en = 'To select the directory it is necessary to attach file system extension to work in the Web Client.'"));
	EndIf;

EndProcedure

&AtClient
Procedure OK(Command)
	
	Close(DirrectoryForPrintDataSave);
	
EndProcedure
