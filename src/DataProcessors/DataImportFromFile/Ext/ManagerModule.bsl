#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Reports the details required for importing data from a file.
//
// Returns:
//  Structure - structure with the following properties:
//     * Presentation               - String - presentation in the list of import options.
//     * DataStructureTemplateName  - String – name of the template that stores the
//                                    data structure (optional parameter, default value:
//                                    DataImportFromFile).
//     * MandatoryTemplateColumns   - Array - list of mandatory fields.
//     * MappingColumnHeader	  		 - String - presentation of the mapping column in
//                                    the mapping table header (optional parameter,
//                                    default value: "Catalog: <catalog synonym>").
//     * ObjectName								    - String - object name.
//
Function ImportFromFileParameters(CatalogMetadata = Undefined) Export
	
	MandatoryTemplateColumns = New Array;
	For Each Attribute In CatalogMetadata.Attributes Do
		If Attribute.FillChecking=FillChecking.ShowError Then 
			MandatoryTemplateColumns.Add(Attribute.Name);
 		EndIf;
	EndDo;
		
	DefaultParameters = New Structure;
	DefaultParameters.Insert("Title", CatalogMetadata.Presentation());
	DefaultParameters.Insert("MandatoryColumns", MandatoryTemplateColumns);
	DefaultParameters.Insert("ColumnDataType", New Map);
	Return DefaultParameters;  
EndFunction	

// Reports the details required for importing data from a file to a tabular section.
Function FileToTSImportParameters(TabularSectionName) Export
	
	DefaultParameters= new Structure;
	DefaultParameters.Insert("MandatoryColumns",New Array);
	DefaultParameters.Insert("DataStructureTemplateName","ImportFromFile");
	DefaultParameters.Insert("TabularSectionName", TabularSectionName);
	
	Return DefaultParameters;
	
EndFunction

// Reports the details required for importing data from a file using an external data processor.
//
// Parameters: 
//    CommandName - String - command name (ID).
//    DataProcessorRef - Ref - reference to data processor.
//    DataStructureTemplateName - String – name of the template that stores columns used in data import.
// Returns: 
//  Structure - structure with the following properties:
//     * Presentation              - String - presentation in the list of import options.
//     * DataStructureTemplateName - String – name of the template that stores the data structure (optional parameter, default value: DataImportFromFile).
//     * MandatoryTemplateColumns  - Array - list of mandatory fields.
//     * MappingColumnHeader       - String - presentation of the mapping column in the mapping table header (optional parameter, default value: "Catalog: <catalog synonym>").
//     * ObjectName                - String - object name.
//
Function ParametersOfImportFromFileExternalDataProcessor(CommandName, DataProcessorRef, DataStructureTemplateName) Export
	MandatoryTemplateColumns = New Array;
	
	If Not ValueIsFilled(DataStructureTemplateName) Then 
		DataStructureTemplateName = "ImportFromFile";
	EndIf;
	
	ImportParameters = New Structure;
	ImportParameters.Insert("DataStructureTemplateName", DataStructureTemplateName);
	ImportParameters.Insert("MandatoryTemplateColumns", MandatoryTemplateColumns);
	ImportParameters.Insert("ColumnDataTypeMap", New Map);
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		AdditionalReportsAndDataProcessorsModule = CommonUseClientServer.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = AdditionalReportsAndDataProcessorsModule.GetExternalDataProcessorsObject(DataProcessorRef);
	EndIf;
	
	Try
		ExternalObject.GetDataImportFromFileParameters(CommandName, ImportParameters);
	Except
		// If a function is defined in the external data processor, this overrides the default settings.
	EndTry;
	
	ImportParameters.Insert("Template", ExternalObject.TemplateWithTemplate(ImportParameters.DataStructureTemplateName));
	
	Return ImportParameters;
EndFunction

// Creates a value table with the list of external data processor commands used for importing data from files.  
//
Procedure SetImportCommands(RegistrationParameters) Export
	
	CommandTable = New ValueTable;
	CommandTable.Columns.Add("Presentation", New TypeDescription("String"));
	CommandTable.Columns.Add("ID", New TypeDescription("String"));
	CommandTable.Columns.Add("TemplateWithTemplate", New TypeDescription("String"));
	CommandTable.Columns.Add("MetadataObjectFullName", New TypeDescription("String"));
	
	RegistrationParameters.Insert("ImportCommands", CommandTable);
	
EndProcedure

#Region UtilityFunctions

Procedure InitRefSearchMode(TemplateWithData, ColumnInfo, TypeDescription) Export
	ColumnMap = New Map;
	ColumnHeader = "";
	Separator = "";
	
	For Each Type In TypeDescription.Types() Do 
		MetadataObject = Metadata.FindByType(Type);
		ObjectStructure = SplitFullObjectName(MetadataObject.FullName());
		
		For Each Column In MetadataObject.InputByString Do 
			If ColumnMap.Get(Column.Name) = Undefined Then 
				
				ColumnHeader = ColumnHeader + Separator +Column.Name;
				Separator = ", ";
				ColumnMap.Insert(Column.Name, Column.Name);
			EndIf;
		EndDo;
		If ObjectStructure.ObjectType = "Document" Then 
			ColumnHeader = ColumnHeader + Separator + "Presentation";
		EndIf;
		
		ColumnHeader = "Entered data";
		
	EndDo;
	AddInformationByColumn(ColumnInfo, "References", ColumnHeader, New TypeDescription("String"), False, 1);
	GenerateTemplateForInformationByColumns(ColumnInfo, TemplateWithData);
	
EndProcedure

Procedure MapAutoColumnValue(MappingTable, ColumnName) Export
	
	Types = MappingTable.Columns.MappedObject.ValueType.Types();
 QueryText = "";
	For Each Type In Types Do
		MetadataObject = Metadata.FindByType(Type);
		ObjectStructure = SplitFullObjectName(MetadataObject.FullName());
		
		ColumnArray = New Array;
		For Each Field In MetadataObject.InputByString Do
			ColumnArray.Add(Field.Name);
		EndDo;
		If ObjectStructure.ObjectType = "Document" Then
			ColumnArray.Add("Ref");
		EndIf;
		
		QueryText = QueryString(QueryText, ObjectStructure.ObjectType,
		ObjectStructure.ObjectName, ColumnArray);
	EndDo;
	
	For Each Row In MappingTable Do 
		If Not ValueIsFilled(Row[ColumnName]) Then 
			Continue;
		EndIf;
		
		If ValueIsFilled(QueryText) Then
			Value = DocumentByPresentation(Row[ColumnName], Types);
			If Value = Undefined Then
				Value = Row[ColumnName];
			EndIf;
			ReferenceArray = FindRefsByFilterParameters(QueryText, Value);
			If ReferenceArray.Count() = 1 Then
				Row.MappedObject = ReferenceArray[0];
				Row.RowMappingResult = "StringIsMapped";
			ElsIf ReferenceArray.Count() > 1 Then
				ConflictList = New ValueList;
				Row.ConflictList.LoadValues(ReferenceArray);
				Row.RowMappingResult = "Conflict";
			Else
				Row.RowMappingResult = "Unmapped";
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

