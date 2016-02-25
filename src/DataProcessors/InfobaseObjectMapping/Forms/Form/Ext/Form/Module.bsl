
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	// Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Checking whether the form is opened from 1C:Enterprise script
	If Not Parameters.Property("ExchangeMessageFileName") Then
		Raise NStr("en = 'The data processor cannot be opened manually.'");
	EndIf;
	
	PerformDataMapping = True;
	PerformDataImport  = True;
	
	If Parameters.Property("PerformDataMapping") Then
		PerformDataMapping = Parameters.PerformDataMapping;
	EndIf;
	
	If Parameters.Property("PerformDataImport") Then
		PerformDataImport = Parameters.PerformDataImport;
	EndIf;
	
	// Initializing the data processor with the passed parameters
	FillPropertyValues(Object, Parameters);
	
	// Calling a constructor of the current data processor instance
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.Constructor();
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	// List of filter statuses:
	//
	//     MappingStatus - Number:
	//          0 - mapping based on information register data 
  //         -1 - unmapped source object
  //         +1 - unmapped target object
	//          3 - mapping available but not approved
	//
	//     MappingStatusAdditional - Number:
	//         1 - unmapped objects
	//         0 - mapped objects
	
	MappingStatusFilterOptions = New Structure;
	
	// Filling filter list
	ChoiceList = Items.FilterByMappingStatus.ChoiceList;;
	
	MappingStatusFilterOptions.Insert(ChoiceList.Add(
		"AllObjects", NStr("en='All data'")
	).Value, New FixedStructure);
	
	MappingStatusFilterOptions.Insert(ChoiceList.Add(
		"UnapprovedMappedObjects", NStr("en='Changes'"),
	).Value, New FixedStructure("MappingStatus",  3));
	
	MappingStatusFilterOptions.Insert(ChoiceList.Add(
		"MappedObjects", NStr("en='Mapped data'"),,
	).Value, New FixedStructure("MappingStatusAdditional", 0));
	
	MappingStatusFilterOptions.Insert(ChoiceList.Add(
		"UnmappedObjects", NStr("en='Unmapped data'"),
	).Value, New FixedStructure("MappingStatusAdditional", 1));
	
	MappingStatusFilterOptions.Insert(ChoiceList.Add(
		"UnmappedTargetObjects", NStr("en='Unmapped data of the current Infobase'"),
	).Value, New FixedStructure("MappingStatus",  1));
	
	MappingStatusFilterOptions.Insert(ChoiceList.Add(
		"UnmappedSourceObjects", NStr("en='Unmapped data of the second Infobase'"),
	).Value, New FixedStructure("MappingStatus", -1));
	
	// Default preferences
	FilterByMappingStatus = "UnmappedObjects";
		
	// Setting the form title
	DataPresentation = String(Metadata.FindByType(Type(Object.TargetTypeString)));
	Title = NStr("en = 'Data mapping ""[DataPresentation]""'");
	Title = StrReplace(Title, "[DataPresentation]", DataPresentation);
	
	// Setting the form item visibility according to option values
	Items.LinksGroup.Visible                        = PerformDataMapping;
	Items.ExecuteAutomaticMapping.Visible           = PerformDataMapping;
	Items.MappingDigestInfo.Visible                 = PerformDataMapping;
	Items.MappingTableContextMenuLinksGroup.Visible = PerformDataMapping;
	
	Items.ExecuteDataImport.Visible = PerformDataImport;
	
	CurrentApplicationDescription = DataExchangeCached.ThisNodeDescription(Object.InfobaseNode);
	CurrentApplicationDescription = ?(IsBlankString(CurrentApplicationDescription), NStr("en = 'This application'"), CurrentApplicationDescription);
	
	SecondApplicationDescription = CommonUse.ObjectAttributeValue(Object.InfobaseNode, "Description");
	SecondApplicationDescription = ?(IsBlankString(SecondApplicationDescription), NStr("en = 'Second application'"), SecondApplicationDescription);
	
	Items.CurrentApplicationData.Title = CurrentApplicationDescription;
	Items.SecondApplicationData.Title  = SecondApplicationDescription;
	
	Items.Explanation.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'To map the %1 data 
		|with the %2 data, use the ""Map automatically"" command"".
		|Then you can map unmapped data manually.'"),
		CurrentApplicationDescription, SecondApplicationDescription);
	
	ObjectMappingScenario();
	
	ApplyUnapprovedRecordTable  = False;
	ApplyAutomaticMappingResult = False;
	AutomaticallyMappedObjectTableAddress = "";
	WriteAndClose = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	WarnOnFormClose = True;
	
	// Setting a flag that shows whether the form has been modified
	AttachIdleHandler("SetFormModified", 2);
	
	UpdateMappingTable();
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If WriteAndClose Then
		Return;
	EndIf;
	
	If Object.UnapprovedMappingTable.Count() = 0 Then
		// All data is mapped
		Return;
	EndIf;
		
	If WarnOnFormClose = True Then
		Notification = New NotifyDescription("BeforeCloseCompletion", ThisObject);
		PreviousFlag = Modified;
		Modified = True;
		
		CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
		
		Modified = PreviousFlag;
		Return;
	EndIf;
	
	BeforeCloseContinuation();
