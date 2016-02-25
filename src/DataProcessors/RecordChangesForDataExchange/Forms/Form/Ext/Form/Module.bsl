// This form is used to edit exchange object registration changes for a specified node.
// You can use the following parameters in the OnCreateAtServer handler:
// 
// ExchangeNode                 - ExchangePlanRef - exchange node reference.
//                                The ExchangeNode parameter must be set.
// SelectExchangeNodeProhibited - Boolean - flag that shows whether a user can change the specified node. 
// NamesOfMetadataToHide        - ValueList - contains metadata names to exclude from a registration tree.
//
// If this form is called from the additional reports and data processors subsystem, the following additional 
// parameters are available:
//
// AdditionalDataProcessorRef - Arbitrary - reference to the item of the additional reports and data processors 
//                              catalog that calls the form.
//                              If this parameter is specified, the TargetObjects parameter must be specified too. 
// TargetObjects             - Array - array of objects to process. 
//                              The first array element is used in the OnCreateAtServer procedure.
//                              If you use this parameter, the CommandID parameter must be set too.
//

&AtClient
Var MetadataCurrentRow;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	VerifyAccessRights("Administration", Metadata);
	
  // Skipping the initialization to guarantee that 
  // the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	CheckPlatformVersionAndCompatibilityMode();
	
	RegistrationTableParameter  = Undefined;
	RegistrationObjectParameter = Undefined;
	
	OpenWithNodeParameter = False;
	CurrentObject = ThisObject();
	
	// Analyzing form parameters and setting options
	If Parameters.AdditionalDataProcessorRef = Undefined Then
		// Starting the data processor in standalone mode, with the ExchangeNodeRef parameter specified
		ExchangeNodeRef = Parameters.ExchangeNode;
		Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);
		OpenWithNodeParameter = True;
		
	Else
		// This data processor is called from the additional reports and data processors subsystem
		If TypeOf(Parameters.TargetObjects) = Type("Array") And Parameters.TargetObjects.Count() > 0 Then
			
			// The form is opened with the specified object
			TargetObject = Parameters.TargetObjects[0];
			Type = TypeOf(TargetObject);
			
			If ExchangePlans.AllRefsType().ContainsType(Type) Then
				ExchangeNodeRef = TargetObject;
				OpenWithNodeParameter = True;
			Else
				// Filling internal attributes
				Details = CurrentObject.MetadataCharacteristics(TargetObject.Metadata());
				If Details.IsReference Then
					RegistrationObjectParameter = TargetObject;
					
				ElsIf Details.IsSet Then
					// Filling the structure and table name
					RegistrationTableParameter = Details.TableName;
					RegistrationObjectParameter  = New Structure;
					For Each Dimension In CurrentObject.RecordSetDimensions(RegistrationTableParameter) Do
						CurName = Dimension.Name;
						RegistrationObjectParameter.Insert(CurName, TargetObject.Filter[CurName].Value);
					EndDo;
					
				EndIf;
			EndIf;
			
		Else
			Raise StrReplace(
				NStr("en = 'Invalid target object parameters for the %1 command'"),
				"%1", Parameters.CommandID);
		EndIf;
		
	EndIf;
	
	// Initializing object settings
	CurrentObject.ReadSettings();
	CurrentObject.ReadSLSupportFlags();
	ThisObject(CurrentObject);
	
	// Initializing other parameters only if this form will be opened
	If RegistrationObjectParameter <> Undefined Then
		Return;
	EndIf;
	
	// Filling the list of prohibited metadata objects based on form parameters
	Parameters.Property("NamesOfMetadataToHide", NamesOfMetadataToHide);
	
	MetadataCurrentRow = Undefined;
	Items.ObjectListVariants.CurrentPage = Items.EmptyPage;
	Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);
	
	If Not ControlSettings() And OpenWithNodeParameter Then
		Raise StrReplace(
			NStr("en = 'Cannot edit object registration for the %1 node.'"),
			"%1", ExchangeNodeRef);
	EndIf;
		
EndProcedure

&AtClient
Procedure OnClose()
	// Autosaving settings
	SavedInSettingsDataModified = True;
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	// Analyzing the selected value, it must be a structure
	If TypeOf(SelectedValue) <> Type("Structure") 
		Or (Not SelectedValue.Property("ChoiceAction"))
		Or (Not SelectedValue.Property("ChoiceData"))
		Or TypeOf(SelectedValue.ChoiceAction) <> Type("Boolean")
		Or TypeOf(SelectedValue.ChoiceData) <> Type("String")
	Then
		Error = NStr("en = 'Unexpected result of selection from a query console'");
	Else
		Error = RefControlForQuerySelection(SelectedValue.ChoiceData);
	EndIf;
	
	If Error <> "" Then 
		ShowMessageBox(,Error);
		Return;
	EndIf;
		
	If SelectedValue.ChoiceAction Then
		Text = NStr("en = 'Do you want to register the query result for the %1 node?'"); 
	Else
		Text = NStr("en = 'Do you want to cancel registration of the query result 
                     |for the %1 node?'");
	EndIf;
	Text = StrReplace(Text, "%1", String(ExchangeNodeRef));
					 
	QuestionTitle = NStr("en = 'Confirmation'");
	
	Notification = New NotifyDescription("ChoiceProcessingCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("SelectedValue", SelectedValue);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EditObjectDataExchangeRegistration" Then
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
		
	ElsIf EventName = "ExchangeNodeDataChange" And ExchangeNodeRef = Parameter Then
		SetMessageNumberTitle();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	// Autosaving settings
	CurrentObject = ThisObject();
	CurrentObject.SaveSettings();
	ThisObject(CurrentObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If RegistrationObjectParameter <> Undefined Then
		// Another form will be used
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.ExchangeNode) Then
		ExchangeNodeRef = Parameters.ExchangeNode;
	Else
		ExchangeNodeRef = Settings["ExchangeNodeRef"];
		// If a restored exchange node is deleted, clearing the ExchangeNodeRef value
		If ExchangeNodeRef <> Undefined 
		    And ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeRef))
		    And IsBlankString(ExchangeNodeRef.DataVersion) 
		Then
			ExchangeNodeRef = Undefined;
		EndIf;
	EndIf;
	
	ControlSettings();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ExchangeNodeRefStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CurFormName = GetFormName() + "Form.ExchangePlanNodeSelection";
	CurParameters = New Structure("Multiselect, InitialSelectionValue", False, ExchangeNodeRef);
	OpenForm(CurFormName, CurParameters, Item);
EndProcedure

&AtClient
Procedure ExchangeNodeRefChoiceProcessing(Item, SelectedValue, StandardProcessing)
	If ExchangeNodeRef <> SelectedValue Then
		ExchangeNodeRef = SelectedValue;
		ExchangeNodeChoiceProcessing();
	EndIf;
EndProcedure

