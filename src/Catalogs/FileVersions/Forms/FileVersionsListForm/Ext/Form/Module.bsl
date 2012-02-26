

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
Procedure ChangeActiveFileVersion(Version)
	
	File 				= Version.Owner.GetObject();
	File.Lock();
	File.CurrentVersion = Version;
	File.TextStorage 	= Version.TextStorage;
	File.Write();
	
EndProcedure

&AtServer
Procedure FillVersionsTree()
	
	Query = New Query(
	"SELECT ALLOWED
	|	FileVersions.Code AS Code,
	|	FileVersions.Size AS Size,
	|	FileVersions.Comment AS Comment,
	|	FileVersions.Author AS Author,
	|	FileVersions.CreationDate AS CreationDate,
	|	FileVersions.FileName AS Details,
	|	FileVersions.ParentalVersion AS ParentalVersion,
	|	CASE
	|		WHEN FileVersions.DeletionMark = TRUE
	|			THEN 1
	|		ELSE FileVersions.PictureIndex
	|	END AS PictureIndex,
	|	FileVersions.DeletionMark AS DeletionMark,
	|	FileVersions.Owner AS Owner,
	|	FileVersions.Ref AS Ref,
	|	CASE
	|		WHEN FileVersions.Owner.CurrentVersion = FileVersions.Ref
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ThisIsCurrent,
	|	FileVersions.Extension AS Extension,
	|	FileVersions.VersionNo AS VersionNo
	|FROM
	|	Catalog.FileVersions AS FileVersions
	|WHERE
	|	FileVersions.Owner = &Owner");
	
	Query.SetParameter("Owner", Parameters.File);
	Data = Query.Execute().Unload();
	
	Tree = FormAttributeToValue("VersionsTree");
	Tree.Rows.Clear();
	
	AddPreviousVersion(Undefined, Tree, Data);
	ValueToFormData(Tree, VersionsTree);
	
EndProcedure	

&AtServer
Procedure AddPreviousVersion(CurrentBranch, Tree, Data)
	
	StringFound = Undefined;
	
	If CurrentBranch = Undefined Then
		For Each String In Data Do
			If String.ThisIsCurrent Then
				StringFound = String;
				Break;
			EndIf;	
		EndDo;		
	Else
		For Each String In Data Do
			If String.Ref = CurrentBranch.ParentalVersion Then 
				StringFound = String;
				Break;
			EndIf;	
		EndDo;
	EndIf;	
	
	If StringFound <> Undefined Then 
		Branch = Tree.Rows.Add();
		FillPropertyValues(Branch, StringFound);
		Data.Delete(StringFound);
		
		AddSubordinateVersions(Branch, Data);
		AddPreviousVersion(Branch, Tree, Data);
	EndIf;			
	
EndProcedure

&AtServer
Procedure AddSubordinateVersions(Branch, Data)
	
	For Each String in Data Do
		If Branch.Ref = String.ParentalVersion Then
			FillPropertyValues(Branch.Rows.Add(), String);
		EndIf;
	EndDo;
	For Each Sprig in Branch.Rows Do
		AddSubordinateVersions(Sprig, Data);
	EndDo;
	
EndProcedure

&AtServer
Procedure MarkForDeletionUnmarkAtServer(Version)
	
	Check = Not Version.DeletionMark;
	
	VersionObject = Version.GetObject();
	VersionObject.Lock();
	VersionObject.SetDeletionMark(Check);
	
EndProcedure	

&AtClient
Procedure MarkForDeletionUnmark()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;
	
	Check = CommonUse.GetAttributeValue(CurrentData.Ref, "DeletionMark");
	If Check Then 
		QuestionText = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Unmark ""%1"" deletion flag?'"),
			String(CurrentData.Ref));
	Else
		QuestionText = StringFunctionsClientServer.SubstitureParametersInString(
			NStr("en = 'Mark ""%1"" for deletion?'"),
			String(CurrentData.Ref));
	EndIf;	
	
	Result = DoQueryBox(QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	If Result <> DialogReturnCode.Yes Then 
		Return;
	EndIf;	
	
	MarkForDeletionUnmarkAtServer(CurrentData.Ref);
	
	If Not Check Then
		CurrentData.PictureIndex = 1;
	Else
		CurrentData.PictureIndex = CommonUse.GetAttributeValue(CurrentData.Ref, "PictureIndex");
	EndIf;
	
EndProcedure	

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	FillVersionsTree();
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

&AtClient
Procedure ActivateExecute()
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;	
	FileData = FileOperations.GetFileData(Undefined, CurrentData.Ref);
	
	If FileData.LockedBy.IsEmpty() Then
		ChangeActiveFileVersion(CurrentData.Ref);
		FillVersionsTree();
		Notify("ActiveVersionChanged", Parameters.File);
	Else
		DoMessageBox(NStr("en = 'Changing the active version is only allowed for non busy files!'"));
	EndIf;	
	
EndProcedure

&AtClient
Function BypassAllTreeNodes(Items, CurrentVersion)
	
	For Each Version In Items Do
		
		If Version.Ref = CurrentVersion Then
			Id = Version.GetID();
			Return Id;
		EndIf;	
		
		ReturnCode = BypassAllTreeNodes(Version.GetItems(), CurrentVersion);
		If ReturnCode <> -1 Then
			Return ReturnCode;
		EndIf;	
	EndDo;	
	
	Return -1;
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EditCompleted" Or EventName = "VersionSaved" Then
		If Parameters.File = Parameter Then
			
			CurrentVersion = Items.List.CurrentData.Ref;
			FillVersionsTree();
			
			ReturnCode = BypassAllTreeNodes(VersionsTree.GetItems(), CurrentVersion);
			If ReturnCode <> -1 Then
				Items.List.CurrentRow = ReturnCode;
			EndIf;	
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.List.CurrentData;
	
	FileOperationsClient.OpenFileVersion(
		FileOperations.GetFileDataForOpening(Undefined, CurrentData.Ref, Uuid),
		Uuid);
	
EndProcedure

&AtClient
Procedure OpenCard(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("Catalog.FileVersions.ObjectForm", FormOpenParameters);
		
	EndIf;		
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancellation)
	
	Cancellation = True;
	MarkForDeletionUnmark();
		
EndProcedure

&AtClient
Procedure MarkForDeletion(Command)
	
	MarkForDeletionUnmark();
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancellation)
	
	Cancellation = True;
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then 
		
		Version = CurrentData.Ref;
		
		FormOpenParameters = New Structure("Key", Version);
		OpenForm("Catalog.FileVersions.ObjectForm", FormOpenParameters);
		
	EndIf;
	