function DocumentByPresentation(Presentation, Types)
	
	For Each Type In Types Do 
		MetadataObject = Metadata.FindByType(Type);
		ObjectNameStructure = SplitFullObjectName(MetadataObject.FullName());
		if ObjectNameStructure.ObjectType <> "Document" Then
			Continue;
		EndIf;
		
		StandardAttributes = New Structure("ObjectPresentation, ExtendedObjectPresentation, ListPresentation, ExtendedListPresentation");
		FillPropertyValues(StandardAttributes, MetadataObject);
		
		If ValueIsFilled(StandardAttributes.ObjectPresentation) Then
			ItemPresentation = StandardAttributes.ObjectPresentation;
		ElsIf ValueIsFilled(StandardAttributes.ExtendedObjectPresentation) Then
			ItemPresentation = StandardAttributes.ExtendedObjectPresentation;
		Else
			ItemPresentation = MetadataObject.Presentation();
		EndIf;
		
		If Find(Presentation, ItemPresentation) > 0 Then
			PresentationNumberAndDate = TrimAll(Mid(Presentation, StrLen(ItemPresentation) + 1));
			NumberEndPosition = Find(PresentationNumberAndDate, " ");
			Number = Left(PresentationNumberAndDate, NumberEndPosition - 1);
			PositionFrom = Find(Lower(PresentationNumberAndDate), "Date");
			PresentationDate = TrimL(Mid(PresentationNumberAndDate, PositionFrom + 2));
			DateEndPosition = Find(PresentationDate, " ");
			DateRoundedToDay = Left(PresentationDate, DateEndPosition - 1) + " 00:00:00";
			NumberDocument = Number;
			DocumentDate = ConvertIntoDate(DateRoundedToDay);
		EndIf;
		Document = Documents[MetadataObject.Name].FindByNumber(NumberDocument, DocumentDate);
		
		If Not (Document = Undefined Or Document = Documents[MetadataObject.Name].EmptyRef()) Then
			Return Document;
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

Function ConvertIntoDate(DateString)

	Try
		Return Date(DateString);
	Except
		Return Undefined;
	EndTry;
	
EndFunction 

Function QueryString(QueryText, ObjectType, ObjectName, ColumnArray)
	
	If ColumnArray.Count() > 0 Then
		WhereText = "";
		WhereSeparator = "";
		For Each Field In ColumnArray Do 
			WhereText = WhereText + WhereSeparator + ObjectName + "." + Field + " = &SearchParameter";
			WhereSeparator = " OR ";
		EndDo;
		
		TemplateText = "SELECT %1.Ref AS ObjectRef FROM %2.%1 AS %1 WHERE " + WhereText;
		If ValueIsFilled(QueryText) Then 
			MergeAllText = Chars.LF + "UNION ALL" + Chars.LF;
		Else
			MergeAllText = "";
		EndIf;
		QueryText = QueryText + MergeAllText + StringFunctionsClientServer.SubstituteParametersInString(TemplateText, ObjectName, ObjectType);
	EndIf;
	Return QueryText;
	
EndFunction

Function FindRefsByFilterParameters(QueryText, Value)
	Query = New Query(QueryText);
	Query.SetParameter("SearchParameter", Value);
	
	ResultTable = Query.Execute().Unload();
	ResultArray = ResultTable.UnloadColumn("ObjectRef");
	Return ResultArray;
EndFunction

Procedure CreateCatalogListForImport(CatalogListForImport) Export
	
	StringType = New TypeDescription("String");
	CatalogInfo = New ValueTable;
	CatalogInfo.Columns.Add("MetadataObjectFullName", StringType);
	CatalogInfo.Columns.Add("Presentation", StringType);
	CatalogInfo.Columns.Add("Parameters");
	
	ExceptionCatalogs = ExceptionCatalogList();
	
	For Each MetadataObjectForOutput In Metadata.Catalogs Do
		If ExceptionCatalogs.Find(MetadataObjectForOutput.Name) = Undefined Then
			ImportTypeInformation = New Structure();
			ImportTypeInformation.Insert("Type", "UniversalImport");
			ImportTypeInformation.Insert("MetadataObjectFullName", MetadataObjectForOutput.FullName());
			
			Row = CatalogInfo.Add();
			Row.MetadataObjectFullName = MetadataObjectForOutput.FullName();
			Row.Presentation = MetadataObjectForOutput.Presentation();
			Row.Parameters = ImportTypeInformation;
		EndIf;
	EndDo;
	
	For Each Catalog In Metadata.Catalogs Do
		Manager = Catalogs[Catalog.Name];
		
		If Catalog.Templates.Find("ImportFromFile") <> Undefined Then
			
			ImportParameters = ImportFromFileParameters(Catalog);
			Try
				Manager.GetDataImportFromFileParameters(ImportParameters);
			Except
			EndTry;
			
			CatalogPresentation = ImportParameters.Title;
			ImportTypeInformation = New Structure();
			ImportTypeInformation.Insert("Type", "AppliedImport");
			ImportTypeInformation.Insert("MetadataObjectFullName", Catalog.FullName());
			
			String = CatalogInfo.Find(Catalog.FullName(), "MetadataObjectFullName");
			If String = Undefined Then 
				String = CatalogInfo.Add();
				Row.MetadataObjectFullName = MetadataObjectForOutput.FullName();
				Row.Presentation = CatalogPresentation;
				Row.Parameters = ImportTypeInformation;
			Else
				Row.Parameters = ImportTypeInformation;
				Row.Presentation = CatalogPresentation;
			EndIf;
			
		EndIf;
	EndDo;
	
	If CommonUse.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Query = New Query;
		Query.Text =
		"SELECT
		|	AdditionalReportsAndDataProcessorsCommands.Ref,
		|	AdditionalReportsAndDataProcessorsCommands.ID,
		|	AdditionalReportsAndDataProcessorsCommands.Presentation,
		|	AdditionalReportsAndDataProcessorsCommands.Modifier
		|FROM
		|	Catalog.AdditionalReportsAndDataProcessors.Commands AS AdditionalReportsAndDataProcessorsCommands
		|WHERE
		|	AdditionalReportsAndDataProcessorsCommands.RunningVariant = &RunningVariant
		|	AND AdditionalReportsAndDataProcessorsCommands.Ref.Kind = &Kind
		|	AND Not AdditionalReportsAndDataProcessorsCommands.Ref.DeletionMark
		|	AND AdditionalReportsAndDataProcessorsCommands.Ref.Publication = &Publication";
		Query.SetParameter("RunningVariant", Enums.AdditionalDataProcessorCallMethods.DataImportFromFile);
		Query.SetParameter("Kind", Enums.AdditionalReportAndDataProcessorKinds.AdditionalDataProcessor);
		Query.SetParameter("Publication", Enums.AdditionalReportsAndDataProcessorsPublicationVariants.Used);
		CommandTable = Query.Execute().Unload();
		
		For Each TableRow In CommandTable Do
			ImportTypeInformation = New Structure;
			ImportTypeInformation.Insert("Type", "OuterLoad");
			ImportTypeInformation.Insert("MetadataObjectFullName", TableRow.ID);
			ImportTypeInformation.Insert("Ref", TableRow.Ref);
			ImportTypeInformation.Insert("TemplateWithTemplate", TableRow.Modifier);
			
			String = CatalogInfo.Add();
			Row.MetadataObjectFullName = MetadataObjectForOutput.Name;
			Row.Parameters = ImportTypeInformation;
			Row.Presentation = TableRow.Presentation;
		EndDo;
	EndIf;
	
	CatalogListForImport.Clear();
	For Each Row In CatalogInfo Do 
		CatalogListForImport.Add(Row.Parameters, Row.Presentation);
	EndDo;
		
	CatalogListForImport.SortByPresentation();
	
EndProcedure 

Function ExceptionCatalogList()
	
	ExceptionCatalogs = New Array;
	
	For Each Catalog In Metadata.Catalogs Do
		
		If CatalogContainsExcludeAttribute(Catalog) Then
			Try
				Manager = Catalogs[Catalog.Name];
				If Manager.UseDataImportFromFile() Then
					Continue;
				EndIf;
			Except
				// Import permission function is not defined in the catalog manager module.
			EndTry;
			ExceptionCatalogs.Add(Catalog.Name);
		EndIf;
		
	EndDo;
	
	Return ExceptionCatalogs;
	
EndFunction

