

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Var FirstPartOfName, SecondPartOfName;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	0 AS Selected,
	|	AdditionalDataAndAttributesSettings.Ref AS Set,
	|	AdditionalDataAndAttributesSettings.Description
	|FROM
	|	Catalog.AdditionalDataAndAttributesSettings AS AdditionalDataAndAttributesSettings
	|
	|ORDER BY
	|	Ref HIERARCHY
	|AUTOORDER";
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	ArrayOfRowsBeingDeleted = New Array;
	
	For Each TreeRow In Tree.Rows Do
		Catalogs.AdditionalDataAndAttributesSettings.GetNameParts(TreeRow.Set, FirstPartOfName, SecondPartOfName);
		
		If Parameters.IsAdditionalData
		   And NOT Catalogs.AdditionalDataAndAttributesSettings.UsedAdditionalData(FirstPartOfName, SecondPartOfName) Then
			ArrayOfRowsBeingDeleted.Add(TreeRow);
		ElsIf NOT Parameters.IsAdditionalData
		   And NOT Catalogs.AdditionalDataAndAttributesSettings.UsedAdditionalAttributes(FirstPartOfName, SecondPartOfName) Then
			ArrayOfRowsBeingDeleted.Add(TreeRow);
		EndIf;
	EndDo;
	
	For Each ItemRowToBeDeleted In ArrayOfRowsBeingDeleted Do
		Tree.Rows.Delete(ItemRowToBeDeleted);
	EndDo;
	
	SelectedSets = Parameters.SelectedSets;
	For Each Set In SelectedSets Do
		Str = Tree.Rows.Find(Set.Value, "Set", True);
		If Str <> Undefined Then
			Str.Selected = True;
		EndIf;
	EndDo;
	
	For Each Str In Tree.Rows Do
		CheckStringFlag(Str);
	EndDo;
	
	ValueToFormAttribute(Tree, "SetTree");
	
	WasPressedClosingKey = False;
	
EndProcedure

&AtClient
Function CheckFormCanBeClosed()
	
	If Modified And Not WasPressedClosingKey Then
		If DoQueryBox(NStr("en = 'Discard changes?'"), QuestionDialogMode.YesNo) = DialogReturnCode.No Then
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

&AtClient
Procedure SelectedOnChange(Item)
	
	curData = Items.SetTree.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	If curData.Selected = 2 Then
		curData.Selected = 0;
	EndIf;
	
	Rows = curData.GetItems();
	SetFlagForSubordinateRows(Rows, curData.Selected);
	
	curItem = curData.GetParent();
	While curItem <> Undefined Do
		
		Is0 = False;
		Is1 = False;
		Is2 = False;
		
		For Each Str In curItem.GetItems() Do
			Is0 = Is0 OR (Str.Selected = 0);
			Is1 = Is1 OR (Str.Selected = 1);
			Is2 = Is2 OR (Str.Selected = 2);
		EndDo;
		
		If Not Is1 And Not Is2 Then
			curItem.Selected = 0;
		ElsIf Not Is2 And Not Is0 Then
			curItem.Selected = 1;
		Else
			curItem.Selected = 2;
		EndIf;
		
		curItem = curItem.GetParent();
	EndDo;
	
EndProcedure

&AtClient
Procedure CancelExecute()
	
	WasPressedClosingKey = False;
	If CheckFormCanBeClosed() Then
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishExecute()
	
	WasPressedClosingKey = True;
	
	SelectedSets = New ValueList;
	FillSelectedSets(SelectedSets, SetTree.GetItems());
	
	If CheckFormCanBeClosed() Then
		Close(SelectedSets);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtClient
Procedure FillSelectedSets(SelectedSets, Rows)
	
	For Each Str In Rows Do
		subordRows = Str.GetItems();
		If subordRows.Count() <> 0 Then
			FillSelectedSets(SelectedSets, subordRows);
		ElsIf Str.Selected Then
			SelectedSets.Add(Str.Set, Str.Description);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckStringFlag(TreeRow)
	
	If TreeRow.Rows.Count() = 0 Then
		Return;
	EndIf;
	
	Is0 = False;
	Is1 = False;
	Is2 = False;
	
	For Each Str In TreeRow.Rows Do
		CheckStringFlag(Str);
		Is0 = Is0 OR (Str.Selected = 0);
		Is1 = Is1 OR (Str.Selected = 1);
		Is2 = Is2 OR (Str.Selected = 2);
	EndDo;
	
	If Not Is1 And Not Is2 Then
		TreeRow.Selected = 0;
	ElsIf Not Is2 And Not Is0 Then
		TreeRow.Selected = 1;
	Else
		TreeRow.Selected = 2;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetFlagForSubordinateRows(Rows, Flag)
	
	For Each Str In Rows Do
		Str.Selected = Flag;
		SetFlagForSubordinateRows(Str.GetItems(), Flag)
	EndDo;
	
EndProcedure
