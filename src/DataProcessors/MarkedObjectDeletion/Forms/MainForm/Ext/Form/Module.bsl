////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	DeletionMode = "Full";
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure DeletionModeOnChange(Item)
	
	ButtonEnabledStates();
	
EndProcedure

// Check field On change event handler 
// Calls a recursive function that sets dependent marks
// in parent and child items
//
&AtClient
Procedure CheckOnChange(Item)
	
	CurrentData = Items.MarkedForDeletionList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SetMarkInList(CurrentData, CurrentData.Check, True);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Marked for deletion list TABLE 

// MarkedForDeletionList tree row Choice event handler
// It tries to open the selected value
//
&AtClient
Procedure MarkedForDeletionListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Item.CurrentData <> Undefined Then 
		ShowValue(, Item.CurrentData.Value);	
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF Remaining object tree TABLE 

// RemainingObjectTree tree row Choice event handler
// It tries to open the selected value
//
&AtClient
Procedure RemainingObjectTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Item.CurrentData <> Undefined Then 
		ShowValue(, Item.CurrentData.Value);	
	EndIf;
	
EndProcedure

&AtClient
Procedure RemainingObjectTreeBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	
	If Item.CurrentData <> Undefined Then
		ShowValue(, Item.CurrentData.Value);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// MarkedForDeletionList tree list command panel Check all button 
// click handler
// It sets marks to all of found objects
//
&AtClient
Procedure MarkedListCheckAllCommand(Command)
	
	ListItems = MarkedForDeletionList.GetItems();
	For Each Item In ListItems Do
		SetMarkInList(Item, True, True);
		Parent = Item.GetParent();
		If Parent = Undefined Then
			CheckParent(Item)
		EndIf;
	EndDo;
	
EndProcedure

// MarkedForDeletionList tree list command panel Uncheck all button 
// click handler
// It clears check mark to all of found objects
//
&AtClient
Procedure MarkedListUncheckAllCommand(Command)
	
	ListItems = MarkedForDeletionList.GetItems();
	For Each Item In ListItems Do
		SetMarkInList(Item, False, True);
		Parent = Item.GetParent();
		If Parent = Undefined Then
			CheckParent(Item)
		EndIf;	
	EndDo;
	
EndProcedure

// Form command panel Next buttion click handler
// 
&AtClient
Procedure NextExecute(Command)
	
	CurrentPage = Items.FormPages.CurrentPage;
	
	If CurrentPage = Items.DeletionModeChoice Then
		Status(NStr("en='Searching for marked for deletion objects'"));
		
		FillMarkedForDeletionTree();
		
		If MarkedForDeletionLevelCount = 1 Then
			For Each Item In MarkedForDeletionList.GetItems() Do
				ID = Item.GetID();
				Items.MarkedForDeletionList.Expand(ID, False);
			EndDo;
		EndIf;
		
		Items.FormPages.CurrentPage = Items.MarkedForDeletion;
		ButtonEnabledStates();
	EndIf;
	
EndProcedure

// Form command panel Back buttion click handler
//
&AtClient
Procedure BackExecute(Command)
	
	CurrentPage = Items.FormPages.CurrentPage;
	If CurrentPage = Items.MarkedForDeletion Then
		Items.FormPages.CurrentPage = Items.DeletionModeChoice;
		ButtonEnabledStates();
	ElsIf CurrentPage = Items.DeletionImpossibilityReasons Then
		If DeletionMode = "Full" Then
			Items.FormPages.CurrentPage = Items.DeletionModeChoice;
		Else
			Items.FormPages.CurrentPage = Items.MarkedForDeletion;
		EndIf;
		ButtonEnabledStates();
	EndIf;
	
EndProcedure

// Form command panel Delete buttion click handler
//
&AtClient
Procedure ExecuteDelete(Command)
	
	Var DeletedObjectTypes;
	
	If DeletionMode = "Full" Then
		Status(NStr("en='Searching for marked objects and deleting them'"));
	Else
		Status(NStr("en='Deleting selected objects'"));
	EndIf;
	
	Result = DeleteSelectedAtServer(DeletedObjectTypes);
	If Not Result.JobCompleted Then
		TaskID = Result.TaskID;
		StorageAddress = Result.StorageAddress;
		
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		Items.FormPages.CurrentPage = Items.LongAction; 
	Else
		RefreshContents(Result.DeletionResult, Result.ErrorMessage,
			Result.DeletionResult.DeletedObjectTypes);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure RefreshContents(Result, ErrorMessage, DeletedObjectTypes)
	
	If Result.State Then
		For Each DeletedObjectType In DeletedObjectTypes Do
			NotifyChanged(DeletedObjectType);
		EndDo;
	Else
		Items.FormPages.CurrentPage = Items.DeletionModeChoice;
		ShowMessageBox(, ErrorMessage);
		Return;
	EndIf;
	
	RefreshMarkedTree = True;
	If NotDeletedObjectCount = 0 Then
		If DeletedObjects = 0 Then
			Text = NStr("en='No objects are marked for deletion. Object deletion was not executed.'");
			RefreshMarkedTree = False;
		Else
			Text = StringFunctionsClientServer.SubstituteParametersInString(
			 NStr("en='Marked objects deletion completed successfully."
"%1 object(s) were deleted.'"),
			 DeletedObjects);
		EndIf;
		Items.FormPages.CurrentPage = Items.DeletionModeChoice;			 
		ShowMessageBox(, Text);
	Else
		Items.FormPages.CurrentPage = Items.DeletionImpossibilityReasons;
		For Each Item In RemainingObjectTree.GetItems() Do
			ID = Item.GetID();
			Items.RemainingObjectTree.Expand(ID, False);
		EndDo;
		ButtonEnabledStates();
		ShowMessageBox(, ResultString);
	EndIf;
	
	If RefreshMarkedTree Then
		FillMarkedForDeletionTree();
		
		If MarkedForDeletionLevelCount = 1 Then 
			For Each Item In MarkedForDeletionList.GetItems() Do
				ID = Item.GetID();
				Items.MarkedForDeletionList.Expand(ID, False);
			EndDo;
		EndIf;
	EndIf;