&AtClient
Procedure ExchangeNodeRefOnChange(Item)
	ExchangeNodeChoiceProcessing();
	ExpandMetadataTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ExchangeNodeRefClear(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FilterVariantByMessageNoOnChange(Item)
	SetFilterByMessageNo(ConstantList,  FilterVariantByMessageNo);
	SetFilterByMessageNo(ReferenceList, FilterVariantByMessageNo);
	SetFilterByMessageNo(RecordSetList, FilterVariantByMessageNo);
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ObjectListVariantsOnCurrentPageChange(Item, CurrentPage)
	UpdatePageContent(CurrentPage);
EndProcedure

#EndRegion

#Region MetadataTreeFormTableItemEventHandlers

&AtClient
Procedure MetadataTreeMarkOnChange(Item)
	ChangeMark(Items.MetadataTree.CurrentRow);
EndProcedure

&AtClient
Procedure MetadataTreeOnActivateRow(Item)
	If Items.MetadataTree.CurrentRow <> MetadataCurrentRow Then
		MetadataCurrentRow  = Items.MetadataTree.CurrentRow;
		AttachIdleHandler("SetUpChangeEditing", 0.0000001, True);
	EndIf;
EndProcedure

#EndRegion

#Region ConstantListFormTableItemEventHandlers

&AtClient
Procedure ConstantListChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	Result = AddRegistrationAtServer(True, ExchangeNodeRef, SelectedValue);
	Items.ConstantList.Refresh();
	FillRegistrationCountInTreeRows();
	ReportRegistrationResults(True, Result);
	
	If TypeOf(SelectedValue) = Type("Array") And SelectedValue.Count() > 0 Then
		Item.CurrentRow = SelectedValue[0];
	Else
		Item.CurrentRow = SelectedValue;
	EndIf;
	
EndProcedure

#EndRegion

#Region RefListFormTableItemsEventHandlers

&AtClient
Procedure ReferenceListChoiceProcessing(Item, SelectedValue, StandardProcessing)
	DataChoiceProcessing(Item, SelectedValue);
EndProcedure

#EndRegion

#Region RecordSetListFormTableItemEventHandlers

&AtClient
Procedure RecordSetListSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	
	WriteParameters = RecordSetKeyStructure(Item.CurrentData);
	If WriteParameters <> Undefined Then
		OpenForm(WriteParameters.FormName, New Structure(WriteParameters.Parameter, WriteParameters.Value));
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetListChoiceProcessing(Item, SelectedValue, StandardProcessing)
	DataChoiceProcessing(Item, SelectedValue);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AddSingleObjectRegistration(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	If CurPage = Items.ConstantPage Then
		AddConstantRegistrationInList();
		
	ElsIf CurPage = Items.RefListPage Then
		AddRegistrationInReferenceList();
		
	ElsIf CurPage = Items.RecordSetPage Then
		AddRegistrationInRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteSingleObjectRegistration(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	If CurPage = Items.ConstantPage Then
		DeleteConstantRegistrationInList();
		
	ElsIf CurPage = Items.RefListPage Then
		DeleteRegistrationFromReferenceList();
		
	ElsIf CurPage = Items.RecordSetPage Then
		DeleteRegistrationInRecordSet();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	If CurPage = Items.RefListPage Then
		AddRegistrationInListFilter();
		
	ElsIf CurPage = Items.RecordSetPage Then
		AddRegistrationInRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	If CurPage = Items.RefListPage Then
		DeleteRegistrationInListFilter();
		
	ElsIf CurPage = Items.RecordSetPage Then
		DeleteRegistrationInRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenNodeRegistrationForm(Command)
	
	If SelectExchangeNodeProhibited Then
		Return;
	EndIf;
		
	Data = GetCurrentObjectToEdit();
	If Data <> Undefined Then
		RegistrationTable = ?(TypeOf(Data) = Type("Structure"), RecordSetListTableName, "");
		OpenForm(GetFormName() + "Form.ObjectRegistrationNodes",
			New Structure("RegistrationObject, RegistrationTable, NotifyAboutChanges", 
				Data, RegistrationTable, True
			),
			ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowExportResults(Command)
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	Serialization = New Array;
	
	If CurPage = Items.ConstantPage Then 
		FormItem = Items.ConstantList;
		For Each Row In FormItem.SelectedRows Do
			CurData = FormItem.RowData(Row);
			Serialization.Add(New Structure("TypeFlag, Data", 1, CurData.MetaFullName));
		EndDo;
		
	ElsIf CurPage = Items.RecordSetPage Then
		DimensionList = RecordSetKeyNameArray(RecordSetListTableName);
		FormItem = Items.RecordSetList;
		Prefix = "RecordSetList";
		For Each Item In FormItem.SelectedRows Do
			CurData = New Structure();
			Data = FormItem.RowData(Item);
			For Each Name In DimensionList Do
				CurData.Insert(Name, Data[Prefix + Name]);
			EndDo;
			Serialization.Add(New Structure("TypeFlag, Data", 2, CurData));
		EndDo;
		
	ElsIf CurPage = Items.RefListPage Then
		FormItem = Items.ReferenceList;
		For Each Item In FormItem.SelectedRows Do
			CurData = FormItem.RowData(Item);
			Serialization.Add(New Structure("TypeFlag, Data", 3, CurData.Ref));
		EndDo;
		
	Else
		Return;
		
	EndIf;
	
	If Serialization.Count() > 0 Then
		Text = SerializationText(Serialization);
		TextTitle = NStr("en = 'Export result (in DIB mode)'");
		Text.Show(TextTitle);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditMessageNumbers(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		CurFormName = GetFormName() + "Form.ExchangePlanNodeMessageNumbers";
		CurParameters = New Structure("ExchangeNodeRef", ExchangeNodeRef);
		OpenForm(CurFormName, CurParameters);
	EndIf;
EndProcedure

&AtClient
Procedure AddConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddObjectDeletionRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddObjectDeletionRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationFromReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationPick(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInReferenceList(True);
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure AddAutoObjectRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteAutoObjectRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure AddAllObjectRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteAllObjectRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure AddRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInRecordSet();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateAllData(Command)
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure AddQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		ActionWithQueryResult(True);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		ActionWithQueryResult(False);
	EndIf;
EndProcedure

&AtClient
Procedure OpenSettingsForm(Command)
	OpenDataProcessorSettingsForm();
EndProcedure

&AtClient
Procedure EditObjectMessageNo(Command)
	
	If Items.ObjectListVariants.CurrentPage = Items.ConstantPage Then
		EditConstantMessageNo();
		
	ElsIf Items.ObjectListVariants.CurrentPage = Items.RefListPage Then
		EditRefMessageNo();
		
	ElsIf Items.ObjectListVariants.CurrentPage = Items.RecordSetPage Then
		EditMessageNoSetList()
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RegisterMOIDAndPredefinedItems(Command)
	
	QuestionTitle = NStr("en = 'Confirmation'");
	QuestionText     = StrReplace( 
		NStr("en = 'Do you want to register subordinate
		     |DIB node data for restoring on the %1 node?'"),
		"%1", ExchangeNodeRef
	);
	
	Notification = New NotifyDescription("RegisterMetadataObjectIDCompletion", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReferenceListMessageNo.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReferenceList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Not exported'"));


	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConstantListMessageNo.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ConstantList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Not exported'"));

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecordSetListMessageNo.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RecordSetList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Not exported'"));

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MetadataTreeChangeCountString.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataTree.ChangeCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("TextColor", WebColors.DarkGray);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'No changes'"));

EndProcedure

// Export command handler for the additional reports and data processors subsystem.
//
// Parameters:
//     CommandID      - String - command ID.
//     TargetObjects - Array - references to process. This parameter is not used in this procedure.
//                      A similar parameter should be passed and processed during the form creation.
//     CreatedObjects - Array - return value, an array of references to created objects. 
//                      This parameter is not used in the current data processor.
//
&AtClient
Procedure ExecuteCommand(CommandID, TargetObjects, CreatedObjects) Export
	
	If CommandID = "OpenRegistrationEditingForm" Then
		
		If RegistrationObjectParameter <> Undefined Then
			// Using parameters that are set in the OnCreateAtServer procedure
			
			RegistrationFormParameters = New Structure;
			RegistrationFormParameters.Insert("RegistrationObject", RegistrationObjectParameter);
			RegistrationFormParameters.Insert("RegistrationTable",  RegistrationTableParameter);

			OpenForm(GetFormName() + "Form.ObjectRegistrationNodes", RegistrationFormParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient 
Procedure RegisterMetadataObjectIDCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ReportRegistrationResults(True, RegisterMOIDAndPredefinedItemsAtServer() );
		
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient 
Procedure ChoiceProcessingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return
	EndIf;
	SelectedValue = AdditionalParameters.SelectedValue;
	
	ReportRegistrationResults(SelectedValue.ChoiceAction,
		ChangeQueryResultRegistrationServer(SelectedValue.ChoiceAction, SelectedValue.ChoiceData));
		
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure EditConstantMessageNo()
	CurData = Items.ConstantList.CurrentData;
	If CurData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditConstantMessageNoCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaFullName", CurData.MetaFullName);
	
	MessageNo = CurData.MessageNo;
	ToolTip = NStr("en = 'Number of the last sent message'"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient
Procedure EditConstantMessageNoCompletion(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// Action cannot be completed
		Return;
	EndIf;
	
	ReportRegistrationResults(MessageNo, 
		EditMessageNumberAtServer(ExchangeNodeRef, MessageNo, AdditionalParameters.MetaFullName));
		
	Items.ConstantList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure EditRefMessageNo()
	CurData = Items.ReferenceList.CurrentData;
	If CurData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditRefMessageNoCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Ref", CurData.Ref);
	
	MessageNo = CurData.MessageNo;
	ToolTip = NStr("en = 'Number of the last sent message'"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient
Procedure EditRefMessageNoCompletion(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// Action cannot be completed
		Return;
	EndIf;
	
	ReportRegistrationResults(MessageNo, 
		EditMessageNumberAtServer(ExchangeNodeRef, MessageNo, AdditionalParameters.Ref));
		
	Items.ReferenceList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure EditMessageNoSetList()
	CurData = Items.RecordSetList.CurrentData;
	If CurData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditMessageNoSetListCompletion", ThisObject, New Structure);
	
	RowData = New Structure;
	KeyNames = RecordSetKeyNameArray(RecordSetListTableName);
	For Each Name In KeyNames Do
		RowData.Insert(Name, CurData["RecordSetList" + Name]);
	EndDo;
	
	Notification.AdditionalParameters.Insert("RowData", RowData);
	
	MessageNo = CurData.MessageNo;
	ToolTip = NStr("en = 'Number of the last sent message'"); 
	
	ShowInputNumber(Notification, MessageNo, ToolTip);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient
Procedure EditMessageNoSetListCompletion(Val MessageNo, Val AdditionalParameters) Export
	If MessageNo = Undefined Then
		// Action cannot be completed
		Return;
	EndIf;
	
	ReportRegistrationResults(MessageNo, EditMessageNumberAtServer(
		ExchangeNodeRef, MessageNo, AdditionalParameters.RowData, RecordSetListTableName));
	
	Items.RecordSetList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure SetUpChangeEditing()
	SetUpChangeEditingServer(MetadataCurrentRow);
EndProcedure

&AtClient
Procedure ExpandMetadataTree()
	For Each Row In MetadataTree.GetItems() Do
		Items.MetadataTree.Expand( Row.GetID() );
	EndDo;
EndProcedure

&AtServer
Procedure SetMessageNumberTitle()
	
	Text = NStr("en = 'Number of received message is %1, number of sent message is %2'");
	
	Data = ReadMessageNumbers();
	Text = StrReplace(Text, "%1", Format(Data.SentNo, "NFD=0; NZ="));
	Text = StrReplace(Text, "%2", Format(Data.ReceivedNo, "NFD=0; NZ="));
	
	Items.FormEditMessageNumbers.Title = Text;
EndProcedure	

&AtServer
Procedure ExchangeNodeChoiceProcessing()
	
	// Modifying node numbers in the FormEditMessageNumbers title
	SetMessageNumberTitle();
	
	// Updating metadata tree
	ReadMetadataTree();
	FillRegistrationCountInTreeRows();
	
	// Updating active page
	LastActiveMetadataColumn = Undefined;
	LastActiveMetadataRow  = Undefined;
	Items.ObjectListVariants.CurrentPage = Items.EmptyPage;
	
	// Setting visibility for related buttons
	
	MetaNodeExchangePlan = ExchangeNodeRef.Metadata();
	
	If Object.DIBModeAvailable                     // Current SL version supports MOID
		And (ExchangePlans.MasterNode() = Undefined) // Current infobase is the main node
		And MetaNodeExchangePlan.DistributedInfobase // Current node is a DIB node
	Then
		Items.FormRegisterMOIDAndPredefinedItems.Visible = True;
	Else
		Items.FormRegisterMOIDAndPredefinedItems.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportRegistrationResults(Command, Results)
	
	If TypeOf(Command) = Type("Boolean") THen
		If Command Then
			WarningTitle = NStr("en = 'Registering changes:'");
			WarningText = NStr("en = '%1 changes out of %2 are registered for the %0 node.'");
		Else
			WarningTitle = NStr("en = 'Canceling registration:'");
			WarningText = NStr("en = 'Registration of %1 changes is canceled for the %0 node.'");
		EndIf;
	Else
		WarningTitle = NStr("en = 'Changing message number:'");
		WarningText = NStr("en = 'Message number is changed to %3 for %1 object(s).'");
	EndIf;
	
	WarningText = StrReplace(WarningText, "%0", ExchangeNodeRef);
	WarningText = StrReplace(WarningText, "%1", Format(Results.Done, "NZ="));
	WarningText = StrReplace(WarningText, "%2", Format(Results.Total, "NZ="));
	WarningText = StrReplace(WarningText, "%3", Command);
	
	WarningRequired = Results.Total <> Results.Done;
	If WarningRequired Then
		RefreshDataRepresentation();
		ShowMessageBox(, WarningText, , WarningTitle);
	Else
		ShowUserNotification(WarningTitle,
			GetURL(ExchangeNodeRef),
			WarningText,
			Items.HiddenPictureInformation32.Picture);
	EndIf;
EndProcedure

&AtServer
Function GetQueryResultChoiceForm()
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	ThisObject(CurrentObject);
	
	Checking = CurrentObject.CheckSettingCorrectness();
	ThisObject(CurrentObject);
	
	If Checking.QueryExternalDataProcessorAddressSetting <> Undefined Then
		Return Undefined;
		
	ElsIf IsBlankString(CurrentObject.QueryExternalDataProcessorAddressSetting) Then
		Return Undefined;
		
	ElsIf Lower(Right(TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting), 4)) = ".epf" Then
		Processing = ExternalDataProcessors.Create(CurrentObject.QueryExternalDataProcessorAddressSetting);
		FormID = ".ObjectForm";
		
	Else
		Processing = DataProcessors[CurrentObject.QueryExternalDataProcessorAddressSetting].Create();
		FormID = ".Form";
		
	EndIf;
	
	Return Processing.Metadata().FullName() + FormID;
EndFunction

&AtClient
Procedure AddConstantRegistrationInList()
	CurFormName = GetFormName() + "Form.SelectConstant";
	CurParameters = New Structure("ExchangeNode, MetadataNameArray, PresentationArray, AutoRecordArray", 
		ExchangeNodeRef,
		MetadataNameStructure.Constants,
		MetadataPresentationStructure.Constants,
		MetadataAutoRecordStructure.Constants);
	OpenForm(CurFormName, CurParameters, Items.ConstantList);
EndProcedure

&AtClient
Procedure DeleteConstantRegistrationInList()
	
	Item = Items.ConstantList;
	
	PresentationList = New Array;
	NameList         = New Array;
	For Each Row In Item.SelectedRows Do
		Data = Item.RowData(Row);
		PresentationList.Add(Data.Description);
		NameList.Add(Data.MetaFullName);
	EndDo;
	
	Count = NameList.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		Text = NStr("en = 'Do you want to cancel registration of %2
                     |for the %1 node?'"); 
	Else
		Text = NStr("en = 'Do you want to cancel registration of the selected constants
		                  |for the %1 node?'"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", PresentationList[0]);
	
	QuestionTitle = NStr("en = 'Confirmation'");
	
	Notification = New NotifyDescription("DeleteConstantRegistrationInListCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("NameList", NameList);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient
Procedure DeleteConstantRegistrationInListCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
		
	ReportRegistrationResults(False, 
		DeleteRegistrationAtServer(True, ExchangeNodeRef, AdditionalParameters.NameList));
		
	Items.ConstantList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure AddRegistrationInReferenceList(IsPick = False)
	CurFormName = GetFormName(ReferenceList) + "ChoiceForm";
	CurParameters = New Structure("ChoiceMode, Multiselect, CloseOnChoice, ChoiceFoldersAndItems", 
		True, True, IsPick, FoldersAndItemsUse.FoldersAndItems);
	OpenForm(CurFormName, CurParameters, Items.ReferenceList);
EndProcedure

&AtClient
Procedure AddObjectDeletionRegistrationInReferenceList()
	Ref = ObjectRefToDelete();
	DataChoiceProcessing(Items.ReferenceList, Ref);
EndProcedure

&AtServer
Function ObjectRefToDelete(Val UUID = Undefined)
	Details = ThisObject().MetadataCharacteristics(ReferenceList.MainTable);
	If UUID = Undefined Then
		Return Details.Manager.GetRef();
	EndIf;
	Return Details.Manager.GetRef(UUID);
EndFunction

&AtClient 
Procedure AddRegistrationInListFilter()
	CurFormName = GetFormName() + "Form.FilterObjectSelection";
	CurParameters = New Structure("ChoiceAction, TableName", 
		True,
		DynamicListMainTable(ReferenceList));
	OpenForm(CurFormName, CurParameters, Items.ReferenceList);
EndProcedure

&AtClient 
Procedure DeleteRegistrationInListFilter()
	CurFormName = GetFormName() + "Form.FilterObjectSelection";
	CurParameters = New Structure("ChoiceAction, TableName", 
		False,
		DynamicListMainTable(ReferenceList));
	OpenForm(CurFormName, CurParameters, Items.ReferenceList);
EndProcedure

&AtClient
Procedure DeleteRegistrationFromReferenceList()
	
	Item = Items.ReferenceList;
	
	DeletionList = New Array;
	For Each Row In Item.SelectedRows Do
		Data = Item.RowData(Row);
		DeletionList.Add(Data.Ref);
	EndDo;
	
	Count = DeletionList.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		Text = NStr("en = 'Do you want to cancel registration of %2
		                  |for the %1 node?'"); 
	Else
		Text = NStr("en = 'Do you want to cancel registration of the selected objects
		                  |for the %1 node?'"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", DeletionList[0]);
	
	QuestionTitle = NStr("en = 'Confirmation'");
	
	Notification = New NotifyDescription("DeleteRegistrationFromReferenceListCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("DeletionList", DeletionList);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient 
Procedure DeleteRegistrationFromReferenceListCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ReportRegistrationResults(False,
		DeleteRegistrationAtServer(True, ExchangeNodeRef, AdditionalParameters.DeletionList));
		
	Items.ReferenceList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure AddRegistrationInRecordSetFilter()
	CurFormName = GetFormName() + "Form.FilterObjectSelection";
	CurParameters = New Structure("ChoiceAction, TableName", 
		True,
		RecordSetListTableName);
	OpenForm(CurFormName, CurParameters, Items.RecordSetList);
EndProcedure

&AtClient
Procedure DeleteRegistrationInRecordSet()
	
	DataStructure = "";
	KeyNames = RecordSetKeyNameArray(RecordSetListTableName);
	For Each Name In KeyNames Do
		DataStructure = DataStructure +  "," + Name;
	EndDo;
	DataStructure = Mid(DataStructure, 2);
	
	Data = New Array;
	Item = Items.RecordSetList;
	For Each Row In Item.SelectedRows Do
		CurData = Item.RowData(Row);
		RowData = New Structure;
		For Each Name In KeyNames Do
			RowData.Insert(Name, CurData["RecordSetList" + Name]);
		EndDo;
		Data.Add(RowData);
	EndDo;
	
	If Data.Count() = 0 Then
		Return;
	EndIf;
	
	Selection = New Structure("TableName, ChoiceData, ChoiceAction, FieldsStructure",
		RecordSetListTableName,
		Data,
		False,
		DataStructure);
		
	DataChoiceProcessing(Items.RecordSetList, Selection);
EndProcedure

&AtClient
Procedure DeleteRegistrationInRecordSetFilter()
	CurFormName = GetFormName() + "Form.FilterObjectSelection";
	CurParameters = New Structure("ChoiceAction, TableName", 
		False,
		RecordSetListTableName);
	OpenForm(CurFormName, CurParameters, Items.RecordSetList);
EndProcedure

&AtClient
Procedure AddSelectedObjectRegistration(WithoutAutoRecord = True)
	
	Data = GetSelectedMetadataNames(WithoutAutoRecord);
	Count = Data.MetaNames.Count();
	If Count = 0 Then
		// Getting current row data
		Data = GetCurrentRowMetadataNames(WithoutAutoRecord);
	EndIf;
	
	Text = NStr("en = 'Do you want to register %1 for exporting from the %2 node?
	                  |
	                  |Changing the registration of a large number of objects can take a long time.'");
					 
	Text = StrReplace(Text, "%1", Data.Details);
	Text = StrReplace(Text, "%2", ExchangeNodeRef);
	
	QuestionTitle = NStr("en = 'Confirmation'");
	
	Notification = New NotifyDescription("AddSelectedObjectRegistrationCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("WithoutAutoRecord", WithoutAutoRecord);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient 
Procedure AddSelectedObjectRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Result = AddRegistrationAtServer(AdditionalParameters.WithoutAutoRecord, 
		ExchangeNodeRef, AdditionalParameters.MetaNames);
	
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
	ReportRegistrationResults(True, Result);
EndProcedure

&AtClient
Procedure DeleteSelectedObjectRegistration(WithoutAutoRecord = True)
	
	Data  = GetSelectedMetadataNames(WithoutAutoRecord);
	Count = Data.MetaNames.Count();
	If Count = 0 Then
		Data = GetCurrentRowMetadataNames(WithoutAutoRecord);
	EndIf;
	
	Text = NStr("en = 'Do you want to cancel registration of %1 for exporting from the %2 node?
	                  |
	                  |Changing the registration of a large number of objects can take a long time.'");
	
	QuestionTitle = NStr("en = 'Confirmation'");
	
	Text = StrReplace(Text, "%1", Data.Details);
	Text = StrReplace(Text, "%2", ExchangeNodeRef);
	
	Notification = New NotifyDescription("DeleteSelectedObjectRegistrationCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("WithoutAutoRecord", WithoutAutoRecord);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient
Procedure DeleteSelectedObjectRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ReportRegistrationResults(False,
		DeleteRegistrationAtServer(AdditionalParameters.WithoutAutoRecord, 
			ExchangeNodeRef, AdditionalParameters.MetaNames));
		
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure DataChoiceProcessing(FormTable, SelectedValue)
	
	Ref  = Undefined;
	Type = TypeOf(SelectedValue);
	
	If Type = Type("Structure") Then
		TableName = SelectedValue.TableName;
		Action    = SelectedValue.ChoiceAction;
		Data      = SelectedValue.ChoiceData;
	Else
		TableName = Undefined;
		Action = True;
		If Type = Type("Array") Then
			Data = SelectedValue;
		Else		
			Data = New Array;
			Data.Add(SelectedValue);
		EndIf;
		
		If Data.Count() = 1 Then
			Ref = Data[0];
		EndIf;
	EndIf;
	
	If Action Then
		Result = AddRegistrationAtServer(True, ExchangeNodeRef, Data, TableName);
		
		FormTable.Refresh();
		FillRegistrationCountInTreeRows();
		ReportRegistrationResults(Action, Result);
		
		FormTable.CurrentRow = Ref;
		Return;
	EndIf;
	
	If Ref = Undefined Then
		Text = NStr("en = 'Do you want to cancel registration of the selected objects 
		                  |for the %1 node?'"); 
	Else
		Text = NStr("en = 'Do you want to cancel registration of %2
		                  |for the %1 node?'"); 
	EndIf;
		
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", Ref);
	
	QuestionTitle = NStr("en = 'Confirmation'");
		
	Notification = New NotifyDescription("DataChoiceProcessingCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Action",    Action);
	Notification.AdditionalParameters.Insert("FormTable", FormTable);
	Notification.AdditionalParameters.Insert("Data",      Data);
	Notification.AdditionalParameters.Insert("TableName", TableName);
	Notification.AdditionalParameters.Insert("Ref",       Ref);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient
Procedure DataChoiceProcessingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Result = DeleteRegistrationAtServer(True, ExchangeNodeRef, AdditionalParameters.Data, AdditionalParameters.TableName);
	
	AdditionalParameters.FormTable.Refresh();
	FillRegistrationCountInTreeRows();
	ReportRegistrationResults(AdditionalParameters.Action, Result);
	
	AdditionalParameters.FormTable.CurrentRow = AdditionalParameters.Ref;
EndProcedure

&AtServer
Procedure UpdatePageContent(Page = Undefined)
	CurPage = ?(Page = Undefined, Items.ObjectListVariants.CurrentPage, Page);
	
	If CurPage = Items.RefListPage Then
		Items.ReferenceList.Refresh();
		
	ElsIf CurPage = Items.ConstantPage Then
		Items.ConstantList.Refresh();
		
	ElsIf CurPage = Items.RecordSetPage Then
		Items.RecordSetList.Refresh();
		
	ElsIf CurPage = Items.EmptyPage Then
		Row = Items.MetadataTree.CurrentRow;
		If Row <> Undefined Then
			Data = MetadataTree.FindByID(Row);
			If Data <> Undefined Then
				SetUpEmptyPage(Data.Description, Data.MetaFullName);
			EndIf;
		EndIf;
	EndIf;
EndProcedure	

&AtClient
Function GetCurrentObjectToEdit()
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	
	If CurPage = Items.RefListPage Then
		Data = Items.ReferenceList.CurrentData;
		If Data <> Undefined Then
			Return Data.Ref; 
		EndIf;
		
	ElsIf CurPage = Items.ConstantPage Then
		Data = Items.ConstantList.CurrentData;
		If Data <> Undefined Then
			Return Data.MetaFullName; 
		EndIf;
		
	ElsIf CurPage = Items.RecordSetPage Then
		Data = Items.RecordSetList.CurrentData;
		If Data <> Undefined Then
			Result = New Structure;
			Dimensions = RecordSetKeyNameArray(RecordSetListTableName);
			For Each Name In Dimensions  Do
				Result.Insert(Name, Data["RecordSetList" + Name]);
			EndDo;
		EndIf;
		Return Result;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure OpenDataProcessorSettingsForm()
	CurFormName = GetFormName() + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure ActionWithQueryResult(ActionCommand)
	
	CurFormName = GetQueryResultChoiceForm();
	If CurFormName <> Undefined Then
		// Opening a form
		If ActionCommand Then
			Text = NStr("en = 'Registering query result changes'");
		Else
			Text = NStr("en = 'Canceling query result change registration'");
		EndIf;
		OpenForm(CurFormName, 
			New Structure("Title, ChoiceAction, ChoiceMode, CloseOnChoice, ", 
				Text, ActionCommand, True, False
			), ThisObject);
		Return;
	EndIf;
	
	// If the query execution handler is not specified, prompting the user to specify it
	QuestionText = NStr("en = 'Query execution handler is not specified in the settings.
	                          |Do you want to specify it?'");
	
	QuestionTitle = NStr("en = 'Settings'");

	Notification = New NotifyDescription("ActionWithQueryResultsCompletion", ThisObject);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Calls the ReportRegistrationResults handler.
&AtClient 
Procedure ActionWithQueryResultsCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	OpenDataProcessorSettingsForm();
EndProcedure

&AtServer
Function PutStringInQuotes(Row)
	Return StrReplace(Row, """", """""");
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
Function DynamicListMainTable(FormAttribute)
	Return FormAttribute.MainTable;
EndFunction

&AtServer
Procedure ChangeMark(Row)
	DataItem = MetadataTree.FindByID(Row);
	ThisObject().ChangeMark(DataItem);
EndProcedure

&AtServer
Procedure ReadMetadataTree()
	Data = ThisObject().GenerateMetadataStructure(ExchangeNodeRef);
	
	// Deleting rows that cannot be edited
	MetaTree = Data.Tree;
	For Each ListItem In NamesOfMetadataToHide Do
		DeleteMetadataValueTreeRows(ListItem.Value, MetaTree.Rows);
	EndDo;
	
	ValueToFormAttribute(MetaTree, "MetadataTree");
	MetadataAutoRecordStructure   = Data.AutoRecordStructure;
	MetadataPresentationStructure = Data.PresentationStructure;
	MetadataNameStructure         = Data.NameStructure;
EndProcedure

&AtServer 
Procedure DeleteMetadataValueTreeRows(Val MetaFullName, TreeRows)
	If IsBlankString(MetaFullName) Then
		Return;
	EndIf;
	
	// Analyzing the current row set
	Filter = New Structure("MetaFullName", MetaFullName);
	For Each DeletionRow In TreeRows.FindRows(Filter, False) Do
		TreeRows.Delete(DeletionRow);
		// If there are no subordinate rows left, deleting the parent row
		If TreeRows.Count() = 0 Then
			ParentRow = TreeRows.Parent;
			If ParentRow.Parent <> Undefined Then
				ParentRow.Parent.Rows.Delete(ParentRow);
				// There are no subordinate rows
				Return;
			EndIf;
		EndIf;
	EndDo;
	
	// Deleting subordinate row recursively
	For Each TreeRow In TreeRows Do
		DeleteMetadataValueTreeRows(MetaFullName, TreeRow.Rows);
	EndDo;
EndProcedure

&AtServer
Procedure FormatChangeCount(Row)
	Row.ChangeCountString = Format(Row.ChangeCount, "NZ=") + " / " + Format(Row.NotExportedCount, "NZ=");
EndProcedure

&AtServer
Procedure FillRegistrationCountInTreeRows()
	
	Data = ThisObject().GetChangeCount(MetadataNameStructure, ExchangeNodeRef);
	
  // Calculating and filling in tree rows the following values: 
  // number of changes, the number of exported items, and the number of items that are not exported.
	Filter = New Structure("MetaFullName, ExchangeNode", Undefined, ExchangeNodeRef);
	Zeros  = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
	
	For Each Root In MetadataTree.GetItems() Do
		RootSum = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
		
		For Each GroupItems In Root.GetItems() Do
			GroupSum = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
			
			NodeList = GroupItems.GetItems();
			If NodeList.Count() = 0 And MetadataNameStructure.Property(GroupItems.MetaFullName) Then
				// There is no node in the current tree row. 
      // Calculating  the number of changes, the number of exported items, and the number of items that are not exported. 
      // Using autoregistration settings from the metadata name structure.
				For Each MetaName In MetadataNameStructure[GroupItems.MetaFullName] Do
					Filter.MetaFullName = MetaName;
					Found = Data.FindRows(Filter);
					If Found.Count() > 0 Then
						Row = Found[0];
						GroupSum.ChangeCount      = GroupSum.ChangeCount      + Row.ChangeCount;
						GroupSum.ExportedCount    = GroupSum.ExportedCount    + Row.ExportedCount;
						GroupSum.NotExportedCount = GroupSum.NotExportedCount + Row.NotExportedCount;
					EndIf;
				EndDo;
				
			Else
       // Calculating for each node the following values: 
       // number of changes, the number of exported items, and the number of items that are not exported.
				For Each Node In NodeList Do
					Filter.MetaFullName = Node.MetaFullName;
					Found = Data.FindRows(Filter);
					If Found.Count() > 0 Then
						Row = Found[0];
						FillPropertyValues(Node, Row, "ChangeCount, ExportedCount, NotExportedCount");
						GroupSum.ChangeCount      = GroupSum.ChangeCount      + Row.ChangeCount;
						GroupSum.ExportedCount    = GroupSum.ExportedCount    + Row.ExportedCount;
						GroupSum.NotExportedCount = GroupSum.NotExportedCount + Row.NotExportedCount;
					Else
						FillPropertyValues(Node, Zeros);
					EndIf;
					
					FormatChangeCount(Node);
				EndDo;
				
			EndIf;
			FillPropertyValues(GroupItems, GroupSum);
			
			RootSum.ChangeCount      = RootSum.ChangeCount      + GroupItems.ChangeCount;
			RootSum.ExportedCount    = RootSum.ExportedCount    + GroupItems.ExportedCount;
			RootSum.NotExportedCount = RootSum.NotExportedCount + GroupItems.NotExportedCount;
			
			FormatChangeCount(GroupItems);
		EndDo;
		
		FillPropertyValues(Root, RootSum);
		
		FormatChangeCount(Root);
	EndDo;
	
EndProcedure

&AtServer
Function ChangeQueryResultRegistrationServer(Command, Address)
	
	Result = GetFromTempStorage(Address);
	Result = Result[Result.UBound()];
	Data   = Result.Unload().UnloadColumn("Ref");
	
	If Command Then
		Return AddRegistrationAtServer(True, ExchangeNodeRef, Data);
	EndIf;
	
	Return DeleteRegistrationAtServer(True, ExchangeNodeRef, Data);
EndFunction

&AtServer
Function RefControlForQuerySelection(Address)
	
	Result = ?(Address = Undefined, Undefined, GetFromTempStorage(Address));
	If TypeOf(Result) = Type("Array") Then 
		Result = Result[Result.UBound()];	
		If Result.Columns.Find("Ref") = Undefined Then
			Return NStr("en = 'There is no Ref column in the last query result'");
		EndIf;
	Else		
		Return NStr("en = 'Error getting query result data'");
	EndIf;
	
	Return "";
EndFunction

&AtServer
Procedure SetUpChangeEditingServer(CurrentRow)
	
	Data = MetadataTree.FindByID(CurrentRow);
	If Data = Undefined Then
		Return;
	EndIf;
	
	TableName     = Data.MetaFullName;
	Description   = Data.Description;
	CurrentObject = ThisObject();
	
	If IsBlankString(TableName) Then
		Meta = Undefined;
	Else		
		Meta = CurrentObject.MetadataByFullName(TableName);
	EndIf;
	
	If Meta = Undefined Then
		SetUpEmptyPage(Description, TableName);
		NewPage = Items.EmptyPage;
		
	ElsIf Meta = Metadata.Constants Then
		// All constants are included in the list
		SetUpConstantList();
		NewPage = Items.ConstantPage;
		
	ElsIf TypeOf(Meta) = Type("MetadataObjectCollection") Then
		// All catalogs, all documents, and so on
		SetUpEmptyPage(Description, TableName);
		NewPage = Items.EmptyPage;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		// A single constant is passed
		SetUpConstantList(TableName, Description);
		NewPage = Items.ConstantPage;
		
	ElsIf Metadata.Catalogs.Contains(Meta) 
		Or Metadata.Documents.Contains(Meta)
		Or Metadata.ChartsOfCharacteristicTypes.Contains(Meta)
		Or Metadata.ChartsOfAccounts.Contains(Meta)
		Or Metadata.ChartsOfCalculationTypes.Contains(Meta)
		Or Metadata.BusinessProcesses.Contains(Meta)
		Or Metadata.Tasks.Contains(Meta)
	Then
		// An object of reference type is passed
		SetUpRefList(TableName, Description);
		NewPage = Items.RefListPage;
		
	Else
		// Checking whether a record set is passed
		Dimensions = CurrentObject.RecordSetDimensions(TableName);
		If Dimensions <> Undefined Then
			SetUpRecordSet(TableName, Dimensions, Description);
			NewPage = Items.RecordSetPage;
		Else
			SetUpEmptyPage(Description, TableName);
			NewPage = Items.EmptyPage;
		EndIf;
		
	EndIf;
	
	Items.ConstantPage.Visible  = False;
	Items.RefListPage.Visible   = False;
	Items.RecordSetPage.Visible = False;
	Items.EmptyPage.Visible     = False;
	
	Items.ObjectListVariants.CurrentPage = NewPage;
	NewPage.Visible = True;
	
	SetUpGeneralMenuCommandVisibility();
EndProcedure

// Displays changes for an object of reference type (catalog, document, chart of characteristic types, 
// chart of accounts, calculation type, business processes, or tasks).
// 
&AtServer
Procedure SetUpRefList(TableName, Description)
	
	ReferenceList.QueryText = "
		|SELECT
		|	ChangeTable.Ref         AS Ref,
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported,
		|
		|	MainTable.Ref AS ObjectRef
		|FROM
		|	" + TableName + " AS
		|MainTable RIGHT JOIN
		|	" + TableName + ".Changes
		|AS
		|ChangeTable ON MainTable.Ref
		|=
		|ChangeTable.Ref WHERE ChangeTable.Node = &SelectedNode
		|";
		
	ReferenceList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	ReferenceList.MainTable = TableName;
	ReferenceList.DynamicDataRead = True;
	
	// Getting object presentation
	Meta = ThisObject().MetadataByFullName(TableName);
	CurTitle = Meta.ObjectPresentation;
	If IsBlankString(CurTitle) Then
		CurTitle = Description;
	EndIf;
	Items.ReferenceListRefPresentation.Title = CurTitle;
EndProcedure

// Prepares the changes in constants for displaying.
//
&AtServer
Procedure SetUpConstantList(TableName = Undefined, Description = "")
	
	If TableName = Undefined Then
		// All constants
		Names = MetadataNameStructure.Constants;
		Presentations = MetadataPresentationStructure.Constants;
		AutoRecord = MetadataAutoRecordStructure.Constants;
	Else
		Names = New Array;
		Names.Add(TableName);
		Presentations = New Array;
		Presentations.Add(Description);
		Index = MetadataNameStructure.Constants.Find(TableName);
		AutoRecord = New Array;
		AutoRecord.Add(MetadataAutoRecordStructure.Constants[Index]);
	EndIf;
	
	// The limit to the number of tables must be considered
	Text = "";
	For Index = 0 To Names.UBound() Do
		Name = Names[Index];
		Text = Text + ?(Text = "", "SELECT", "UNION ALL SELECT") + "
		|	" + Format(AutoRecord[Index], "NZ=; NG=") + " AS
		|	AutoRecordPictureIndex, 2 AS PictureIndex, """ + PutStringInQuotes(Presentations[Index]) + """ AS
		|	Description, """ + Name + """ AS MetaFullName,
		|
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported
		|FROM
		|	" + Name + ".Changes
		|AS
		|ChangeTable WHERE ChangeTable.Node = &SelectedNode
		|";
	EndDo;
	
	ConstantList.QueryText = "
		|SELECT
		|	AutoRecordPictureIndex, PictureIndex, MetaFullName, NotExported,
		|	Description, MessageNo
		|
		|{SELECT
		|	AutoRecordPictureIndex, PictureIndex, 
		|	Description, MetaFullName, 
		|	MessageNo, NotExported
		|}
		|
		|FROM (" + Text + ")
		|
		|Data
		|	{WHERE Description, MessageNo,
		|NotExported }
		|";
		
	ListItems = ConstantList.Order.Items;
	If ListItems.Count() = 0 Then
		Item = ListItems.Add(Type("DataCompositionOrderItem"));
		Item.Field = New DataCompositionField("Description");
		Item.Use = True;
	EndIf;
	
	ConstantList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	ConstantList.DynamicDataRead = True;
EndProcedure	

// Displays a stub with an empty page.
&AtServer
Procedure SetUpEmptyPage(Description, TableName = Undefined)
	
	If TableName = Undefined Then
		CountsText = "";
	Else
		Tree = FormAttributeToValue("MetadataTree");
		Row = Tree.Rows.Find(TableName, "MetaFullName", True);
		If Row <> Undefined Then
			CountsText = NStr("en = 'Objects registered: %1
			                        |Objects exported: %2
			                        |Objects not exported: %3
			                        |'");
	
			CountsText = StrReplace(CountsText, "%1", Format(Row.ChangeCount, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%2", Format(Row.ExportedCount, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%3", Format(Row.NotExportedCount, "NFD=0; NZ="));
		EndIf;
	EndIf;
	
	Text = NStr("en = '%1.
	                 |
	                 |%2
	                 |To register or to cancel registration of data exchange
	                 |for the %3 node, select object type
	                 |in the left part of the metadata tree and use ""Register"" or ""Cancel registration"" command'");
		
	Text = StrReplace(Text, "%1", Description);
	Text = StrReplace(Text, "%2", CountsText);
	Text = StrReplace(Text, "%3", ExchangeNodeRef);
	Items.EmptyPageDecoration.Title = Text;
EndProcedure

// Displays record set dimension changes.
//
&AtServer
Procedure SetUpRecordSet(TableName, Dimensions, Description)
	
	SelectionText = "";
	Prefix        = "RecordSetList";
	For Each Row In Dimensions Do
		Name = Row.Name;
		SelectionText = SelectionText + ",ChangeTable." + Name + " AS " + Prefix + Name + Chars.LF;
		// Adding the prefix to exclude the MessageNo and NotExported dimensions
		Row.Name = Prefix + Name;
	EndDo;
	
	RecordSetList.QueryText = "
		|SELECT ALLOWED
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported
		|
		|
		|SELECT ALLOWED
		|	ChangeTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangeTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported
		|
		|	" + SelectionText + "
		|FROM
		|	" + TableName + ".Changes
		|AS
		|ChangeTable WHERE ChangeTable.Node = &SelectedNode
		|";
	RecordSetList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	
	// Adding columns to the appropriate group
	ThisObject().AddColumnsToFormTable(
		Items.RecordSetList, 
		"MessageNo, NotExported, Order, Filter, Grouping, StandardPicture, Parameters, ConditionalAppearance",
		Dimensions,
		Items.RecordSetListGroupDimensionGroup);
	RecordSetList.DynamicDataRead = True;
	RecordSetListTableName = TableName;
EndProcedure

// Sets a filter by MessageNo field.
//
&AtServer
Procedure SetFilterByMessageNo(DynamList, Option)
	
	Field = New DataCompositionField("NotExported");
	// Iterating through the filter item list to delete a specific item
	ListItems = DynamList.Filter.Items;
	Index = ListItems.Count();
	While Index > 0 Do
		Index = Index - 1;
		Item = ListItems[Index];
		If Item.LeftValue = Field Then 
			ListItems.Delete(Item);
		EndIf;
	EndDo;
	
	FilterItem = ListItems.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = Field;
	FilterItem.ComparisonType  = DataCompositionComparisonType.Equal;
	FilterItem.Use = False;
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	If Option = 1 Then 		// Exported items
		FilterItem.RightValue = False;
		FilterItem.Use        = True;
		
	ElsIf Option = 2 Then // Items that are not exported
		FilterItem.RightValue = True;
		FilterItem.Use        = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUpGeneralMenuCommandVisibility()
	
	CurPage = Items.ObjectListVariants.CurrentPage;
	
	If CurPage = Items.ConstantPage Then
		Items.FormAddSingleObjectRegistration.Enabled     = True;
		Items.FormAddRegistrationFilter.Enabled           = False;
		Items.FormDeleteSingleObjectRegistration.Enabled  = True;
		Items.FormDeleteRegistrationFilter.Enabled        = False;
		
	ElsIf CurPage = Items.RefListPage Then
		Items.FormAddSingleObjectRegistration.Enabled    = True;
		Items.FormAddRegistrationFilter.Enabled          = True;
		Items.FormDeleteSingleObjectRegistration.Enabled = True;
		Items.FormDeleteRegistrationFilter.Enabled       = True;
		
	ElsIf CurPage = Items.RecordSetPage Then
		Items.FormAddSingleObjectRegistration.Enabled    = True;
		Items.FormAddRegistrationFilter.Enabled          = False;
		Items.FormDeleteSingleObjectRegistration.Enabled = True;
		Items.FormDeleteRegistrationFilter.Enabled       = False;
		
	Else
		Items.FormAddSingleObjectRegistration.Enabled    = False;
		Items.FormAddRegistrationFilter.Enabled          = False;
		Items.FormDeleteSingleObjectRegistration.Enabled = False;
		Items.FormDeleteRegistrationFilter.Enabled       = False;
		
	EndIf;
EndProcedure	

&AtServer
Function RecordSetKeyNameArray(TableName, NamePrefix = "")
	Result = New Array;
	Dimensions = ThisObject().RecordSetDimensions(TableName);
	If Dimensions <> Undefined Then
		For Each Row In Dimensions Do
			Result.Add(NamePrefix + Row.Name);
		EndDo;
	EndIf;
	Return Result;
EndFunction	

&AtServer
Function GetManagerByMetadata(TableName) 
	Details = ThisObject().MetadataCharacteristics(TableName);
	If Details <> Undefined Then
		Return Details.Manager;
	EndIf;
	Return Undefined;
EndFunction

&AtServer
Function SerializationText(Serialization)
	
	Text = New TextDocument;
	
	Write = New XMLWriter;
	For Each Item In Serialization Do
		Write.SetString("UTF-16");	
		Value = Undefined;
		
		If Item.TypeFlag = 1 Then
			// Getting a value manager for a passed metadata type
			Manager = GetManagerByMetadata(Item.Data);
			Value = Manager.CreateValueManager();
			
		ElsIf Item.TypeFlag = 2 Then
			// Getting a record set with a filter
			Manager = GetManagerByMetadata(RecordSetListTableName);
			Value = Manager.CreateRecordSet();
			Filter = Value.Filter;
			For Each NameValue In Item.Data Do
				Filter[NameValue.Key].Set(NameValue.Value);
			EndDo;
			Value.Read();
			
		ElsIf Item.TypeFlag = 3 Then
			// Getting object by reference
			Value = Item.Data.GetObject();
			If Value = Undefined Then
				Value = New ObjectDeletion(Item.Data);
			EndIf;
		EndIf;
		
		WriteXML(Write, Value); 
		Text.AddLine(Write.Close());
	EndDo;
	
	Return Text;
EndFunction	

&AtServer
Function DeleteRegistrationAtServer(WithoutAutoRecord, Node, ToDelete, TableName = Undefined)
	Return ThisObject().EditRegistrationAtServer(False, WithoutAutoRecord, Node, ToDelete, TableName);
EndFunction

&AtServer
Function AddRegistrationAtServer(WithoutAutoRecord, Node, ToAdd, TableName = Undefined)
	Return ThisObject().EditRegistrationAtServer(True, WithoutAutoRecord, Node, ToAdd, TableName);
EndFunction

&AtServer
Function EditMessageNumberAtServer(Node, MessageNo, Data, TableName = Undefined)
	Return ThisObject().EditRegistrationAtServer(MessageNo, True, Node, Data, TableName);
EndFunction

&AtServer
Function GetSelectedMetadataDetails(WithoutAutoRecord, MetaGroupName = Undefined, MetaNodeName = Undefined)
    
	If MetaGroupName = Undefined And MetaNodeName = Undefined Then
		// No item specified
		Text = NStr("en = 'all objects%1 according to the selected hierarchy kind'");
		
	ElsIf MetaGroupName <> Undefined And MetaNodeName = Undefined Then
		// Only a group is specified
		Text = "%2%1";
		
	ElsIf MetaGroupName = Undefined And MetaNodeName <> Undefined Then
		// Only a node is specified
		Text = NStr("en = 'all objects %1 according to the selected hierarchy kind'");
		
	Else
		// A group and a node are specified, using these values to obtain metadata presentation
		Text = NStr("en = 'all objects of %3 type%1'");
		
	EndIf;
	
	If WithoutAutoRecord Then
		FlagText = "";
	Else
		FlagText = NStr("en = ' with autoregistration flag'");
	EndIf;
	
	Presentation = "";
	For Each KeyValue In MetadataPresentationStructure Do
		If KeyValue.Key = MetaGroupName Then
			Index = MetadataNameStructure[MetaGroupName].Find(MetaNodeName);
			Presentation = ?(Index = Undefined, "", KeyValue.Value[Index]);
			Break;
		EndIf;
	EndDo;
	
	Text = StrReplace(Text, "%1", FlagText);
	Text = StrReplace(Text, "%2", Lower(MetaGroupName));
	Text = StrReplace(Text, "%3", Presentation);
	
	Return TrimAll(Text);
EndFunction

&AtServer
Function GetCurrentRowMetadataNames(WithoutAutoRecord) 
	
	Row = MetadataTree.FindByID(Items.MetadataTree.CurrentRow);
	If Row = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure("MetaNames, Details", 
		New Array, GetSelectedMetadataDetails(WithoutAutoRecord));
	MetaName = Row.MetaFullName;
	If IsBlankString(MetaName) Then
		Result.MetaNames.Add(Undefined);	
	Else
		Result.MetaNames.Add(MetaName);	
		
		Parent = Row.GetParent();
		MetaParentName = Parent.MetaFullName;
		If IsBlankString(MetaParentName) Then
			Result.Details = GetSelectedMetadataDetails(WithoutAutoRecord, Row.Description);
		Else
			Result.Details = GetSelectedMetadataDetails(WithoutAutoRecord, MetaParentName, MetaName);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function GetSelectedMetadataNames(WithoutAutoRecord)
	
	Result = New Structure("MetaNames, Details", 
		New Array, GetSelectedMetadataDetails(WithoutAutoRecord));
	
	For Each Root In MetadataTree.GetItems() Do
		
		If Root.Check = 1 Then
			Result.MetaNames.Add(Undefined);
			Return Result;
		EndIf;
		
		PartialItemCount = 0;
		GroupCount       = 0;
		NodeCount        = 0;
		For Each GroupItem In Root.GetItems() Do
			
			If GroupItem.Check = 0 Then
				Continue;
			ElsIf GroupItem.Check = 1 Then
				//	Getting data of the selected group
				GroupCount   = GroupCount + 1;
				GroupDetails = GetSelectedMetadataDetails(WithoutAutoRecord, GroupItem.Description);
				
				If GroupItem.GetItems().Count() = 0 Then
					// Reading marked data from the metadata names structure
					PresentationArray = MetadataPresentationStructure[GroupItem.MetaFullName];
					AutoArray         = MetadataAutoRecordStructure[GroupItem.MetaFullName];
					NameArray         = MetadataNameStructure[GroupItem.MetaFullName];
					For Index = 0 To NameArray.UBound() Do
						If WithoutAutoRecord Or AutoArray[Index] = 2 Then
							Result.MetaNames.Add(NameArray[Index]);
							NodeDetails = GetSelectedMetadataDetails(WithoutAutoRecord, GroupItem.MetaFullName, NameArray[Index]);
						EndIf;
					EndDo;
					
					Continue;
				EndIf;
				
			Else
				PartialItemCount = PartialItemCount + 1;
			EndIf;
			
			For Each Node In GroupItem.GetItems() Do
				If Node.Check = 1 Then
					// Node.AutoRecord = 2 -> allowed
					If WithoutAutoRecord Or Node.AutoRecord = 2 Then
						Result.MetaNames.Add(Node.MetaFullName);
						NodeDetails = GetSelectedMetadataDetails(WithoutAutoRecord, GroupItem.MetaFullName, Node.MetaFullName);
						NodeCount = NodeCount + 1;
					EndIf;
				EndIf
			EndDo;
			
		EndDo;
		
		If GroupCount = 1 And PartialItemCount = 0 Then
			Result.Details = GroupDetails;
		ElsIf GroupCount = 0 And NodeCount = 1 Then
			Result.Details = NodeDetails;
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function ReadMessageNumbers()
	QueryAttributes = "SentNo, ReceivedNo";
	Data = ThisObject().GetExchangeNodeParameters(ExchangeNodeRef, QueryAttributes);
	If Data = Undefined Then
		Return New Structure(QueryAttributes)
	EndIf;
	Return Data;
EndFunction

&AtServer
Procedure ProcessNodeChangeProhibition()
	OperationsAllowed = Not SelectExchangeNodeProhibited;
	
	If OperationsAllowed Then
		Items.ExchangeNodeRef.Visible = True;
		Title = NStr("en = 'Record changes for data exchange'");
	Else
		Items.ExchangeNodeRef.Visible = False;
		Title = StrReplace(NStr("en = 'Registering changes for exchange with the %1 node'"), "%1", String(ExchangeNodeRef));
	EndIf;
	
	Items.FormOpenNodeRegistrationForm.Visible = OperationsAllowed;
	
	Items.ConstantListContextMenuOpenNodeRegistrationForm.Visible  = OperationsAllowed;
	Items.ReferenceListContextMenuOpenNodeRegistrationForm.Visible = OperationsAllowed;
	Items.RecordSetListContextMenuOpenNodeRegistrationForm.Visible = OperationsAllowed;
EndProcedure

&AtServer
Function ControlSettings()
	Result = True;
	
	// Checking the specified exchange node
	CurrentObject = ThisObject();
	If ExchangeNodeRef <> Undefined And ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeRef)) Then
		AllowedExchangeNodes = CurrentObject.GenerateNodeTree();
		PlanName = ExchangeNodeRef.Metadata().Name;
		If AllowedExchangeNodes.Rows.Find(PlanName, "ExchangePlanName", True) = Undefined Then
			// A node with an invalid exchange plan
			ExchangeNodeRef = Undefined;
			Result = False;
		ElsIf ExchangeNodeRef = ExchangePlans[PlanName].ThisNode() Then
			// The current infobase node
			ExchangeNodeRef = Undefined;
			Result = False;
		EndIf;
	EndIf;
	
	If ValueIsFilled(ExchangeNodeRef) Then
		ExchangeNodeChoiceProcessing();
	EndIf;
	ProcessNodeChangeProhibition();
	
	// Setting filter options
	SetFilterByMessageNo(ConstantList,  FilterVariantByMessageNo);
	SetFilterByMessageNo(ReferenceList, FilterVariantByMessageNo);
	SetFilterByMessageNo(RecordSetList, FilterVariantByMessageNo);
	
	Return Result;
EndFunction

&AtServer
Function RecordSetKeyStructure(Val CurrentData)
	
	Details = ThisObject().MetadataCharacteristics(RecordSetListTableName);
	
	If Details = Undefined Then
		// Unknown source
		Return Undefined;
	EndIf;
	
	Result = New Structure("FormName, Parameter, Value");
	
	Dimensions = New Structure;
	KeyNames   = RecordSetKeyNameArray(RecordSetListTableName);
	For Each Name In KeyNames Do
		Dimensions.Insert(Name, CurrentData["RecordSetList" + Name]);
	EndDo;
	
	If Dimensions.Property("Recorder") Then
		MetaRecorder = Metadata.FindByType(TypeOf(Dimensions.Recorder));
		If MetaRecorder = Undefined Then
			Result = Undefined;
		Else
			Result.FormName  = MetaRecorder.FullName() + ".ObjectForm";
			Result.Parameter = "Key";
			Result.Value     = Dimensions.Recorder;
		EndIf;
		
	ElsIf Dimensions.Count() = 0 Then
		// Degenerate record set parameters are passed
		Result.FormName = RecordSetListTableName + ".ListForm";
		
	Else
		Set = Details.Manager.CreateRecordSet();
		For Each KeyValue In Dimensions Do
			Set.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		Set.Read();
		If Set.Count() = 1 Then
			// A single record is to be obtained
			Result.FormName = RecordSetListTableName + ".RecordForm";
			Result.Parameter = "Key";
			
			Key = New Structure;
			For Each SetColumn In Set.Unload().Columns Do
				ColumnName = SetColumn.Name;
				Key.Insert(ColumnName, Set[0][ColumnName]);
			EndDo;
			Result.Value = Details.Manager.CreateRecordKey(Key);
		Else
			// A record set is to be obtained
			Result.FormName = RecordSetListTableName + ".ListForm";
			Result.Parameter = "Filter";
			Result.Value = Dimensions;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function CheckPlatformVersionAndCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		And (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		And Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("en = 'This data processor is intended to
			|run on 1C:Enterprise platform version 8.3 or later (with disabled compatibility mode)'");
		
	EndIf;
	
EndFunction

&AtServer
Function RegisterMOIDAndPredefinedItemsAtServer()
	
	CurrentObject = ThisObject();
	Return CurrentObject.SL_UpdateAndRegisterMainNodeMetadataObjectID(ExchangeNodeRef);
	
EndFunction


#EndRegion
