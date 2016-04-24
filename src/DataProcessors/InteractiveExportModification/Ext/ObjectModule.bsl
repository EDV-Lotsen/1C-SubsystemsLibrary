#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

//  Returns a technical report in the spreadsheet document format.
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//      MetadataNameList - Array - contains full metadata names for restricting 
//                         a query selection. The array can be a collection of 
//                         items with the FullMetadataName field. 
//  Returns:
//      SpreadsheetDocument - the report.
//
Function GenerateSpreadsheetDocument(MetadataNameList=Undefined) Export
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer(MetadataNameList);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, CompositionData.SettingsComposer.GetSettings(), , , Type("DataCompositionTemplateGenerator"));
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template, New Structure(
		"MetadataTableNodeContent", CompositionData.MetadataTableNodeContent
	),,True);
	Output = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	Output.SetDocument(New SpreadsheetDocument);
	
	Return Output.Output(Processor);
EndFunction

//  Starts an additional registration background job.
//
//  Returns:
//      UUID      - background job ID. 
//      Undefined - if the job is completed.
//
Function AdditionalChangeBackgroundRegistration() Export
	
	If CommonUse.FileInfobase() Then
		RecordAdditionalChanges();
		Return Undefined;
	EndIf;
	
	JobParameters = New Array;
	JobParameters.Add(ThisObjectInStructureForBackgroundJob());
	
	Return DataExchangeServer.RunBackgroundJob(
		"DataExchangeServer.InteractiveExportModification_RecordAdditionalChanges",
		JobParameters, NStr("en='Registration of additional data to be sent during the synchronization'"));
	
EndFunction

//  Starts a report generation background job.
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//      ResultAddress    - String - temporary storage address for saving the result. 
//      FullMetadataName - String - report parameter. 
//      Presentation     - String - report parameter. 
//      SimplifiedMode   - Boolean - report generation parameter, affects the print form content.
//
//  Returns:
//      UUID      - background job ID. 
//      Undefined - if the job is completed.
//
Function UserSpreadsheetDocumentBackgroundGeneration(ResultAddress, FullMetadataName="", Presentation="", SimplifiedMode=False) Export
	
	If CommonUse.FileInfobase() Then
		ResultAddress = PutToTempStorage(
			GenerateUserSpreadsheetDocument(FullMetadataName, Presentation, SimplifiedMode));
		Return Undefined;
	EndIf;
	
	JobParameters = New Array;
	JobParameters.Add(ThisObjectInStructureForBackgroundJob());
	JobParameters.Add(ResultAddress);
	JobParameters.Add(FullMetadataName);
	JobParameters.Add(Presentation);
	JobParameters.Add(SimplifiedMode);
	
	Return DataExchangeServer.RunBackgroundJob(
		"DataExchangeServer.InteractiveExportModification_GenerateUserSpreadsheetDocument",
		JobParameters, NStr("en='Report generation: data to be sent during the synchronization'"));
EndFunction

//  Starts a value tree generation background job.
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//      ResultAddress    - String, UUID - temporary storage address for saving the result. 
//      MetadataNameList - Array of Strings - metadata names to be used in the report.
//
//  Returns:
//      UUID      - background job ID. 
//      Undefined - if the job is completed.
//
Function ValueTreeBackgroundGeneration(ResultAddress, MetadataNameList=Undefined) Export
	
	If CommonUse.FileInfobase() Then
		ResultAddress = PutToTempStorage( GenerateValueTree(MetadataNameList) );
		Return Undefined;
	EndIf;
	
	JobParameters = New Array;
	JobParameters.Add(ThisObjectInStructureForBackgroundJob());
	JobParameters.Add(ResultAddress);
	JobParameters.Add(MetadataNameList);
	
	Return DataExchangeServer.RunBackgroundJob(
		"DataExchangeServer.InteractiveExportModification_GenerateValueTree",
		JobParameters, NStr("en='Calculating the number of objects to be sent during the synchronization'"));
	
EndFunction

//  Returns a user report in the spreadsheet document format.
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//       FullMetadataName - String - restriction.
//       Presentation     - String - result parameter. 
//       SimplifiedMode   - Boolean - template selection.
//
//  Returns:
//      SpreadsheetDocument - the report.
//
Function GenerateUserSpreadsheetDocument(FullMetadataName="", Presentation="", SimplifiedMode=False) Export
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer();
	
	If IsBlankString(FullMetadataName) Then
		DetailsData = New DataCompositionDetailsData;
		OptionName = "UserData"; 
	Else
		DetailsData = Undefined;
		OptionName = "DetailsByObjectKind"; 
	EndIf;
	
	// Saving filter settings
	FilterSettings = CompositionData.SettingsComposer.GetSettings();
	
	// Applying the selected option
	CompositionData.SettingsComposer.LoadSettings(
		CompositionData.CompositionSchema.SettingVariants[OptionName].Settings);
	
	// Restoring filter settings
	AddDataCompositionFilterValues(CompositionData.SettingsComposer.Settings.Filter.Items, 
		FilterSettings.Filter.Items);
	
	Parameters = CompositionData.CompositionSchema.Parameters;
	Parameters.Find("CreationDate").Value   = CurrentSessionDate();
	Parameters.Find("SimplifiedMode").Value = SimplifiedMode;
	
	Parameters.Find("CommonSynchronizationParameterText").Value = DataExchangeServer.DataSynchronizationRuleDetails(InfobaseNode);
	Parameters.Find("AdditionalParameterText").Value             = AdditionalParameterText();
	
	If Not IsBlankString(FullMetadataName) Then
		Parameters.Find("ListPresentation").Value = Presentation;
		
		FilterItems = CompositionData.SettingsComposer.Settings.Filter.Items;
		
		Item = FilterItems.Add(Type("DataCompositionFilterItem"));
		Item.LeftValue      = New DataCompositionField("FullMetadataName");
		Item.Presentation   = Presentation;
		Item.ComparisonType = DataCompositionComparisonType.Equal;
		Item.RightValue     = FullMetadataName;
		Item.Use            = True;
	EndIf;
	
	ComposerSettings = CompositionData.SettingsComposer.GetSettings();
	If SimplifiedMode Then
		// Disabling some fields
		HiddenFields = New Structure("CountByGeneralRules, AdditionallyRegistration, TotalCount, NotToBeExported, ObjectExportAvailable");
		For Each Grouping In ComposerSettings.Structure Do
			HideSelectionFields(Grouping.Selection.Items, HiddenFields)
		EndDo;
		// Modifying footer section
		GroupCount = ComposerSettings.Structure.Count();
		If GroupCount > 0 Then
			ComposerSettings.Structure[GroupCount-1].Name = "EmptyFooter";
		EndIf;
	EndIf;

	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, ComposerSettings, DetailsData, , Type("DataCompositionTemplateGenerator"));
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template, 
		New Structure("MetadataTableNodeContent", CompositionData.MetadataTableNodeContent),
		DetailsData, True
	);
	
	Output = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	Output.SetDocument(New SpreadsheetDocument);
	
	Return New Structure("SpreadsheetDocument, Details, CompositionSchema",
		Output.Output(Processor), DetailsData, CompositionData.CompositionSchema);