Function CatalogContainsExcludeAttribute(Catalog)
	
	For Each Attribute In Catalog.TabularSections Do
		If Attribute.Name <> "ContactInformation" And
			Attribute.Name <> "AdditionalAttributes" And
			Attribute.Name <> "EncryptionCertificates" Then
				Return True;
		EndIf;
	EndDo;
	
	For Each Attribute In Catalog.Attributes Do 
		For Each AttributeType In Attribute.Type.Types() Do
			If AttributeType = Type("ValueStorage") Then
				Return True;
			EndIf;
		EndDo;
	EndDo;
	
	If Title(Left(Catalog.Name, 7)) = "Delete" Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Fills the data mapping value table based on template data.
//
Procedure FillMappingTableWithDataFromTemplateBackground(ExportParameters, StorageAddress) Export
	
	TemplateWithData = ExportParameters.TemplateWithData;
	MappingTable = ExportParameters.MappingTable;
	ColumnInfo = ExportParameters.ColumnInfo;
	
	GetColumnPositionsInTemplate(TemplateWithData, ColumnInfo);
	MappingTable.Clear();
	FillMappingTableWithImportedData(TemplateWithData, ColumnInfo, MappingTable, True);
	
	PutToTempStorage(MappingTable, StorageAddress);
	
EndProcedure

Procedure FillMappingTableWithDataFromTemplate(TemplateWithData, MappingTable, ColumnInfo) Export
	
	GetColumnPositionsInTemplate(TemplateWithData, ColumnInfo);
	MappingTable.Clear();
	FillMappingTableWithImportedData(TemplateWithData, ColumnInfo, MappingTable);
	
EndProcedure

Procedure FillMappingTableWithImportedData(TemplateWithData, InformationByColumnTable, MappingTable, BackgroundJob = False)
	
	For LineNumber = 2 To TemplateWithData.TableHeight Do 
		NewRow = MappingTable.Add();
		NewRow.ID = LineNumber - 1;
		NewRow.RowMappingResult = "No mapping";
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do 
			Cell = TemplateWithData.GetArea(LineNumber, ColumnNumber, LineNumber, ColumnNumber).CurrentArea;
			
			Column = FindInformationAboutColumn(InformationByColumnTable, "Position", ColumnNumber);
			
			If Column <> Undefined Then 
				DataType = TypeOf(NewRow[Column.ColumnName]);
				If DataType <> Type("String") And DataType <> Type("Boolean") And DataType <> Type("Number") And DataType <> Type("Date")  And DataType <> Type("UUID") Then 
					CellData = CellValue(Column, Cell.Text);
				Else
					CellData = Cell.Text;
				EndIf;
				NewRow[Column.ColumnName] = CellData;
			EndIf;
		EndDo;
		
		If BackgroundJob Then
			Percent = Round(LineNumber *100 / TemplateWithData.TableHeight);
			LongActionModule = CommonUseClientServer.CommonModule("LongActions");
			LongActionModule.RegisterProgress(Percent);
		EndIf;
		
	EndDo;
	
EndProcedure

Function FindInformationAboutColumn(InformationByColumnTable, ColumnName, Value)
	Filter = New Structure(ColumnName, Value);
	FoundColumns = InformationByColumnTable.FindRows(Filter);
	Column = Undefined;
	If FoundColumns.Count() > 0 Then 
		Column = FoundColumns[0];
	EndIf;	
	
	Return Column;
EndFunction

Function CellValue(Column, CellValue)
	
	CellData = "";
	For Each DataType In Column.ColumnType.Types() Do 
		Object = Metadata.FindByType(DataType);
		ObjectDescription = SplitFullObjectName(Object.FullName());
		If ObjectDescription.ObjectType = "Catalog" Then
			If Not Object.Autonumbering And Object.CodeLength > 0 Then 
				CellData = Catalogs[ObjectDescription.ObjectName].FindByCode(CellValue, True);
			EndIf;
			If Not ValueIsFilled(CellData) Then 
				CellData = Catalogs[ObjectDescription.ObjectName].FindByDescription(CellValue, True);
			EndIf;
		ElsIf ObjectDescription.ObjectType = "Enum" Then 
			For Each EnumValue In Enums[ObjectDescription.ObjectName] Do 
				If String(EnumValue) = TrimAll(CellValue) Then 
					CellData = EnumValue; 
				EndIf;
			EndDo;
		ElsIf ObjectDescription.ObjectType = "ChartOfAccounts" Then
			CellData = ChartsOfAccounts[ObjectDescription.ObjectName].FindByCode(CellValue);
			If CellData.IsEmpty() Then 
				CellData = ChartsOfAccounts[ObjectDescription.ObjectName].FindByDescription(CellValue, True);
			EndIf;
		ElsIf ObjectDescription.ObjectType = "ChartOfCharacteristicTypes" Then
			If Not Object.Autonumbering And Object.CodeLength > 0 Then 
				CellData = ChartsOfCharacteristicTypes[ObjectDescription.ObjectName].FindByCode(CellValue, True);
			EndIf;
			If Not ValueIsFilled(CellData) Then 
				CellData = ChartsOfCharacteristicTypes[ObjectDescription.ObjectName].FindByDescription(CellValue, True);
			EndIf;
		Else
			CellData = String(CellValue);
		EndIf;
		If ValueIsFilled(CellData) Then 
			Break;
		EndIf;
	EndDo;
	
	Return CellData;
	
EndFunction

Procedure GetColumnPositionsInTemplate(TemplateWithData, ColumnInfo)
	
	TitleArea = TableTemplateTitleArea(TemplateWithData);
	
	ColumnMap = New Map;
	For ColumnNumber = 1 To TitleArea.TableWidth Do 
		Cell=TemplateWithData.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
		ColumnNameInTemplate = Cell.Text;
		ColumnMap.Insert(ColumnNameInTemplate, ColumnNumber);
	EndDo;
	
	For Each Column In ColumnInfo Do 
		Position = ColumnMap.Get(Column.ColumnPresentation);
		If Position <> Undefined Then 
			Column.Position = Position;
		Else
			Column.Position = -1;
		EndIf;
	EndDo;
	
EndProcedure

Function TableTemplateTitleArea(Template)
	MetadataTableTitleArea = Template.Areas.Find("Header");
	
	If MetadataTableTitleArea = Undefined Then 
		TableTitleArea = Template.GetArea("R1");
	Else 
		TableTitleArea = Template.GetArea("Header"); 
	EndIf;
	
	Return TableTitleArea;
	
EndFunction