EndProcedure	

// Changes form buttons enable states according to 
// the current page and the form attribute state
//
&AtClient
Procedure ButtonEnabledStates()
	
	CurrentPage = Items.FormPages.CurrentPage;
	
	If CurrentPage = Items.DeletionModeChoice Then
		Items.BackCommand.Enabled = False;
		If DeletionMode = "Full" Then
			Items.NextCommand.Enabled = False;
			Items.DeleteCommand.Enabled = True;
		ElsIf DeletionMode = "Selective" Then
			Items.NextCommand.Enabled 	= True;
			Items.DeleteCommand.Enabled = False;
		EndIf;
	ElsIf CurrentPage = Items.MarkedForDeletion Then
		Items.BackCommand.Enabled = True;
		Items.NextCommand.Enabled = False;
		Items.DeleteCommand.Enabled = True;
	ElsIf CurrentPage = Items.DeletionImpossibilityReasons Then
		Items.BackCommand.Enabled = True;
		Items.NextCommand.Enabled = False;
		Items.DeleteCommand.Enabled = False;
	EndIf;
	
EndProcedure

// Returns TreeRows tree branch by the Value
// If no branches found, a new one will be created.
&AtServer
Function FindOrAddTreeBranch(TreeRows, Value, Presentation, Mark)
	
	// Trying to find the existing branch not recursively in TreeRows 
	Branch = TreeRows.Find(Value, "Value", False);
	
	If Branch = Undefined Then
		// There is no such branch, creating a new one.
		Branch = TreeRows.Add();
		Branch.Value = Value;
		Branch.Presentation = Presentation;
		Branch.Check = Mark;
	EndIf;
	
	Return Branch;
	
EndFunction

&AtServer
Function FindOrAddTreeBranchWithPicture(TreeRows, Value, Presentation, PictureNumber)
	
	// Trying to find the existing not recursive branch in TreeRows 
	Branch = TreeRows.Find(Value, "Value", False);
	If Branch = Undefined Then
		// There is no such branch, creating a new one.
		Branch = TreeRows.Add();
		Branch.Value = Value;
		Branch.Presentation = Presentation;
		Branch.PictureNumber = PictureNumber;
	EndIf;

	Return Branch;
	
EndFunction

// Fills the tree of marked for deletion objects
//
&AtServer
Procedure FillMarkedForDeletionTree()
	
	// Filling the tree of marked for deletion
	MarkedTree = FormAttributeToValue("MarkedForDeletionList");
	
	MarkedTree.Rows.Clear();
	
	// Processing the marked objects
	MarkedArray = DataProcessors.MarkedObjectDeletion.GetMarkedForDeletion();
	
	For Each MarkedArrayItem In MarkedArray Do
		MetadataObjectValue = MarkedArrayItem.Metadata().FullName();
		MetadataObjectPresentation = MarkedArrayItem.Metadata().Presentation();
		MetadataObjectRow = FindOrAddTreeBranch(MarkedTree.Rows, MetadataObjectValue, MetadataObjectPresentation, True);
		FindOrAddTreeBranch(MetadataObjectRow.Rows, MarkedArrayItem , String(MarkedArrayItem ) + " - " + MetadataObjectPresentation, True);
	EndDo;
	
	MarkedTree.Rows.Sort("Value", True);
	
	For Each MetadataObjectRow In MarkedTree.Rows Do
		// Creating a presentation for rows displaying the metadata object branch
		MetadataObjectRow.Presentation = MetadataObjectRow.Presentation + " (" + MetadataObjectRow.Rows.Count() + ")";
	EndDo;
	
	MarkedForDeletionLevelCount = MarkedTree.Rows.Count();
	
	ValueToFormAttribute(MarkedTree, "MarkedForDeletionList");
	
EndProcedure

// The recursive function that selects/clears check marks for
// dependent parent and child items
&AtClient
Procedure SetMarkInList(Data, Mark, CheckParent)
	
	// Marking child items
	RowItems = Data.GetItems();
	
	For Each Item In RowItems Do
		Item.Check = Mark;
		SetMarkInList(Item, Mark, False);
	EndDo;
	
	// Check for the parent item
	Parent = Data.GetParent();
	
	If CheckParent And Parent <> Undefined Then 
		CheckParent(Parent);
	EndIf;	
	