EndFunction

//  Returns a two-level tree where the first level contains metadata types and the 
//  second level contains metadata objects. 
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//      MetadataNameList - Array - array of full metadata names for specifying composer settings.
//                         This parameter can contain a collection of objects that have 
//                         the FullMetadataName field. 
//
Function GenerateValueTree(MetadataNameList = Undefined) Export
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer(MetadataNameList);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, CompositionData.SettingsComposer.GetSettings(), , , Type("DataCompositionValueCollectionTemplateGenerator"));	
	Processor = New DataCompositionProcessor;
	Processor.Initialize(Template, New Structure(
		"MetadataTableNodeContent", CompositionData.MetadataTableNodeContent
	),,True);
	
	Output = New DataCompositionResultValueCollectionOutputProcessor;
	Output.SetObject(New ValueTree);
	ResultTree = Output.Output(Processor);
	
	Return ResultTree;
EndFunction

//  Initializes the data processor.
//
//  Parameters:
//      Source - String, UUID - source object address in the temporary storage or in the settings structure.
//
//  Returns:
//      DataProcessorObject - InteractiveExportModification.
//
Function InitializeThisObject(Val Source = "") Export
	
	If TypeOf(Source)=Type("String") Then
		If IsBlankString(Source) Then
			Return ThisObject;
		EndIf;
		Source = GetFromTempStorage(Source);
	EndIf;
		
	FillPropertyValues(ThisObject, Source, , "AllDocumentsFilterComposer, AdditionalRegistration, AdditionalNodeScenarioRegistration");
	
	DataExchangeServer.FillValueTable(AdditionalRegistration, Source.AdditionalRegistration);
	DataExchangeServer.FillValueTable(AdditionalNodeScenarioRegistration, Source.AdditionalNodeScenarioRegistration);
	
	// Reinitializing composer
	If IsBlankString(Source.AllDocumentsComposerAddress) Then
		Data = CommonFilterSettingsComposer();
	Else
		Data = GetFromTempStorage(Source.AllDocumentsComposerAddress);
	EndIf;
		
	ThisObject.AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
	ThisObject.AllDocumentsFilterComposer.Initialize(
		New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	ThisObject.AllDocumentsFilterComposer.LoadSettings(Data.Settings);
	
	If IsBlankString(Source.AllDocumentsComposerAddress) Then
		ThisObject.AllDocumentsComposerAddress = PutToTempStorage(Data, Source.FromStorageAddress);
	Else 
		ThisObject.AllDocumentsComposerAddress = Source.AllDocumentsComposerAddress;
	EndIf;
		
	Return ThisObject;
EndFunction

//  Saves this object data in the temporary storage.
//
//  Parameters:
//      StorageAddress - String, UUID - storage form ID or storage address.
//
//  Returns:
//      String - address in the temporary storage. 
//
Function SaveThisObject(Val StorageAddress) Export
	Data = New Structure;
	For Each Meta In ThisObject.Metadata().Attributes Do
		Name = Meta.Name;
		Data.Insert(Name, ThisObject[Name]);
	EndDo;
	
	ComposerData = CommonFilterSettingsComposer();
	Data.Insert("AllDocumentsComposerAddress", PutToTempStorage(ComposerData, StorageAddress));
	
	Return PutToTempStorage(Data, StorageAddress);
EndFunction

//  Returns composer settings for common node filters. 
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//      SchemaSavingAddress - String, UUID - temporary storage address for saving a data composition schema.
//
// Returns:
//      Structure - fields:
//          * Settings          - DataCompositionSettings - composer settings. 
//          * CompositionSchema - DataCompositionSchema - data composition schema. 
//
Function CommonFilterSettingsComposer(SchemaSavingAddress=Undefined) Export
	
	SavedOption = ExportVariant;
	
	ExportVariant = 1;
	
	AddressToSave = ?(SchemaSavingAddress = Undefined, New UUID, SchemaSavingAddress);
	
	Data = InitializeComposer(Undefined, True, AddressToSave);
	
	ExportVariant = SavedOption;
	
	Result = New Structure;
	Result.Insert("Settings",  Data.SettingsComposer.Settings);
	Result.Insert("CompositionSchema", Data.CompositionSchema);
	
	Return Result;
EndFunction

//  Returns a filter composer for a single metadata type of the node 
//  specified in the InfobaseNode attribute.
//
//  Parameters:
//      FullMetadataName    - String - data for filling composer settings. This parameter 
//                            can contain IDs that correspond to "All documents" or 
//                            "All catalogs", or a group reference.
//      Presentation        - String - object presentation in the filter. 
//      Filter              - DataCompositionFilter - composition filter to fill. 
//      SchemaSavingAddress - String, UUID - temporary storage address for saving a data composition schema.
//
// Returns:
//      DataCompositionSettingsComposer - initialized composer.
//
Function SettingsComposerByTableName(FullMetadataName, Presentation = Undefined, Filter = Undefined, SchemaSavingAddress = Undefined) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	TablesToAdd = EnlargedMetadataGroupContent(FullMetadataName);
	
	For Each TableName In TablesToAdd Do
		AddSetToCompositionSchema(CompositionSchema, TableName, Presentation);
	EndDo;
	
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	
	If Filter <> Undefined Then
		AddDataCompositionFilterValues(Composer.Settings.Filter.Items, Filter.Items);
		Composer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
	
	Return Composer;
EndFunction

// Returns:
//     String - prefix for getting forms of the current data processor.
//
Function BaseFormName() Export
	Return Metadata().FullName() + "."
EndFunction

// Returns:
//     String - title for generation of "All documents" filter presentation.
//
Function AllDocumentsFilterGroupTitle() Export
	Return NStr("en='All documents'");
EndFunction

// Returns:
//     String - title for generation of "All catalogs" filter presentation.
//
Function AllCatalogsFilterGroupTitle() Export
	Return NStr("en='All catalogs'");
EndFunction

//  Returns period and filter details in the string format.
//
//  Parameters:
//      Period             - StandardPeriod - period used in the filter options. 
//      Filter             - DataCompositionFilter - data composition filter.
//      EmptyFilterDetails - String - the function returns this value if an empty filter is passed.
//
Function FilterPresentation(Period, Filter, Val EmptyFilterDetails = Undefined) Export
	Return DataExchangeServer.ExportAdditionFilterPresentation(Period, Filter, EmptyFilterDetails);
EndFunction

//  Returns period details and details of the filter by AllDocumentsFilterPeriod 
//  and AllDocumentsFilterComposer attributes.
//
//  Parameters:
//      EmptyFilterDetails - String - the function returns this value if an empty filter is passed.
//
Function AllDocumentsFilterPresentation(Val EmptyFilterDetails = Undefined) Export
	
	If EmptyFilterDetails = Undefined Then
		EmptyFilterDetails = AllDocumentsFilterGroupTitle();
	EndIf;
	
	Return FilterPresentation("", AllDocumentsFilterComposer, EmptyFilterDetails);
EndFunction

//  Returns details of the filter by AdditionalRegistration attribute.
//
//  Parameters:
//      EmptyFilterDetails - String - the function returns this value if an empty filter is passed.
//
Function DetailedFilterPresentation(Val EmptyFilterDetails=Undefined) Export
	Return DataExchangeServer.DetailedExportAdditionPresentation(AdditionalRegistration, EmptyFilterDetails);
EndFunction

// Returns:
//     String - the ID of the internal metadata object group "All documents".
//
Function AllDocumentsID() Export
	// The ID must not be identical to the full metadata name
	Return DataExchangeServer.ExportAdditionAllDocumentsID();
EndFunction

// Returns:
//     String - The ID of the internal metadata object group "All catalogs".
//
Function AllCatalogsID() Export
	// The ID must not be identical to the full metadata name
	Return DataExchangeServer.ExportAdditionAllCatalogsID();
EndFunction

//  Adds a filter to the end of a filter, can correct field data sources.
//
//  Parameters:
//      TargetItems - DataCompositionFilterItemCollection - target.
//      SourceItems - DataCompositionFilterItemCollection - source.
//      FieldMap    - KeyAndValue object collection:
//                      Key - source path to field data
//                      Value - path to the result. 
//                    For example, to replace "Ref.Description" -> "RegistrationObject.Description", 
//                    pass the following structure: New Structure("Ref", "RegistrationObject").
//
Procedure AddDataCompositionFilterValues(TargetItems, SourceItems, FieldMap=Undefined) Export
	
	For Each Item In SourceItems Do
		
		Type = TypeOf(Item);
		FilterItem = TargetItems.Add(Type);
		FillPropertyValues(FilterItem, Item);
		If Type = Type("DataCompositionFilterItemGroup") Then
			AddDataCompositionFilterValues(FilterItem.Items, Item.Items, FieldMap);
			
		ElsIf FieldMap <> Undefined Then
			SourceFieldString = Item.LeftValue;
			For Each KeyValue In FieldMap Do
				ControlNew    = Lower(KeyValue.Key);
				ControlLength = 1 + StrLen(ControlNew);
				SourceControl = Lower(Left(SourceFieldString, ControlLength));
				If SourceControl = ControlNew Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value);
					Break;
				ElsIf SourceControl = ControlNew + "." Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value + Mid(SourceFieldString, ControlLength));
					Break;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