// Generates a spreadsheet document template based on catalog attributes.
//
Procedure GenerateTemplateByCatalogAttributes(MappingObjectName, TemplateWithData, ColumnInfo) Export
	
	CatalogMetadata= Metadata.FindByFullName(MappingObjectName);
	TemporaryVT = New ValueTable;
	StringTypeDescription = New TypeDescription("String");
	
	Cell = TemplateWithData.GetArea(1, 1, 1, 1);
	NoteText = "";
	
	Position = 1;
	If Not CatalogMetadata.Autonumbering And CatalogMetadata.CodeLength > 0 Then
		CreateStandardAttributesColumn(TemplateWithData, ColumnInfo, CatalogMetadata, Cell, "Code", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.DescriptionLength > 0  Then
		CreateStandardAttributesColumn(TemplateWithData, ColumnInfo, CatalogMetadata, Cell, "Description", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.Hierarchical Then
		 CreateStandardAttributesColumn(TemplateWithData, ColumnInfo, CatalogMetadata, Cell, "Parent", Position);
		 Position = Position + 1;
	EndIf;
	 
	If CatalogMetadata.Owners.Count() > 0 Then
		 CreateStandardAttributesColumn(TemplateWithData, ColumnInfo, CatalogMetadata, Cell, "Owner", Position);
		 Position = Position + 1;
	EndIf;
	
	For Each Attribute In CatalogMetadata.Attributes Do
		
		If Attribute.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		
		ColumnWidth = 20;
		ColumnTypeDescription = "";
		If Attribute.Type.ContainsType(Type("Boolean")) Then 
			ColumnTypeDescription = NStr("en = 'Type: 1 for Yes / 0 for No'");
			ColumnWidth = 3;
		ElsIf Attribute.Type.ContainsType(Type("Number")) Then 
			ColumnTypeDescription =  StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Type: Number, Length: %1, Precision: %2'"),
			String(Attribute.Type.NumberQualifiers.DigitCapacity),
			String(Attribute.Type.NumberQualifiers.FractionDigits));
			ColumnWidth = Attribute.Type.NumberQualifiers.DigitCapacity + 1;
		ElsIf Attribute.Type.ContainsType(Type("String")) Then 
			If Attribute.Type.StringQualifiers.Length > 0 Then 
				StringLength = String(Attribute.Type.StringQualifiers.Length);
				ColumnWidth = ?(Attribute.Type.StringQualifiers.Length > 20, 20, Attribute.Type.StringQualifiers.Length);
			Else
				StringLength = NStr("en = 'Unlimited'");
				ColumnWidth = 20;
			EndIf;
			ColumnTypeDescription =  StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Type: String ( Length: %1 )'"),StringLength);
		ElsIf Attribute.Type.ContainsType(Type("Date")) Then 
			ColumnTypeDescription =  StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Type: %1'"),String(Attribute.Type.DateQualifiers.DateFractions));
			ColumnWidth = 12;
		ElsIf Attribute.Type.ContainsType(Type("UUID")) Then 
			ColumnTypeDescription = NStr("en = 'Type: UUID'");
			ColumnWidth = 20;
		Else
			GetDataByRefTypeColumns(Attribute.Type, ColumnTypeDescription, ColumnWidth);
		EndIf;
		
		If StrLen(Attribute.Name) > ColumnWidth Then 
			ColumnWidth = StrLen(Attribute.Name);
		EndIf;
		
		TemporaryVT.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
		
		// TEMPLATE
		ToolTip = ?(ValueIsFilled(Attribute.ToolTip), Attribute.ToolTip, Attribute.Presentation()) +  Chars.LF + ColumnTypeDescription;
		MandatoryField =  ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
		FillTemplateHeaderCell(Cell, Attribute.Presentation(), ColumnWidth,ToolTip, MandatoryField, Attribute.Name);
		TemplateWithData.Join(Cell);
		
		// Information by columns
		AddInformationByColumn(ColumnInfo, Attribute.Name, Attribute.Presentation(), Attribute.Type, MandatoryField, Position);
		Position = Position + 1;
		
	EndDo;
	
	TemplateWithData.FixedTop = 1;
EndProcedure

Procedure CreateStandardAttributesColumn(TemplateWithData, ColumnInfo, CatalogMetadata, Cell, ColumnName, Position)
	
	Attribute = CatalogMetadata.StandardAttributes[ColumnName];
	Presentation = CatalogMetadata.StandardAttributes[ColumnName].Presentation();
	DataType = CatalogMetadata.StandardAttributes[ColumnName].Type.Types()[0];
	TypeDescription = CatalogMetadata.StandardAttributes[ColumnName].Type;
	
	ColumnWidth = 11;
	
	If DataType = Type("String") Then 
		TypePresentation = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'String (up to %1 characters)"), TypeDescription.StringQualifiers.Length);
		ColumnWidth = ?(TypeDescription.StringQualifiers.Length < 30, TypeDescription.StringQualifiers.Length + 1, 30);
	ElsIf DataType = Type("Number") Then	
		TypePresentation = NStr("en = 'Number'");
	Else
		If CatalogMetadata.StandardAttributes[ColumnName].Type.Types().Count() = 1 Then 
			TypePresentation = String(DataType); 
		Else
			TypePresentation = "";
			Separator = "";
			For Each DataType In CatalogMetadata.StandardAttributes[ColumnName].Type.Types() Do 
				TypePresentation = TypePresentation  + Separator + String(DataType);
				Separator = " or ";
			EndDo;
		EndIf;
	EndIf;
	NoteText = Attribute.ToolTip + Chars.LF + TypePresentation;
	
	FillTemplateHeaderCell(Cell, ColumnName, ColumnWidth , NoteText, True, Attribute.Name);
	TemplateWithData.Join(Cell);
	
	ObligatoryForFilling = ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
	AddInformationByColumn(ColumnInfo, ColumnName, Presentation, TypeDescription, ObligatoryForFilling, Position);
	
EndProcedure

Procedure GetDataByRefTypeColumns(DataType, ToolTipText, Width)
	
	ObjectMetadata=Metadata.FindByType(DataType.Types()[0]);	
	
	ObjectStructure = SplitFullObjectName(ObjectMetadata.FullName());
	
	If ObjectStructure.ObjectType = "Catalog" Then 
		ToolTipText = ObjectMetadata.Explanation;
		Width = 15;
		BunchText = Chars.LF;
		If Not ObjectMetadata.Autonumbering And ObjectMetadata.CodeLength > 0  Then	
			Width = ObjectMetadata.CodeLength + 1;
			
			CodeToolTipText = ObjectMetadata.StandardAttributes.Code.ToolTip;
			If Type(ObjectMetadata.CodeType) = Type("String") Then 
				TypeDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'String (up to %1 characters)'"), ObjectMetadata.CodeLength);
			Else	
				TypeDescription = NStr("en = 'Number'");
			EndIf;
			ToolTipText = ToolTipText  + Chars.LF + CodeToolTipText + " (" + TypeDescription + ")";
			BunchText = NStr("en = ' or '") + Chars.LF;
		EndIf;
		
		If ObjectMetadata.DescriptionLength > 0  Then
			If ObjectMetadata.DescriptionLength > Width Then
				Width = ?(ObjectMetadata.DescriptionLength > 30, 30, ObjectMetadata.DescriptionLength + 1);
			EndIf;
			
			CodeToolTipText = ObjectMetadata.StandardAttributes.Description.ToolTip;
			If Type(ObjectMetadata.CodeType) = Type("String") Then 
				TypeDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'String (up to %1 characters)'"), ObjectMetadata.DescriptionLength);
			Else	
				TypeDescription = NStr("en = 'Number'");
			EndIf;
			ToolTipText  = ToolTipText + BunchText + CodeToolTipText + " (" + TypeDescription + ")";
		EndIf;
	ElsIf ObjectStructure.ObjectType = "Enum" Then 
		ToolTipText = NStr("en = 'Available column values:'") + Chars.LF;
		For Each Value In ObjectMetadata.EnumValues Do
			ToolTipText = ToolTipText + " " + Value.Synonym + Chars.LF;
		EndDo;
	EndIf;
	
EndProcedure

Procedure FillTemplateHeaderCell(Cell, Text, Width, ToolTip, MandatoryField, Name = "") Export
	
	Cell.CurrentArea.Text = Text;
	Cell.CurrentArea.Name = Name;
	Cell.CurrentArea.DetailsParameter = Name;
	Cell.CurrentArea.BackColor =  StyleColors.ReportHeaderBackColor;
	Cell.CurrentArea.ColumnWidth = Width;
	Cell.CurrentArea.Comment.Text = ToolTip;
	If MandatoryField Then 
		Cell.CurrentArea.Font = New Font(,,True);	
	Else
		Cell.CurrentArea.Font = New Font(,,False);	
	EndIf;
	
EndProcedure	

// Fills the table with complete information about template columns. This information is used for generating a mapping table.
Procedure CreateInformationByColumnsBasedOnTemplate(TableTitleArea, ColumnDataTypeMap, ColumnInfo) Export 
	
	For ColumnNumber = 1 to TableTitleArea.TableWidth Do
		Cell = TableTitleArea.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
		
		If Find(Cell.Name, "R") > 0 And Find(Cell.Name, "C") > 0 Then 
			AttributeName = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
			AttributePresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.DetailsParameter);
			Association = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
		Else	
			AttributeName = Cell.Name;
			AttributePresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.Name);
			Association = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Name);
		EndIf;
		
		ColumnDataType = New TypeDescription("String");
		If ColumnDataTypeMap <> Undefined Then 
			ColumnDataTypeOverridden = ColumnDataTypeMap.Get(AttributeName);
			If ColumnDataTypeOverridden <> Undefined Then 
				ColumnDataType = ColumnDataTypeOverridden;
			EndIf;
		EndIf;
		
		If ValueIsFilled(AttributeName) Then 
			AddInformationByColumn(ColumnInfo, AttributeName, AttributePresentation, ColumnDataType,
				Cell.Font.Bold, ColumnNumber, Association);
		EndIf;
	EndDo;
	
