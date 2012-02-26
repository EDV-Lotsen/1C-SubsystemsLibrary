

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.Property("Parent") Then
		Object.Parent = Parameters.Parent;
	EndIf;
	
	WorkingDirectory = FileOperations.GetWorkingDirectory(Object.Ref);
	
	// Handler of the subsystem "Properties"
	AdditionalDataAndAttributesManagement.OnCreateAtServer(ThisForm, Object, "");
	
	RefreshFullPath();
	
EndProcedure

&AtServer
Procedure RefreshFullPath()
	
	FolderParent = Object.Parent;
	FullPath = "";
	While Not FolderParent.IsEmpty() Do
		
		FullPath = String(FolderParent) + "\" + FullPath;
		FolderParent = FolderParent.Parent;
		
	EndDo;
	
	FullPath = FullPath + String(Object.Ref);
	
	If Not IsBlankString(FullPath) Then
		FullPath = """" + FullPath + """";
	EndIf;
	
EndProcedure	

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Handler of the subsystem "Properties"
	If AdditionalDataAndAttributesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalDataAndAttributesItems();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancellation, CurrentObject)
	
	// Handler of the subsystem "Properties"
	AdditionalDataAndAttributesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES OF PROPERTIES SUBSYSTEM

&AtClient
Procedure Pluggable_EditContentOfProperties()
	
	AdditionalDataAndAttributesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalDataAndAttributesItems()
	
	AdditionalDataAndAttributesManagement.UpdateAdditionalDataAndAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	If Object.Ref.IsEmpty() Then
		If Write() = False Then
			Return;
		EndIf;	
	EndIf;	
	
	ClearMessages();
	
	Directory = "";
	Mode = FileDialogMode.ChooseDirectory;
	
	FileOpenDialog = New FileDialog(Mode);
	FileOpenDialog.Directory = WorkingDirectory;
	FileOpenDialog.FullFileName = "";
	Filter = NStr("en = 'All files(*.*)|*.*'");
	FileOpenDialog.Filter = Filter;
	FileOpenDialog.Multiselect = False;
	FileOpenDialog.Title = NStr("en = 'Select the folder'");
	If FileOpenDialog.Choose() Then
		
		DirectoryName = FileOpenDialog.Directory;
		FileFunctionsClientServer.AddLastPathSeparatorIfMissing(DirectoryName);
		
		// Create directory for the files
		Try
			CreateDirectory(DirectoryName);
			DirectoryNameIsTest = DirectoryName + "AccessVerification\";
			CreateDirectory(DirectoryNameIsTest);
			DeleteFiles(DirectoryNameIsTest);
		Except
			// no rights for directory creation, or this path is absent
			
			ErrorText 
				= StringFunctionsClientServer.SubstitureParametersInString(NStr("en = 'Incorrect path or no access to directory ""%1""'"),
				DirectoryName);
			
			CommonUseClientServer.MessageToUser(ErrorText, , "WorkingDirectory");
			Return;
		EndTry;
		
		WorkingDirectory = DirectoryName;
		FileOperations.SaveWorkingDirectory(Object.Ref, WorkingDirectory);
		
	EndIf;
	
	RefreshDataRepresentation();
	
EndProcedure

&AtClient
Procedure OwnerWorkingDirectoryClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ParentRef = CommonUse.GetAttributeValue(Object.Ref, "Parent");
	ParentWorkingDirectory = FileOperations.GetWorkingDirectory(ParentRef);	
	
	WorkingDirectoryOfThisFolders = FileOperations.GetWorkingDirectory(Object.Ref);
	WorkingDirectoryInherited = ParentWorkingDirectory + Object.Description + "\";
	
	If IsBlankString(ParentWorkingDirectory) Then
		WorkingDirectory = "";
		FileOperations.ClearWorkingDirectory(Object.Ref);
	ElsIf WorkingDirectoryInherited <> WorkingDirectoryOfThisFolders Then
		WorkingDirectory = WorkingDirectoryInherited;
		FileOperations.SaveWorkingDirectory(Object.Ref, WorkingDirectory);
	EndIf;
	
	RefreshDataRepresentation();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	WorkingDirectory = FileOperations.GetWorkingDirectory(Object.Ref);
EndProcedure


&AtClient
Procedure ParentOnChange(Item)
	
	RefreshFullPath();
	
EndProcedure

