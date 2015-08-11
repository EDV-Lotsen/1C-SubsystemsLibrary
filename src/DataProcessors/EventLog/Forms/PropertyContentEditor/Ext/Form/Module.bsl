////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	ListToEdit = Parameters.ListToEdit;
	ParametersToSelect = Parameters.ParametersToSelect;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEditorParameters(ListToEdit, ParametersToSelect);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure CheckOnChange(Item)
	MarkTreeItem(Items.List.CurrentData, Items.List.CurrentData.Check);
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure ChooseFilterContent(Command)
	
	Notify("EventLogFilterItemValueChoice",
	 GetEditedList(),
	 FormOwner);
	Close();
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	SetMarks(True);
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	SetMarks(False);
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtClient
Procedure SetEditorParameters(ListToEdit, ParametersToSelect)
	FilterParameterStructure = GetEventLogFilterValuesByColumn(ParametersToSelect);
	FilterValues = FilterParameterStructure[ParametersToSelect];
	
	If TypeOf(FilterValues) = Type("Array") Then
		ListItems = List.GetItems();
		For Each ArrayItem In FilterValues Do
			NewItem = ListItems.Add();
			NewItem.Check = False;
			NewItem.Value = ArrayItem;
			NewItem.Presentation = ArrayItem;
		EndDo;
	ElsIf TypeOf(FilterValues) = Type("Map") Then
		If ParametersToSelect = "Event" or 
			 ParametersToSelect = "Metadata" Then 
			// getting as a tree
			For Each MapItem In FilterValues Do
				NewItem = GetTreeBranch(MapItem.Value);
				NewItem.Check = False;
				NewItem.Value = MapItem.Key;
			EndDo;
		Else 
			// getting as a flat list
			ListItems = List.GetItems();
			For Each MapItem In FilterValues Do
				NewItem = ListItems.Add();
				NewItem.Check = False;
				NewItem.Value = MapItem.Key;
				If ParametersToSelect = "User" Then
					// In this case the user name serves as a key 
					NewItem.Value = MapItem.Value;
					NewItem.Presentation = MapItem.Value;
					If NewItem.Value = "" Then
						// In case of default user
						NewItem.Value = "";
						NewItem.Presentation = Users.UnspecifiedUserFullName();
					EndIf;
				Else
					NewItem.Presentation = MapItem.Value;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	// Marking tree items that are mapped to ListToEdit items
	MarkFoundItems(List.GetItems(), ListToEdit);
	
	// Finding child items in the list. If there are no such items
	// switching the control in a list mode.
	IsTree = False;
	For Each TreeItem In List.GetItems() Do
		If TreeItem.GetItems().Count() > 0 Then 
			IsTree = True;
			Break;
		EndIf;
	EndDo;
	If Not IsTree Then
		Items.List.Representation = TableRepresentation.List;
	EndIf;
EndProcedure

&AtClient
Function GetEditedList()
	
	ListToEdit = New ValueList;
	
	ListToEdit.Clear();
	HasUnmarked = False;
	GetSubtreeList(ListToEdit, List.GetItems(), HasUnmarked);
	
	Return ListToEdit;
	
EndFunction

&AtClient
Function GetTreeBranch(Presentation)
	PathStrings = SplitStringByDots(Presentation);
	If PathStrings.Count() = 1 Then
		TreeItems = List.GetItems();
		BranchName = PathStrings[0];
	Else
		// Assembling a path to parent branch by path fragments
		ParentPathPresentation = "";
		For Cnt = 0 to PathStrings.Count() - 2 Do
			If Not IsBlankString(ParentPathPresentation) Then
				ParentPathPresentation = ParentPathPresentation + ".";
			EndIf;
			ParentPathPresentation = ParentPathPresentation + PathStrings[Cnt];
		EndDo;
		TreeItems = GetTreeBranch(ParentPathPresentation).GetItems();
		BranchName = PathStrings[PathStrings.Count() - 1];
	EndIf;
	
	For Each TreeItem In TreeItems Do
		If TreeItem.Presentation = BranchName Then
			Return TreeItem;
		EndIf;
	EndDo;
	// Tree item not found, it have to be created 
	TreeItem = TreeItems.Add();
	TreeItem.Presentation = BranchName;
	TreeItem.Check = False;
	Return TreeItem;