EndProcedure

Procedure AddInformationByColumn(ColumnInfo, Name, Presentation, Type, MandatoryForFilling, Position, Association = "")
	ColumnInfoRow = ColumnInfo.Add();
	ColumnInfoRow.ColumnName = Name;
	ColumnInfoRow.ColumnPresentation = Presentation;
	ColumnInfoRow.ColumnType = Type;
	ColumnInfoRow.MandatoryForFilling = MandatoryForFilling;
	ColumnInfoRow.Position = Position;
	ColumnInfoRow.Association = ?(ValueIsFilled(Association), Association, Name);
EndProcedure

Procedure FilterDataByRefs(TemplateWithData, ColumnInfo, ImportDataAddress) Export
	
EndProcedure

// Creates a value table based on the template data and stores it to a temporary storage. 
//
Procedure ExportDataForTS(TemplateWithData, ColumnInfo, ImportDataAddress) Export
	
	ImportData = New ValueTable;
	
	TitleArea = TableTemplateTitleArea(TemplateWithData);
	
	For Each Column In ColumnInfo Do 
		ImportData.Columns.Add(Column.ColumnName, New TypeDescription("String"), Column.ColumnPresentation);
	EndDo;
	NumberTypeDescription = New TypeDescription("Number");
	StringTypeDescription = New TypeDescription("String");
	ImportData.Columns.Add("ID",NumberTypeDescription, "ID");
	ImportData.Columns.Add("RowMappingResult",StringTypeDescription, "Result");
	ImportData.Columns.Add("ErrorDescription",StringTypeDescription, "Reason");
	
	For LineNumber = 2 To TemplateWithData.TableHeight Do 
		NewRow = ImportData.Add();
		NewRow.ID =  LineNumber - 1;
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do 
			Cell = TemplateWithData.GetArea(LineNumber,ColumnNumber,LineNumber,ColumnNumber).CurrentArea;
			
			FoundColumn = FindInformationAboutColumn(ColumnInfo, "Position", ColumnNumber);

			If FoundColumn <> Undefined Then 
				ColumnName = FoundColumn.ColumnName; 
				NewRow[ColumnName] = Cell.Text; 
			EndIf;
		EndDo;
	EndDo;
	
	ImportDataAddress = PutToTempStorage(ImportData);
EndProcedure

Procedure InitializeImportToTabularSection(TabularSectionFullName, DataStructureTemplateName, ColumnInfo, TemplateWithData, Cancel) Export
	ObjectName = SplitFullObjectName(TabularSectionFullName);
	
	Try
		ImportFromFileParameters = FileToTSImportParameters(TabularSectionFullName);
	Except
	EndTry;
	
	If ObjectName.ObjectType = "Document" Then 
		ObjectManager = Documents[ObjectName.ObjectName];
		TSMetadata = Metadata.Documents[ObjectName.ObjectName].TabularSections[ObjectName.TabularSectionName];
		
		Try
			ObjectManager.SetFileToTSImportParameters(ImportFromFileParameters);
		Except
		EndTry;
		
		ImportParameters = ImportFromFileParameters;
		MetadataTemplate = Metadata.Documents[ObjectName.ObjectName].Templates.Find(DataStructureTemplateName);
		
		MetadataTemplate= Metadata.Documents[ObjectName.ObjectName].Templates.Find("ImportFromFile"+ObjectName.TabularSectionName);
		If MetadataTemplate = Undefined Then 
			MetadataTemplate = Metadata.Documents[ObjectName.ObjectName].Templates.Find("ImportFromFile");
		EndIf;
		
		If MetadataTemplate <> Undefined Then
			Template = ObjectManager.GetTemplate(MetadataTemplate.Name);
		Else
			Cancel = True;
			Return;
		EndIf;
		
		TableTitle = TableTemplateTitleArea(Template);
		CreateInformationByColumnsBasedOnTemplate(TableTitle, Undefined, ColumnInfo);
		
		For Each Attribute In TSMetadata.Attributes Do
			
			Column = FindInformationAboutColumn(ColumnInfo, "ColumnName", Attribute.Name);
			
			If Column <> Undefined Then 
				Column.ColumnType = Attribute.Type;
				If Attribute.FillChecking = FillChecking.ShowError Then 
					Column.ObligatoryForFilling = True;
				EndIf;
			EndIf;
		EndDo;	
		
		TemplateWithData.Output(TableTitle);
	EndIf; 
	
EndProcedure

Procedure GenerateTemplateForInformationByColumns(ColumnInfo, Template) Export

	SimpleTemplate = DataProcessors.DataImportFromFile.GetTemplate("SimpleTemplate");
	AreaTitle = SimpleTemplate.GetArea("Title");
	For Each Column In ColumnInfo Do 
		AreaTitle.Parameters.Title = Column.ColumnPresentation;
		AreaTitle.CurrentArea.ColumnWidth = StrLen(Column.ColumnPresentation) + 5;
		Template.Join(AreaTitle);
	EndDo;
	
EndProcedure

Function FullTabularSectionObjectName(ObjectName) Export
	
	Result = StringFunctionsClientServer.SplitStringIntoSubstringArray(ObjectName,".");
	If Result.Count() = 4 Then
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
	ElsIf Result.Count() = 3 Then
		If Result[2] <> "TabularSection" Then 
			ObjectName = Result[0] + "." + Result[1] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
		ElsIf Result[1] = "TabularSection" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		
		Return Undefined;
	ElsIf Result.Count() = 2 Then
		If Result[0] <> "Document" or Result[0] <> "Catalog" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		MetadataObjectName = Result[0];
		TabularSectionName = Result[1];
		MetadataObjectType = Metadata.Catalogs.Find(MetadataObjectName);
		If MetadataObjectType <> Undefined Then 
			MetadataObjectType = "Catalog";
		Else
			MetadataObjectType = Metadata.Documents.Find(MetadataObjectName);					
			If MetadataObjectType <> Undefined Then 
				MetadataObjectType = "Document";
			Else 
				Return Undefined;
			EndIf;
		EndIf;
	EndIf;
	
	Return Undefined;	
	
EndFunction

