
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

&AtClient
Procedure FilesListBeforeAddRow(Element, Cancel, Clone, Parent, Folder)
	Cancel = True;
	AddFiles();
EndProcedure

&AtClient
Procedure AddFiles()
	
	FileChoice = New FileDialog(FileDialogMode.Open);
	FileChoice.Multiselect = True;
	FileChoice.Title = NStr("en = 'Choose a file'");
	FileChoice.Filter = NStr("en = 'All files'") + " (*.*)|*.*";
	FileChoice.Preview = True;
	If FileChoice.Choose() Then
		For Each File In FileChoice.SelectedFiles Do
			FilesList.Add(File);
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure AddDirectory()
	
	FileChoice = New FileDialog(FileDialogMode.ChooseDirectory);
	If FileChoice.Choose() Then
		Files = FindFiles(FileChoice.Directory, "*.*", True);
		For Each File In Files Do
			If File.IsFile() Then
				FilesList.Add(File.FullName);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportExecute()
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	ClearMessages();
	If FilesList.Count() = 0 Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Files are not selected'");
		Message.Message();
		Return;
	EndIf;
	
	FilesToPut = New Array;
	For Each File In FilesList Do
		Details = New TransferableFileDescription(File.Value, "");
		FilesToPut.Add(Details);
	EndDo;
	
	PuttedFiles = New Array;
	If PutFiles(FilesToPut, PuttedFiles, , False) Then
		
		For Each File In PuttedFiles Do
			ImportedFiles.Add(File);
		EndDo;
		Result =  New  Structure(
			"ImportedFiles, Owner",
			ImportedFiles, Owner);
		Close(Result);		
	Else
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Files are not imported");
		Message.Message();
		
	EndIf;

EndProcedure