//  Returns a value list item found by presentation.
//
//  Parameters:
//      ValueList    - ValueList - list to search. 
//      Presentation - String - search parameter.
//
// Returns:
//      ListItem  - found item. 
//      Undefined - if the item is not found.
//
Function FindByPresentationListItem(ValueList, Presentation) Export
	For Each ListItem In ValueList Do
		If ListItem.Presentation = Presentation Then
			Return ListItem;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

//  Performs additional registration based on the current object data.
//
Procedure RecordAdditionalChanges() Export
	
	If ExportVariant <= 0 Then
		// no changes
		Return;
	EndIf;
	
	ChangeTree = GenerateValueTree();
	
	SetPrivilegedMode(True);
	For Each GroupRow In ChangeTree.Rows Do
		For Each Row In GroupRow.Rows Do
			If Row.CountToExport > 0 Then
				DataExchangeEvents.RecordDataChanges(InfobaseNode, Row.RegistrationObject, False);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

//  Returns a value list that contains all available settings presentations.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - an exchange node for getting settings. 
//                     If not specified, the current InfobaseNode attribute value is used.
//      Options      - Array - if specified, the settings are filtered as follows: 
//                     0 - no filter, 1 – "All documents" filter, 2 – detailed report, 3 - node scenario.
//
//  Returns:
//      ValueList - available settings.
//
Function ReadSettingsListPresentations(ExchangeNode=Undefined, Options=Undefined) Export
	
	SettingsParameters = SettingsParameterStructure(ExchangeNode);
	
	SetPrivilegedMode(True);    
	VariantList = CommonSettingsStorage.Load(
	SettingsParameters.ObjectKey, SettingsParameters.SettingsKey,
	SettingsParameters, SettingsParameters.User);
	
	PresentationList = New ValueList;
	If VariantList <> Undefined Then
		For Each Item In VariantList Do
			If Options = Undefined Or Options.Find(Item.Value.ExportVariant) <> Undefined Then
				PresentationList.Add(Item.Presentation, Item.Presentation);
			EndIf;
		EndDo;
	EndIf;
	
	Return PresentationList;