// Returns an object name as a structure.
//
// Parameters:
// FullObjectName - Structure - object name. 
//    * ObjectType         - String - object type. 
//    * ObjectName         - String - object name. 
//    * TabularSectionName - String - tabular section name.
Function SplitFullObjectName(FullObjectName) Export
	Result = StringFunctionsClientServer.SplitStringIntoSubstringArray(FullObjectName, ".");
	
	ObjectName = New Structure;
	ObjectName.Insert("ObjectType");
	ObjectName.Insert("ObjectName");
	ObjectName.Insert("TabularSectionName");
	
	If Result.Count() = 2 Then
		If Result[0] = "Document" Or Result[0] = "Catalog" Or Result[0] = "BusinessProcess" Or
			Result[0] = "Enum" Or Result[0] = "ChartOfCharacteristicTypes" Or Result[0] = "ChartOfAccounts" Then
			ObjectName.ObjectType = Result[0];
			ObjectName.ObjectName = Result[1];
		Else
			 ObjectName.ObjectType = GetMetadataObjectTypeByName(Result[0]);
			 ObjectName.ObjectName = Result[0];
			 ObjectName.TabularSectionName = Result[1];
		EndIf;
	ElsIf Result.Count() = 3 Then
		ObjectName.ObjectType = Result[0];
		ObjectName.ObjectName = Result[1];
		ObjectName.TabularSectionName = Result[2];
	ElsIf Result.Count() = 4 Then 
		ObjectName.ObjectType = Result[0];
		ObjectName.ObjectName = Result[1];
		ObjectName.TabularSectionName = Result[3];
	ElsIf Result.Count() = 1 Then
		ObjectName.ObjectType = GetMetadataObjectTypeByName(Result[0]);
		ObjectName.ObjectName = Result[0];
	EndIf;

	Return ObjectName;
	
EndFunction

Function GetMetadataObjectTypeByName(Name)
	For Each Object In Metadata.Catalogs Do 
		If Object.Name = Name Then 
			Return "Catalog";
		EndIf;
	EndDo;
	
	For Each Object In Metadata.Documents Do 
		If Object.Name = Name Then 
			Return "Document";
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Procedure FillTableByImportedDataFromFile(DataFromFile, TemplateWithData, ColumnInfo) Export 
	
	StringHeader = DataFromFile.Get(0);
	ColumnMap = New Map;
	
	For Each Column In DataFromFile.Columns Do
		FoundColumn = FindInformationAboutColumn(ColumnInfo, "ColumnPresentation", StringHeader[Column.Name]);
		If FoundColumn <> Undefined Then 
			ColumnMap.Insert(FoundColumn.Position, Column.Name);	
		EndIf;
	EndDo;
	
	For Index= 1 To DataFromFile.Count()-1 Do
		VTRow = DataFromFile.Get(Index);
		
		For ColumnNumber =1 to TemplateWithData.TableWidth Do 
			Column = ColumnMap.Get(ColumnNumber);
			Cell = TemplateWithData.GetArea(2, ColumnNumber, 2, ColumnNumber);
			If Column<>Undefined Then 
				Cell.CurrentArea.Text = VTRow[Column];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Else
				Cell.CurrentArea.Text = "";
			EndIf;
			If ColumnNumber=1 Then
				TemplateWithData.Output(Cell);
			else
				TemplateWithData.Join(Cell);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

#Region Excel2007FileFormatImport

Procedure ImportExcel2007FileIntoTable(PathToFile, TemplateWithData, ColumnInfo) Export
	File = New File(PathToFile);
	If Not File.Exist() Then
		Return;
	EndIf;
	
	ExcelFile = PathToFile;
	TemporaryDirectory = TempFilesDir() + GetPathSeparator() + "excel2007";
	DeleteFiles(TemporaryDirectory);
	
	UnzipFile(ExcelFile, TemporaryDirectory);
	
	RowFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() +"sharedStrings.xml";
	RowList = ReadRowList(RowFile);
	
	FormatFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() +"styles.xml";
	FormatList = ReadFormatList(FormatFile);
	
	WorksheetNumber = 1;
	SheetFile = TemporaryDirectory + GetPathSeparator() + "xl" + GetPathSeparator() + "worksheets" + GetPathSeparator() + "sheet" + WorksheetNumber + ".xml";
	File = New File(SheetFile);
	If Not File.Exist() Then
		Return;
	EndIf;
	
	LetterArray = GetLetterArray();
	DataTree = GetDataTree(SheetFile);
	
	Table = New ValueTable;
	
	// Creating columns
	Columns = DataTree.Rows.Find("dimension", "Object", True);
	Counter = 0;   
	For Each Row In Columns.Rows Do
		If Row.Object = "ref" Then
			Range = Row.Value; 
			// Searching for maximum column value
			Counter = LetterArray.Count();
			While Counter > 0 Do 
				Counter = Counter - 1;
				If Find(Range, LetterArray[Counter]) > 0 Then
					For Index = 0 To Counter Do               
						Table.Columns.Add(LetterArray[Index]);
					EndDo;   
					Counter = 0;
				EndIf;   
			EndDo;
			Break;
		EndIf;
	EndDo;
	
	
	// Reading rows
	RowStr = DataTree.Rows.Find("sheetdata", "Object", True);
	For Each Row In RowStr.Rows Do
		NewRow = Table.Add();
		
		For Each Column In Row.Rows Do
			If Column.Object <> "c" Then
				Continue;
			EndIf;
			
			CellValue = Undefined;
			
			ValueStr = Column.Rows.Find("v", "Object");
			If ValueStr <> Undefined Then
				CellValue = ValueStr.Value;
			EndIf;
			
			ValueStr = Column.Rows.Find("t", "Object");
			If ValueStr <> Undefined And ValueStr.Value = "s" And CellValue <> Undefined Then
				CellValue = RowList.Get(Number(CellValue)).Value;
			EndIf;
			
			ValueStr = StringToNumber(Column.Rows.Find("s", "Object").Value, -1);
			If ValueStr >= 0 Then
				FormatName = FormatList.Get(ValueStr);
				If FormatName = "Date" Or FormatName = "DateTime" Or FormatName = "Time" Then
					SeparatorPosition = Find(CellValue, ".");
					If SeparatorPosition > 0 Then 
						DayCount = StringToNumber(Left(CellValue, SeparatorPosition - 1)) * 86400 - 2 * 86400;
						SecondsCount = StringToNumber(Mid(CellValue, SeparatorPosition + 1)) - 2 * 60;
					Else
						DayCount = StringToNumber(CellValue) * 86400 - 2 * 86400;
						SecondsCount = 0;
					EndIf;
					ReceivedDate = Date(1900, 1, 1, 0, 0, 0) + DayCount + SecondsCount;
					If FormatName = "Date" Then 
						CellValue = Format(ReceivedDate, "DLF=D");
					ElsIf FormatName = "DateTime" Then 
						CellValue = Format(ReceivedDate, "DLF=DT");
					ElsIf FormatName = "Time" Then 
						CellValue = Format(ReceivedDate, "DLF=T");
					EndIf;
				ElsIf FormatName = "Number" Then
					CellValue = StringToNumber(CellValue);
				EndIf;
			EndIf;

			// Searching for column
			ValueStr = Column.Rows.Find("r", "Object");
			If ValueStr <> Undefined Then
				ColumnName = ValueStr.Value;
			EndIf;
			LineIndex = Undefined;
			Counter = LetterArray.Count();
			While Counter > 0 Do 
				Counter = Counter - 1;
				If Find(ColumnName, LetterArray[Counter])>0 Then
					LineIndex = Counter;
					Counter = 0;
				EndIf;   
			EndDo;
			
			NewRow[LetterArray[LineIndex]] = CellValue;
		EndDo;
	EndDo;
	
	FillTableByImportedDataFromFile(Table, TemplateWithData, ColumnInfo);
	
EndProcedure

Procedure UnzipFile(File, Directory)
	Zip = New ZipFileReader;
	Zip.Open(File);
	Zip.ExtractAll(Directory, ZIPRestoreFilePathsMode.Restore);
EndProcedure