EndProcedure

&AtClient
Procedure BeforeCloseCompletion(Val QuestionResult = Undefined, Val AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		// Closing the form and saving data
		BeforeCloseContinuation();
		Close();
		
	ElsIf QuestionResult = DialogReturnCode.No Then
		// Closing the form without saving data
		WarnOnFormClose = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseContinuation()
	WriteAndClose = True;
	WarnOnFormClose = True;
	UpdateMappingTable();
EndProcedure

&AtClient
Procedure OnClose()
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("UniquenessKey",            Parameters.Key);
	NotificationParameters.Insert("DataImportedSuccessfully", Object.DataImportedSuccessfully);
	
	Notify("ClosingObjectMappingForm", NotificationParameters);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectMapping.Form.AutomaticMappingSetup") Then
		
		If TypeOf(SelectedValue) <> Type("ValueList") Then
			Return;
		EndIf;
		
		// Performing automatic object mapping
		FormParameters = New Structure;
		FormParameters.Insert("TargetTableName",           Object.TargetTableName);
		FormParameters.Insert("ExchangeMessageFileName",   Object.ExchangeMessageFileName);
		FormParameters.Insert("SourceTableObjectTypeName", Object.SourceTableObjectTypeName);
		FormParameters.Insert("SourceTypeString",          Object.SourceTypeString);
		FormParameters.Insert("TargetTypeString",          Object.TargetTypeString);
		FormParameters.Insert("TargetTableFields",         Object.TargetTableFields);
		FormParameters.Insert("TargetTableSearchFields",   Object.TargetTableSearchFields);
		FormParameters.Insert("InfobaseNode",              Object.InfobaseNode);
		FormParameters.Insert("TableFieldList",            Object.TableFieldList.Copy());
		FormParameters.Insert("UsedFieldList",             Object.UsedFieldList.Copy());
		FormParameters.Insert("MappingFieldList",          SelectedValue.Copy());
		FormParameters.Insert("MaxCustomFieldCount",       MaxCustomFieldCount());
		FormParameters.Insert("Title",                     Title);
		
		FormParameters.Insert("UnapprovedMappingTableTempStorageAddress", PutUnapprovedMappingTableIntoTempStorage());
		
		// Opening the automatic object mapping form
		OpenForm("DataProcessor.InfobaseObjectMapping.Form.AutomaticMappingResult", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectMapping.Form.AutomaticMappingResult") Then
		
		If TypeOf(SelectedValue) = Type("String")
			And Not IsBlankString(SelectedValue) Then
			
			ApplyAutomaticMappingResult = True;
			AutomaticallyMappedObjectTableAddress = SelectedValue;
			
			UpdateMappingTable();
			
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectMapping.Form.TableFieldSetup") Then
		
		If TypeOf(SelectedValue) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.UsedFieldList = SelectedValue.Copy();
		SetTableFieldVisible("MappingTable"); // Setting visibility and titles of the mapping table fields
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectMapping.Form.MappingFieldTableSetup") Then
		
		If TypeOf(SelectedValue) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.TableFieldList = SelectedValue.Copy();
		
		FillListWithSelectedItems(Object.TableFieldList, Object.UsedFieldList);
		
		// Generating the sorting table
		FillSortTable(Object.UsedFieldList);
		
		// Updating the mapping table
		UpdateMappingTable();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectMapping.Form.SortingSetup") Then
		
		If TypeOf(SelectedValue) <> Type("FormDataCollection") Then
			Return;
		EndIf;
		
		Object.SortTable.Clear();
		
		// Filling the form collection with retrieved settings
		For Each TableRow In SelectedValue Do
			FillPropertyValues(Object.SortTable.Add(), TableRow);
		EndDo;
		
		// Sorting mapping table
		ExecuteTableSorting();
		
		// Updating tabular section filter
		SetTabularSectionFilter();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.InfobaseObjectMapping.Form.MappingChoiceForm") Then
		
		If SelectedValue = Undefined Then
			Return; // Manual mapping is canceled
		EndIf;
		
		BeginningRowID = Items.MappingTable.CurrentRow;
		
		// Server call
		FoundRows = MappingTable.FindRows(New Structure("SerialNumber", SelectedValue));
		If FoundRows.Count() > 0 Then
			EndingRowID = FoundRows[0].GetID();
			// Processing retrieved mapping
			AddUnapprovedMappingAtClient(BeginningRowID, EndingRowID);
		EndIf;
		
		// Switching to the mapping table
		CurrentItem = Items.MappingTable;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FilterByMappingStatusOnChange(Item)
	
	SetTabularSectionFilter();
	
EndProcedure

#EndRegion

#Region MappingTableFormTableItemEventHandlers

&AtClient
Procedure MappingTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	SetMappingInteractively();
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure MappingTableBeforeRowChange(Item, Cancel)
	Cancel = True;
	SetMappingInteractively();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Refresh(Command)
	
	UpdateMappingTable();
	
EndProcedure

&AtClient
Procedure ExecuteAutomaticMapping(Command)
	
	Cancel = False;
	
	// Determining the number of user-defined fields to be displayed
	CheckUserFieldsFilled(Cancel, Object.UsedFieldList.UnloadValues());
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the mapping field list
	FormParameters = New Structure;
	FormParameters.Insert("MappingFieldList", Object.TableFieldList.Copy());
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form.AutomaticMappingSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ExecuteDataImport(Command)
	NString = NStr("en = 'Do you want to import data into the Infobase?'");
	Notification = New NotifyDescription("ExecuteDataImportCompletion1", ThisObject);
	
	ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure ChangeTableFields(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FieldList", Object.UsedFieldList.Copy());
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form.TableFieldSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SetupTableFieldList(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("FieldList", Object.TableFieldList.Copy());
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form.MappingFieldTableSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure Sort(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("SortTable", Object.SortTable);
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form.SortingSetup", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddMapping(Command)
	
	SetMappingInteractively();
	
EndProcedure

&AtClient
Procedure ClearMapping(Command)
	
	SelectedRows = Items.MappingTable.SelectedRows;
	
	ClearMappingAtServer(SelectedRows);
	
	// Updating the tabular section filter
	SetTabularSectionFilter();
	
EndProcedure

&AtClient
Procedure WriteRefresh(Command)
	
	ApplyUnapprovedRecordTable = True;
	
	UpdateMappingTable();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	ApplyUnapprovedRecordTable = True;
	WriteAndClose = True;
	
	UpdateMappingTable();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS (Supplied part)

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsGoNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		
		GoToNumber = 0;
		
	EndIf;
	
	GoToNumberOnChange(IsGoNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsGoNext)
	
	// Executing wizard step change event handlers
	ExecuteGoToEventHandlers(IsGoNext);
	
	// Setting page to be displayed
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage = Items[GoToRowCurrent.MainPageName];
	
	If Not IsBlankString(GoToRowCurrent.DecorationPageName) Then
		
		Items.DataSynchronizationPanel.CurrentPage = Items[GoToRowCurrent.DecorationPageName];
		
	EndIf;
	
	If IsGoNext And GoToRowCurrent.LongAction Then
		
		AttachIdleHandler("ExecuteLongActionHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsGoNext)
	
	// Step change handlers
	If IsGoNext Then
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// OnGoNext handler
			If Not IsBlankString(GoToRow.GoNextHandlerName)
				And Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoNextHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	Else
		
		GoToRows = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			
			GoToRow = GoToRows[0];
			
			// OnGoBack handler
			If Not IsBlankString(GoToRow.GoBackHandlerName)
				And Not GoToRow.LongAction Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRow.GoBackHandlerName);
				
				Cancel = False;
				
				A = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.LongAction And Not IsGoNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandleName](Cancel, SkipPage, IsGoNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel   = False;
		SkipPage = False;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsGoNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteLongActionHandler()
	
	GoToRowsCurrent = GoToTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("en = 'Page to be displayed is not specified.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// LongActionProcessing handler
	If Not IsBlankString(GoToRowCurrent.LongActionHandlerName) Then
		
		ProcedureName = "Attachable_[HandleName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.LongActionHandlerName);
		
		Cancel   = False;
		GoToNext = True;
		
		A = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure GoToTableNewRow(GoToNumber,
									MainPageName,
									NavigationPageName = "",
									DecorationPageName = "",
									OnOpenHandlerName = "",
									GoNextHandlerName = "",
									GoBackHandlerName = "",
									LongAction = False,
									LongActionHandlerName = "")
	NewRow = GoToTable.Add();
	
	NewRow.GoToNumber         = GoToNumber;
	NewRow.MainPageName       = MainPageName;
	NewRow.DecorationPageName = DecorationPageName;
	NewRow.NavigationPageName = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.GoBackHandlerName = GoBackHandlerName;
	NewRow.OnOpenHandlerName = OnOpenHandlerName;
	
	NewRow.LongAction = LongAction;
	NewRow.LongActionHandlerName = LongActionHandlerName;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MappingTableTargetField1.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MappingTable.MappingStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = -1;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'No mapping. Object will be copied.'"));

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MappingTableSourceField1.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MappingTable.MappingStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 1;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("Text", NStr("en = 'No mapping. Object will be copied.'"));

EndProcedure

&AtClient
Procedure ExecuteDataImportCompletion1(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If Object.DataImportedSuccessfully Then
		NString = NStr("en = 'Data is already imported. Do you want to import it again?'");
		Notification = New NotifyDescription("ExecuteDataImportCompletion2", ThisObject);
		
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	ExecuteDataImportCompletion3();
EndProcedure

&AtClient
Procedure ExecuteDataImportCompletion2(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteDataImportCompletion3();
EndProcedure

&AtClient
Procedure ExecuteDataImportCompletion3()
	
	// Displaying current state
	Status(NStr("en = 'Importing data. Please wait...'"));
	
	// Importing data on the server
	Cancel = False;
	ExecuteDataImportAtServer(Cancel);
	
	If Cancel Then
		NString = NStr("en = 'Data import error.
		                     |Do you want to view the event log?'");
		
		Notification = New NotifyDescription("PerformDataLoadingCompletion4", ThisObject);
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		
		Return;
	EndIf;
	
	// Updating mapping table data
	UpdateMappingTable();
EndProcedure

&AtClient
Procedure ExecuteDataImportCompletion4(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
EndProcedure

&AtClient
Procedure GoToNext()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure GoBack()
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtServer
Procedure ClearMappingAtServer(SelectedRows)
	
	For Each RowID In SelectedRows Do
		
		CurrentData = MappingTable.FindByID(RowID);
		
		If CurrentData.MappingStatus = 0 Then // Mapping based on information register data
			
			CancelDataMapping(CurrentData, False);
			
		ElsIf CurrentData.MappingStatus = 3 Then // Unapproved mapping
			
			CancelDataMapping(CurrentData, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CancelDataMapping(CurrentData, IsUnapprovedMapping)
	
	Filter = New Structure;
	Filter.Insert("SourceUUID", CurrentData.TargetUUID);
	Filter.Insert("TargetUUID", CurrentData.SourceUUID);
	Filter.Insert("SourceType", CurrentData.TargetType);
	Filter.Insert("TargetType", CurrentData.SourceType);
	
	If IsUnapprovedMapping Then
		For Each FoundRow In Object.UnapprovedMappingTable.FindRows(Filter) Do
			// Deleting the unapproved mapping item from the unapproved mapping table
			Object.UnapprovedMappingTable.Delete(FoundRow);
		EndDo;
		
	Else
		CancelApprovedMappingAtServer(Filter);
		
	EndIf;
	
	// Adding new source and target rows to the mapping table
	NewSourceRow = MappingTable.Add();
	NewTargetRow = MappingTable.Add();
	
	FillPropertyValues(NewSourceRow, CurrentData, "SourceField1, SourceField2, SourceField3, SourceField4, SourceField5, SourceUUID, SourceType, SourcePictureIndex");
	FillPropertyValues(NewTargetRow, CurrentData, "TargetField1, TargetField2, TargetField3, TargetField4, TargetField5, TargetUUID, TargetType, TargetPictureIndex");
	
	// Setting field values for sorting source rows
	NewSourceRow.OrderField1   = CurrentData.SourceField1;
	NewSourceRow.OrderField2   = CurrentData.SourceField2;
	NewSourceRow.OrderField3   = CurrentData.SourceField3;
	NewSourceRow.OrderField4   = CurrentData.SourceField4;
	NewSourceRow.OrderField5   = CurrentData.SourceField5;
	NewSourceRow.PictureIndex  = CurrentData.SourcePictureIndex;
	
	// Setting field values for sorting target rows
	NewTargetRow.OrderField1  = CurrentData.TargetField1;
	NewTargetRow.OrderField2   = CurrentData.TargetField2;
	NewTargetRow.OrderField3   = CurrentData.TargetField3;
	NewTargetRow.OrderField4   = CurrentData.TargetField4;
	NewTargetRow.OrderField5   = CurrentData.TargetField5;
	NewTargetRow.PictureIndex  = CurrentData.TargetPictureIndex;
	
	NewSourceRow.MappingStatus = -1;
	NewSourceRow.MappingStatusAdditional = 1; // Unmapped objects
	
	NewTargetRow.MappingStatus = 1;
	NewTargetRow.MappingStatusAdditional = 1; // Unmapped objects
	
	// Deleting the current mapping table row
	MappingTable.Delete(CurrentData);
	
	// Updating numbers
	NewSourceRow.SerialNumber = NextNumberByMappingOrder();
	NewTargetRow.SerialNumber = NextNumberByMappingOrder();
EndProcedure

&AtServer
Procedure CancelApprovedMappingAtServer(Filter)
	
	Filter.Insert("InfobaseNode", Object.InfobaseNode);
	
	InformationRegisters.InfobaseObjectMappings.DeleteRecord(Filter);
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Applying unapproved mapping table to the database
	DataProcessorObject.ApplyUnapprovedRecordTable(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	TableToImport = New Array;
	
	DataTableKey = DataExchangeServer.DataTableKey(Object.SourceTypeString, Object.TargetTypeString, Object.IsObjectDeletion);
	
	TableToImport.Add(DataTableKey);
	
	// Importing data from a batch file in the data exchange mode
	DataProcessorObject.ExecuteDataImportForInfobase(Cancel, TableToImport);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	PictureIndex = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectCount, Object.DataImportedSuccessfully);
	
EndProcedure

&AtServer
Function PutUnapprovedMappingTableIntoTempStorage()
	
	Return PutToTempStorage(Object.UnapprovedMappingTable.Unload(), UUID);
	
EndFunction

&AtServer
Function GetMappingChoiceTableTempStorageAddress(FilterParameters)
	
	Columns = "SerialNumber, OrderField1, OrderField2, OrderField3, OrderField4, OrderField5, PictureIndex";
	
	Return PutToTempStorage(MappingTable.Unload(FilterParameters, Columns));
	
EndFunction

&AtClient
Procedure SetFormModified()
	
	Modified = (Object.UnapprovedMappingTable.Count() > 0);
	
EndProcedure

&AtClient
Procedure UpdateMappingTable()
	
	Items.TableButtons.Enabled = False;
	Items.TableHeaderGroup.Enabled = False;
	
	GoToNumber = 0;
	
	// Selecting the second wizard step
	SetGoToNumber(2);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Applied procedures and functions.

&AtClient
Procedure FillSortTable(SourceValueList)
	
	Object.SortTable.Clear();
	
	For Each Item In SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = Object.SortTable.Add();
		
		TableRow.FieldName     = Item.Value;
		TableRow.Use           = IsFirstField; // Default sorting by the first field
		TableRow.SortDirection = True; // Ascending
		
	EndDo;
	
EndProcedure

&AtClient
Procedure FillListWithSelectedItems(SourceList, TargetList)
	
	TargetList.Clear();
	
	For Each Item In SourceList Do
		
		If Item.Check Then
			
			TargetList.Add(Item.Value, Item.Presentation, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetTabularSectionFilter()
	
	Items.MappingTable.RowFilter = MappingStatusFilterOptions[FilterByMappingStatus];
	
EndProcedure

&AtClient
Procedure CheckUserFieldsFilled(Cancel, UserFields)
	
	If UserFields.Count() = 0 Then
		
		// One or more fields must be specified
		NString = NStr("en = 'Specify one or more fields to be displayed.'");
		
		CommonUseClientServer.MessageToUser(NString,,"Object.TableFieldList",, Cancel);
		
	ElsIf UserFields.Count() > MaxCustomFieldCount() Then
		
		// The value must not exceed the specified number
		MessageString = NStr("en = 'Reduce the number of fields (you can select no more than %1 fields).'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(MaxCustomFieldCount()));
		
		CommonUseClientServer.MessageToUser(MessageString,,"Object.TableFieldList",, Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetTableFieldVisible(FormTableName)
	
	SourceFieldName = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	TargetFieldName = StrReplace("#FormTableName#TargetFieldNN","#FormTableName#", FormTableName);
	
	// Making all mapping table fields invisible
	For FieldNumber = 1 To MaxCustomFieldCount() Do
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		Items[SourceField].Visible = False;
		Items[TargetField].Visible = False;
		
	EndDo;
	
	// Making all mapping table fields that are selected by user visible
	For Each Item In Object.UsedFieldList Do
		
		FieldNumber = Object.UsedFieldList.IndexOf(Item) + 1;
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		// Setting field visibility
		Items[SourceField].Visible = Item.Check;
		Items[TargetField].Visible = Item.Check;
		
		// Setting field titles
		Items[SourceField].Title = Item.Presentation;
		Items[TargetField].Title = Item.Presentation;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetMappingInteractively()
	CurrentData = Items.MappingTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	// Only unmapped source or target objects can be selected for mapping
	If Not (
		    CurrentData.MappingStatus = -1	// Unmapped source object
		Or CurrentData.MappingStatus = +1	// Unmapped target object
	) Then
		
		ShowMessageBox(, NStr("en = 'Objects are already mapped.'"), 2);
		
		// Switching to the mapping table
		CurrentItem = Items.MappingTable;
		Return;
	EndIf;
	
	CannotCreateMappingFast = False;
	
	SelectedRows = Items.MappingTable.SelectedRows;
	If SelectedRows.Count() <> 2 Then
		CannotCreateMappingFast = True;
		
	Else
		ID1 = SelectedRows[0];
		ID2 = SelectedRows[1];
		
		String1 = MappingTable.FindByID(ID1);
		String2 = MappingTable.FindByID(ID2);
		
		If Not (
			(
				  String1.MappingStatus = -1 // Unmapped source object
				And String2.MappingStatus = +1 // Unmapped target object
			) Or (
				  String1.MappingStatus = +1 // Unmapped target object
				And String2.MappingStatus = -1 // Unmapped source object
			) )
		Then
			CannotCreateMappingFast = True;
		EndIf;
	EndIf;
	
	If CannotCreateMappingFast Then
		// Setting the mapping in a regular way
		BeginningRowID = Items.MappingTable.CurrentRow;
		
		FilterParameters = New Structure("MappingStatus", ?(CurrentData.MappingStatus = -1, 1, -1));
		
		FormParameters = New Structure;
		FormParameters.Insert("TempStorageAddress",   GetMappingChoiceTableTempStorageAddress(FilterParameters));
		FormParameters.Insert("StartRowSerialNumber", CurrentData.SerialNumber);
		FormParameters.Insert("UsedFieldList",        Object.UsedFieldList.Copy());
		FormParameters.Insert("MaxCustomFieldCount",  MaxCustomFieldCount());
		FormParameters.Insert("ObjectToMap",          GetObjectToMap(CurrentData));
		FormParameters.Insert("Application1",         ?(CurrentData.MappingStatus = -1, SecondApplicationDescription, CurrentApplicationDescription));
		FormParameters.Insert("Application2",         ?(CurrentData.MappingStatus = -1, CurrentApplicationDescription, SecondApplicationDescription));
		
		OpenForm("DataProcessor.InfobaseObjectMapping.Form.MappingChoiceForm", FormParameters, ThisObject,,,,,FormWindowOpeningMode.LockOwnerWindow);
		
		Return;
	EndIf;
	
	// Proposing fast mapping
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes,    NStr("en='Set'"));
	Buttons.Add(DialogReturnCode.Cancel, NStr("en='Cancel'"));
	
	Notification = New NotifyDescription("SetMappingInteractivelyCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("ID1", ID1);
	Notification.AdditionalParameters.Insert("ID2", ID2);
	
	QuestionText = NStr("en='Do you want to map the selected objects?'");
	ShowQueryBox(Notification, QuestionText, Buttons,, DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure SetMappingInteractivelyCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AddUnapprovedMappingAtClient(AdditionalParameters.ID1, AdditionalParameters.ID2);
	CurrentItem = Items.MappingTable;
EndProcedure

&AtClient
Function GetObjectToMap(Data)
	
	Result = New Array;
	
	FieldNamePattern = ?(Data.MappingStatus = -1, "SourceFieldNN", "TargetFieldNN");
	
	For FieldNumber = 1 To MaxCustomFieldCount() Do
		
		Field = StrReplace(FieldNamePattern, "NN", String(FieldNumber));
		
		If Items["MappingTable" + Field].Visible
			And ValueIsFilled(Data[Field]) Then
			
			Result.Add(Data[Field]);
			
		EndIf;
		
	EndDo;
	
	If Result.Count() = 0 Then
		
		Result.Add(NStr("en = '<not specified>'"));
		
	EndIf;
	
	Return StringFunctionsClientServer.StringFromSubstringArray(Result, ", ");
EndFunction

&AtClient
Procedure AddUnapprovedMappingAtClient(Val BeginningRowID, Val EndingRowID)
	
	// Getting two mapped table rows by the specified IDs.
	// Adding a row to the unapproved mapping table.
	// Adding a row to the mapping table.
	// Deleting two mapped rows from the mapping table.
	
	BeginningRow = MappingTable.FindByID(BeginningRowID);
	EndingRow    = MappingTable.FindByID(EndingRowID);
	
	If BeginningRow = Undefined Or EndingRow = Undefined Then
		Return;
	EndIf;
	
	If BeginningRow.MappingStatus = -1 And EndingRow.MappingStatus = +1 Then
		SourceRow = BeginningRow;
		TargetRow = EndingRow;
	ElsIf BeginningRow.MappingStatus = +1 And EndingRow.MappingStatus = -1 Then
		SourceRow = EndingRow;
		TargetRow = BeginningRow;
	Else
		Return;
	EndIf;
	
	// Adding a row to the unapproved mapping table
	NewRow = Object.UnapprovedMappingTable.Add();
	
	NewRow.SourceUUID = TargetRow.TargetUUID;
	NewRow.SourceType = TargetRow.TargetType;
	NewRow.TargetUUID = SourceRow.SourceUUID;
	NewRow.TargetType = SourceRow.SourceType;
	
	// Adding a row to the mapping table as an unapproved one
	NewRowUnapproved = MappingTable.Add();
	
	// Taking sorting fields from the target row
	FillPropertyValues(NewRowUnapproved, SourceRow, "SourcePictureIndex, SourceField1, SourceField2, SourceField3, SourceField4, SourceField5, SourceUUID, SourceType");
	FillPropertyValues(NewRowUnapproved, TargetRow, "TargetPictureIndex, TargetField1, TargetField2, TargetField3, TargetField4, TargetField5, TargetUUID, TargetType, OrderField1, OrderField2, OrderField3, OrderField4, OrderField5, PictureIndex");
	
	NewRowUnapproved.MappingStatus               = 3; // Unapproved mapping
	NewRowUnapproved.MappingStatusAdditional = 0;
	
	// Deleting mapped rows
	MappingTable.Delete(BeginningRow);
	MappingTable.Delete(EndingRow);
	
	// Updating numbers
	NewRowUnapproved.SerialNumber = NextNumberByMappingOrder();
	
	// Setting the filter and updating data in the mapping table
	SetTabularSectionFilter();
EndProcedure

&AtServer
Function NextNumberByMappingOrder()
	Result = 0;
	
	For Each Row In MappingTable Do
		Result = Max(Result, Row.SerialNumber);
	EndDo;
	
	Return Result + 1;
EndFunction
	
&AtClient
Procedure ExecuteTableSorting()
	
	SortingFields = GetSortingFields();
	If Not IsBlankString(SortingFields) Then
		MappingTable.Sort(SortingFields);
	EndIf;
	
EndProcedure

&AtClient
Function GetSortingFields()
	
	// Return value
	SortingFields = "";
	
	FieldPattern = "OrderFieldNN #SortDirection";
	
	For Each TableRow In Object.SortTable Do
		
		If TableRow.Use Then
			
			Separator = ?(IsBlankString(SortingFields), "", ", ");
			
			SortDirectionStr = ?(TableRow.SortDirection, "Asc", "Desc");
			
			ListItem = Object.UsedFieldList.FindByValue(TableRow.FieldName);
			
			FieldIndex = Object.UsedFieldList.IndexOf(ListItem) + 1;
			
			FieldName = StrReplace(FieldPattern, "NN", String(FieldIndex));
			FieldName = StrReplace(FieldName, "#SortDirection", SortDirectionStr);
			
			SortingFields = SortingFields + Separator + FieldName;
			
		EndIf;
		
	EndDo;
	
	Return SortingFields;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

&AtClient
Function MaxCustomFieldCount()
	
	Return DataExchangeClient.MaxObjectMappingFieldCount();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Idle handlers.

&AtClient
Procedure BackgroundJobIdleHandler()
	
	LongActionFinished = False;
	
	State = DataExchangeServerCall.JobState(JobID);
	
	If State = "Active" Then
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	ElsIf State = "Completed" Then
		
		LongAction = False;
		LongActionFinished = True;
		
		GoToNext();
		
	Else // Failed
		
		LongAction = False;
		
		GoBack();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Step change handlers.

// Page 0: Mapping error.
//
&AtClient
Function Attachable_ObjectMappingError_OnOpen(Cancel, SkipPage, IsGoNext)
	
	ApplyUnapprovedRecordTable = False;
	ApplyAutomaticMappingResult = False;
	AutomaticallyMappedObjectTableAddress = "";
	WriteAndClose = False;
	
	Items.TableButtons.Enabled = True;
	Items.TableHeaderGroup.Enabled = True;
	
EndFunction

// Page 1 (waiting): Object mapping.
//
&AtClient
Function Attachable_ObjectMappingWait_LongActionProcessing(Cancel, GoToNext)
	
	// Determining the number of user-defined fields to be displayed
	CheckUserFieldsFilled(Cancel, Object.UsedFieldList.UnloadValues());
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	ExecuteObjectMapping(Cancel);
	
EndFunction

// Page 1 (waiting): Object mapping.
//
&AtClient
Function Attachable_ObjectMappingWaitLongAction_LongActionProcessing(Cancel, GoToNext)
	
	If LongAction Then
		
		GoToNext = False;
		
		AttachIdleHandler("BackgroundJobIdleHandler", 5, True);
		
	EndIf;
	
EndFunction

// Page 1 (waiting): Object mapping.
//
&AtClient
Function Attachable_ObjectMappingWaitLongActionCompletion_LongActionProcessing(Cancel, GoToNext)
	
	If WriteAndClose Then
		GoToNext = False;
		Close();
		Return Undefined;
	EndIf;
	
	If LongActionFinished Then
		
		ExecuteObjectMappingCompletion(Cancel);
		
	EndIf;
	
	Items.TableButtons.Enabled = True;
	Items.TableHeaderGroup.Enabled = True;
	
	// Setting filter in the mapping tabular section
	SetTabularSectionFilter();
	
	// Setting mapping table field headers and visibility
	SetTableFieldVisible("MappingTable");

EndFunction

// Page 1: Object mapping.
//
&AtServer
Procedure ExecuteObjectMapping(Cancel)
	
	LongAction = False;
	LongActionFinished = False;
	JobID = Undefined;
	TempStorageAddress = "";
	
	Try
		
		FormAttributes = New Structure;
		FormAttributes.Insert("UnapprovedRecordTableApplyOnly", WriteAndClose);
		FormAttributes.Insert("ApplyUnapprovedRecordTable", ApplyUnapprovedRecordTable);
		FormAttributes.Insert("ApplyAutomaticMappingResult", ApplyAutomaticMappingResult);
		
		MethodParameters = New Structure;
		MethodParameters.Insert("ObjectContext", DataExchangeServer.GetObjectContext(FormAttributeToValue("Object")));
		MethodParameters.Insert("FormAttributes", FormAttributes);
		
		If ApplyAutomaticMappingResult Then
			MethodParameters.Insert("AutomaticallyMappedObjectTable", GetFromTempStorage(AutomaticallyMappedObjectTableAddress));
		EndIf;
		
		If CommonUse.FileInfobase() Then
			
			MappingResult = DataProcessors.InfobaseObjectMapping.ObjectMappingResult(MethodParameters);
			AfterObjectMapping(MappingResult);
			
		Else
			
			Result = LongActions.ExecuteInBackground(
				UUID,
				"DataProcessors.InfobaseObjectMapping.ExecuteObjectMapping",
				MethodParameters,
				NStr("en = 'Object mapping'")
			);
			
			If Result.JobCompleted Then
				
				AfterObjectMapping(GetFromTempStorage(Result.StorageAddress));
				
			Else
				
				LongAction = True;
				JobID = Result.JobID;
				TempStorageAddress = Result.StorageAddress;
				
			EndIf;
			
		EndIf;
		
	Except
		Cancel = True;
		WriteLogEvent(NStr("en = 'Object mapping wizard.Data analysis'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// Page 1: Object mapping.
//
&AtServer
Procedure ExecuteObjectMappingCompletion(Cancel)
	
	Try
		AfterObjectMapping(GetFromTempStorage(TempStorageAddress));
	Except
		Cancel = True;
		WriteLogEvent(NStr("en = 'Object mapping wizard.Data analysis'", CommonUseClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo())
		);
		Return;
	EndTry;
	
EndProcedure

// Page 1: Object mapping.
//
&AtServer
Procedure AfterObjectMapping(Val MappingResult)
	
	If WriteAndClose Then
		Return;
	EndIf;
	
	// {Mapping digest}
	ObjectCountInSource = MappingResult.ObjectCountInSource;
	ObjectCountInTarget = MappingResult.ObjectCountInTarget;
	MappedObjectCount   = MappingResult.MappedObjectCount;
	UnmappedObjectCount = MappingResult.UnmappedObjectCount;
	MappedObjectPercent = MappingResult.MappedObjectPercent;
	PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectCount, Object.DataImportedSuccessfully);
	
	MappingTable.Load(MappingResult.MappingTable);
	
	DataProcessorObject = DataProcessors.InfobaseObjectMapping.Create();
	DataExchangeServer.ImportObjectContext(MappingResult.ObjectContext, DataProcessorObject);
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	If ApplyUnapprovedRecordTable Then
		Modified = False;
	EndIf;
	
	ApplyUnapprovedRecordTable = False;
	ApplyAutomaticMappingResult = False;
	AutomaticallyMappedObjectTableAddress = "";
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Filling wizard navigation table.

&AtServer
Procedure ObjectMappingScenario()
	
	GoToTable.Clear();
	
	GoToTableNewRow(1, "ObjectMappingError",,, "ObjectMappingError_OnOpen");
	
	// Waiting for object mapping
	GoToTableNewRow(2, "ObjectMappingWait",,,,,, True, "ObjectMappingWait_LongActionProcessing");
	GoToTableNewRow(3, "ObjectMappingWait",,,,,, True, "ObjectMappingWaitLongAction_LongActionProcessing");
	GoToTableNewRow(4, "ObjectMappingWait",,,,,, True, "ObjectMappingWaitLongActionCompletion_LongActionProcessing");
	
	// Operations with object mapping table
	GoToTableNewRow(5, "ObjectMapping");
	
EndProcedure

#EndRegion