EndProcedure

&AtClient
Procedure CheckParent(Parent)
	
	ParentMark = True;
		RowItems = Parent.GetItems();
		For Each Item In RowItems Do
			If Not Item.Check Then
				ParentMark = False;
				Break;
			EndIf;
		EndDo;
	Parent.Check = ParentMark;
	
EndProcedure

// Tries to delete marked objects
// Objects that was not deleted are shown in the separate table
//
&AtServer
Function DeleteSelectedAtServer(DeletedObjectTypes)
	
	DeletionParameters = New Structure("MarkedForDeletionList, DeletionMode, DeletedObjectTypes, ", 
		MarkedForDeletionList, DeletionMode, DeletedObjectTypes);
											
	StorageAddress = PutToTempStorage(Undefined, UUID);
	DataProcessors.MarkedObjectDeletion.DeleteMarkedObjects(DeletionParameters, StorageAddress);
	Result = New Structure("JobCompleted", True);		
	
	If Result.JobCompleted Then
		Result = FillResults(StorageAddress, Result);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function FillResults(StorageAddress, Result)
	
	DeletionResult = GetFromTempStorage(StorageAddress);
	If Not DeletionResult.State Then 
		Result.Insert("DeletionResult", DeletionResult);
		Result.Insert("ErrorMessage", DeletionResult.Value);
		Return Result;
	EndIf;
	
	Tree = FillRemainingObjectTree(DeletionResult);
	ValueToFormAttribute(Tree, "RemainingObjectTree");
	
	ToDeleteCount 			= DeletionResult.ToDeleteCount;
	NotDeletedObjectCount 	= DeletionResult.NotDeletedObjectCount;
	FillResultString(ToDeleteCount);
	
	If TypeOf(DeletionResult.Value) = Type("Structure") Then
		DeletionResult.Delete("Value");
	EndIf;	
	
	Result.Insert("DeletionResult", DeletionResult);
	Result.Insert("ErrorMessage", "");
Return Result;
	
EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If Items.FormPages.CurrentPage = Items.LongAction Then
			If LongActions.JobCompleted(JobID) Then
				Result = FillResults(StorageAddress, New Structure);
				DeletedObjectTypes = Undefined;
				RefreshContents(Result.DeletionResult, Result.DeletionResult.Value, Result.DeletionResult.DeletedObjectTypes);
			Else
				LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
				AttachIdleHandler(
					"Attachable_CheckJobExecution", 
					IdleHandlerParameters.CurrentInterval, 
					True);
			EndIf;
		EndIf;
	Except
		Raise;
	EndTry;

EndProcedure	

&AtServer
Function FillRemainingObjectTree(Result)
	
	Found = Result.Value.Found;
	NotDeleted = Result.Value.NotDeleted;
	
	NotDeletedObjectCount = NotDeleted.Count();
	
	// Creating a table of remaining (not deleted) objects
	RemainingObjectTree.GetItems().Clear();
	
	Tree = FormAttributeToValue("RemainingObjectTree");
	
	For Each FoundItem In Found Do
		NotDeleted = FoundItem[0];
		Referencing = FoundItem[1];
		ReferencingObjectMetadata = FoundItem[2].Presentation();
		NotDeletedObjectMetadataValue = NotDeleted.Metadata().FullName();
		NotDeletedObjectMetadataPresentation = NotDeleted.Metadata().Presentation();
		// Metadata branch
		MetadataObjectRow = FindOrAddTreeBranchWithPicture(Tree.Rows, NotDeletedObjectMetadataValue, NotDeletedObjectMetadataPresentation, 0);
		// Branch of the not deleted object
		NotDeletedObjectRefRow = FindOrAddTreeBranchWithPicture(MetadataObjectRow.Rows, NotDeleted, String(NotDeleted), 2);
		// Branch of the not deleted object reference 
		FindOrAddTreeBranchWithPicture(NotDeletedObjectRefRow.Rows, Referencing, String(Referencing) + " - " + ReferencingObjectMetadata, 1);
	EndDo;
	
	Tree.Rows.Sort("Value", True);
	
	Return Tree;

EndFunction

&AtServer
Procedure FillResultString(ToDeleteCount)
	
	DeletedObjects = ToDeleteCount - NotDeletedObjectCount;
	
	If DeletedObjects = 0 Then
		ResultString = NStr("en='No objects were deleted because references to them were found in the infobase.'");
	Else
		ResultString = 
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Deletion of marked objects completed."
" %1 object(s) were deleted.'"),
							String(DeletedObjects));
	EndIf;
	
	If NotDeletedObjectCount > 0 Then
		ResultString = ResultString + Chars.LF +
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 object(s) were not deleted to keep the infobase integrity because references to them were found."
"Click OK to view the list of objects that were not deleted.'"),
				String(NotDeletedObjectCount));
	EndIf;

EndProcedure
 