EndFunction

//  Restores the current object attributes from the specified list item.
//
//  Parameters:
//      Presentation       - String - presentation of settings to be restored. 
//      Options            - Array - if specified, the settings to be restored 
//                           are filtered as follows:
//                           0 - no filter, 1 – "All documents" filter, 2 – detailed report, 3 - node scenario. 
//      FromStorageAddress - String, UUID - optional address for saving data.
//
// Returns:
//      Boolean - True if settings are restored.
//                False if settings are not found.
//
Function RestoreCurrentAttributesFromSettings(Presentation, Options = Undefined, FromStorageAddress = Undefined) Export
	
	VariantList = ReadSettingsList(Options);
	ListItem = FindByPresentationListItem(VariantList, Presentation);
	
	Result = ListItem <> Undefined;
	If Result Then
		FillPropertyValues(ThisObject, ListItem.Value);
		
		// Specifying composer options
		Data = CommonFilterSettingsComposer();
		AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
		AllDocumentsFilterComposer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
		AllDocumentsFilterComposer.LoadSettings(ListItem.Value._AllDocumentsFilterComposerSettings);
		
		// Initializing additional composer
		If FromStorageAddress <> Undefined Then
			AllDocumentsComposerAddress = PutToTempStorage(Data, FromStorageAddress);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

//  Saves the current object attribute values to the settings, with the specified presentation.
//
//  Parameters:
//      Presentation - String - settings presentation.
//
Procedure SaveCurrentValuesInSettings(Presentation) Export
	VariantList = ReadSettingsList();
	
	ListItem = FindByPresentationListItem(VariantList, Presentation);
	If ListItem = Undefined Then
		ListItem = VariantList.Add(, Presentation);
		VariantList.SortByPresentation();
	EndIf;
	
	AttributesToSave = "InfobaseNode, ExportVariant, AllDocumentsFilterPeriod,
		|AdditionalRegistration, NodeScenarioFilterPeriod, AdditionalNodeScenarioRegistration, NodeScenarioFilterPresentation";
	
	ListItem.Value = New Structure(AttributesToSave);
	FillPropertyValues(ListItem.Value, ThisObject);
	
	ListItem.Value.Insert("_AllDocumentsFilterComposerSettings", AllDocumentsFilterComposer.Settings);
	
	SettingsParameters = SettingsParameterStructure();
	
	SetPrivilegedMode(True);
	CommonSettingsStorage.Save(
		SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, 
		VariantList, 
		SettingsParameters, SettingsParameters.User);
EndProcedure

//  Deletes an item from the list of report options.
//
//  Parameters:
//      Presentation - String - settings presentation.
//
Procedure DeleteSettingsVariant(Presentation) Export
	VariantList = ReadSettingsList();
	ListItem = FindByPresentationListItem(VariantList, Presentation);
	
	If ListItem <> Undefined Then
		VariantList.Delete(ListItem);
		VariantList.SortByPresentation();
		SaveSettingsList(VariantList);
	EndIf;
	
EndProcedure

// Returns a metadata object name array according to FullMetadataName parameter value. 
// The result is based on the InfobaseNode attribute value.
//
// Parameters:
//      FullMetadataName - String, ValueTree - metadata object name (for example, Catalog.Currencies),
//                         or predefined group name (for example, AllDocuments), or a value tree that describes a group.
//
// Returns:
//      Array - metadata names.
//
Function EnlargedMetadataGroupContent(FullMetadataName) Export
	
	If TypeOf(FullMetadataName) <> Type("String") Then
		// Value tree with a filter group. 
   // The root contains the filter description and the rows contain metadata names.
		ContentTable = New Array;
		For Each GroupRow In FullMetadataName.Rows Do
			For Each GroupContentRow In GroupRow.Rows Do
				ContentTable.Add(GroupContentRow.FullMetadataName);
			EndDo;
		EndDo;
		
	ElsIf FullMetadataName = AllDocumentsID() Then
		// Getting names of all node documents
		AllData = DataExchangeServer.NodeContentRefTables(InfobaseNode, True, False);
		ContentTable = AllData.UnloadColumn("FullMetadataName");
		
	ElsIf FullMetadataName=AllCatalogsID() Then
		// Getting names of all node catalogs
		AllData = DataExchangeServer.NodeContentRefTables(InfobaseNode, False, True);
		ContentTable = AllData.UnloadColumn("FullMetadataName");
		
	Else
		// Single metadata table
		ContentTable = New Array;
		ContentTable.Add(FullMetadataName);
		
	EndIf;
	
	// Hiding items with NotExport set
	NotExportMode = Enums.ExchangeObjectExportModes.NotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanContent(InfobaseNode);
	
	Position = ContentTable.UBound();
	While Position >= 0 Do
		If ExportModes[ContentTable[Position]] = NotExportMode Then
			ContentTable.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	Return ContentTable;
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