EndFunction

// Splits a string into a row array using dot as a separator
&AtClient
Function SplitStringByDots(Val Presentation)
	Fragments = New Array;
	While True Do
		Presentation = TrimAll(Presentation);
		DotPosition = Find(Presentation, ".");
		If DotPosition > 0 Then
			Fragment = TrimAll(Left(Presentation, DotPosition - 1));
			Fragments.Add(Fragment);
			Presentation = Mid(Presentation, DotPosition + 1);
		Else
			Fragments.Add(TrimAll(Presentation));
			Break;
		EndIf;
	EndDo;
	Return Fragments;
EndFunction

&AtServer
Function GetEventLogFilterValuesByColumn(ParametersToSelect)
	Return GetEventLogFilterValues(ParametersToSelect);
EndFunction

&AtClient
Procedure GetSubtreeList(ListToEdit, TreeItems, HasUnmarked)
	For Each TreeItem In TreeItems Do
		If TreeItem.GetItems().Count() <> 0 Then
			GetSubtreeList(ListToEdit, TreeItem.GetItems(), HasUnmarked);
		Else
			If TreeItem.Check Then
				NewListItem = ListToEdit.Add();
				NewListItem.Value = TreeItem.Value;
				NewListItem.Presentation = AssemblePresentation(TreeItem);
			Else
				HasUnmarked = True;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure MarkFoundItems(TreeItems, ListToEdit)
	For Each TreeItem In TreeItems Do
		If TreeItem.GetItems().Count() <> 0 Then 
			MarkFoundItems(TreeItem.GetItems(), ListToEdit);
		Else
			CombinedPresentation = AssemblePresentation(TreeItem);
			For Each ListItem In ListToEdit Do
				If CombinedPresentation = ListItem.Presentation Then
					MarkTreeItem(TreeItem, True);
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure MarkTreeItem(TreeItem, Check, CheckParentState = True)
	TreeItem.Check = Check;
	// Marking all child items of tree 
	For Each TreeChildItem In TreeItem.GetItems() Do
		MarkTreeItem(TreeChildItem, Check, False);
	EndDo;
	// Checking if parent item state should be changed.
	If CheckParentState Then
		CheckBranchMarked(TreeItem.GetParent());
	EndIf;
EndProcedure

&AtClient
Procedure CheckBranchMarked(Branch)
	If Branch = Undefined Then 
		Return;
	EndIf;
	ChildBranches = Branch.GetItems();
	If ChildBranches.Count() = 0 Then
		Return;
	EndIf;
	
	HasTrue = False;
	HasFalse = False;
	For Each ChildBranche In ChildBranches Do
		If ChildBranche .Check Then
			HasTrue = True;
			If HasFalse Then
				Break;
			EndIf;
		Else
			HasFalse = True;
			If HasTrue Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If HasTrue Then
		If HasFalse Then
			// There are marked and unmarked branches. If nesessary, unmarking current item and than checking parent one.
			If Branch.Check Then
				Branch.Check = False;
				CheckBranchMarked(Branch.GetParent());
			EndIf;
		Else
			// All of child branches are marked
			If Not Branch.Check Then
				Branch.Check = True;
				CheckBranchMarked(Branch.GetParent());
			EndIf;
		EndIf;
	Else
		// All of child branches are unmarked
		If Branch.Check Then
			Branch.Check = False;
			CheckBranchMarked(Branch.GetParent());
		EndIf;
	EndIf;
EndProcedure

&AtClient
Function AssemblePresentation(TreeItem)
	If TreeItem = Undefined Then 
		Return "";
	EndIf;
	If TreeItem.GetParent() = Undefined Then
		Return TreeItem.Presentation;
	EndIf;
	Return AssemblePresentation(TreeItem.GetParent()) + "." + TreeItem.Presentation;
EndFunction

&AtClient
Procedure SetMarks(Value)
	For Each TreeItem In List.GetItems() Do
		MarkTreeItem(TreeItem, Value, False);
	EndDo;
EndProcedure
 
