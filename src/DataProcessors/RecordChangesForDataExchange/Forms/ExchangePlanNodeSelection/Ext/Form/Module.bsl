
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	VerifyAccessRights("Administration", Metadata);
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Multiselect = False;
	ReadExchangeNodeTree();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurParameters = SetFormParameters();
	ExpandNodes(CurParameters.Marked);
	Items.ExchangeNodeTree.CurrentRow = CurParameters.CurrentRow;
EndProcedure

&AtClient
Procedure OnReopen()
	CurParameters = SetFormParameters();
	ExpandNodes(CurParameters.Marked);
	Items.ExchangeNodeTree.CurrentRow = CurParameters.CurrentRow;
EndProcedure

#EndRegion

#Region NodeTreeFormTableItemEventHandlers

&AtClient
Procedure ExchangeNodeTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	PerformNodeChoice(False);
EndProcedure

&AtClient
Procedure ExchangeNodeTreeMarkOnChange(Item)
	ChangeMark(Items.ExchangeNodeTree.CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Selects a node and notifies the caller form that a node is selected.
&AtClient
Procedure SelectNode(Command)
	PerformNodeChoice(Multiselect);
EndProcedure

// Opens the object form that is specified in the configuration for 
// the exchange plan where the node belongs.
&AtClient
Procedure ChangeNode(Command)
	KeyRef = Items.ExchangeNodeTree.CurrentData.Ref;
	If KeyRef <> Undefined Then
		OpenForm(GetFormName(KeyRef) + "ObjectForm", New Structure("Key", KeyRef));
	EndIf;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();


	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodeTreeCode.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodeTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visibility", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure

 
&AtClient
Procedure ExpandNodes(Marked) 
	If Marked <> Undefined Then
		For Each CurID In Marked Do
			CurRow = ExchangeNodeTree.FindByID(CurID);
			CurParent = CurRow.GetParent();
			If CurParent <> Undefined Then
				Items.ExchangeNodeTree.Expand(CurParent.GetID());
			EndIf;
		EndDo;
	EndIf;
EndProcedure	

&AtClient
Procedure PerformNodeChoice(IsMultiselect)
	
	If IsMultiselect Then
		Data = SelectedNodes();
		If Data.Count() > 0 Then
			NotifyChoice(Data);
		EndIf;
		Return;
	EndIf;
	
	Data = Items.ExchangeNodeTree.CurrentData;
	If Data <> Undefined And Data.Ref <> Undefined Then
		NotifyChoice(Data.Ref);
	EndIf;
	
EndProcedure

&AtServer
Function SelectedNodes(NewData = Undefined)
	
	If NewData <> Undefined Then
		// Setup
		Marked = New Array;
		InternalMarkSelectedNodes(ThisObject(), ExchangeNodeTree, NewData, Marked);
		Return Marked;
	EndIf;
	
	// Getting the list of nodes
	Result = New Array;
	For Each CurPlan In ExchangeNodeTree.GetItems() Do
		For Each CurRow In CurPlan.GetItems() Do
			If CurRow.Check And CurRow.Ref <> Undefined Then
				Result.Add(CurRow.Ref);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Procedure InternalMarkSelectedNodes(CurrentObject, Data, NewData, Marked)
	For Each CurRow In Data.GetItems() Do
		If NewData.Find(CurRow.Ref) <> Undefined Then
			CurRow.Check = True;
			CurrentObject.SetMarksForParents(CurRow);
			Marked.Add(CurRow.GetID());
		EndIf;
		InternalMarkSelectedNodes(CurrentObject, CurRow, NewData, Marked);
	EndDo;
EndProcedure

Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction	

&AtServer
Procedure ReadExchangeNodeTree()
	Tree = ThisObject().GenerateNodeTree();
	ValueToFormAttribute(Tree,  "ExchangeNodeTree");
EndProcedure

&AtServer
Procedure ChangeMark(DataRow)
	DataItem = ExchangeNodeTree.FindByID(DataRow);
	ThisObject().ChangeMark(DataItem);
EndProcedure

&AtServer
Function SetFormParameters()
	
	Result = New Structure("CurrentRow, Marked");
	
	// Multiple selection
	Items.ExchangeNodeTreeCheck.Visible = Parameters.Multiselect;
	// Clearing marks if selection type is changed
	If Parameters.Multiselect <> Multiselect Then
		CurrentObject = ThisObject();
		For Each CurRow In ExchangeNodeTree.GetItems() Do
			CurRow.Check = False;
			CurrentObject.SetMarksForChilds(CurRow);
		EndDo;
	EndIf;
	Multiselect = Parameters.Multiselect;
	
	// Positioning the cursor
	If Multiselect And TypeOf(Parameters.InitialSelectionValue) = Type("Array") Then 
		Marked = SelectedNodes(Parameters.InitialSelectionValue);
		Result.Marked = Marked;
		If Marked.Count() > 0 Then
			Result.CurrentRow = Marked[0];
		EndIf;
			
	ElsIf Parameters.InitialSelectionValue <> Undefined Then
		// Single item selection
		Result.CurrentRow = RowIDByNode(ExchangeNodeTree, Parameters.InitialSelectionValue);
		
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function RowIDByNode(Data, Ref)
	For Each CurRow In Data.GetItems() Do
		If CurRow.Ref = Ref Then
			Return CurRow.GetID();
		EndIf;
		Result = RowIDByNode(CurRow, Ref);
		If Result <> Undefined Then 
			Return Result;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

#EndRegion