//  Value table constructor. Generates a table with custom type columns.
//
//  Parameters:
//      ColumnList - String - list of table columns separated by commas.
//      IndexList  - String - list of table indexes separated by commas.
//
// Returns:
//      ValueTable - generated table.
//
Function ValueTable(ColumnList, IndexList="")
	ResultTable = New ValueTable;
	
	For Each KeyValue In (New Structure(ColumnList)) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	For Each KeyValue In (New Structure(IndexList)) Do
		ResultTable.Indexes.Add(KeyValue.Key);
	EndDo;
	
	Return ResultTable;
EndFunction

//  Adds a single filter item to the list.
//
//  Parameters:
//      FilterItems     - DataCompositionFilterItem - reference to the object that is checked.
//      DataPathField   - String - data path of the filter item. 
//      ComparisonType  - DataCompositionComparisonType - comparison type. 
//      Value           - Arbitrary - comparison value. 
//      Presentation    - String - optional field presentation.
//      
Procedure AddFilterItem(FilterItems, DataPathField, ComparisonType, Value, Presentation=Undefined)
	
	Item = FilterItems.Add(Type("DataCompositionFilterItem"));
	Item.Use            = True;
	Item.LeftValue      = New DataCompositionField(DataPathField);
	Item.ComparisonType = ComparisonType;
	Item.RightValue     = Value;
	
	If Presentation <> Undefined Then
		Item.Presentation = Presentation;
	EndIf;
EndProcedure

//  Adds a data set to a composition schema. The data set is based on a metadata object and contains a single Ref field.
//
//  Parameters:
//      DataCompositionSchema - DataCompositionSchema - data composition schema. 
//      TableName             - String - data table name. 
//      Presentation:         - String - reference field presentation.
//
Procedure AddSetToCompositionSchema(DataCompositionSchema, TableName, Presentation=Undefined)
	
	Set = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = "
		|SELECT 
		|   Ref
		|FROM 
		|   " + TableName + "
		|";
	Set.AutoFillAvailableFields = True;
	Set.DataSource = DataCompositionSchema.DataSources[0].Name;
	Set.Name = "Set" + Format(DataCompositionSchema.DataSets.Count()-1, "NZ=; NG=");
	
	Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	Field.Field = "Ref";
	Field.Title = ?(Presentation=Undefined, DataExchangeServer.ObjectPresentation(TableName), Presentation);
	
EndProcedure

//  Adds composer settings from a source structure to a target structure.
//
//  Parameters:
//      TargetItems - DataCompositionSettingStructureItemCollection - target.
//      SourceItems - DataCompositionSettingStructureItemCollection - source.
//
Procedure AddCompositionStructureValues(TargetItems, SourceItems)
	For Each Item In SourceItems Do
		Type = TypeOf(Item);
		FilterItem = TargetItems.Add(Type);
		FillPropertyValues(FilterItem, Item);
		If Type = Type("DataCompositionGroup") Then
			AddCompositionStructureValues(FilterItem.Items, Item.Items);
		EndIf;
	EndDo
EndProcedure

