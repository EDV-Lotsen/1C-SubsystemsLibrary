&AtClient
Var WarnOnFormClose;

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	WarnOnFormClose = True;
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	// Checking whether the form has been opened programmatically
	If Not Parameters.Property("ExchangeMessageFileName") Then
		
		NString = NStr("en = 'The data processor form cannot be opened interactively.'");
		CommonUseClientServer.MessageToUser(NString,,,, Cancel);
		Return;
		
	EndIf;
	
	PerformDataMapping = True;
	PerformDataImport = True;
	
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
	
	// Filling the filter list
	ChoiceList = Items.FilterByMappingState.ChoiceList;
	ChoiceList.Add("AllObjects",              NStr("en = 'All data'"));
	ChoiceList.Add("MappedObjectsUnapproved", NStr("en = 'Changes'"));
	ChoiceList.Add("MappedObjects",           NStr("en = 'Mapped data'"));
	ChoiceList.Add("UnmappedObjects",         NStr("en = 'Unmapped data'"));
	ChoiceList.Add("UnmappedObjectsTarget", NStr("en = 'Unmapped data of this infobase'"));
	ChoiceList.Add("UnmappedSourceObjects",   NStr("en = 'Unmapped data of the other infobase'"));
	
	// Setting the default filter
	FilterByMappingState = "UnmappedObjects";
	
	// Setting the form title
	DataPresentation = String(Metadata.FindByType(Type(Object.TargetTypeString)));
	Title = NStr("en = '[DataPresentation] data mapping'");
	Title = StrReplace(Title, "[DataPresentation]", DataPresentation);
	
	// Setting the form item visibility according to option values
	Items.LinksGroup.Visible                         = PerformDataMapping;
	Items.ExecuteAutomaticMapping.Visible               = PerformDataMapping;
	Items.MappingDigestInfo.Visible                     = PerformDataMapping;
	Items.MappingTableContextMenuLinksGroup.Visible = PerformDataMapping;
	
	Items.ExecuteDataImport.Visible                     = PerformDataImport;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Refresh(Undefined);
	
	// Setting a flag that shows whether the form has been modified
	AttachIdleHandler("SetFormModified", 2);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	If Object.UnapprovedRelationTable.Count() > 0 Then
		
		If WarnOnFormClose = True Then
			
			NString = NStr("en = 'Data has been changed. Do you want to save changes?'");
			
			Response = DoQueryBox(NString, QuestionDialogMode.YesNoCancel, ,DialogReturnCode.Yes);
			
			If Response = DialogReturnCode.No Then
				
				Return; // Closing the form without saving data
				
			ElsIf Response = DialogReturnCode.Yes Then
				
				// Closing the form and saving data
				
			ElsIf Response = DialogReturnCode.Cancel Then
				
				// The form  must not be closed, data must not be saved
				Cancel = True;
				Return;
				
			EndIf;
			
		EndIf;
		
		WarnOnFormClose = True;
		
		// Applying the unapproved reference table
		ApplyUnapprovedRecordTable(Cancel);
		
		If Cancel Then
			
			DoMessageBox(NStr("en = 'Errors occurred.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("UniqueKey",                UniqueKey);
	NotificationParameters.Insert("DataImportedSuccessfully", Object.DataImportedSuccessfully);
	
	Notify("ClosingFormsObjectsMapping", NotificationParameters);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure FilterByMappingStateOnChange(Item)
	
	SetTabularSectionFilter();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF MappingTable TABLE 

&AtClient
Procedure MappingTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	SetRelationInteractively();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Refresh(Command)
	
	Cancel = False;
	
	// Determining the number of user-defined fields to be displayed
	CheckUserFieldsFilled(Cancel, Object.UsedFieldList.UnloadValues());
	
	If Cancel Then
		Return;
	EndIf;
	
	// State notification
	Status(NStr("en = 'Objects are being mapped. Please wait...'"));
	
	UpdateAtServer(Cancel);
	
	// Setting the current filter to the mapping tabular section
	SetTabularSectionFilter();
	
	// Setting mapping table field titles and visibility
	SetTableFieldVisible("MappingTable");
	
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Error mapping objects.'"));
		
	EndIf;
	
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
	FormParameters = New Structure("MappingFieldList", Object.TableFieldList.Copy());
	
	MappingFieldList = OpenFormModal("DataProcessor.InfoBaseObjectMapping.Form.AutomaticMappingSetup", FormParameters, ThisForm);
	
	If TypeOf(MappingFieldList) <> Type("ValueList") Then
		Return;
	EndIf;
	
	// Mapping objects automatically
	FormParameters = New Structure;
	FormParameters.Insert("TargetTableName",           Object.TargetTableName);
	FormParameters.Insert("ExchangeMessageFileName",   Object.ExchangeMessageFileName);
	FormParameters.Insert("SourceTableObjectTypeName", Object.SourceTableObjectTypeName);
	FormParameters.Insert("SourceTypeString",          Object.SourceTypeString);
	FormParameters.Insert("TargetTypeString",          Object.TargetTypeString);
	FormParameters.Insert("TargetTableFields",         Object.TargetTableFields);
	FormParameters.Insert("TargetTableSearchFields",   Object.TargetTableSearchFields);
	FormParameters.Insert("InfoBaseNode",              Object.InfoBaseNode);
	FormParameters.Insert("TableFieldList",            Object.TableFieldList.Copy());
	FormParameters.Insert("UsedFieldList",             Object.UsedFieldList.Copy());
	FormParameters.Insert("MappingFieldList",          MappingFieldList.Copy());
	FormParameters.Insert("MaxCustomFieldCount",       MaxCustomFieldCount());
	FormParameters.Insert("Title",                     Title);
	
	FormParameters.Insert("UnapprovedRelationTableTempStorageAddress", PutUnapprovedRelationTableIntoTempStorage());
	
	Status(NStr("en = 'Automatic mapping is being executed. Please wait...'"));
	
	// Opening the form of automatic object mapping
	TempStorageAddress = OpenFormModal("DataProcessor.InfoBaseObjectMapping.Form.AutomaticMappingResult", FormParameters, ThisForm);
	
	If TypeOf(TempStorageAddress) = Type("String") Then
		
		// Applying the result and updating the mapping table according to the received object map
		ApplyAutomaticObjectMappingResultAndUpdate(Cancel, TempStorageAddress);
		
		If Not Cancel Then
			
			// Setting the current filter
			SetTabularSectionFilter();
			
		EndIf;
		
	EndIf;
		
	If Cancel Then
		
		DoMessageBox(NStr("en = 'Error occured during automatically object mapping.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataImport(Command)
	
	Cancel = False;
	
	NString = NStr("en = 'Do you want to import data into the infobase?'");
	Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.Yes);
	If Response = DialogReturnCode.No Then
		Return;
	EndIf;
	
	If Object.DataImportedSuccessfully Then
		
		NString = NStr("en = 'Data has already been imported. Do you want to re-import data into the infobase?'");
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.No Then
			Return;
		EndIf;
		
	EndIf;
	
	// State notification
	Status(NStr("en = 'Data is being imported. Please wait...'"));
	
	// Importing data on the server
	ExecuteDataImportAtServer(Cancel);
	
	// Updating data in the mapping table
	Refresh(Command);
	
	If Cancel Then
		
		NString = NStr("en = 'Error importing data.
							|Do you want to open the event log?'");
		
		Response = DoQueryBox(NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		If Response = DialogReturnCode.Yes Then
			
			DataExchangeClient.GoToDataEventLogModally(Object.InfoBaseNode, ThisForm, "DataImport");
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeTableFields(Command)
	
	FormParameters = New Structure("FieldList", Object.UsedFieldList.Copy());
	
	SetupFormFieldList = OpenFormModal("DataProcessor.InfoBaseObjectMapping.Form.TableFieldSetup", FormParameters, ThisForm);
	
	If TypeOf(SetupFormFieldList) <> Type("ValueList") Then
		
		Return;
		
	EndIf;
	
	Object.UsedFieldList = SetupFormFieldList.Copy();
	
	// Setting mapping table field titles and visibility
	SetTableFieldVisible("MappingTable");
	
EndProcedure

&AtClient
Procedure SetupTableFieldList(Command)
	
	Cancel = False;
	
	FormParameters = New Structure("FieldList", Object.TableFieldList.Copy());
	
	SetupFormFieldList = OpenFormModal("DataProcessor.InfoBaseObjectMapping.Form.MappingFieldTableSetup", FormParameters, ThisForm);
	
	If TypeOf(SetupFormFieldList) <> Type("ValueList") Then
		Return;
	EndIf;
	
	Object.TableFieldList = SetupFormFieldList.Copy();
	
	FillListWithSelectedItems(Object.TableFieldList, Object.UsedFieldList);
	
	// Filling the sorting table
	FillSortTable(Object.UsedFieldList);
	
	// Updating the mapping table according the new table fields
	Refresh(Command);
	
EndProcedure

&AtClient
Procedure Sorting(Command)
	
	FormParameters = New Structure("SortTable", Object.SortTable);
	
	SortTableResult = OpenFormModal("DataProcessor.InfoBaseObjectMapping.Form.SortingSetup", FormParameters, ThisForm);
	
	If TypeOf(SortTableResult) <> Type("FormDataCollection") Then
		
		Return;
		
	EndIf;
	
	Object.SortTable.Clear();
	
	// Filling the form collection with the received settings
	For Each TableRow In SortTableResult Do
		
		FillPropertyValues(Object.SortTable.Add(), TableRow);
		
	EndDo;
	
	// Sorting the mapping table
	ExecuteTableSorting();
	
	// Update the filter 
	SetTabularSectionFilter();
	
EndProcedure

&AtClient
Procedure AddMapping(Command)
	
	SetRelationInteractively();
	
EndProcedure

&AtClient
Procedure CancelMapping(Command)
	
	SelectedRows = Items.MappingTable.SelectedRows;
	
	CancelMappingAtServer(SelectedRows);
	
	// Update the filter
	SetTabularSectionFilter();
	
EndProcedure

&AtClient
Procedure WriteRefresh(Command)
	
	Cancel = False;
	
	// Applying the unapproved reference table
	ApplyUnapprovedRecordTableAndUpdate(Cancel);
	
	// Setting current filter of the mapping part tabular section
	SetTabularSectionFilter();
	
	If Cancel Then
		DoMessageBox(NStr("en = 'Error occurred.'"));
	Else
		Modified = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WarnOnFormClose = False;
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure UpdateAtServer(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Mapping objects
	DataProcessorObject.ExecuteObjectMapping(Cancel);
	
	// {Mapping digest}
	ObjectCountInSource = DataProcessorObject.ObjectCountInSource();
	ObjectCountInTarget = DataProcessorObject.ObjectCountInTarget();
	MappedObjectCount   = DataProcessorObject.MappedObjectCount();
	UnmappedObjectCount = DataProcessorObject.UnmappedObjectCount();
	MappedObjectPercent = DataProcessorObject.MappedObjectPercent();
	PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectCount, Object.DataImportedSuccessfully);
	
	If Not Cancel Then
		
		MappingTable.Load(DataProcessorObject.MappingTable());
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ApplyAutomaticObjectMappingResultAndUpdate(Cancel, Val TempStorageAddress)
	
	If IsTempStorageURL(TempStorageAddress) Then
		
		UserAutomaticallyMappedObjectTable = GetFromTempStorage(TempStorageAddress);
		
		DeleteFromTempStorage(TempStorageAddress);
		
		If UserAutomaticallyMappedObjectTable.Count() = 0 Then
			Return; // The table is empty
		EndIf;
		
		DataProcessorObject = FormAttributeToValue("Object");
		
		// Supplementing the unapproved reference table
		For Each TableRow In UserAutomaticallyMappedObjectTable Do
			
			FillPropertyValues(DataProcessorObject.UnapprovedRelationTable.Add(), TableRow);
			
		EndDo;
		
		// Getting the mapping table according to the unapproved reference table update
		DataProcessorObject.ExecuteObjectMapping(Cancel);
		
		// {Mapping digest}
		ObjectCountInSource = DataProcessorObject.ObjectCountInSource();
		ObjectCountInTarget = DataProcessorObject.ObjectCountInTarget();
		MappedObjectCount   = DataProcessorObject.MappedObjectCount();
		UnmappedObjectCount = DataProcessorObject.UnmappedObjectCount();
		MappedObjectPercent = DataProcessorObject.MappedObjectPercent();
		PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectCount, Object.DataImportedSuccessfully);
		
		If Not Cancel Then
			
			MappingTable.Load(DataProcessorObject.MappingTable());
			
			ValueToFormAttribute(DataProcessorObject, "Object");
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ApplyUnapprovedRecordTableAndUpdate(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Applying the unapproved reference table
	DataProcessorObject.ApplyUnapprovedRecordTable(Cancel);
	
	If Not Cancel Then
		
		// Getting the mapping table according to the unapproved reference table update
		DataProcessorObject.ExecuteObjectMapping(Cancel);
		
		// {Mapping digest}
		ObjectCountInSource = DataProcessorObject.ObjectCountInSource();
		ObjectCountInTarget = DataProcessorObject.ObjectCountInTarget();
		MappedObjectCount   = DataProcessorObject.MappedObjectCount();
		UnmappedObjectCount = DataProcessorObject.UnmappedObjectCount();
		MappedObjectPercent = DataProcessorObject.MappedObjectPercent();
		PictureIndex        = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectCount, Object.DataImportedSuccessfully);
		
	EndIf;
	
	If Not Cancel Then
		
		MappingTable.Load(DataProcessorObject.MappingTable());
		
		ValueToFormAttribute(DataProcessorObject, "Object");
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ApplyUnapprovedRecordTable(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// apply unapproved reference table
	DataProcessorObject.ApplyUnapprovedRecordTable(Cancel);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
EndProcedure

&AtServer
Procedure CancelMappingAtServer(SelectedRows)
	
	For Each RowID In SelectedRows Do
		
		CurrentData = MappingTable.FindByID(RowID);
		
		If CurrentData.MappingState = 0 Then // mapping with information register 
			
			CancelDataMapping(CurrentData, False);
			
		ElsIf CurrentData.MappingState = 3 Then // unapproved mapping
			
			CancelDataMapping(CurrentData, True);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CancelDataMapping(CurrentData, IsUnapprovedRelation)
	
	Filter = New Structure;
	Filter.Insert("SourceUUID", CurrentData.TargetUUID);
	Filter.Insert("TargetUUID", CurrentData.SourceUUID);
	Filter.Insert("SourceType", CurrentData.TargetType);
	Filter.Insert("TargetType", CurrentData.SourceType);
	
	If IsUnapprovedRelation Then
		
		FoundRows = Object.UnapprovedRelationTable.FindRows(Filter);
		
		If FoundRows.Count() > 0 Then
			
			// Deleting the unapproved reference from the unapproved reference table 
			Object.UnapprovedRelationTable.Delete(FoundRows[0]);
			
		EndIf;
		
	Else
		
		CancelApprovedMappingAtServer(Filter);
		
	EndIf;
	
	
	// Adding new source and target rows to the mapping table.
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
	NewTargetRow.OrderField1   = CurrentData.TargetField1;
	NewTargetRow.OrderField2   = CurrentData.TargetField2;
	NewTargetRow.OrderField3   = CurrentData.TargetField3;
	NewTargetRow.OrderField4   = CurrentData.TargetField4;
	NewTargetRow.OrderField5   = CurrentData.TargetField5;
	NewTargetRow.PictureIndex  = CurrentData.TargetPictureIndex;
	
	NewSourceRow.MappingState = -1;
	NewSourceRow.MappingStateAdditional = 1; // unmapped objects
	
	NewTargetRow.MappingState = 1;
	NewTargetRow.MappingStateAdditional = 1; // unmapped objects
	
	// Deleting the current mapping table row
	MappingTable.Delete(CurrentData);
	
EndProcedure

&AtServer
Procedure CancelApprovedMappingAtServer(Filter)
	
	Filter.Insert("InfoBaseNode", Object.InfoBaseNode);
	
	InformationRegisters.InfoBaseObjectMaps.DeleteRecord(Filter);
	
EndProcedure

&AtServer
Procedure ExecuteDataImportAtServer(Cancel)
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	// Applying unapproved reference table
	DataProcessorObject.ApplyUnapprovedRecordTable(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	TableToImport = New Array;
	
	DataTableKey = DataExchangeServer.DataTableKey(Object.SourceTypeString, Object.TargetTypeString, Object.IsObjectDeletion);
	
	TableToImport.Add(DataTableKey);
	
	// Importing data from batch file in the data exchange mode
	DataProcessorObject.ExecuteDataImportForInfoBase(Cancel, TableToImport);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	PictureIndex = DataExchangeServer.StatisticsTablePictureIndex(UnmappedObjectCount, Object.DataImportedSuccessfully);
	
EndProcedure

&AtServer
Function PutUnapprovedRelationTableIntoTempStorage()
	
	Return PutToTempStorage(Object.UnapprovedRelationTable.Unload());
	
EndFunction

&AtServer
Function GetRelationChoiceTableTempStorageAddress(FilterParameters)
	
	Columns = "SerialNumber, OrderField1, OrderField2, OrderField3, OrderField4, OrderField5, PictureIndex";
	
	Return PutToTempStorage(MappingTable.Unload(FilterParameters, Columns));
	
EndFunction

&AtClient
Procedure SetFormModified()
	
	Modified = (Object.UnapprovedRelationTable.Count() > 0);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Applied procefures and functions

&AtClient
Procedure FillSortTable(SourceValueList)
	
	Object.SortTable.Clear();
	
	For Each Item In SourceValueList Do
		
		IsFirstField = SourceValueList.IndexOf(Item) = 0;
		
		TableRow = Object.SortTable.Add();
		
		TableRow.FieldName     = Item.Value;
		TableRow.Use           = IsFirstField; // By default, sorting by the first field
		TableRow.SortDirection = True;         // Ascending
		
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
	
	If FilterByMappingState = "AllObjects"                 Then FixedStructure = New FixedStructure;
	ElsIf FilterByMappingState = "UnmappedObjects"         Then FixedStructure = New FixedStructure("MappingStateAdditional", 1);
	ElsIf FilterByMappingState = "MappedObjects"           Then FixedStructure = New FixedStructure("MappingStateAdditional", 0);
	ElsIf FilterByMappingState = "UnmappedSourceObjects"   Then FixedStructure = New FixedStructure("MappingState", -1);
	ElsIf FilterByMappingState = "UnmappedObjectsTarget"   Then FixedStructure = New FixedStructure("MappingState",  1);
	ElsIf FilterByMappingState = "MappedObjectsUnapproved" Then FixedStructure = New FixedStructure("MappingState",  3);
	EndIf;
	
	Items.MappingTable.RowFilter = FixedStructure;
	
EndProcedure

&AtClient
Procedure CheckUserFieldsFilled(Cancel, UserFields)
	
	If UserFields.Count() = 0 Then
		
		// One or more fields must be specified
		NString = NStr("en = 'Specify one or more fields to be displayed.'");
		
		CommonUseClientServer.MessageToUser(NString,,"Object.TableFieldList",, Cancel);
		
	ElsIf UserFields.Count() > MaxCustomFieldCount() Then
		
		// The value must not exceed the specified number
		MessageString = NStr("en = 'Reduce the number of fields (you can select no more than [NumberOfFields] fields).'");
		MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, String(MaxCustomFieldCount()));
		
		CommonUseClientServer.MessageToUser(MessageString,,"Object.TableFieldList",, Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetTableFieldVisible(FormTableName)
	
	SourceFieldName = StrReplace("#FormTableName#SourceFieldNN","#FormTableName#", FormTableName);
	TargetFieldName = StrReplace("#FormTableName#TargetFieldNN","#FormTableName#", FormTableName);
	
	// Making all map table fields invisible
	For FieldNumber = 1 to MaxCustomFieldCount() Do
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		Items[SourceField].Visible = False;
		Items[TargetField].Visible = False;
		
	EndDo;
	
	// Making all map table fields selected by the user visible 
	For Each Item In Object.UsedFieldList Do
		
		FieldNumber = Object.UsedFieldList.IndexOf(Item) + 1;
		
		SourceField = StrReplace(SourceFieldName, "NN", String(FieldNumber));
		TargetField = StrReplace(TargetFieldName, "NN", String(FieldNumber));
		
		// Setting field visibility
		Items[SourceField].Visible = Item.Check;
		Items[TargetField].Visible = Item.Check;
		
		// Setting fields titles
		Items[SourceField].Title = Item.Value;
		Items[TargetField].Title = Item.Value;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetRelationInteractively()
	
	CurrentData = Items.MappingTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	// Relation can be chosen only for unmapped objects of the source or target
	If Not (CurrentData.MappingState = -1
		 Or CurrentData.MappingState = +1) Then
		
		DoMessageBox(NStr("en = 'Objects are already mapped.'"), 2);
		
		// Switching to the mapping table
		CurrentItem = Items.MappingTable;
		
		Return;
	EndIf;
	
	BeginningRowID = Items.MappingTable.CurrentRow;
	
	FilterParameters = New Structure("MappingState", ?(CurrentData.MappingState = -1, 1, -1));
	
	// Calling the server
	FormParameters = New Structure();
	FormParameters.Insert("TempStorageAddress",   GetRelationChoiceTableTempStorageAddress(FilterParameters));
	FormParameters.Insert("StartRowSerialNumber", CurrentData.SerialNumber);
	FormParameters.Insert("UsedFieldList",        Object.UsedFieldList.Copy());
	FormParameters.Insert("MaxCustomFieldCount",  MaxCustomFieldCount());
	FormParameters.Insert("ObjectToMap",          GetObjectToMap(CurrentData));
	
	// Calling the server
	EndingRowSerialNumber = OpenFormModal("DataProcessor.InfoBaseObjectMapping.Form.MappingRelationChoiceForm", FormParameters, ThisForm);
	
	If EndingRowSerialNumber = Undefined Then
		Return; // refusing to choose a relation for mapping
	EndIf;
	
	// Calling the server
	FoundRows = MappingTable.FindRows(New Structure("SerialNumber", EndingRowSerialNumber));
	
	EndingRowID = FoundRows[0].GetID();
	
	// Processing received mapping
	AddUnapprovedMappingAtClient(BeginningRowID, EndingRowID);
	
	// Switching to the mapping table
	CurrentItem = Items.MappingTable;
	
EndProcedure

&AtClient
Function GetObjectToMap(Data)
	
	Result = New Array;
	
	FieldNamePattern = ?(Data.MappingState = -1, "SourceFieldNN", "TargetFieldNN");
	
	For FieldNumber = 1 to MaxCustomFieldCount() Do
		
		Field = StrReplace(FieldNamePattern, "NN", String(FieldNumber));
		
		If Items["MappingTable" + Field].Visible
			And ValueIsFilled(Data[Field]) Then
			
			Result.Add(Data[Field]);
			
		EndIf;
		
	EndDo;
	
	If Result.Count() = 0 Then
		
		Result.Add(NStr("en = '<not specified>'"));
		
	EndIf;
	
	Return StringFunctionsClientServer.GetStringFromSubstringArray(Result, ", ");
EndFunction

&AtClient
Procedure AddUnapprovedMappingAtClient(BeginningRowID, EndingRowID)
	
	// Getting two mapped table rows by the specified IDs.
	// Adding a row to the unapproved relation table.
	// Adding a row to the mapping table.
	// Deleting two mapped rows from the mapping table.
	
	BeginningRow = MappingTable.FindByID(BeginningRowID);
	EndingRow    = MappingTable.FindByID(EndingRowID);
	
	If BeginningRow = Undefined
		Or EndingRow = Undefined Then
		Return;
	EndIf;
	
	IsSourceTargetMapping = (BeginningRow.MappingState = -1);
	
	SourceRow = ?(IsSourceTargetMapping, BeginningRow,  EndingRow);
	TargetRow = ?(IsSourceTargetMapping, EndingRow, BeginningRow);
	
	// Adding a row to the unapproved reference table
	NewRow = Object.UnapprovedRelationTable.Add();
	
	NewRow.SourceUUID = TargetRow.TargetUUID;
	NewRow.SourceType = TargetRow.TargetType;
	NewRow.TargetUUID = SourceRow.SourceUUID;
	NewRow.TargetType = SourceRow.SourceType;
	
	// Adding a row to the mapping table as an unapproved one
	NewRowUnapproved = MappingTable.Add();
	
	// Taking sorting fields from the target row
	FillPropertyValues(NewRowUnapproved, SourceRow, "SourcePictureIndex, SourceField1, SourceField2, SourceField3, SourceField4, SourceField5, SourceUUID, SourceType");
	FillPropertyValues(NewRowUnapproved, TargetRow, "TargetPictureIndex, TargetField1, TargetField2, TargetField3, TargetField4, TargetField5, TargetUUID, TargetType, OrderField1, OrderField2, OrderField3, OrderField4, OrderField5, PictureIndex");
	
	NewRowUnapproved.MappingState           = 3; // unapproved relation	
	NewRowUnapproved.MappingStateAdditional = 0;
	
	// Deleting mapped rows
	MappingTable.Delete(BeginningRow);
	MappingTable.Delete(EndingRow);
	
	// Setting the filter and updating data in the mapping table
	SetTabularSectionFilter();
	
EndProcedure

&AtClient
Procedure ExecuteTableSorting()
	
	SortingFields = GetSortingFields();
	
	If Not IsBlankString(SortingFields) Then
		
		// Calling the server
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
// Functions for retrieving properties

&AtClient
Function MaxCustomFieldCount()
	
	Return DataExchangeClient.MaxObjectMappingFieldCount();
	
EndFunction