Function GetLetterArray()
	LetterArray = New Array;
	LetterArray.Add("A");
	LetterArray.Add("B");
	LetterArray.Add("C");
	LetterArray.Add("D");
	LetterArray.Add("E");
	LetterArray.Add("F");
	LetterArray.Add("G");
	LetterArray.Add("H");
	LetterArray.Add("I");
	LetterArray.Add("J");
	LetterArray.Add("K");
	LetterArray.Add("L");
	LetterArray.Add("M");
	LetterArray.Add("N");
	LetterArray.Add("O");
	LetterArray.Add("P");
	LetterArray.Add("Q");
	LetterArray.Add("R");
	LetterArray.Add("S");
	LetterArray.Add("T");
	LetterArray.Add("U");
	LetterArray.Add("V");
	LetterArray.Add("W");
	LetterArray.Add("X");
	LetterArray.Add("Y");
	LetterArray.Add("Z");
	
	Return LetterArray;
EndFunction

Function ReadRowList(RowFile)
	Rows = New ValueList;
	
	Xml = New XMLReader;
	Xml.OpenFile(RowFile);
	
	While Xml.Read() Do
		If Xml.NodeType = XMLNodeType.Text Then
			Rows.Add(Xml.Value);
		EndIf;
	EndDo;
	
	Xml.Close();
	
	Return Rows;
EndFunction

Function GetDataTree(File)
	
	DataTree = New ValueTree;
	DataTree.Columns.Add("Object");
	DataTree.Columns.Add("Value");
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(File);
	
	CurItem = Undefined;
	CurBase = Undefined;
	
	While XMLReader.Read() Do
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ImportMode = XMLReader.Name;
			
			If CurItem = Undefined Then
				CurItem = DataTree.Rows.Add();
				CurItem.Object = ImportMode;
			Else
				CurItem = CurItem.Rows.Add();
				CurItem.Object = ImportMode;					
			EndIf;
			
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			If CurItem = Undefined Then
				CurItem = Undefined;
			Else
				CurItem = CurItem.Parent;
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			CurItem.Value = XMLReader.Value;
		EndIf;
		
		For Index = 0 To XMLReader.AttributeCount() - 1 Do
			Row = CurItem.Rows.Add();
			Row.Object = XMLReader.AttributeName(Index);
			Row.Value = XMLReader.AttributeValue(Index);
		EndDo;
	EndDo;
	
	XMLReader.Close();
	
	Return DataTree;
EndFunction
Function ReadFormatList(FormatFile)
	
	Xml = New XMLReader;
	Xml.OpenFile(FormatFile);
	FormatDescription = New Map;
	Position = -1;
	
	While Xml.Read() Do
		If Xml.NodeType = XMLNodeType.StartElement and Xml.Name = "xf" Then
			// http://social.msdn.microsoft.com/Forums/office/en-US/e27aaf16-b900-4654-8210-83c5774a179c/xlsx-numfmtid-predefined-id-14-doesnt-match?forum=oxmlsdk
			FormatNumber =  Number(Xml.AttributeValue("numFmtId"));
			If FormatNumber > 0 And FormatNumber < 12 Then
				FormatDescription.Insert(Position, "Number");
			ElsIf FormatNumber > 13 And FormatNumber <= 17 Then
				FormatDescription.Insert(Position, "Date");
			ElsIf FormatNumber >= 18 And FormatNumber <= 21 Then
				FormatDescription.Insert(Position, "Time");
			ElsIf FormatNumber = 22 Or FormatNumber = 165 Or FormatNumber = 166 Then
				FormatDescription.Insert(Position, "DateTime");
			Else 
				FormatDescription.Insert(Position, "String");
			EndIf;
			Position = Position + 1;
		EndIf;
	EndDo;
	
	Xml.Close();
	
	Return FormatDescription;
	
EndFunction

// Converts a string to a number without raising exceptions. The standard conversion function 
// Number() checks whether the string only contains numeric characters.
//
Function StringToNumber(SourceString, DefaultValue = 0)
	StringIntoNumber = New Map;
	For Value = 0 To 9 Do
		StringIntoNumber.Insert(String(Value), Value);
	EndDo;
	
	Result = 0;
	For Index = 1 To StrLen(SourceString) Do
		LastDigit = StringIntoNumber.Get(Mid(SourceString, Index, 1));
		If LastDigit <> Undefined Then
			Result = Result * 10 + LastDigit;
		EndIf;
	EndDo;
	
	Return ?(Result = 0, DefaultValue, Result);
EndFunction


#EndRegion 

#Region CSVFileOperations 

Procedure ImportFileToTable(ServerCallParameters, StorageAddress) Export
	
	Extension = ServerCallParameters.Extension;
	TemplateWithData = ServerCallParameters.TemplateWithData;
	TempFileName = ServerCallParameters.TempFileName;
	ColumnInfo = ServerCallParameters.ColumnInfo;
	
	If Extension = "xlsx" Then 
		ImportExcel2007FileIntoTable(TempFileName, TemplateWithData, ColumnInfo);
	ElsIf Extension = "csv" Then 
		ImportCSVFileIntoTable(TempFileName, TemplateWithData, ColumnInfo);
	Else
		TemplateWithData.Read(TempFileName);
	EndIf;
	
	StorageAddress = PutToTempStorage(TemplateWithData, StorageAddress);
	
EndProcedure

Procedure ImportCSVFileIntoTable(FileName, TemplateWithData, ColumnInfo) Export
	
	File = new File(FileName);
	If Not File.Exist() Then 
		Return;
	EndIf;
	
	TextReader = New TextReader(FileName);
	String = TextReader.ReadLine();
	If String = Undefined Then 
		MessageText = NStr("en = 'Cannot import data from the file. Make sure the file contains valid data.'");
		Return;
	EndIf;
	
	HeaderColumns = StringFunctionsClientServer.SplitStringIntoWordArray(String, ";");
	Source = New ValueTable;
	
	
	For Each Column In HeaderColumns Do 
		
		FoundColumn = FindInformationAboutColumn(ColumnInfo, "ColumnPresentation", Column);
		
		If FoundColumn <> Undefined Then 
			NewColumn = Source.Columns.Add();
			NewColumn.Name = FoundColumn.ColumnName; 
			NewColumn.Title = Column;	
		EndIf;
	EndDo;
	
	If Source.Columns.Count() = 0 Then
		Return;
	EndIf;
	
	While String <> Undefined Do 
		NewRow = Source.Add();
		Position = Find(String, ";");
		Index = 0;
		While Position > 0 Do
			If Source.Columns.Count() < Index + 1  Then 
				Break;
			EndIf;
			NewRow[Index] = Left(String, Position - 1);
			String = Mid(String, Position + 1);
			Position = Find(String, ";");
			Index = Index + 1; 
		EndDo;
		If Source.Columns.Count() = Index + 1  Then 
			NewRow[Index] = String;
		EndIf;

		String = TextReader.ReadLine();
	EndDo;
	
	FillTableByImportedDataFromFile(Source, TemplateWithData, ColumnInfo);
	
EndProcedure

Procedure SaveTableToCSVFile(PathToFile, ColumnInfo) Export
	
	HeaderFormatForCSV = "";
	
	For Each Column In ColumnInfo Do 
		HeaderFormatForCSV = HeaderFormatForCSV + Column.ColumnPresentation + ";";
	EndDo;
	
	If StrLen(HeaderFormatForCSV) > 0 Then
		HeaderFormatForCSV = Left(HeaderFormatForCSV, StrLen(HeaderFormatForCSV)-1);
	EndIf;
	
	File = New TextWriter(PathToFile);
	File.WriteLine(HeaderFormatForCSV);
	File.Close();
	
EndProcedure

#EndRegion

#Region LongActions

Procedure PrepareDataForFill(DocumentParameters, StorageAddress) Export
 
	DataForFill = New Structure;
	DataForFill.Insert("Implementation", PrepareRealizationSectionData(DocumentParameters));
	PutToTempStorage(DataForFill, StorageAddress);
 
EndProcedure

Function  PrepareRealizationSectionData(_in)
	
EndFunction