//  Adds data sets to a composition schema and initializes a composer. 
//  The result is based on InfobaseNode, AdditionalRegistration, ExportVariant, 
//  AllDocumentsFilterPeriod, and AllDocumentsFilterComposer attribute values.
//
//  Parameters:
//      MetadataNameList     - Array - metadata names (restriction group value trees, 
//                             "All documents" or "All regulatory data" internal IDs)
//                             that serve as a basis for the composition schema.
//                             If it is Undefined, all metadata types from node content are used.
//     LimitUsingWithFilter  - Boolean - a flag that shows whether the composition 
//                             schema is initialized only for filtering export items.
//      SchemaSavingAddress  - String, UUID - a temporary storage address for saving a composition schema.
//
//  Returns:
//      Structure - fields:
//         * MetadataTableNodeContent - ValueTable - node content details. 
//         * CompositionSchema        - DataCompositionSchema - initialized value. 
//         * SettingsComposer         - DataCompositionSettingsComposer - initialized value.
//
Function InitializeComposer(MetadataNameList=Undefined, LimitUsingWithFilter=False, SchemaSavingAddress=Undefined)
	
	MetadataTableNodeContent = DataExchangeServer.NodeContentRefTables(InfobaseNode);
	CompositionSchema = GetTemplate("DataCompositionSchema");
	
	// Sets for all metadata
	ItemsSetsCounts = CompositionSchema.DataSets.TotalItemCount.Items;
	
	// Sets for each metadata type included in the exchange
	SetItemsChanges = CompositionSchema.DataSets.ChangeRegistration.Items;
	While SetItemsChanges.Count()>1 Do
		// [0] - Field details
		SetItemsChanges.Delete(SetItemsChanges[1]);
	EndDo;
	DataSource = CompositionSchema.DataSources[0].Name;
	
	// Filling the MetadataNameFilter
	MetadataNameFilter = New Map;
	If MetadataNameList <> Undefined Then
		If TypeOf(MetadataNameList) = Type("Array") Then
			For Each MetaName In MetadataNameList Do
				MetadataNameFilter.Insert(MetaName, True);
			EndDo;
		Else
			For Each Item In MetadataNameList Do
				MetadataNameFilter.Insert(Item.FullMetadataName, True);
			EndDo;
		EndIf;
	EndIf;
	
	// Details on  options for automatic change recording and number of objects to be 
 // registered are always used in filter settings
	For Each Row In MetadataTableNodeContent Do
		FullMetadataName = Row.FullMetadataName;
		If MetadataNameList <> Undefined And MetadataNameFilter[FullMetadataName] <> True Then
			Continue;
		EndIf;
		
		MetadataSetName = StrReplace(FullMetadataName, ".", "_");
		SetName = "Automatically_" + MetadataSetName;
		If SetItemsChanges.Find(SetName) = Undefined Then
			Set = SetItemsChanges.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.AutoFillAvailableFields = False;
			Set.DataSource = DataSource;
			Set.Name = SetName;
			Set.Query = "
				|SELECT DISTINCT ALLOWED
				|	" + SetName + "_Changes.Ref AS RegistrationObject,
				|	TYPE(" + FullMetadataName + ") AS RegistrationObjectType,
				|	&RegistrationReasonAutomatically AS RegistrationReason
				|FROM
				|	" + FullMetadataName + ".Changes AS " + SetName + "_Changes
				|WHERE
				|Node = &InfobaseNode
				|";
		EndIf;
		
		SetName = "Count_" + MetadataSetName;
		If ItemsSetsCounts.Find(SetName) = Undefined Then
			Set = ItemsSetsCounts.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.AutoFillAvailableFields = True;
			Set.DataSource = DataSource;
			Set.Name = SetName;
			Set.Query = "
				|SELECT ALLOWED
				|	TYPE(" + FullMetadataName + ") AS Type,
				|	COUNT(" + SetName + ".Ref)
				|AS TotalCount FROM
				|	" + FullMetadataName + " AS " + SetName + "
				|";
		EndIf;
		
	EndDo;
	
	// Additional modification options
	If ExportVariant = 1 Then
		// General filter by header attributes
		AdditionalChangeTable = ValueTable("FullMetadataName, Filter, Period, SelectPeriod");
		Row = AdditionalChangeTable.Add();
		Row.FullMetadataName = AllDocumentsID();
		Row.SelectPeriod     = True;
		Row.Period           = AllDocumentsFilterPeriod;
		Row.Filter           = AllDocumentsFilterComposer.Settings.Filter;
		
	ElsIf ExportVariant = 2 Then
		// Detailed filter
		AdditionalChangeTable = AdditionalRegistration;
		
	Else
		// No additional filter options
		AdditionalChangeTable = New ValueTable;
		
	EndIf;
	
	// Additional changes
	For Each Row In AdditionalChangeTable Do
		FullMetadataName = Row.FullMetadataName;
		If MetadataNameList <> Undefined And MetadataNameFilter[FullMetadataName] <> True Then
			Continue;
		EndIf;
		
		TablesToAdd = EnlargedMetadataGroupContent(FullMetadataName);
		For Each NameOfTableToAdd In TablesToAdd Do
			If MetadataNameList <> Undefined And MetadataNameFilter[NameOfTableToAdd] <> True Then
				Continue;
			EndIf;
			
			SetName = "Advanced_" + StrReplace(NameOfTableToAdd, ".", "_");
			If SetItemsChanges.Find(SetName) = Undefined Then 
				Set = SetItemsChanges.Add(Type("DataCompositionSchemaDataSetQuery"));
				Set.DataSource = DataSource;
				Set.AutoFillAvailableFields = True;
				Set.Name = SetName;
				
				Set.Query = "
					|SELECT ALLOWED
					|	" + SetName +".Ref            AS RegistrationObject,
					|	TYPE(" + NameOfTableToAdd + ") AS RegistrationObjectType,
					|	&RegistrationReasonAdvanced   AS RegistrationReason
					|FROM
					|	" + NameOfTableToAdd + " AS " + SetName + "
					|";
					
				// Adding more sets for getting their filter tabular section data
				AddingOptions = New Structure;
				AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
				AddingOptions.Insert("CompositionSchema",       CompositionSchema);
				AddTabularSectionCompositionAdditionalSets(Row.Filter.Items, AddingOptions)
			EndIf;
			
		EndDo;
	EndDo;
	
	// Common parameters
	Parameters = CompositionSchema.Parameters;
	Parameters.Find("InfobaseNode").Value = InfobaseNode;
	
	AutomaticallyParameter = Parameters.Find("RegistrationReasonAutomatically");
	AutomaticallyParameter.Value = NStr("en = 'By common rules'");
	
	AdditionallyParameter = Parameters.Find("RegistrationReasonAdvanced");
	AdditionallyParameter.Value = NStr("en = 'Advanced'");
	
	ParameterByRef = Parameters.Find("RegistrationReasonByRef");
	ParameterByRef.Value = NStr("en = 'By reference'");
	
	If LimitUsingWithFilter Then
		Fields = CompositionSchema.DataSets.ChangeRegistration.Fields;
		Restriction = Fields.Find("RegistrationObjectType").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("RegistrationReason").UseRestriction;
		Restriction.Condition = True;
		
		Fields = CompositionSchema.DataSets.MetadataTableNodeContent.Fields;
		Restriction = Fields.Find("ListPresentation").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("Presentation").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("FullMetadataName").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("Periodical").UseRestriction;
		Restriction.Condition = True;
	EndIf;
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	If AdditionalChangeTable.Count()> 0 Then 
		
		If LimitUsingWithFilter Then
			SettingsRoot = SettingsComposer.FixedSettings;
		Else
			SettingsRoot = SettingsComposer.Settings;
		EndIf;
		
		// Adding additional data filter settings
		FilterGroup = SettingsRoot.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterGroup.Use = True;
		FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItems = FilterGroup.Items;
		
		// Adding autoregistration filter options
		AddFilterItem(FilterGroup.Items, "RegistrationReason", DataCompositionComparisonType.Equal, AutomaticallyParameter.Value);
		AddFilterItem(FilterGroup.Items, "RegistrationReason", DataCompositionComparisonType.Equal, ParameterByRef.Value);
		
		For Each Row In AdditionalChangeTable Do
			FullMetadataName = Row.FullMetadataName;
			If MetadataNameList <> Undefined And MetadataNameFilter[FullMetadataName] <> True Then
				Continue;
			EndIf;
			
			TablesToAdd = EnlargedMetadataGroupContent(FullMetadataName);
			For Each NameOfTableToAdd In TablesToAdd Do
				If MetadataNameList <> Undefined And MetadataNameFilter[NameOfTableToAdd] <> True Then
					Continue;
				EndIf;
				
				FilterGroup = FilterItems.Add(Type("DataCompositionFilterItemGroup"));
				FilterGroup.Use = True;
				
				AddFilterItem(FilterGroup.Items, "FullMetadataName", DataCompositionComparisonType.Equal, NameOfTableToAdd);
				AddFilterItem(FilterGroup.Items, "RegistrationReason",  DataCompositionComparisonType.Equal, AdditionallyParameter.Value);
				
				If Row.SelectPeriod Then
					StartDate = Row.Period.StartDate;
					EndDate   = Row.Period.EndDate;
					If StartDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "RegistrationObject.Date", DataCompositionComparisonType.GreaterOrEqual, StartDate);
					EndIf;
					If EndDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "RegistrationObject.Date", DataCompositionComparisonType.LessOrEqual, EndDate);
					EndIf;
				EndIf;
				
				// Adding filter items with field replacement: "Ref" -> "RegistrationObject"
				AddingOptions = New Structure;
				AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
				
				AddTabularSectionCompositionAdditionalFilters(
					FilterGroup.Items, Row.Filter.Items, SetItemsChanges, 
					AddingOptions
				);
			EndDo;
		EndDo;
		
	EndIf;
	
	Return New Structure("MetadataTableNodeContent, CompositionSchema, SettingsComposer", 
		MetadataTableNodeContent, CompositionSchema, SettingsComposer);
