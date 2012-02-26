

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	FileOperationsClient.OpenFile(
		FileOperations.GetFileDataForOpening(RowSelected, Undefined, Uuid)); 
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	
	FileBasis = Items.List.CurrentRow;
	
	If Not Clone Then
		
		Cancellation = True;
		Try
			FileOwner = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
			FileOperationsClient.CreateNewFile(FileOwner.Value, ThisForm);
		Except
			InfoInfo = ErrorInfo();
			DoMessageBox(StringFunctionsClientServer.SubstitureParametersInString(
			                 NStr("en = 'Error while creating new file:""%1""'"),
			                 InfoInfo.Details) );
		EndTry;
		
	Else
		
		FileOwner = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
		FileOperationsClient.CopyFile(FileOwner.Value, FileBasis);
		Cancellation = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "FilesImportCompleted" Then
		Items.List.Refresh();
		
		If Parameter <> Undefined Then
			Items.List.CurrentRow = Parameter;
		EndIf;
	EndIf;
	
	If EventName = "FileCreated" Then
		
		If Parameter <> Undefined Then
			
			ListFileOwner = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
			
			FileOwner = Undefined;
			If Parameter.Property("Owner", FileOwner) Then
				If FileOwner = ListFileOwner.Value Then
					Items.List.Refresh();
					
					CreatedFile = Undefined;
					If Parameter.Property("File", CreatedFile) Then
						Items.List.CurrentRow = CreatedFile;
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndIf;
	
	If EventName = "FileDataModified" Then
		If Items.List.CurrentData <> Undefined Then
			SetAccessibilityOfFileCommands();
		EndIf;	
	EndIf;	
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	If Parameters.Property("FormTitle") Then 
		Title = Parameters.FormTitle;
	EndIf;	
	
	If Parameters.Property("FileOwner") Then 
		List.Parameters.SetParameterValue(
			"Owner", Parameters.FileOwner);
		EndIf;	
		
	List.Parameters.SetParameterValue(
		"CurrentUser", CommonUse.CurrentUser());
		
	FileOperations.FillFileListConditionalAppearance(List);		
	
EndProcedure

&AtClient
Procedure CreateFileExecute()
	
	Try
		FileOwner = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
		FileOperationsClient.CreateNewFile(FileOwner.Value, ThisForm);
	Except
		InfoInfo = ErrorInfo();
			DoMessageBox(StringFunctionsClientServer.SubstitureParametersInString(
			                    NStr("en = 'Error while creating new file:""%1""'"),
			                    InfoInfo.Description) );
	EndTry;
	
EndProcedure

&AtClient
Procedure EndEdit(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileOperationsCommands.EndEdit(
		Items.List.CurrentRow,
		Uuid,
		Items.List.CurrentData.StoreVersions,
		Items.List.CurrentData.LockedByCurrentUser,
		Items.List.CurrentData.LockedBy);
		
	SetAccessibilityOfFileCommands();
		
EndProcedure

&AtClient
Procedure Take(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;

	FileOperationsCommands.Lock(Items.List.CurrentRow);
	
	SetAccessibilityOfFileCommands();
	
EndProcedure

&AtClient
Procedure Release(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileOperationsCommands.UnlockFile(
		Items.List.CurrentRow,
		Items.List.CurrentData.StoreVersions,
		Items.List.CurrentData.LockedByCurrentUser,
		Items.List.CurrentData.LockedBy);
		
	SetAccessibilityOfFileCommands();
		
EndProcedure

&AtClient
Procedure OpenFileDirectory(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.OpenFileDirectory(FileData);
EndProcedure

&AtClient
Procedure OpenFile(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForOpening(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.Open(FileData);
EndProcedure

&AtClient
Procedure Edit(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileOperationsCommands.Edit(Items.List.CurrentRow);
	
	SetAccessibilityOfFileCommands();
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
EndProcedure
	
&AtClient
Procedure SaveAs(Command)
	If Items.List.CurrentRow = Undefined Then 
		Return;
	EndIf;
	
	FileData = FileOperations.GetFileDataForSaving(Items.List.CurrentRow, Undefined, Uuid);
	FileOperationsCommands.SaveAs(FileData);
EndProcedure

&AtClient
Procedure ListDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ListDrag(Item, DragParameters, StandardProcessing, String, Field)
	StandardProcessing = False;
	
	FileOwner = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
	ListFileOwner = FileOwner.Value;
	
	If ListFileOwner.IsEmpty() Then
		Return;
	EndIf;
	
	FileOperationsClient.DraganddropProcessingToLinearList(DragParameters, ListFileOwner, ThisForm);
EndProcedure

&AtClient
Procedure SetAccessibilityOfFileCommands()
	
	If Items.List.CurrentData <> Undefined Then
		
		If TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow") Then
			
			SetAccessibilityOfCommands(Items.List.CurrentData.LockedByCurrentUser,
				Items.List.CurrentData.LockedBy, Items.List.CurrentData.Signed,
				Items.List.CurrentData.Encrypted);
					
		EndIf;	
			
	EndIf;	
	
EndProcedure

&AtClient
Procedure SetAccessibilityOfCommands(LockedByCurrentUser, LockedBy, Signed, Encrypted)
	
	Items.EndEdit.Enabled = LockedByCurrentUser;
	Items.ListContextMenu.ChildItems.ContextMenuListEndEdit.Enabled = LockedByCurrentUser;
	
	Items.SaveChanges.Enabled = LockedByCurrentUser;
	Items.ListContextMenu.ChildItems.ContextMenuListSaveChanges.Enabled = LockedByCurrentUser;
	
	Items.Release.Enabled = Not LockedBy.IsEmpty();
	Items.ListContextMenu.ChildItems.ContextMenuListRelease.Enabled = Not LockedBy.IsEmpty();
	
	Items.Take.Enabled = LockedBy.IsEmpty() And NOT (Signed OR Encrypted);
	Items.ListContextMenu.ChildItems.ContextMenuListTake.Enabled = LockedBy.IsEmpty() And NOT (Signed OR Encrypted);
	
	Items.Edit.Enabled = NOT (Signed OR Encrypted);
	Items.ListContextMenu.ChildItems.ContextMenuListEdit.Enabled = NOT (Signed OR Encrypted);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	If Items.List.CurrentData <> Undefined Then
		SetAccessibilityOfFileCommands();
	EndIf;	
EndProcedure

&AtClient
Procedure FilesImport(Command)
	#If Not WebClient Then
		
		// select files in advance (before open of import dialog)
		Mode = FileDialogMode.Open;
		
		FileOpenDialog = New FileDialog(Mode);
		FileOpenDialog.FullFileName = "";
		Filter = NStr("en = 'All files(*.*)|*.*'");
		FileOpenDialog.Filter = Filter;
		FileOpenDialog.Multiselect = True;
		FileOpenDialog.Title = NStr("en = 'Select files'");
		If FileOpenDialog.Choose() Then
			FilenamesArray = New Array;
			
			FilesArray = FileOpenDialog.SelectedFiles;
			For Each FileName In FilesArray Do
				FilenamesArray.Add(FileName);
			EndDo;
			
			FileOwner = List.Parameters.FindParameterValue(New DataCompositionParameter("Owner"));
			ImportParameters = New Structure("FolderForAdd, FilenamesArray", FileOwner.Value, FilenamesArray);
			OpenForm("Catalog.Files.Form.FileImportForm", ImportParameters);
		EndIf;
	#Else	
		DoMessageBox(NStr("en = 'Web client cannot perform files import. Use command ""Create"" in the file list.'"));
	#EndIf
EndProcedure