EndProcedure


// Function convert Windows filename to OpenOffice URL
Function ConvertToURL(FileName)
	Return "file:///" + StrReplace(FileName, "\", "/");
EndFunction

// creating structure for OpenOffice parameters
&AtClient
Function AssignValueToProperty(Object, PropertyName, PropertyValue)
    Properties = Object.Bridge_GetStruct("com.sun.star.beans.PropertyValue");
    Properties.Name = PropertyName;
    Properties.Value = PropertyValue;
    
    Return Properties;
EndFunction

// Compare 2 selected versions.
&AtClient
Procedure Compare(Command)
	Var Ref1;
	Var Ref2;
	
	NumberOfSelectedRows = Items.List.SelectedRows.Count();
	
	If NumberOfSelectedRows = 2 OR NumberOfSelectedRows = 1 Then
		
		#If NOT WebClient Then	
			
			If NumberOfSelectedRows = 2 Then
				Ref1 = VersionsTree.FindByID(Items.List.SelectedRows[0]).Ref;
				Ref2 = VersionsTree.FindByID(Items.List.SelectedRows[1]).Ref;
			ElsIf NumberOfSelectedRows = 1 Then
				
				Ref1 = Items.List.CurrentData.Ref;
				Ref2 = Items.List.CurrentData.ParentalVersion;
				
			EndIf;
			
			FileVersionsCompareMethod = Undefined;
			Extension = Lower(Items.List.CurrentData.Extension);
			
			ExtensionSupported = (Extension = "txt" OR Extension = "doc" OR Extension = "docx" OR Extension = "rtf" OR Extension = "htm" OR Extension = "html" OR Extension = "odt");
			
			If Not ExtensionSupported Then
				DoMessageBox(NStr(  "en = 'Version compare is kept only for the following file type: 
                                     |Text document (.txt)""RTF format document (.rtf) ""Document Microsoft Word (.doc, .docx) ""HTML Document (.html .htm) ""Open Document (.odt)'"));
				Return;
			EndIf;
			
			If StandardSubsystemsClientSecondUse.ClientParameters().ThisIsBasicConfigurationVersion Then
				CommonUseClientServer.MessageToUser(NStr("en = 'Specified operation is not supported in basic version.'"));
				Return;
			EndIf;
			
			If Extension = "odt" Then
				FileVersionsCompareMethod = "OpenOfficeOrgWriter";
			EndIf;	
			If Extension = "htm" OR Extension = "html" Then
				FileVersionsCompareMethod = "MicrosoftOfficeWord";
			EndIf;	
			
			If FileVersionsCompareMethod = Undefined Then
				FileVersionsCompareMethod = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().FileVersionsCompareMethod;
			EndIf;	
			
			If FileVersionsCompareMethod = Undefined Then // first call - setting has not been initialized yet
				Result = OpenFormModal("Catalog.FileVersions.Form.VersionComparisonMethodChoiceForm");
				
				If Result <> DialogReturnCode.OK Then
					Return;
				EndIf;	
				
				FileVersionsCompareMethod = FileOperationsSecondUseClient.GetFileOperationsPersonalSettings().FileVersionsCompareMethod;					
			EndIf;
			
			If FileVersionsCompareMethod = Undefined Then
				Return;
			EndIf;
			
			FileData1 = FileOperations.GetFileDataForOpening(Undefined, Ref1, Uuid);
			FileData2 = FileOperations.GetFileDataForOpening(Undefined, Ref2, Uuid);
			
			StatusText = StringFunctionsClientServer.SubstitureParametersInString(
				NStr("en = 'Comparing versions of the file ""%1""'"), FileData1.Ref);
			Status(StatusText);
			
			FullFileName1 = "";
			Result1 = FileOperationsClient.GetVersionFileToWorkingDirectory(FileData1, FullFileName1);
			
			FullFileName2 = "";
			Result2 = FileOperationsClient.GetVersionFileToWorkingDirectory(FileData2, FullFileName2);
			
			If Result1 And Result2 Then
				
				PathToFile1 = "";
				PathToFile2 = "";
				
				If FileData1.VersionNo < FileData2.VersionNo Then
					PathToFile1 = FullFileName1;
					PathToFile2 = FullFileName2;
				Else
					PathToFile1 = FullFileName2;
					PathToFile2 = FullFileName1;
				EndIf;
				
				Try
					
					If FileVersionsCompareMethod = "MicrosoftOfficeWord" Then
						ObjectWord = New COMObject("Word.Application");
						ObjectWord.Visible = 0;

						Document = ObjectWord.Documents.Open(PathToFile1);
						
						Document.Merge(PathToFile2, 0, 0, 0); // MergeTarget:=wdMergeTargetSelected, DetectFormatChanges:=False, UseFormattingFrom:=wdFormattingFromCurrent
						
						ObjectWord.Visible = 1;
						ObjectWord.Activate(); 	
						
						Document.Close();
					ElsIf FileVersionsCompareMethod = "OpenOfficeOrgWriter" Then 
						
						// clear readonly - or it won't work
						File1 = New File(PathToFile1);
						File1.SetReadOnly(False);
						
						File2 = New File(PathToFile2);
						File2.SetReadOnly(False);
						
						// Open OpenOffice
						ServiceManager 	= New COMObject					("com.sun.star.ServiceManager");
						Reflection 		= ServiceManager.createInstance ("com.sun.star.reflection.CoreReflection");
						Desktop 		= ServiceManager.createInstance ("com.sun.star.frame.Desktop");
						Dispatcher		= ServiceManager.createInstance ("com.sun.star.frame.DispatchHelper");
						
						// Open OpenOffice document
						Args = New COMSafeArray("Vt_dispatch", 1);
						OODocument = Desktop.loadComponentFromURL(ConvertToURL(PathToFile2), "_blank", 0, Args);
						
						frame = Desktop.getCurrentFrame();
						
						// adjust displaying of modifications
						CompareParameters = New COMSafeArray("Vt_variant", 1);
						CompareParameters.SetValue(0, AssignValueToProperty(ServiceManager, "ShowTrackedChanges", True));
						dispatcher.executeDispatch(frame, ".uno:ShowTrackedChanges", "", 0, CompareParameters);

						// compare with document
						CallParameters = New COMSafeArray("Vt_variant", 1);
						CallParameters.SetValue(0, AssignValueToProperty(ServiceManager, "URL", ConvertToURL(PathToFile1)));
						dispatcher.executeDispatch(frame, ".uno:CompareDocuments", "", 0, CallParameters);
						
						OODocument = Undefined;
					EndIf;
					
				Except
					Information = ErrorInfo();
					CommonUseClientServer.MessageToUser(Information.Description);
				EndTry;
				
			EndIf;
			
			Status();
		#Else
			DoMessageBox(NStr("en = 'Versions compare on Web client is not supported!'"));
		#EndIf

	EndIf;
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	NumberOfSelectedRows = Items.List.SelectedRows.Count();
	
	CompareCommandAvailable = False;
	
	If NumberOfSelectedRows = 2 Then
		CompareCommandAvailable = True;
	ElsIf NumberOfSelectedRows = 1 Then
		
		If Not Items.List.CurrentData.ParentalVersion.IsEmpty() Then
			CompareCommandAvailable = True;		
		Else
			CompareCommandAvailable = False;
		EndIf;
			
	Else
		CompareCommandAvailable = False;
	EndIf;
	

	If CompareCommandAvailable = True Then
		Items.MainCommandBar.ChildItems.Compare.Enabled = True;
		Items.ListContextMenu.ChildItems.ContextMenuListCompare.Enabled = True;
	Else
		Items.MainCommandBar.ChildItems.Compare.Enabled = False;
		Items.ListContextMenu.ChildItems.ContextMenuListCompare.Enabled = False;
	EndIf;
EndProcedure

&AtClient
Procedure OpenVersion(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData = Undefined Then 
		Return;
	EndIf;	
	
	FileOperationsClient.OpenFileVersion(
		FileOperations.GetFileDataForOpening(Undefined, CurrentData.Ref, Uuid),
		Uuid);
	
EndProcedure