EndFunction

Procedure AddTabularSectionCompositionAdditionalSets(SourceItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	CompositionSchema  = AddingOptions.CompositionSchema;
	
	CommonSet  = CompositionSchema.DataSets.ChangeRegistration;
	DataSource = CompositionSchema.DataSources[0].Name; 
	
	MetaObject = Metadata.FindByFullName(NameOfTableToAdd);
	If MetaObject = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Incorrect metadata name ""%1"" for registration at node ""%2""'"),
				NameOfTableToAdd, InfobaseNode
			);
		EndIf;
		
	For Each Item In SourceItems Do
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			AddTabularSectionCompositionAdditionalSets(Item.Items, AddingOptions);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind
		FieldName = Item.LeftValue;
		If Left(FieldName, 7) = "Ref." Then
			FieldName = Mid(FieldName, 8);
		ElsIf Left(FieldName, 18) = "RegistrationObject." Then
			FieldName = Mid(FieldName, 19);
		Else
			Continue;
		EndIf;
			
		Position           = Find(FieldName, "."); 
		TableName          = Left(FieldName, Position-1);
		MetaTabularSection = MetaObject.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Filter of header attributes can be retrieved by reference
			Continue;
		ElsIf MetaTabularSection = Undefined Then
			// The tabular section does not match the conditions
			Continue;
		EndIf;
		
		// The tabular section that matches the conditions
		DataPath = Mid(FieldName, Position + 1);
		If Left(DataPath + ".", 7)="Ref." Then
			// Redirecting to the parent table
			Continue;
		Else
			Alias = StrReplace(NameOfTableToAdd, ".", "") + TableName;
			SetName = "Advanced_" + Alias;
			Set = CommonSet.Items.Find(SetName);
			If Set = Undefined Then
				Set = CommonSet.Items.Add(Type("DataCompositionSchemaDataSetQuery"));
				Set.AutoFillAvailableFields = True;
				Set.DataSource              = DataSource;
				Set.Name                    = SetName;
				
				AllTabularSectionFields = TabularSectionAttributesForQuery(MetaTabularSection, Alias);
				Set.Query = "
					|SELECT ALLOWED
					|	Ref                             AS RegistrationObject,
					|	TYPE(" + NameOfTableToAdd + ") AS
					|	RegistrationObjectType, &RegistrationReasonAdvanced AS RegistrationReason
					|	" + AllTabularSectionFields.QueryFields +  "
					|FROM
					|	" + NameOfTableToAdd + "." + TableName + "
					|";
					
				For Each FieldName In AllTabularSectionFields.FieldNames Do
					Field = Set.Fields.Find(FieldName);
					If Field = Undefined Then
						Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
						Field.DataPath = FieldName;
						Field.Field    = FieldName;
					EndIf;
					Field.AttributeUseRestriction.Where = True;
					Field.AttributeUseRestriction.Field = True;
					Field.UseRestriction.Where          = True;
					Field.UseRestriction.Field          = True;
				EndDo;
			EndIf;
			
		EndIf;
		
	EndDo;
		
EndProcedure

Procedure AddTabularSectionCompositionAdditionalFilters(TargetItems, SourceItems, SetItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	MetaObject = Metadata.FindByFullName(NameOfTableToAdd);
	
	For Each Item In SourceItems Do
		// The analysis script fragment is similar to the script fragment
   // in the AddTabularSectionCompositionAdditionalSets procedure
		
		Type = TypeOf(Item);
		If Type = Type("DataCompositionFilterItemGroup") Then
			// Copying filter item
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			
			AddTabularSectionCompositionAdditionalFilters(
				FilterItem.Items, Item.Items, SetItems, 
				AddingOptions
			);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind
		FieldName = String(Item.LeftValue);
		If FieldName = "Ref" Then
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject");
			Continue;
			
		ElsIf Left(FieldName, 7) = "Ref." Then
			FieldName = Mid(FieldName, 8);
			
		ElsIf Left(FieldName, 18) = "RegistrationObject." Then
			FieldName = Mid(FieldName, 19);
			
		Else
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			Continue;
			
		EndIf;
			
		Position = Find(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		MetaTabularSection = MetaObject.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Header attribute filter is retrieved by reference
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject." + FieldName);
			Continue;
			
		ElsIf MetaTabularSection = Undefined Then
			// The specified tabular section does not match the conditions. Adjusting the filter settings.
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue      = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.Use            = True;
			FilterItem.RightValue     = "";
			
			Continue;
		EndIf;
		
		// Setting up filter for a tabular section
		DataPath = Mid(FieldName, Position + 1);
		If Left(DataPath + ".", 7) = "Ref." Then
			// Redirecting to the parent table
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject." + Mid(DataPath, 8));
			
		ElsIf DataPath <> "LineNumber" And DataPath <> "Ref"
			And MetaTabularSection.Attributes.Find(DataPath) = Undefined 
		Then
			// The tabular section is correct but an attribute does not match the conditions. Adjusting the filter settings.
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue      = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.Use            = True;
			FilterItem.RightValue     = "";
			
		Else
			// Modifying filter item name
			FilterItem = TargetItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			DataPath = StrReplace(NameOfTableToAdd + TableName, ".", "") + DataPath;
			FilterItem.LeftValue = New DataCompositionField(DataPath);
		EndIf;
		
	EndDo;
	
EndProcedure

Function TabularSectionAttributesForQuery(Val MetaTabularSection, Val Prefix = "")
	
	QueryFields = ", LineNumber AS " + Prefix + "LineNumber,
	              |Ref AS " + Prefix + "Ref
	              |";
	
	FieldNames  = New Array;
	FieldNames.Add(Prefix + "LineNumber");
	FieldNames.Add(Prefix + "Ref");
	
	For Each MetaAttribute In MetaTabularSection.Attributes Do
		Name        = MetaAttribute.Name;
		Alias       = Prefix + Name;
		QueryFields = QueryFields + ", " + Name + " AS " + Alias + Chars.LF;
		FieldNames.Add(Alias);
	EndDo;
	
	Return New Structure("QueryFields, FieldNames", QueryFields, FieldNames);
EndFunction

//  Returns parameters for saving settings according to an exchange plan for all users.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - exchange node reference for getting settings. 
//                     If not specified, the current InfobaseNode attribute value is used.
//
//  Returns:
//      SettingsDescription - settings details.
//
Function SettingsParameterStructure(ExchangeNode=Undefined)
	Node = ?(ExchangeNode=Undefined,  InfobaseNode, ExchangeNode);
	
	Meta = Node.Metadata();
	
	Presentation = Meta.ExtendedObjectPresentation;
	If IsBlankString(Presentation) Then
		Presentation = Meta.ObjectPresentation;
	EndIf;
	If IsBlankString(Presentation) Then
		Presentation = String(Meta);
	EndIf;
	
	SettingsParameters = New SettingsDescription();
	SettingsParameters.Presentation = Presentation;
	SettingsParameters.ObjectKey    = "InteractiveExportSettingsOptions";
	SettingsParameters.SettingsKey  = Meta.Name;
	SettingsParameters.User         = "*";
	
	Return SettingsParameters;
EndFunction

// Returns a settings list for the current InfobaseNode attribute value.
//
// Parameters:
//      Options - Array - if specified, settings to be restored are
//                filtered according to following options: 
//                0 - no filter, 1 – "All documents" filter, 2 – detailed filter, 3 - node scenario.
//
//  Returns:
//      ValueList - settings.
//
Function ReadSettingsList(Options=Undefined)
	SettingsParameters = SettingsParameterStructure();
	
	SetPrivilegedMode(True);
	VariantList = CommonSettingsStorage.Load(
		SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, 
		SettingsParameters, SettingsParameters.User);
		
	If VariantList = Undefined Then
		Result = New ValueList;
	ElsIf Options = Undefined Then
		Result = VariantList;
	Else
		Result = VariantList;
		Position = Result.Count() - 1;
		While Position >= 0 Do
			If Options.Find(Result[Position].Value.ExportVariant) = Undefined Then
				Result.Delete(Position);
			EndIf;
			Position = Position - 1
		EndDo;
	EndIf;
		
	Return Result;
EndFunction

// Saves a settings list for the current InfobaseNode attribute value.
//
//  Parameters:
//      VariantList - ValueList - option list to be saved.
//
Procedure SaveSettingsList(VariantList)
	SettingsParameters = SettingsParameterStructure();
	
	SetPrivilegedMode(True);
	If VariantList.Count() = 0 Then
		CommonSettingsStorage.Delete(
			SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, SettingsParameters.User);
	Else
		CommonSettingsStorage.Save(
			SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, 
			VariantList, 
			SettingsParameters, SettingsParameters.User);
	EndIf;        
EndProcedure

// Returns a description for a selected export option.
//
Function AdditionalParameterText()
	
	If ExportVariant = 0 Then
		// All automatic data
		Return NStr("en='Export without additional data.'");
		
	ElsIf ExportVariant = 1 Then
		AllDocumentsText = AllDocumentsFilterGroupTitle();
		Result = FilterPresentation(AllDocumentsFilterPeriod, AllDocumentsFilterComposer, AllDocumentsText);
		Return StrReplace(Result, "RegistrationObject.", AllDocumentsText + ".")
		
	ElsIf ExportVariant = 2 Then
		Return DetailedFilterPresentation();
		
	EndIf;
	
	Return "";
EndFunction

// Returns a structure of object attributes.
//
Function ThisObjectInStructureForBackgroundJob()
	ResultStructure = New Structure;
	For Each Meta In Metadata().Attributes Do
		AttributeName = Meta.Name;
		ResultStructure.Insert(AttributeName, ThisObject[AttributeName]);
	EndDo;
	
	// Filling the structure with the AllDocumentsFilterComposer settings, filter only
	ResultStructure.Insert("AllDocumentsFilterComposerSettings", AllDocumentsFilterComposer.Settings);
	
	Return ResultStructure;
EndFunction

Procedure HideSelectionFields(GroupingItems, Val HiddenFields)
	GroupType = Type("DataCompositionSelectedFieldGroup");
	For Each GroupItem In GroupingItems Do
		If TypeOf(GroupItem) = GroupType Then
			HideSelectionFields(GroupItem.Items, HiddenFields)
		Else
			FieldName = StrReplace(String(GroupItem.Field), ".", "");
			If Not IsBlankString(FieldName) And HiddenFields.Property(FieldName) Then
				GroupItem.Use = False;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#EndIf