Procedure WriteMappedData(ExportParameters, StorageAddress) Export
	
	MappedData = ExportParameters.MappedData;
	MappingObjectName =ExportParameters.MappingObjectName;
	ImportParameters = ExportParameters.ImportParameters;
	ColumnInfo = ExportParameters.ColumnInfo;
	
	CreateIfNotMapped = ImportParameters.CreateIfNotMapped;
	UpdateExistingItems = ImportParameters.UpdateExistingItems;
	
	StringType = New TypeDescription("String");
	
	CatalogName = SplitFullObjectName(MappingObjectName).ObjectName;
	CatalogManager = Catalogs[CatalogName];
	
	LineNumber = 0;
	TotalRows = MappedData.Count();
	For Each TableRow In MappedData Do 
		LineNumber = LineNumber + 1;
		Try
			BeginTransaction();
			If Not ValueIsFilled(TableRow.MappingObject) Then 
				If CreateIfNotMapped Then 
					ItemCatalog = CatalogManager.CreateItem();
					TableRow.MappingObject = ItemCatalog;
					TableRow.RowMappingResult = "Created";
				Else
					TableRow.RowMappingResult = "Skipped";
					SetProgressPercentage(TotalRows, LineNumber);
					Continue;
				EndIf;
			Else
				If Not UpdateExistingItems Then 
					TableRow.RowMappingResult = "Skipped";
					SetProgressPercentage(TotalRows, LineNumber);
					Continue;
				EndIf;
				
				DataLock = New DataLock;
				LockItem = DataLock.Add("Catalog." + CatalogName);
				LockItem.SetValue("Ref", TableRow.MappingObject);
				
				ItemCatalog = TableRow.MappingObject.GetObject();
				TableRow.RowMappingResult = "Updated";
				If ItemCatalog = Undefined Then
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
     // Universal product code (UPC)
					NStr("en = 'Product with UPC %1 does not exist.'"), TableRow.SKU);
					Raise MessageText;
				EndIf;
			EndIf;
			
			For Each Column In ColumnInfo Do 
				ItemCatalog[Column.ColumnName] = TableRow[Column.ColumnName];
			EndDo;
			
			If ItemCatalog.CheckFilling() Then 
				ItemCatalog.Write();
				CommitTransaction();
			Else
				TableRow.RowMappingResult = "Skipped";
				UserMessages = GetUserMessages(True);
				
				If UserMessages.Count() > 0 Then 
					MessageText = "";
					For Each UserMessage In UserMessages Do
						MessageText = messageText + UserMessage.Text + Chars.LF;
					EndDo;
					TableRow.ErrorDescription = MessageText;
				EndIf;
			
				RollbackTransaction();

			EndIf;
			
			SetProgressPercentage(TotalRows, LineNumber);
		Except
			RollbackTransaction();
			TableRow.RowMappingResult = "Skipped";
			TableRow.ErrorDescription = NStr("en = 'Cannot save invalid data'");
		EndTry;
	
	EndDo;
	
	StorageAddress = PutToTempStorage(MappedData, StorageAddress);
	
EndProcedure

Procedure SetProgressPercentage(Total, LineNumber)
	Percent = LineNumber * 50 / Total;
	LongActionModule = CommonUseClientServer.CommonModule("LongActions");
	LongActionModule.RegisterProgress(Percent);
EndProcedure

Procedure GenerateReportOnBackgroundImport(ExportParameters, StorageAddress) Export
	
	ReportTable = ExportParameters.ReportTable;
	MappedData  = ExportParameters.MappedData;
	ColumnInfo  = ExportParameters.ColumnInfo;
	TemplateWithData = ExportParameters.TemplateWithData;
	ReportType = ExportParameters.ReportType;
	CalculateProgressPercentage = ExportParameters.CalculateProgressPercentage;
	
	If Not ValueIsFilled(ReportType) Then
		ReportType = "AllItems";
	EndIf;
	
	GenerateReportTemplate(ReportTable, TemplateWithData);
	
	TitleArea = TableTemplateTitleArea(ReportTable);
	
	CreatedItemsCount = 0;
	UpdatedItemsCount = 0;
	SkippedItemsCount = 0;
	SkippedItemsWithErrorCount = 0;
	For LineNumber = 1 To MappedData.Count() Do
		Row = MappedData.Get(LineNumber - 1);
		
		Cell = ReportTable.GetArea(LineNumber + 1, 1, LineNumber + 1, 1);
		Cell.CurrentArea.Text = Row.RowMappingResult;
		Cell.CurrentArea.Details = Row.MappingObject;
		Cell.CurrentArea.Comment.Text = Row.ErrorDescription;
		If Row.RowMappingResult = "Created" Then 
			Cell.CurrentArea.TextColor = StyleColors.SuccessResultColor;
			CreatedItemsCount = CreatedItemsCount + 1;
		ElsIf Row.RowMappingResult = "Updated" Then
			Cell.CurrentArea.TextColor = StyleColors.ModifiedAttributeValueColor;
			UpdatedItemsCount = UpdatedItemsCount + 1;
		Else
			Cell.CurrentArea.TextColor = StyleColors.ErrorInformationText;
			SkippedItemsCount = SkippedItemsCount + 1;
			If ValueIsFilled(Row.ErrorDescription) Then
				SkippedItemsWithErrorCount = SkippedItemsWithErrorCount + 1;
			EndIf;
		EndIf;
		
		If ReportType = "New" And Row.RowMappingResult <> "Created" Then
			Continue;
		EndIf;
		
		If ReportType = "Updated" And Row.RowMappingResult <> "Updated" Then 
			Continue;
		EndIf;
		
		If ReportType = "Skipped" And Row.RowMappingResult <> "Skipped" Then 
			Continue;
		EndIf;
		
		ReportTable.Put(Cell);
		For Index = 1 To ColumnInfo.Count() Do 
			Cell = ReportTable.GetArea(LineNumber + 1, Index + 1, LineNumber + 1, Index + 1);
			
			Filter = New Structure("Position", Index);
			FoundColumns = ColumnInfo.FindRows(Filter);
			If FoundColumns.Count() > 0 Then 
				ColumnName = FoundColumns[0].ColumnName;
				Cell.CurrentArea.Details = Row.MappingObject;
				Cell.CurrentArea.Text = Row[ColumnName];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			EndIf;
			ReportTable.Join(Cell);
			
		EndDo;
		
		If CalculateProgressPercentage Then 
			Percent = Round(LineNumber * 50 / MappedData.Count()) + 50;
			LongActionModule = CommonUseClientServer.CommonModule("LongActions");
			LongActionModule.RegisterProgress(Percent);
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("ReportType", ReportType);
	Result.Insert("Total", MappedData.Count());
	Result.Insert("Created", CreatedItemsCount);
	Result.Insert("Updated", UpdatedItemsCount);
	Result.Insert("Skipped", SkippedItemsCount);
	Result.Insert("Invalid", SkippedItemsWithErrorCount);
	Result.Insert("ReportTable", ReportTable);
	
	StorageAddress = PutToTempStorage(Result, StorageAddress); 
	
EndProcedure

Procedure GenerateReportTemplate(ReportTable, TemplateWithData)
	
	ReportTable.Clear();
	Cell = TemplateWithData.GetArea(1, 1, 1, 1);
	
	TableHeader = TemplateWithData.GetArea("R1");
	FillTemplateHeaderCell(Cell, NStr("en ='Result'"), 12, NStr("en ='Data import result'"), True);
	ReportTable.Join(TableHeader); 
	ReportTable.InsertArea(Cell.CurrentArea, ReportTable.Area("C1"), SpreadsheetDocumentShiftType.Horizontal);
	
	ReportTable.FixedTop = 1;
EndProcedure


#EndRegion

#EndRegion

#EndIf