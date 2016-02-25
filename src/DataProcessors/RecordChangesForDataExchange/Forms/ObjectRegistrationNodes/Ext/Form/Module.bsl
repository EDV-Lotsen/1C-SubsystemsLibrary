 
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
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSLSupportFlags();
	ThisObject(CurrentObject);
	
	RegistrationObject = Parameters.RegistrationObject;
	Details            = "";
	
	If TypeOf(RegistrationObject) = Type("Structure") Then
		RegistrationTable = Parameters.RegistrationTable;
		ObjectString = RegistrationTable;
		For Each KeyValue In RegistrationObject Do
			Details = Details + "," + KeyValue.Value;
		EndDo;
		Details = " (" + Mid(Details,2) + ")";
	Else		
		RegistrationTable = "";
		ObjectString = RegistrationObject;
	EndIf;
	Title = "Registration " + CurrentObject.RefPresentation(ObjectString) + Details;
	
	ReadExchangeNodes();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	ExpandAllNodes();
EndProcedure

#EndRegion

#Region ExchangeNodeTreeFormTableItemEventHandlers

&AtClient
Procedure ExchangeNodeTreeChoice(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	If Field = Items.ExchangeNodeTreeDescription Or Field = Items.ExchangeNodeTreeCode Then
		OpenOtherObjectEditForm();
		Return;
	ElsIf Field <> Items.ExchangeNodeTreeMessageNumber Then
		Return;
	EndIf;
	
	CurrentData = Items.ExchangeNodeTree.CurrentData;
	Notification = New NotifyDescription("ExchangeNodeTreeChoiceCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Node", CurrentData.Ref);
	
	ToolTip = NStr("en = 'Number of the last sent message'"); 
	ShowInputNumber(Notification, CurrentData.MessageNo, ToolTip);
EndProcedure

&AtClient
Procedure ExchangeNodeTreeMarkOnChange(Item)
	ChangeMark(Items.ExchangeNodeTree.CurrentRow);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RereadNodeTree(Command)
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes();
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenEditNodeForm(Command)
	OpenOtherObjectEditForm();
EndProcedure

&AtClient
Procedure MarkAllNodes(Command)
	For Each PlanRow In ExchangeNodeTree.GetItems() Do
		PlanRow.Check = True;
		ChangeMark(PlanRow.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure ClearMarkForAllNodes(Command)
	For Each PlanRow In ExchangeNodeTree.GetItems() Do
		PlanRow.Check = False;
		ChangeMark(PlanRow.GetID())
	EndDo;
EndProcedure

&AtClient
Procedure InvertMarkForAllNodes(Command)
	For Each PlanRow In ExchangeNodeTree.GetItems() Do
		For Each NodeRow In PlanRow.GetItems() Do
			NodeRow.Check = Not NodeRow.Check;
			ChangeMark(NodeRow.GetID())
		EndDo;
	EndDo;
EndProcedure

&AtClient
Procedure EditRegistration(Command)
	
	QuestionTitle = NStr("en = 'Confirmation'");
	Text = NStr("en = 'Edit registration of %1 changes for nodes?'");
	
	Text = StrReplace(Text, "%1", RegistrationObject);
	
	Notification = New NotifyDescription("EditRegistrationCompletion", ThisObject);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

&AtClient
Procedure EditRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Count = NodeRegistrationEdit(ExchangeNodeTree);
	If Count > 0 Then
		Text = NStr("en = 'Registration of %1 changes was modified for %2 nodes'");
		NotificationTitle = NStr("en = 'Change registration:'");
		
		Text = StrReplace(Text, "%1", RegistrationObject);
		Text = StrReplace(Text, "%2", Count);
		
		ShowUserNotification(NotificationTitle,
			GetURL(RegistrationObject),
			Text,
			Items.HiddenPictureInformation32.Picture);
		
		If Parameters.NotifyAboutChanges Then
			Notify("EditObjectDataExchangeRegistration",
				New Structure("RegistrationObject, RegistrationTable", RegistrationObject, RegistrationTable),
				ThisObject);
		EndIf;
	EndIf;
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
EndProcedure

&AtClient
Procedure OpenSettingsForm(Command)
	OpenDataProcessorSettingsForm();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();


	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodeTreeMessageNumber.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodeTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodeTree.Check");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
  Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
  Item.Appearance.SetParameterValue("Text", NStr("en = 'Not exported'"));


	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodeTreeCode.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodeTreeAutoRecord.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ExchangeNodeTreeMessageNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExchangeNodeTree.Ref");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Visibility", False);
	Item.Appearance.SetParameterValue("Show", False);

EndProcedure

&AtClient
Procedure ExchangeNodeTreeChoiceCompletion(Val Number, Val AdditionalParameters) Export
	If Number = Undefined Then 
		// Canceling input
		Return;
	EndIf;
	
	EditMessageNumberAtServer(AdditionalParameters.Node, Number, RegistrationObject, RegistrationTable);
	
	CurrentNode = CurrentSelectedNode();
	ReadExchangeNodes(True);
	ExpandAllNodes(CurrentNode);
	
	If Parameters.NotifyAboutChanges Then
		Notify("EditObjectDataExchangeRegistration",
			New Structure("RegistrationObject, RegistrationTable", RegistrationObject, RegistrationTable),
			ThisObject);
	EndIf;
EndProcedure

&AtClient
Function CurrentSelectedNode()
	CurrentData = Items.ExchangeNodeTree.CurrentData;
	If CurrentData = Undefined Then
		Return Undefined;
	EndIf;
	Return New Structure("Description, Ref", CurrentData.Description, CurrentData.Ref);
EndFunction

&AtClient
Procedure OpenDataProcessorSettingsForm()
	CurFormName = GetFormName() + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure OpenOtherObjectEditForm()
	CurFormName = GetFormName() + "Form.Form";
	Data = Items.ExchangeNodeTree.CurrentData;
	If Data <> Undefined And Data.Ref <> Undefined Then
		CurParameters = New Structure("ExchangeNode, CommandID, TargetObjects", Data.Ref);
		OpenForm(CurFormName, CurParameters, ThisObject);
	EndIf;
EndProcedure

&AtClient
Procedure ExpandAllNodes(FocusNode = Undefined)
	FoundNode = Undefined;
	
	For Each Row In ExchangeNodeTree.GetItems() Do
		ID = Row.GetID();
		Items.ExchangeNodeTree.Expand(ID, True);
		
		If FocusNode <> Undefined And FoundNode = Undefined Then
			If Row.Description = FocusNode.Description And Row.Ref = FocusNode.Ref Then
				FoundNode = ID;
			Else
				For Each Substring In Row.GetItems() Do
					If Substring.Description = FocusNode.Description And Substring.Ref = FocusNode.Ref Then
						FoundNode = Substring.GetID();
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
	EndDo;
	
	If FocusNode <> Undefined And FoundNode <> Undefined Then
		Items.ExchangeNodeTree.CurrentRow = FoundNode;
	EndIf;
	
EndProcedure

&AtServer
Function NodeRegistrationEdit(Val Data)
	CurrentObject = ThisObject();
	NodeCount = 0;
	For Each Row In Data.GetItems() Do
		If Row.Ref <> Undefined Then
			AlreadyRegistered = CurrentObject.ObjectRegisteredForNode(Row.Ref, RegistrationObject, RegistrationTable);
			If Row.Check = 0 And AlreadyRegistered Then
				Result = CurrentObject.EditRegistrationAtServer(False, True, Row.Ref, RegistrationObject, RegistrationTable);
				NodeCount = NodeCount + Result.Done;
			ElsIf Row.Check = 1 And (Not AlreadyRegistered) Then
				Result = CurrentObject.EditRegistrationAtServer(True, True, Row.Ref, RegistrationObject, RegistrationTable);
				NodeCount = NodeCount + Result.Done;
			EndIf;
		EndIf;
		NodeCount = NodeCount + NodeRegistrationEdit(Row);
	EndDo;
	Return NodeCount;
EndFunction

&AtServer
Function EditMessageNumberAtServer(Node, MessageNo, Data, TableName = Undefined)
	Return ThisObject().EditRegistrationAtServer(MessageNo, True, Node, Data, TableName);
EndFunction

&AtServer
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
Procedure ChangeMark(Row)
	DataItem = ExchangeNodeTree.FindByID(Row);
	ThisObject().ChangeMark(DataItem);
EndProcedure

&AtServer
Procedure ReadExchangeNodes(OnlyUpdate = False)
	CurrentObject = ThisObject();
	Tree = CurrentObject.GenerateNodeTree(RegistrationObject, RegistrationTable);
	
	If OnlyUpdate Then
		// Updating  fields using the current tree values
		For Each PlanRow In ExchangeNodeTree.GetItems() Do
			For Each NodeRow In PlanRow.GetItems() Do
				TreeRow = Tree.Rows.Find(NodeRow.Ref, "Ref", True);
				If TreeRow <> Undefined Then
					FillPropertyValues(NodeRow, TreeRow, "Check, SourceCheck, MessageNumber, NotExported");
				EndIf;
			EndDo;
		EndDo;
	Else
		// Assigning a new value to the ExchangeNodeTree form attribute
		ValueToFormAttribute(Tree, "ExchangeNodeTree");
	EndIf;
	
	For Each PlanRow In ExchangeNodeTree.GetItems() Do
		For Each NodeRow In PlanRow.GetItems() Do
			CurrentObject.ChangeMark(NodeRow);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion
