
////////////////////////////////////////////////////////////////////////////////
//  OBJECT MODULE OF THE REPORT "REPORT ON CHANGE"
//  CONTAINS FUNCTIONS FOR GENERATING THE REPORT BY OBJECT DIMENSIONS,
//  AND ALSO FUNCTIONS FOR DESERIALIZATION AND PREPARATION OF OBJECT PRESENTATION
//

// Filled when generating a report by the spreadsheet document from the template "Common_Template" of the report
Var Common_Template;

////////////////////////////////////////////////////////////////////////////////
//  SECTION OF EXPORT FUNCTIONS

// Module main export function, that generates the report.
// Depending on the number of versions in the array runs either functionality
// of report generation by one version, or functionality of report generation
// by dimensions between several versions.
//
Procedure GenerateReport(ReportTS, Val VersionsList) Export
	
	Common_Template = Reports.ReportByVersions.GetTemplate("StandardTemplateOfObjectPresentation");
	
	VersionsArray = New Array;
	For Each VersionID In VersionsList Do
		VersionsArray.Add(VersionID.Value);
	EndDo;
	
	If VersionsArray.Count() = 1 Then
		GenerateReportByObjectVersion(ReportTS, VersionsArray[0]);
	Else
		GenerateChangesReport(ReportTS, VersionsArray);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for generating the report by some object

// Function is used for generating the report by object version
//
// Parameters:
// ReportTS  - SpreadsheetDocument - spreadsheet document, where report will be output
// VersionID - String/Number - object version number
//
Procedure GenerateReportByObjectVersion(ReportTS, VersionID)
	
	ReportTS.Clear();
	
	ObjectDescription = ObjectReference.Metadata().Name;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(ObjectReference)) Then
		If Metadata.Catalogs[ObjectDescription].Templates.Find("ObjectTemplate") <> Undefined Then
			Template = Catalogs[ObjectDescription].GetTemplate("ObjectTemplate");
		Else
			Template = Undefined;
		EndIf;
	Else
		If Metadata.Documents[ObjectDescription].Templates.Find("ObjectTemplate") <> Undefined Then
			Template = Documents[ObjectDescription].GetTemplate("ObjectTemplate");
		Else
			Template = Undefined;
		EndIf;
	EndIf;
	
	VersionDetails = GetDescriptionByVersion(VersionID);
	
	If Template <> Undefined Then
		FormationByStandardTemplate(ReportTS,
		                                 Template,
		                                 GetObjectFromXML(SaveFileByVersion(VersionID)),
		                                 VersionDetails);
	Else
		ObjectVersion = VersionParsing(VersionID, ObjectReference);
		
		Section = ReportTS.GetArea("R2");
		OutputTextToReport(ReportTS, Section, "R2c2", ObjectReference.Metadata().Synonym,,,16, True);
		
		///////////////////////////////////////////////////////////////////////////////
		// output list of modified attributes
		
		ReportTS.Area("C2").ColumnWidth = 30;
		OutputHeaderByVersion(ReportTS, VersionDetails, 3);
		NumberOfPutRows = OutputAttributesByParsedObject(ReportTS, ObjectVersion);
		NumberOfPutRows = OutputTabularSectionsByParsedObject(ReportTS, ObjectVersion, NumberOfPutRows+7);
	EndIf;
	
EndProcedure

// Generates report by object, using standard template.
//
// Parameters:
// ReportTS 		 - SpreadsheetDocument - spreadsheet document, where report will be output
// ObjectVersion 	 - CatalogObject,DocumentObject - object, whose data has to displayed in the report
// ObjectDescription - String - object description
//
Procedure FormationByStandardTemplate(ReportTS, Template, ObjectVersion, Val VersionDetails)
	
	ObjectMetadata = ObjectReference.Metadata();
	
	ObjectDescription = ObjectMetadata.Name;
	
	ReportTS = New SpreadsheetDocument;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(ObjectReference)) Then
		Template = Catalogs[ObjectDescription].GetTemplate("ObjectTemplate");
	Else
		Template = Documents[ObjectDescription].GetTemplate("ObjectTemplate");
	EndIf;
	
	// Title
	Area = Template.GetArea("Title");
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R3");
	SetTextProperties(Area.Area("R1c2"), VersionDetails, , , , True);
	ReportTS.Put(Area);
	
	Area = ReportTS.GetArea("R5");
	ReportTS.Put(Area);
	
	// Header
	Header = Template.GetArea("Header");
	Header.Parameters.Fill(ObjectVersion);
	ReportTS.Put(Header);
	
	For Each TSMetadata In ObjectMetadata.TabularSections Do
		If ObjectVersion[TSMetadata.Name].Count() > 0 Then
			Area = Template.GetArea(TSMetadata.Name+"Header");
			ReportTS.Put(Area);
			
			AreaDetailsJoiningItem = Template.GetArea(TSMetadata.Name);
			For Each CurRowStockItemReceiptDetails In ObjectVersion[TSMetadata.Name] Do
				AreaDetailsJoiningItem.Parameters.Fill(CurRowStockItemReceiptDetails);
				ReportTS.Put(AreaDetailsJoiningItem);
			EndDo;
		EndIf;
	EndDo;
	
	ReportTS.ShowGrid = False;
	ReportTS.Protection = True;
	ReportTS.ReadOnly = True;
	ReportTS.ShowHeaders = False;
	
EndProcedure

// Outputs modified attributes to the report. And get their presentation.
//
Function OutputAttributesByParsedObject(ReportTS, ObjectVersion)
	
	Section = ReportTS.GetArea("R6");
	OutputTextToReport(ReportTS, Section, "R1c1:R1c3", " ");
	OutputTextToReport(ReportTS, Section, "R1c2", "Attributes", , , 11, True);
	ReportTS.StartRowGroup("AttriburesGroup");
	OutputTextToReport(ReportTS, Section, "R1c1:R1c3", " ");
	
	NumberOfRowsToPut = 0;
	
	For Each ItemAttribute In ObjectVersion.Attributes Do
		
		AttributeDescription = GetAttributePresentationInLanguage(ItemAttribute.AttributeDescription);
		
		AttributeDetails = ObjectReference.Metadata().Attributes.Find(AttributeDescription);
		
		If AttributeDetails = Undefined Then
			For Each StandardAttributeDescription In ObjectReference.Metadata().StandardAttributes Do
				If StandardAttributeDescription.Name = AttributeDescription Then
					AttributeDetails = StandardAttributeDescription;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		DetailsValue = ?(ItemAttribute.DetailsValue = Undefined, "", ItemAttribute.DetailsValue);
		
		If ValueIsFilled(ItemAttribute.AttributeType) Then
			OutputDescription = AttributeDescription;
			ValuePresentation = CastToPresentationByTypeAndValue(
			                           ItemAttribute.AttributeType,
			                           DetailsValue);
		ElsIf (AttributeDetails <> Undefined) Then
			OutputDescription = ?(ValueIsFilled(AttributeDetails.Synonym), AttributeDetails.Synonym, AttributeDetails.Name);
			AttributeTypeDetails = AttributeDetails.Type;
			// trying to find direct map
			ValuePresentation = 
					GeneratePresentationByTypeDescription(AttributeTypeDetails,
					                                        DetailsValue);
		Else
			OutputDescription = AttributeDescription;
		EndIf;
		
		SetTextProperties(Section.Area("R1c2"), OutputDescription, ,WebColors.White, , True);
		SetTextProperties(Section.Area("R1c3"), ValuePresentation);
		Section.Area("R1c2:R1c3").BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 1, 0);
		Section.Area("R1c2:R1c3").BorderColor = New Color (200,200,200);
		
		ReportTS.Put(Section);
		
		NumberOfRowsToPut = NumberOfRowsToPut + 1;
	EndDo;
	
	ReportTS.EndRowGroup();
	
	Return NumberOfRowsToPut;
	
EndFunction

// Outputs tabular sections by the disassembled object, on output of the single object
//
Function OutputTabularSectionsByParsedObject(ReportTS, ObjectVersion, OutputLineNumber);
	
	NumberOfRowsToPut = 0;
	
	If ObjectVersion.TabularSections.Count() <> 0 Then
		
		For Each RowTabularSection In ObjectVersion.TabularSections Do
			TabularSectionDescription  = RowTabularSection.Key;
			TabularSection             = RowTabularSection.Value;
			If TabularSection.Count() > 0 Then
				
				TSMetadata = ObjectReference.Metadata().TabularSections[TabularSectionDescription];
				TSSynonym = TSMetadata.Synonym;
				TSSynonym = ?(ValueIsFilled(TSSynonym), TSSynonym, TabularSectionDescription);
				
				Section = ReportTS.GetArea("R" + String(OutputLineNumber));
				OutputTextToReport(ReportTS, Section, "R1c1:R1c3", " ");
				OutputTextToReport(ReportTS, Section, "R1c2", TSSynonym, , , 11, True);
				ReportTS.StartRowGroup("GroupOfRows");
				OutputTextToReport(ReportTS, Section, "R1c1:R1c3", " ");
				
				NumberOfRowsToPut = NumberOfRowsToPut + 1;
				
				OutputLineNumber = OutputLineNumber + 3;
				
				AddedTS = New SpreadsheetDocument;
				
				AddedTS.Join(GenerateEmptySector(TabularSection.Count()+1));
				
				ColumnNumber = 2;
				
				MapOfColumnsDimensions = New Map;
				
				Section = New SpreadsheetDocument;
				
				SetTextProperties(Section.Area("R1c1"),"N", ,WebColors.LightGray, , True, True);
				
				LineNumber = 1;
				For Each TabularSectionRow In TabularSection Do
					LineNumber = LineNumber + 1;
					SetTextProperties(Section.Area("R" + LineNumber + "C1"), String(LineNumber-1), ,WebColors.White,,,True);
				EndDo;
				AddedTS.Join(Section);
				
				ColumnNumber = 3;
				
				For Each TabularSectionColumn In TabularSection.Columns Do
					Section 				= New SpreadsheetDocument;
					FieldDescription 		= TabularSectionColumn.Name;
					FieldDetails 	= TSMetadata.Attributes.Find(FieldDescription);
					If FieldDetails = Undefined Or Not ValueIsFilled(FieldDetails.Synonym) Then
						OutputFieldDescription = FieldDescription;
					Else
						OutputFieldDescription = FieldDetails.Synonym;
					EndIf;
					ColumnHeaderColor = ?(FieldDetails = Undefined, WebColors.VioletRed, WebColors.LightGray);
					SetTextProperties(Section.Area("R1c1"),
											 OutputFieldDescription, ,ColumnHeaderColor, , True, True);
					MapOfColumnsDimensions.Insert(ColumnNumber, StrLen(FieldDescription) + 4);
					LineNumber = 1;
					For Each TabularSectionRow In TabularSection Do
						LineNumber = LineNumber + 1;
						Value = ?(TabularSectionRow[FieldDescription] = Undefined, "", TabularSectionRow[FieldDescription]);
						If FieldDetails <> Undefined Then
							ValuePresentation = GeneratePresentationByTypeDescription(FieldDetails.Type, Value);
						Else
							ValuePresentation = Value;
						EndIf;
						SetTextProperties(Section.Area("R" + LineNumber + "C1"), ValuePresentation, ,WebColors.White,,,True);
						If StrLen(ValuePresentation) > (MapOfColumnsDimensions[ColumnNumber] - 4) Then
							MapOfColumnsDimensions[ColumnNumber] = StrLen(ValuePresentation) + 4;
						EndIf;
					EndDo; // For Each TabularSectionRow In TabularSection Do
					
					AddedTS.Join(Section);
					ColumnNumber = ColumnNumber + 1;
				EndDo; // For Each TabularSectionColumn In TabularSection.Columns Do
				
				OutputArea = ReportTS.Put(AddedTS);
				ReportTS.Area("R"+OutputArea.Top+"C1:R"+OutputArea.Bottom+"C"+ColumnNumber).CreateFormatOfRows();
				ReportTS.Area("R"+OutputArea.Top+"C2").ColumnWidth = 7;
				For ColumnCurrentNumber = 3 To ColumnNumber-1 Do
					ReportTS.Area("R"+OutputArea.Top+"C"+ColumnCurrentNumber).ColumnWidth = MapOfColumnsDimensions[ColumnCurrentNumber];
				EndDo;
				ReportTS.EndRowGroup();
				
			EndIf; // If TabularSection.Quantity() > 0 Then
		EndDo; // For Each RowTabularSection In ObjectVersion.TabularSections Do
		
	EndIf;
	
EndFunction

// Outputs report header on output the report by object version
//
Procedure OutputHeaderByVersion(ReportTS, Val Text, Val ColumnNumber)
	
	ReportTS.Area("C"+String(ColumnNumber)).ColumnWidth = 50;
	
	State = "R4c"+String(ColumnNumber);
	ReportTS.Area(State).Text 			= Text;
	ReportTS.Area(State).BackColor 	= WebColors.LightGray;
	ReportTS.Area(State).Font 			= New Font(, 8, True, , , );
	ReportTS.Area(State).TopBorder 	= New Line(SpreadsheetDocumentCellLineType.Solid);
	ReportTS.Area(State).BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
	ReportTS.Area(State).LeftBorder  	= New Line(SpreadsheetDocumentCellLineType.Solid);
	ReportTS.Area(State).RightBorder 	= New Line(SpreadsheetDocumentCellLineType.Solid);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for generating the report by dimensions

// Main managing function for generation the report by dimensions.
// Has three stages:
// 1. Get XML presentation of object stored versions. Generate
//    special data structures for the object comparison.
// 2. Get
//
Procedure GenerateChangesReport(ReportTS, Val VersionsArray)
	
	// Stores transitional disassembled object version,
	// to minimize the number XML parsings
	Var ObjectVersion;
	
	// "End-to-end" id of modified strings in versions
	Var counterUniqueId;
	
	ReportTS.Clear();
	
	// Generates the array of version numbers (as some of them could be missing
	// and have inconsecutive numeration), array is sorted ascending.
	VersionNumbersArray = VersionsArray;
	
	// Number of object versions stored in db (k).
	// To generate the report it's required to make (k-1) comparisions.
	// Practically this means, that dimension tables will have (k) columns
	//ObjectVersionsCount = VersionsCount;
	ObjectVersionsCount = VersionNumbersArray.Count();
	
	// Stores inside all attribute changes, has to dimensionality:
	// first (lines) contains values of the descriptions of object attributes
	// second (columns) contains an object version identification and a characteristic
	// of change of version changes identification - this is the string that definitely identifies
	// object version among others and reports additional data about modification
	AttributesChangesTable = New ValueTable;
	PrepareColumnsOfAttributeChangesTables(AttributesChangesTable, VersionNumbersArray);
	
	// Stores inside changes of the tabular sections as maps of names
	// of tabular sections of the object of changes history of this value table
	// each map - is a tabular section
	// first (lines) contains description values of tabular section fields
	// second (columns) contains object version identification
	// version identification this is the string that definitely identifies object version
	// among others and reports additional data about modification
	TableOfChangesOfTabularSections = New Map;
	
	// generate object initial versions, whose values are always shown
	// (if there are further changes)
	ObjectVersion_Prev = ReadInitialAttributeValuesAndTabularSections(
	                               AttributesChangesTable,
	                               TableOfChangesOfTabularSections,
	                               ObjectVersionsCount,
	                               VersionNumbersArray);
	
	counterUniqueId = GetUniqueUniqueId(TableOfChangesOfTabularSections, "Ver" + VersionNumbersArray[0]);
	
	For VersionIndex = 2 To VersionNumbersArray.Count() Do
		VersionNo = VersionNumbersArray[VersionIndex-1];
		PreviousVersionNumber = "Ver" + (Number(VersionNumbersArray[VersionIndex-2]));
		CurrentVersionColumnName = "Ver" + VersionNo;
		
		ComparisonResult = CalculateChanges(VersionNo, ObjectVersion_Prev, ObjectVersion);
		
		ChangAttr 	= ComparisonResult["Attributes"]["i"];
		AddAttrib 	= ComparisonResult["Attributes"]["d"];
		DelAtt 		= ComparisonResult["Attributes"]["u"];
		
		// fill report table by the attributes
		FillAttributeChangeCharacteristic(ChangAttr, "I", AttributesChangesTable, CurrentVersionColumnName, ObjectVersion);
		FillAttributeChangeCharacteristic(AddAttrib, "D", AttributesChangesTable, CurrentVersionColumnName, ObjectVersion);
		FillAttributeChangeCharacteristic(DelAtt, "U", AttributesChangesTable, CurrentVersionColumnName, ObjectVersion);
		
		// Changes in tabular sections
		ChangTS = ComparisonResult["TabularSections"]["i"];
		
		// This functionality is not being implemented so far
		AddTS = ComparisonResult["TabularSections"]["d"];
		DelTS = ComparisonResult["TabularSections"]["u"];
		
		For Each MapItem In ObjectVersion.TabularSections Do
			TableName = MapItem.Key;
			
			If ValueIsFilled(AddTS.Find(TableName))
			 Or ValueIsFilled(DelTS.Find(TableName)) Then
				Continue;
			EndIf;
			
			TableOfChangesOfTabularSections[TableName][CurrentVersionColumnName] = 
			        ObjectVersion.TabularSections[TableName].Copy();
			RefToTableVersion = TableOfChangesOfTabularSections[TableName][CurrentVersionColumnName];
			RefToTableVersion.Columns.Add("_RowId");
			RefToTableVersion.FillValues(Undefined, "_RowId");
			RefToTableVersion.Columns.Add("_Modification");
			RefToTableVersion.FillValues(Undefined, "_Modification");
			TableWithChanges = ChangTS.Get(TableName);
			If TableWithChanges <> Undefined Then
				ChangTS_RowsI = TableWithChanges["I"];
				ChangTS_RowsD = TableWithChanges["D"];
				ChangTS_RowsU = TableWithChanges["U"];
				
				DimensionInTS0 = ObjectVersion_Prev.TabularSections[TableName].Count();
				If DimensionInTS0 = 0 Then
					MarkedInTS0 = New Array;
				Else
					MarkedInTS0 = New Array(DimensionInTS0);
				EndIf;
				
				DimensionInTS1 = ObjectVersion.TabularSections[TableName].Count();
				If DimensionInTS1 = 0 Then
					MarkedInTS1 = New Array;
				Else
					MarkedInTS1 = New Array(DimensionInTS1);
				EndIf;
				
				For Each TSItem In ChangTS_RowsI Do
					RowOfTCTS = TableOfChangesOfTabularSections[TableName][PreviousVersionNumber][TSItem.IndexInTS0-1];
					RefToTableVersion[TSItem.IndexInTS1-1]._RowId = RowOfTCTS._RowId;
					RefToTableVersion[TSItem.IndexInTS1-1]._Modification = "I";
				EndDo;
				
				For Each TSItem In ChangTS_RowsD Do
					RefToTableVersion[TSItem.IndexInTS1-1]._RowId = IncrementCounter(counterUniqueId, TableName);
					RefToTableVersion[TSItem.IndexInTS1-1]._Modification = "D";
				EndDo;
				
				// Need to fill UniqueID(correlate with the previous version) for all items
				For IndexOf = 1 To RefToTableVersion.Count() Do
					If RefToTableVersion[IndexOf-1]._RowId = Undefined Then
						// found row, and we need to find map for this row in previous table
						TSLine = RefToTableVersion[IndexOf-1];
						
						FilterParameters = New Structure;
						For Each CollectionItem In RefToTableVersion.Columns Do
							If (CollectionItem.Name <> "_RowId") And (CollectionItem.Name <> "_Modification") Then
								FilterParameters.Insert(CollectionItem.Name, TSLine[CollectionItem.Name]);
							EndIf;
						EndDo;
						CurrentTSRowsArray = RefToTableVersion.FindRows(FilterParameters);
						PreviousTSRowsArray = TableOfChangesOfTabularSections[TableName][PreviousVersionNumber].FindRows(FilterParameters);
						
						For IndByVT_Current = 1 To CurrentTSRowsArray.Count() Do
							If IndByVT_Current <= PreviousTSRowsArray.Count() Then
								CurrentTSRowsArray[IndByVT_Current-1]._RowId = PreviousTSRowsArray[IndByVT_Current-1]._RowId;
							EndIf;
							CurrentTSRowsArray[IndByVT_Current-1]._Modification = False;
						EndDo;
					EndIf;
				EndDo;
				For Each TSItem In ChangTS_RowsU Do
					StringImaginary = RefToTableVersion.Add();
					StringImaginary._RowId = TableOfChangesOfTabularSections[TableName][PreviousVersionNumber][TSItem.IndexInTS0-1]._RowId;
					StringImaginary._Modification = "U";
				EndDo;
			EndIf;
		EndDo;
		ObjectVersion_Prev = ObjectVersion;
	EndDo;
	
	// pass composed information into the special lock to output data into the report
	OutputCompositionResultsToReport(AttributesChangesTable,
	                                  TableOfChangesOfTabularSections,
	                                  counterUniqueId,
	                                  VersionNumbersArray,
	                                  ReportTS);
	
	TemplateLegend = Common_Template.GetArea("Legend");
	ReportTS.Put(TemplateLegend);
	
EndProcedure

Procedure OutputAttributeChanges(ReportTS,
                                     AttributesChangesTable,
                                     VersionNumbersArray)
	
	AreaAttributesHeader = Common_Template.GetArea("AttributesHeader");
	ReportTS.Put(AreaAttributesHeader);
	ReportTS.StartRowGroup("AttriburesGroup");
	
	For Each ItemModAttribute In AttributesChangesTable Do
		If ItemModAttribute._Modification = True Then
			// get attribute name
			AttributeDescription = ItemModAttribute.Description;
			// output description, replacing it to another one before, if it is predefined
			OutputDescription = GetAttributePresentationInLanguage(AttributeDescription);
			
			AttributeDetails = ObjectReference.Metadata().Attributes.Find(OutputDescription);
			
			If AttributeDetails = Undefined Then
				For Each StandardAttributeDescription In ObjectReference.Metadata().StandardAttributes Do
					If StandardAttributeDescription.Name = GetAttributePresentationInLanguage(AttributeDescription) Then
						AttributeDetails = StandardAttributeDescription;
						Break;
					EndIf;
				EndDo;
			EndIf;
			
			EmptyCell = Common_Template.GetArea("EmptyCell");
			ReportTS.Put(EmptyCell);;
			
			AttributeDescription = Common_Template.GetArea("FieldsAttributeDescription");
			AttributeDescription.Parameters.FieldsAttributeDescription = OutputDescription;
			ReportTS.Join(AttributeDescription);
			
			IndexByAttributeVersions = VersionNumbersArray.Count();
			
			While IndexByAttributeVersions >= 1 Do
				StructureChangeCharacteristic = ItemModAttribute["Ver"+VersionNumbersArray[IndexByAttributeVersions-1]];
				
				AttributeValuePresentation = "";
				DetailsValue = "";
				Update = Undefined;
				ValueType = "";
				
				// if in current version attribute has not been modified, then skip it to the next version
				If TypeOf(StructureChangeCharacteristic) = Type("String") Then
					DetailsValue = StructureChangeCharacteristic;
					
					If (AttributeDetails <> Undefined) Then
						AttributeTypeDetails = AttributeDetails.Type;
						// trying to find direct map
						AttributeValuePresentation =
								GeneratePresentationByTypeDescription(AttributeTypeDetails,
							                                        DetailsValue);
					EndIf;
																
				ElsIf StructureChangeCharacteristic <> Undefined Then
					If StructureChangeCharacteristic.ChangeType = "U" Then
					Else
						DetailsValue = StructureChangeCharacteristic.Value.DetailsValue;
						ValueType = StructureChangeCharacteristic.Value.AttributeType;
						If ValueIsFilled(ValueType) Then
							AttributeValuePresentation = 
									CastToPresentationByTypeAndValue(
									                ValueType,
									                DetailsValue);
						ElsIf (AttributeDetails <> Undefined) Then
							AttributeTypeDetails = AttributeDetails.Type;
							// trying to find direct map
							AttributeValuePresentation =
									GeneratePresentationByTypeDescription(AttributeTypeDetails,
																			DetailsValue);
						EndIf;
					EndIf;
					// get attribute modification structure in the current version
					Update = StructureChangeCharacteristic.ChangeType;
				EndIf;
				
				If AttributeValuePresentation = "" Then
					AttributeValuePresentation = DetailsValue;
					If AttributeValuePresentation = "" Then
						AttributeValuePresentation = " ";
					EndIf;
				EndIf;
				
				If      Update = Undefined Then
					AreaAttributeValue = Common_Template.GetArea("InitialAttributeValue");
					AreaAttributeValue.Parameters.DetailsValue = AttributeValuePresentation;
				ElsIf Update = "I" Then
					AreaAttributeValue = Common_Template.GetArea("ModifiedAttributeValue");
					AreaAttributeValue.Parameters.DetailsValue = AttributeValuePresentation;
				ElsIf Update = "U" Then
					AreaAttributeValue = Common_Template.GetArea("DeletedAttribute");
					AreaAttributeValue.Parameters.DetailsValue = AttributeValuePresentation;
				ElsIf Update = "D" Then
					AreaAttributeValue = Common_Template.GetArea("AddedAttribute");
					AreaAttributeValue.Parameters.DetailsValue = AttributeValuePresentation;
				EndIf;
				
				ReportTS.Join(AreaAttributeValue);
				
				IndexByAttributeVersions = IndexByAttributeVersions - 1;
			EndDo;
		EndIf; // If ItemModAttribute._Modification = True Then
	EndDo;
	
	ReportTS.EndRowGroup();
	
EndProcedure

Procedure OutputChangesTableSections(ReportTS,
                                          TableOfChangesOfTabularSections,
                                          VersionNumbersArray,
                                          counterUniqueId)
	
	TabularSectionsSectionsOutputTitle = False;
	
	TemplateEmptyRow = Common_Template.GetArea("FreeString");
	TemplateNextTSLine = Common_Template.GetArea("TabularSectionRowHeader");
	
	ReportTS.Put(TemplateEmptyRow);
	
	// loop over all modified attribs
	For Each ItemModifiedTS In TableOfChangesOfTabularSections Do
		TabularSectionName = ItemModifiedTS.Key;
		CurrentTSVersions = ItemModifiedTS.Value;
		
		CurrentTabularSectionChanged = False;
		
		For CurCounterUniqueId = 1 To CounterUniqueId[TabularSectionName] Do
			
			StringUniqueIdChanged = False;
			// in case if modification was found, need to show original version,
			// from which all changes have began
			BeginningVersionFilled = False;
			
			// search by all modification versions by current row (UniqueID = CurCounterUniqueId)
			// if row has been deleted, then search can be stopped and we can move to the next
			// row, first highlighting "deleted" with the color of the deleted entity
			IndexByVersions = VersionNumbersArray.Count();
			
			// ---------------------------------------------------------------------------------
			// check versions on front, to be sure, that there will be some changes ---
			
			StringModified = False;
			
			While IndexByVersions >= 1 Do
				TSVersionCurrentColumn = "Ver"+VersionNumbersArray[IndexByVersions-1];
				VersionCurrentTS = CurrentTSVersions[TSVersionCurrentColumn];
				StringFound = VersionCurrentTS.Find(CurCounterUniqueId, "_RowId");
				If StringFound <> Undefined Then
					If (StringFound._Modification <> Undefined) Then
						If (TypeOf(StringFound._Modification) = Type("String")
							OR (TypeOf(StringFound._Modification) = Type("Boolean")
							      And StringFound._Modification = True)) Then
							StringModified = True;
						EndIf;
					EndIf;
				EndIf;
				IndexByVersions = IndexByVersions - 1;
			EndDo;
			
			If Not StringModified Then
				Continue;
			EndIf;
			
			// ---------------------------------------------------------------------------------
			
			// start to output versions into the spreadsheet document
			IndexByVersions = VersionNumbersArray.Count();
			
			IntervalBetweenFillins = 0;
			
			// Loop over all versions. Tying to find changes by row in every version
			// by its UniqueID.
			While IndexByVersions >= 1 Do
				IntervalBetweenFillins = IntervalBetweenFillins + 1;
				TSVersionCurrentColumn = "Ver"+VersionNumbersArray[IndexByVersions-1];
				// tabular section of the current version (value table with the modification flags)
				VersionCurrentTS = CurrentTSVersions[TSVersionCurrentColumn];
				StringFound = VersionCurrentTS.Find(CurCounterUniqueId, "_RowId");
				
				// in the next version row change was found (it can be the first change from the end)
				If StringFound <> Undefined Then
					
					// lock for output of header of section of all tabulat sections
					If Not TabularSectionsSectionsOutputTitle Then
						TabularSectionsSectionsOutputTitle = True;
						TemplateCommonHeaderOFTSSection = Common_Template.GetArea("TabularSectionsHeader");
						ReportTS.Put(TemplateCommonHeaderOFTSSection);
						ReportTS.StartRowGroup("TableSectionsGroup");
						ReportTS.Put(TemplateEmptyRow);
					EndIf;
					
					// lock for output of header of the current tabular section that is being processed now
					If Not CurrentTabularSectionChanged Then
						CurrentTabularSectionChanged = True;
						TemplateHeaderOfCurrentTS = Common_Template.GetArea("TabularSectionHeader");
						TemplateHeaderOfCurrentTS.Parameters.TabularSectionDescription = TabularSectionName;
						ReportTS.Put(TemplateHeaderOfCurrentTS);
						ReportTS.StartRowGroup("TabularSection"+TabularSectionName);
						ReportTS.Put(TemplateEmptyRow);
					EndIf;
					
					Modification = StringFound._Modification;
					
					If StringUniqueIdChanged = False Then
						StringUniqueIdChanged = True;
						
						TemplateTSRowHeader = Common_Template.GetArea("TabularSectionRowHeader");
						TemplateTSRowHeader.Parameters.TabularSectionRowNumber = CurCounterUniqueId;
						ReportTS.Put(TemplateTSRowHeader);
						ReportTS.StartRowGroup("GroupOfRows"+TabularSectionName+CurCounterUniqueId);
						
						OutputType = "";
						If Modification = "U" Then
							OutputType = "U"
						EndIf;
						FillArray = New Array;
						For Each Column In VersionCurrentTS.Columns Do
							If Column.Name = "_RowId"
							 Or Column.Name = "_Modification" Then
								Continue;
							EndIf;
							FillArray.Add(Column.Name);
						EndDo;
						
						EmptySector = GenerateEmptySector(VersionCurrentTS.Columns.Count()-2);
						EmptyFillableSector = GenerateEmptySector(VersionCurrentTS.Columns.Count()-2, OutputType);
						Section = GenerateTSRowSector(FillArray, OutputType);
						
						ReportTS.Join(EmptySector);
						ReportTS.Join(Section);
					EndIf;
					
					While IntervalBetweenFillins > 1 Do
						ReportTS.Join(EmptyFillableSector);
						IntervalBetweenFillins = IntervalBetweenFillins - 1;
					EndDo;
					
					IntervalBetweenFillins = 0;
					
					// filling next modified table string now
					FillArray = New Array;
					For Each Column In VersionCurrentTS.Columns Do
						If Column.Name = "_RowId"
						 Or Column.Name = "_Modification" Then
							Continue;
						EndIf;
						
						Value = StringFound[Column.Name];
						
						TableFieldDetails = ObjectReference.Metadata().TabularSections.Find(TabularSectionName).Attributes.Find(Column.Name);
						Presentation = DefinePresentation(Value, Column.Name, TableFieldDetails);
						FillArray.Add(Presentation);
						
					EndDo;
					
					If TypeOf(Modification) = Type("Boolean") Then
						OutputType = "";
					Else
						OutputType = Modification;
					EndIf;
					
					Section = GenerateTSRowSector(FillArray, OutputType);
					
					ReportTS.Join(Section);
					
				EndIf; // StringFound <> Undefined
				IndexByVersions = IndexByVersions - 1;
			EndDo;
			
			If StringUniqueIdChanged Then
				ReportTS.EndRowGroup();
				ReportTS.Put(TemplateEmptyRow);
			EndIf;
			
		EndDo;
		
		If CurrentTabularSectionChanged Then
			ReportTS.EndRowGroup();
			ReportTS.Put(TemplateEmptyRow);
		EndIf;
		
	EndDo;
	
	If TabularSectionsSectionsOutputTitle Then
		ReportTS.EndRowGroup();
		ReportTS.Put(TemplateEmptyRow);
	EndIf;
	
EndProcedure

Function OutputCompositionResultsToReport(AttributesChangesTable,
                                          TableOfChangesOfTabularSections,
                                          counterUniqueId,
                                          VersionNumbersArray,
                                          ReportTS)
	
	NumberOfChangedAttributes = CalculateQuantityOfChangedAttributes(AttributesChangesTable, VersionNumbersArray);
	VersionsNumber = VersionNumbersArray.Count();
	
	///////////////////////////////////////////////////////////////////////////////
	//                           OUTPUT REPORT                                   //
	///////////////////////////////////////////////////////////////////////////////
	
	ReportTS.Clear();
	
	OutputHeader(ReportTS, VersionNumbersArray, VersionsNumber);
	
	If NumberOfChangedAttributes = 0 Then
		AreaAttributesHeader = Common_Template.GetArea("AttributesHeader");
		ReportTS.Put(AreaAttributesHeader);
		ReportTS.StartRowGroup("AttriburesGroup");
		AreaAttributesNotChanged = Common_Template.GetArea("AttributesWereNotChanged");
		ReportTS.Put(AreaAttributesNotChanged);
		ReportTS.EndRowGroup();
	Else
		OutputAttributeChanges(ReportTS,
		                           AttributesChangesTable,
		                           VersionNumbersArray);
		
	EndIf;
	
	OutputChangesTableSections(ReportTS,
	                                TableOfChangesOfTabularSections,
	                                VersionNumbersArray,
	                                counterUniqueId);
	
	ReportTS.TotalsBelow = False;
	ReportTS.ShowGrid = False;
	ReportTS.Protection = False;
	ReportTS.ReadOnly = True;
	
EndFunction

Function OutputHeader(ReportTS, VersionNumbersArray, VersionsNumber)
	
	AreaHeader = Common_Template.GetArea("Header");
	AreaHeader.Parameters.ReportDescription = NStr("en = 'Report by changes of the object''s version'");
	AreaHeader.Parameters.ObjectDescription = String(ObjectReference);
	
	ReportTS.Put(AreaHeader);
	
	EmptyCell = Common_Template.GetArea("EmptyCell");
	VersionArea = Common_Template.GetArea("VersionTitle");
	ReportTS.Join(EmptyCell);
	ReportTS.Join(VersionArea);
	
	VersionArea = Common_Template.GetArea("VersionPresentation");
	
	IndexByVersions = VersionsNumber;
	While IndexByVersions > 0 Do
		VersionArea.Parameters.VersionPresentation = 
		                      GetDescriptionByVersion(VersionNumbersArray[IndexByVersions-1]);
		ReportTS.Join(VersionArea);
		ReportTS.Area("C"+String(IndexByVersions+2)).ColumnWidth = 50;
		IndexByVersions = IndexByVersions - 1;
	EndDo;
	
	AreaEmptyRow = Common_Template.GetArea("FreeString");
	ReportTS.Put(AreaEmptyRow);
	
EndFunction

// Report mechanism. Fills report by the number of passed version.
// Comparison is done between the version passed in parameter ResultOfVersionParsing_0
// and the version specified by VersionNo
// Sequence of actions:
// 1. Get result of parsing versions of the compared objects
// 2. Generate list of attributes and tabular sections, which were
//    - modified
//    - added
//    - deleted
//
Function CalculateChanges(VersionNo,
                           ResultOfVersionParsing_0,
                           ResultOfVersionParsing_1)
	
	MetadataObjectIsDocument = False;
	
	If Metadata.Documents.Contains(ObjectReference.Metadata()) Then
		MetadataObjectIsDocument = True;
	EndIf;
	
	// Parse last version but one
	Attributes_0      = ResultOfVersionParsing_0.Attributes;
	TabularSections_0 = ResultOfVersionParsing_0.TabularSections;
	
	// Parse last version
	ResultOfVersionParsing_1 = VersionParsing(VersionNo, ObjectReference);
	Attributes_1      = ResultOfVersionParsing_1.Attributes;
	TabularSections_1 = ResultOfVersionParsing_1.TabularSections;
	
	///////////////////////////////////////////////////////////////////////////////
	//           Generate list of modified tabular sections           //
	///////////////////////////////////////////////////////////////////////////////
	ListOfTabularSections_0	= CreateComparisonTable();
	For Each Item In TabularSections_0 Do
		NewRow = ListOfTabularSections_0.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	ListOfTabularSections_1	= CreateComparisonTable();
	For Each Item In TabularSections_1 Do
		NewRow = ListOfTabularSections_1.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	// metadata structure could be modified - some attributes were added or deleted
	ListOfAddedTS = SubtractTable(ListOfTabularSections_1, ListOfTabularSections_0);
	ListOfDeletedTS  = SubtractTable(ListOfTabularSections_0, ListOfTabularSections_1);
	
	// list of not changed attributes, we will search matches / differences using them
	ListOfRemainingTS = SubtractTable(ListOfTabularSections_1, ListOfAddedTS);
	
	// list o attributes, that were modified
	ListOfChangedTS = FindChangedTabularSections(ListOfRemainingTS,
	                                                       TabularSections_0,
	                                                       TabularSections_1);
	
	///////////////////////////////////////////////////////////////////////////////
	//           Generate list of the attributes, that were modified                 //
	///////////////////////////////////////////////////////////////////////////////
	ListOfAttributes0 = CreateComparisonTable();
	For Each Attribute In ResultOfVersionParsing_0.Attributes Do
		NewRow = ListOfAttributes0.Add();		
		NewRow.Set(0, TrimAll(String(Attribute.AttributeDescription)));
	EndDo;
	
	ListOfAttributes1 = CreateComparisonTable();
	For Each Attribute In ResultOfVersionParsing_1.Attributes Do
		NewRow = ListOfAttributes1.Add();
		NewRow.Set(0, TrimAll(String(Attribute.AttributeDescription)));
	EndDo;
	
	// metadata structure could be modified - some attributes were added or deleted
	ListOfAddedAttributes = SubtractTable(ListOfAttributes1, ListOfAttributes0);
	ListOfDeletedAttributes  = SubtractTable(ListOfAttributes0, ListOfAttributes1);
	
	// list of not changed attributes, we will search matches / differences using them
	ListOfRemainingAttributes = SubtractTable(ListOfAttributes1, ListOfAddedAttributes);
	
	// list o attributes, that were modified
	ListOfChangedAttributes = CreateComparisonTable();
	
	ChangesInAttributes = New Map;
	ChangesInAttributes.Insert("d", ListOfAddedAttributes);
	ChangesInAttributes.Insert("u", ListOfDeletedAttributes);
	ChangesInAttributes.Insert("i", ListOfChangedAttributes);
	
	For Each ValueTableRow In ListOfRemainingAttributes Do
		
		Attribute = ValueTableRow.Value;
		Val_0 = Attributes_0.Find(Attribute, "AttributeDescription").DetailsValue;
		Val_1 = Attributes_1.Find(Attribute, "AttributeDescription").DetailsValue;
		
		If Val_0 <> Val_1 Then
			NewRow = ListOfChangedAttributes.Add();
			NewRow.Set(0, Attribute);
		EndIf;
		
	EndDo;
	
	ChangesInTables = CalculateChangesOfTabularSections(
	                              ListOfChangedTS,
	                              TabularSections_0,
	                              TabularSections_1);
	
	TableSectionModifications = New Structure;
	TableSectionModifications.Insert("d", ListOfAddedTS);
	TableSectionModifications.Insert("u", ListOfDeletedTS);
	TableSectionModifications.Insert("i", ChangesInTables);
	
	ChangesComposition = New Map;
	ChangesComposition.Insert("Attributes",      ChangesInAttributes);
	ChangesComposition.Insert("TabularSections", TableSectionModifications);
	
	Return ChangesComposition;
	
EndFunction

// Function adds columns, according to the number of object versions
// Columns are named as "Ver<Number>", where <Number> can be equal to
// values from 1 to the number of stored object versions. The numeration
// is conditional, i.e. for example name "Ver1" may not correspond to the
// stored object version with version 0.
//
Procedure PrepareColumnsOfAttributeChangesTables(ValueTable,
                                                      VersionNumbersArray)
	
	ValueTable = New ValueTable;
	
	ValueTable.Columns.Add("Description");
	ValueTable.Columns.Add("_Modification");
	ValueTable.Columns.Add("_ValueType"); // expected value type
	
	For IndexOf = 1 To VersionNumbersArray.Count() Do
		ValueTable.Columns.Add("Ver" + VersionNumbersArray[IndexOf-1]);
	EndDo;
	
EndProcedure

Function CalculateChangesOfTabularSections(ListOfChangedTS,
                                          TabularSections_0,
                                          TabularSections_1)
	
	ChangesInTables = New Map;
	
	// loop by number of tabular sections
	For IndexOf = 1 To ListOfChangedTS.Count() Do
		
		ChangesInTables.Insert(ListOfChangedTS[IndexOf-1].Value, New Map);
		
		// Segmentation table is needed for storage of the search intervals
		// search will be stopped only then, when the table
		// will not contain non zero indicators. Search can be done ONLY
		// by the interval table and only by the current interval!!!
		//
		SearchIntervalsTable = New ValueTable;
		SearchIntervalsTable.Columns.Add("BlockBegin_1");
		SearchIntervalsTable.Columns.Add("BlockEnd_1");
		SearchIntervalsTable.Columns.Add("BlockBegin_2");
		SearchIntervalsTable.Columns.Add("BlockEnd_2");
		
		TableForAnalysis = ListOfChangedTS[IndexOf-1].Value;
		Ts0 = TabularSections_0[TableForAnalysis];
		Ts1 = TabularSections_1[TableForAnalysis];
		
		FirstSplit = SearchIntervalsTable.Add();
		FirstSplit.BlockBegin_1 = 1;
		FirstSplit.BlockEnd_1  = Ts0.Count();
		FirstSplit.BlockBegin_2 = 1;
		FirstSplit.BlockEnd_2  = Ts1.Count();
		
		// Part #1:
		// filtration of matching items
		// as a result - filled SearchIntervalsTable.
		// Now we need to process and calculate this table
		// added/deleted/modified items.
		
		ChangesInIntervals = True;
		// do loop until there appear new intervals for the search
		While ChangesInIntervals Do
			
			// number of intervals in which search will be performed
			SearchIntervalsNumber = SearchIntervalsTable.Count();
			
			ChangesInIntervals = False;
			
			For SearchIntervalNumber = 1 To SearchIntervalsNumber Do
			
				BlockBegin_1 = SearchIntervalsTable[SearchIntervalNumber-1].BlockBegin_1;
				BlockEnd_1   = SearchIntervalsTable[SearchIntervalNumber-1].BlockEnd_1;
				
				BlockBegin_2 = SearchIntervalsTable[SearchIntervalNumber-1].BlockBegin_2;
				BlockEnd_2   = SearchIntervalsTable[SearchIntervalNumber-1].BlockEnd_2;
				
				If    (BlockBegin_1 > BlockEnd_1)
					OR (BlockBegin_2 > BlockEnd_2) Then
					
					Continue;
					
				EndIf;
				
				// this interval can be deleted
				If      (BlockEnd_1 = 0) And (BlockEnd_2 = 0) Then
					// delete this interval and reset counter by segments
					SearchIntervalsTable.Delete(SearchIntervalNumber);
					Break;
				// If split interval of the TS0 is zero, then rows have been added to the TS1
				ElsIf (BlockEnd_1 = 0) Then
				// If split interval of the TS1 os zero, then rows have been deleted from the TS1
				ElsIf (BlockEnd_2 = 0) Then
				
				Else
					Result = FindSimilarBlocks(Ts0, Ts1,
					                                 BlockBegin_1,
					                                 BlockEnd_1,
					                                 BlockBegin_2,
					                                 BlockEnd_2,
					                                 SearchIntervalsTable,
					                                 SearchIntervalNumber);
					
					If Result <> Undefined Then
						
						ChangesInIntervals = True;
						
						// split current interval - find the area, where there are no matching items
						
						String = SearchIntervalsTable.Insert(SearchIntervalNumber-1);
						String.BlockBegin_1 = BlockBegin_1;
						String.BlockEnd_1   = Result.BlockBegin_1 - 1;
						
						String.BlockBegin_2 = BlockBegin_2;
						String.BlockEnd_2   = Result.BlockBegin_2 - 1;
						
						String = SearchIntervalsTable.Insert(SearchIntervalNumber);
						String.BlockBegin_1 = Result.BlockBegin_1+Result.Size;
						String.BlockEnd_1   = BlockEnd_1;
						
						String.BlockBegin_2 = Result.BlockBegin_2+Result.Size;
						String.BlockEnd_2   = BlockEnd_2;
						
						SearchIntervalsTable.Delete(SearchIntervalNumber+1);
						
						Continue;
					EndIf;
				EndIf;
			EndDo;
		EndDo;
		
		// Delete "empty intervals".
		For Each Item In SearchIntervalsTable Do
			If  (Item.BlockBegin_1 > Item.BlockEnd_1)
				And (Item.BlockBegin_2 > Item.BlockEnd_2) Then
				SearchIntervalsTable.Delete(Item);
			EndIf;
		EndDo;
		
		// step 3- sort row by the indicator added / deleted / modified
		
		TableOfAddedRows   = New ValueTable;
		DeletedRowsTable   = New ValueTable;
		TableModifiedRows  = New ValueTable;
		
		For Each Item In Ts0.Columns Do
			TableOfAddedRows.Columns.Add(Item.Name);
			DeletedRowsTable.Columns.Add(Item.Name);
			TableModifiedRows.Columns.Add(Item.Name);
		EndDo;
		
		// 3.1 search for all the occurences in their subintervals
		
		TableModifiedRows = New ValueTable;
		TableModifiedRows.Columns.Add("IndexInTS0");
		TableModifiedRows.Columns.Add("IndexInTS1");
		
		TableOfAddedRows = New ValueTable;
		TableOfAddedRows.Columns.Add("IndexInTS1");
		
		DeletedRowsTable = New ValueTable;
		DeletedRowsTable.Columns.Add("IndexInTS0");
		
		For Each Item In SearchIntervalsTable Do
			ModifiedLines = CalculateChangesByRows(TableModifiedRows,
			                                                TableOfAddedRows,
			                                                DeletedRowsTable,
			                                                Item,
			                                                Ts0,
			                                                Ts1);
		EndDo;
		
		ChangesInTables[ListOfChangedTS[IndexOf-1].Value].Insert("D", TableOfAddedRows);
		ChangesInTables[ListOfChangedTS[IndexOf-1].Value].Insert("u", DeletedRowsTable);
		ChangesInTables[ListOfChangedTS[IndexOf-1].Value].Insert("I", TableModifiedRows);
		
	EndDo;
	
	Return ChangesInTables;
	
EndFunction

// Compares two tabular sections, the list of these tabular sections is being passed in the first parameter.
// Trys to find differences in these tabular sections (not matching items). If there are
// such kind of tables, then the list of such tabular sections is being generated.
//
Function FindChangedTabularSections(ListOfRemainingTS,
                                        TabularSections_0,
                                        TabularSections_1)
	
	ListOfChangedTS = CreateComparisonTable();
	
	// Search Tabular sections, where rows have been modified
	For Each Item In ListOfRemainingTS Do
		
		Ts_0 = TabularSections_0[Item.Value];
		Ts_1 = TabularSections_1[Item.Value];
		
		If Ts_0.Count() = Ts_1.Count() Then
			
			DifferenceFound = False;
			// check, that structure of columns has not been changed (equivalent)
			If TSEquivalents (Ts_0.Columns, Ts_1.Columns) Then
				
				// search for the differing items - rows
				For IndexOf = 0 To Ts_0.Count() - 1 Do
					String_0 = Ts_0[IndexOf];
					String_1 = Ts_1[IndexOf];
					
					If NOT RowsOfTSAreEqual(String_0, String_1, Ts_0.Columns) Then
						DifferenceFound = True;
						Break;
					EndIf
				EndDo;
				
			Else
				DifferenceFound = True;
			EndIf;
			
			If DifferenceFound Then
				NewRow = ListOfChangedTS.Add();
				NewRow.Set(0, Item.Value);
			EndIf;
			
		Else
			NewRow = ListOfChangedTS.Add();
			NewRow.Set(0, Item.Value);
		EndIf;
			
	EndDo;
	
	Return ListOfChangedTS;
	
EndFunction

// Function gets object from the information register by the object version number and
// object ref, writes it to the disk and calls for the function parsing object
// XML presentation.
// Parameters:
//   VersionNo   - number - document version number in the information register
//   Ref         - CatalogRef/DocumentRef - ref to the instance of the metadata object
// Value returned:
//   Structure
//
Function VersionParsing(VersionNo, Ref)
	
	Query = New Query;
	Query.Text = "SELECT VersionAuthor, VersionDate, ObjectVersion 
	                |FROM InformationRegister.ObjectVersions
	                |WHERE Object = &Ref
	                |And VersionNo = &VerNum";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("VerNum", Number(VersionNo));
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	ObjectVersion = Selection.ObjectVersion.Get();
	
	If ObjectVersion = Undefined Then
		Return False;
	Else
		Result = ParsingObjectXMLPresentation(ObjectVersion, Ref);
		Result.Insert("ObjectName", String(Ref));
		Result.Insert("ChangesAuthor", TrimAll(String(Selection.VersionAuthor)));
		Result.Insert("ModificationDate", Selection.VersionDate);
		Return Result;
	EndIf;
	
EndFunction

// Function reads initial values of document attributes and tabular sections.
// format of the generated data structure for the attributes:
// AttributeTable - ValueTable
// Columns
// |-Ver<low version number>
// |-...
// |-Ver<high version number>
// |-_Modification (Boolean)
// |-Description
//
// Rows contain the list of attributes and there changes in time, column _Modification
// contains the flag indicating if row has been modified:
// false - row has not been modified
// "a"  - row has been inserted
// "d"  - row has been deleted
// "m"  - row has been modified
//
// Format of the data structure generated for value tables:
// TSTable - Map
// |- <Tabular section1 name> - Map
//    |-Ver<low version number> - ValueTable
//       Columns
//       |- Basic columns of the corresponding table of the object part
//       |- _RowId     - unique, inside the table, id of the current row
//       |- _Modification  - flag of row modification
//           can be equal to:
//           false - row has not been modified
//           "a"  - row has been inserted
//           "d"  - row has been deleted
//           "m"  - row has been modified
//    |-...
//    |-Ver<high version number>
// |-...
// |- <Tabular sectionN name>
//
Function ReadInitialAttributeValuesAndTabularSections(AttributeTable,
                                                           TableTS,
                                                           VersionsCount,
                                                           VersionNumbersArray)
	
	ObjectLowerVersion = VersionNumbersArray[0];
	
	// Parse first version
	ObjectVersion   = VersionParsing(ObjectLowerVersion, ObjectReference);
	Attributes      = ObjectVersion.Attributes;
	TabularSections = ObjectVersion.TabularSections;
	
	Column = "Ver" + VersionNumbersArray[0];
	
	For Each ValueTableRow In Attributes Do
		NewRow 					= AttributeTable.Add();
		NewRow[Column] 			= ValueTableRow.DetailsValue;
		NewRow.Description 		= ValueTableRow.AttributeDescription;
		NewRow._Modification	= False;
		NewRow._ValueType		= ValueTableRow.AttributeType;
	EndDo;
	
	For Each TSItem In TabularSections Do
		
		TableTS.Insert(TSItem.Key, New Map);
		PrepareColumnsOfChangesTablesForMap(TableTS[TSItem.Key], VersionNumbersArray);
		TableTS[TSItem.Key]["Ver"+ObjectLowerVersion] = TSItem.Value.Copy();
		
		CurrentVT = TableTS[TSItem.Key]["Ver"+ObjectLowerVersion];
		
		// Row special id to distinguish the rows
		// value is unique inside this value table
		CurrentVT.Columns.Add("_RowId");
		CurrentVT.Columns.Add("_Modification");
		
		For IndexOf = 1 To CurrentVT.Count() Do
			CurrentVT[IndexOf-1]._RowId = IndexOf;
			CurrentVT[IndexOf-1]._Modification = False;
		EndDo;
	
	EndDo;
	
	Return ObjectVersion;
	
EndFunction

// Procedure reads XML data from file and fills data structures
//
// Value returned:
// Structure, containing two maps: TabularSections, Attributes
// Data storage structure:
// Map TabularSections, that stores values of the tabular sections
// format:
//          MapName1 -> ValueTable1
//                            |      |     ... |
//                            Field1  Field2     FieldM1
//
//          MapName2 -> ValueTable2
//                            |      |     ... |
//                            Field1  Field2     FieldM2
//
//
//          MapNameN -> ValueTableN
//                            |      |     ... |
//                            Field1  Field2     FieldM3
//
// Map AttributeValues
//          AttributeName1 -> Value1
//          AttributeName2 -> Value2
//          ...
//          AttributeNameN -> ValueN
//
Function ParsingObjectXMLPresentation(BinaryData, Ref)
	
	// contains metadata name of the modified object
	Var ObjectName;
	
	// Contains token location in the XML tree.
	// Required for the identification of the current item.
	Var ReadLevel;
	
	// Contain values of the attributes of catalogs / documents
	AttributeValues = New ValueTable;
	
	AttributeValues.Columns.Add("AttributeDescription");
	AttributeValues.Columns.Add("DetailsValue");
	AttributeValues.Columns.Add("AttributeType");
	
	TabularSections = New Map;
	
	XMLReader = New FastInfosetReader;
	
	XMLReader.SetBinaryData(BinaryData);
	
	// token level position in the XML hierarchy:
	// 0 - level is not specified
	// 1 - first item (name of object)
	// 2 - attribute or tabular section description
	// 3 - tabular section line description
	// 4 - description of the field of tabular section line
	ReadLevel = 0;
	
	MTDTabularSections = Ref.Metadata().TabularSections;
	
	ValueType = "";
	
	TypeOfTSFieldValue = "";
	
	// main loop of XML parsing
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			ReadLevel = ReadLevel + 1;
			If ReadLevel = 1 Then // pointer is on the first XML item - XML root
				ObjectName = XMLReader.Name;
			ElsIf ReadLevel = 2 Then // second level - this is an attribute or a tabular section name
				AttributeName = XMLReader.Name;
				If MTDTabularSections.Find(AttributeName) <> Undefined Then
					TabularSectionName = AttributeName;
					// create new value table in the map table
					If TabularSections[TabularSectionName] = Undefined Then
						TabularSections.Insert(TabularSectionName, New ValueTable);
					EndIf;
				EndIf;
				NewRL = AttributeValues.Add();
				NewRL.AttributeDescription = AttributeName;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
						   And XMLReader.Name = "xsi:type" Then
							NewRL.AttributeType = XMLReader.Value;
						EndIf;
					EndDo;
				EndIf;
			
			ElsIf (ReadLevel = 3) And (XMLReader.Name = "Row") Then // pointer to the tabular section field
				TabularSections[TabularSectionName].Add();
			ElsIf ReadLevel = 4 Then // pointer to the tabular section field
				
				TypeOfTSFieldValue = "";
				
				TSFieldName = XMLReader.Name; // 
				Table   = TabularSections[TabularSectionName];
				If Table.Columns.Find(TSFieldName)= Undefined Then
					Table.Columns.Add(TSFieldName);
				EndIf;
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.NodeType = XMLNodeType.Attribute 
						   And XMLReader.Name = "xsi:type" Then
							TypeOfTSFieldValue = XMLReader.Value;
						EndIf;
					EndDo;
				EndIf;
				
			EndIf;
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
			ReadLevel = ReadLevel - 1;
			ValueType = "";
		ElsIf XMLReader.NodeType = XMLNodeType.Text Then
			If (ReadLevel = 2) Then // attribute value
				NewRL.DetailsValue = XMLReader.Value;
			//AttributeValues[AttributeName] = XMLReader.Value;
				
			ElsIf (ReadLevel = 4) Then // attribute value
				LastString = TabularSections[TabularSectionName].Get(TabularSections[TabularSectionName].Count()-1);
				
				LastString[TSFieldName] = ?(IsBlankString(TypeOfTSFieldValue), XMLReader.Value, XMLValue(Type(TypeOfTSFieldValue), XMLReader.Value));
				
			EndIf;
		EndIf;
	EndDo;
	
	// 2-nd part: from the list of attributes exclude tabular sections
	For Each Item In TabularSections Do
		AttributeValues.Delete(AttributeValues.Find(Item.Key));
	EndDo;
	//MTDTabularSections
	For Each MapItem In TabularSections Do
		Table = MapItem.Value;
		If Table.Columns.Count() = 0 Then
			TableMTD = MTDTabularSections.Find(MapItem.Key);
			If TableMTD <> Undefined Then
				For Each ColumnDetails In TableMTD.Attributes Do
					If Table.Columns.Find(ColumnDetails.Name)= Undefined Then
						Table.Columns.Add(ColumnDetails.Name);
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("Attributes", AttributeValues);
	Result.Insert("TabularSections", TabularSections);
	
	Return Result;
	
EndFunction

Procedure PrepareColumnsOfChangesTablesForMap(Map, VersionNumbersArray)
	
	Quantity = VersionNumbersArray.Count();
	
	For IndexOf = 1 To Quantity Do
		Map.Insert("Ver" + VersionNumbersArray[IndexOf-1], New ValueTable);
	EndDo;
	
EndProcedure

// Function searches one occurrence of the part of one lock into the other lock
//
Function FindSimilarBlocks(ValueTable1,
                             ValueTable2,
                             BlockBegin_1,
                             BlockEnd_1,
                             BlockBegin_2,
                             BlockEnd_2,
                             SearchIntervalsTable,
                             IntervalCurrentNumber);
	
	// number of splits of the smaller value table of the search interval
	NumberOfSplit = 0;
	
	// initialization, so that compiler would not display warnings
	Endd = 0;
	
	MatchFound = False;
	
	MatchesTable = New ValueTable;
	MatchesTable.Columns.Add("BlockBegin_1");
	MatchesTable.Columns.Add("BlockBegin_2");
	MatchesTable.Columns.Add("Size");
	
	Dimensionality1 = BlockEnd_1 - BlockBegin_1 + 1;
	Dimensionality2 = BlockEnd_2 - BlockBegin_2 + 1;
	
	// find table being splitted - this is the table with the less number
	// of items
	
	If Dimensionality1 <= Dimensionality2 Then
		AnalysisTable1 = ValueTable1;
		AnalysisTable2 = ValueTable2;
		FirstBlock_Beg = BlockBegin_1;
		FirstBlock_End = BlockEnd_1;
		SecondBlock_Beg = BlockBegin_2;
		SecondBlock_End = BlockEnd_2;
		DirectMap = True;
	Else
		AnalysisTable1 = ValueTable2;
		AnalysisTable2 = ValueTable1;
		FirstBlock_Beg = BlockBegin_2;
		FirstBlock_End = BlockEnd_2;
		SecondBlock_Beg = BlockBegin_1;
		SecondBlock_End = BlockEnd_1;
		DirectMap = False;
	EndIf;
	
	While NOT MatchFound Do
		
		NumberOfSplit = NumberOfSplit + 1;
		
		If NumberOfSplit > (FirstBlock_End - FirstBlock_Beg + 1) Then
			Break;
		EndIf;
		
		For Counter = 1 To NumberOfSplit Do
			
			// narrow area of the lock sought in TS
			If Counter = 1 Then
				Beg = Int(FirstBlock_Beg + (FirstBlock_End-FirstBlock_Beg)/NumberOfSplit*(Counter-1));
			Else
				Beg = Endd + 1;
			EndIf;
			
			Endd = Int(FirstBlock_Beg + (FirstBlock_End-FirstBlock_Beg)/NumberOfSplit*Counter);
			
			// returns position number
			Result = SubtableSearch(AnalysisTable1, Beg, Endd, AnalysisTable2, SecondBlock_Beg, SecondBlock_End);
			
			// If match was found - continue:
			// search subtable continuation until the found pattern and after.
			// Lower boundary of the sought pattern is bounded by FirstBlock_Beg, its top boundary
			// is limited by FirstBlock_End. Boundary of the table based on which search is being done
			// is limited by SecondBlock_Beg and SecondBlock_End.
			//
			If Result <> Undefined Then
				
				// 1. trying to "roll" back to the beginning
				
				LowerSlidingBoundaryOfAnalysisTable1 = Beg;
				LowerSlidingBoundaryOfAnalysisTable2 = Result;
				
				While  (LowerSlidingBoundaryOfAnalysisTable1 - 1) >= 1
					And (LowerSlidingBoundaryOfAnalysisTable2 - 1) >= 1
					And (LowerSlidingBoundaryOfAnalysisTable1 - 1) > SearchIntervalsTable[IntervalCurrentNumber-1].BlockBegin_1
					And (LowerSlidingBoundaryOfAnalysisTable2 - 1) > SearchIntervalsTable[IntervalCurrentNumber-1].BlockBegin_2
					And RowsOfTSAreEqual(AnalysisTable1[LowerSlidingBoundaryOfAnalysisTable1-2], AnalysisTable2[LowerSlidingBoundaryOfAnalysisTable2-2], AnalysisTable1.Columns) Do
					
					If (LowerSlidingBoundaryOfAnalysisTable1-1)>=FirstBlock_Beg And (LowerSlidingBoundaryOfAnalysisTable2-1)>=SecondBlock_Beg Then
						LowerSlidingBoundaryOfAnalysisTable1 = LowerSlidingBoundaryOfAnalysisTable1 - 1;
						LowerSlidingBoundaryOfAnalysisTable2 = LowerSlidingBoundaryOfAnalysisTable2 - 1;
					Else
						Break;
					EndIf;
				EndDo;
				
				// 2. trying to "roll" to the end of the table
				
				UpperSlidingBoundaryTableAnalysis1 = Endd;
				UpperSlidingBoundaryTableAnalysis2 = Result + Endd - Beg;
				
				While  UpperSlidingBoundaryTableAnalysis1 < AnalysisTable1.Count()
					And UpperSlidingBoundaryTableAnalysis2 < AnalysisTable2.Count()
					And RowsOfTSAreEqual(AnalysisTable1[UpperSlidingBoundaryTableAnalysis1-1+1], AnalysisTable2[UpperSlidingBoundaryTableAnalysis2-1+1], AnalysisTable1.Columns) Do
					
					If UpperSlidingBoundaryTableAnalysis1 < FirstBlock_End And UpperSlidingBoundaryTableAnalysis2 < SecondBlock_End Then
						UpperSlidingBoundaryTableAnalysis1 = UpperSlidingBoundaryTableAnalysis1 + 1;
						UpperSlidingBoundaryTableAnalysis2 = UpperSlidingBoundaryTableAnalysis2 + 1;
					Else
						Break;
					EndIf;
				EndDo;
				
				// 3. MatchesTable
				// when continuation has been found, calculate the index, where match begins
				// also calculate match size in lines (number of lines)
				NewRow = MatchesTable.Add();
				NewRow.BlockBegin_1 = LowerSlidingBoundaryOfAnalysisTable1;
				NewRow.BlockBegin_2 = LowerSlidingBoundaryOfAnalysisTable2;
				NewRow.Size         = UpperSlidingBoundaryTableAnalysis1-LowerSlidingBoundaryOfAnalysisTable1 + 1;
				
				MatchFound = True;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	Max_Ind = -1;
	
	For I = 1 To MatchesTable.Count() Do
		
		If Max_Ind = -1 Then
			Max_Ind = I;
		EndIf;
		
		If MatchesTable[I-1].Size > MatchesTable[Max_Ind-1].Size Then
			Max_Ind = I;
		EndIf;
		
	EndDo;
	
	If Max_Ind = -1 Then
		Return Undefined;
	Else
		
		If Not DirectMap Then
			TempVar = MatchesTable[Max_Ind-1].BlockBegin_1;
			MatchesTable[Max_Ind-1].BlockBegin_1 = MatchesTable[Max_Ind-1].BlockBegin_2;
			MatchesTable[Max_Ind-1].BlockBegin_2 = TempVar;
		EndIf;
		
		Return MatchesTable[Max_Ind-1];
	EndIf;
	
EndFunction

// Function specification
// function does precise search in ENTIRE WINDOW of search SoughtTemplate(StartPositionInSearchWindow, TargetPositionInSearchWindow) in search bounds
// AnalysedTable (LowerSearchBoundary, UpperSearchBoundary)
// Returns position number in AnalysedTable (numeration from 1) starting which subtable has been found
Function SubtableSearch(
                         SoughtTemplate,               // sought table
                         StartPositionInSearchWindow, // first item index in the search window
                         TargetPositionInSearchWindow, // last item index in the search window
                         // StartPositionInSearchWindow and TargetPositionInSearchWindow define the search window
                         AnalysedTable,        // Table where search is being performed
                         LowerSearchBoundary,         // LowerSearchBoundary, UpperSearchBoundary - define boundaries,
                         UpperSearchBoundary)        // where search is possible
	
	// do search until expression is True
	// CurrentSearchPosition + (TargetPositionInSearchWindow - StartPositionInSearchWindow) <= UpperSearchBoundary
	
	CurrentSearchPosition = LowerSearchBoundary;
	
	While ((CurrentSearchPosition + (TargetPositionInSearchWindow - StartPositionInSearchWindow)) <= UpperSearchBoundary) Do
		
		SubstringIsFound = True;
		
		For IndexOf = StartPositionInSearchWindow To TargetPositionInSearchWindow Do
			If NOT RowsOfTSAreEqual(SoughtTemplate[IndexOf-1], AnalysedTable[CurrentSearchPosition+IndexOf-StartPositionInSearchWindow-1], SoughtTemplate.Columns) Then
				SubstringIsFound = False;    //LowerSearchBoundary+CurrentSearchPosition+IndexOf-StartPositionInSearchWindow-2
				Break;
			EndIf
		EndDo;
		
		If SubstringIsFound Then
			Break;
		EndIf;
		
		CurrentSearchPosition = CurrentSearchPosition + 1;
		
	EndDo;
	
	If SubstringIsFound Then
		
		Return CurrentSearchPosition;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Accepts two tabular sections with the record about the intervals, where changes
// have to be found
Function CalculateChangesByRows(TableModifiedRows,
                                    TableOfAddedRows,
                                    DeletedRowsTable,
                                    Item,
                                    Ts0,
                                    Ts1)
	
	toTS0 = New ValueTable;
	toTS1 = New ValueTable;
	
	Columns = Ts0.Columns;
	
	For Each Column In Ts0.Columns Do
		toTS0.Columns.Add(Column.Name);
		toTS1.Columns.Add(Column.Name);
	EndDo;
	
	toTS0.Columns.Add("Used");
	toTS1.Columns.Add("Used");
	
	For IndexOf = Item.BlockBegin_1 To Item.BlockEnd_1 Do
		NewRow = toTS0.Add();
		FillPropertyValues(NewRow, Ts0[IndexOf-1]);
	EndDo;
	
	For IndexOf = Item.BlockBegin_2 To Item.BlockEnd_2 Do
		NewRow = toTS1.Add();
		FillPropertyValues(NewRow, Ts1[IndexOf-1]);
	EndDo;
	
	DimensionTS0 = Item.BlockEnd_1 - Item.BlockBegin_1 + 1;
	DimensionTS1 = Item.BlockEnd_2 - Item.BlockBegin_2 + 1;
	
	For Index1 = 1 To DimensionTS0 Do
	
		TSLine0 = toTS0[Index1 - 1];
		MapFound = False;
		
		If TSLine0.Used <> True Then
			For Index2 = 1 To DimensionTS1 Do
				TSLine1 = toTS1[Index2 - 1];
				If TSLine1.Used <> True Then
					If CheckStringsForEquality (TSLine0, TSLine1, Columns) Then
						MapFound = True;
						Break;
					EndIf;
				EndIf; // If TSLine1.Used <> True Then
			EndDo; // For Index2= 1 On DimensionTS1 Do
		EndIf; // If TSLine0.Used <> True Then
		
		If MapFound Then
			TSLine0.Used = True;
			TSLine1.Used = True;
			NewRow = TableModifiedRows.Add();
			NewRow.IndexInTS0 = Index1+Item.BlockBegin_1-1;
			NewRow.IndexInTS1 = Index2+Item.BlockBegin_2-1;
		Else
			TSLine0.Used = True;
			NewRow = DeletedRowsTable.Add();
			NewRow.IndexInTS0 = Index1+Item.BlockBegin_1-1;
		EndIf;
		
	EndDo; // For Index1 = 1 On DimensionTS0 Do
	
	For IndexOf = 1 To DimensionTS1 Do
	
		TSLine1 = toTS1[IndexOf - 1];
		If TSLine1.Used <> True Then
			TSLine1.Used = True;
			NewRow = TableOfAddedRows.Add();
			NewRow.IndexInTS1 = IndexOf+Item.BlockBegin_2-1;
		EndIf; // If TSLine0.Used <> True Then
		
	EndDo; // For Index1 = 1 On DimensionTS0 Do
	
EndFunction

// Accepts two lines from tabular sections with the identical structure and compares them.
// Lines are considered modified, if at least one their column matches.
Function CheckStringsForEquality(String1, String2, SetOfColumns)
	
	NumberOfIdenticalColumns = 0;
	NumberOfColumns = 0;
	
	For Each Column In SetOfColumns Do
		NumberOfColumns = NumberOfColumns + 1;
		If String1[Column.Name] = String2[Column.Name] Then
			NumberOfIdenticalColumns = NumberOfIdenticalColumns + 1;
		EndIf;
	EndDo;
	
	If (NumberOfIdenticalColumns/NumberOfColumns) >= CriterionOfAccessForStringsEquality() Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns access - ratio of the number of not modified columns in the tabular section line
// to the total number of columns. For the moment access is - 3/5. I.e. if
// on comparison of two lines in two tabular sections with the identical set of columns
// just 2 columns of 5 have been changed, then we consider, that this is the same line.
//
Function CriterionOfAccessForStringsEquality()
	Return (0.6);
EndFunction

// Returns True or False depending on that, if tabular sections
// are equivalent or not. TSs are considered equivalent, if number, description
// and type of their fields are identical. Altered order of columns is not considered as
// tabular section modification.
//
Function TSEquivalents(Columns1, Columns2)
	
	TableOfColumns1 = CreateComparisonTable();
	For Each Item In Columns1 Do
		NewRow = TableOfColumns1.Add();
		NewRow.Set(0, Item.Name);
	EndDo;
	
	TableOfColumns2 = CreateComparisonTable();
	For Each Item In Columns2 Do
		NewRow = TableOfColumns2.Add();
		NewRow.Set(0, Item.Name);
	EndDo;
	
	ListOfAddedColumns = SubtractTable(TableOfColumns1, TableOfColumns2);
	If ListOfAddedColumns.Count() > 0 Then
		Return False;
	EndIf;
	
	ListOfDeletedColumns   = SubtractTable(TableOfColumns1, TableOfColumns2);
	If ListOfDeletedColumns.Count() > 0 Then
		Return False;
	EndIf;
	
	// check if column types match
	For Each Item1 In Columns1 Do
		
		Item2 = Columns2.Find(Item1.Name);
		Types1 = Item1.ValueType.Types();
		For Each Type In Types1 Do
			If Not Item2.ValueType.ContainsType (Type) Then
				Return False;
			EndIf;
		EndDo;
		
	EndDo;
	
	// check if column types match
	For Each Item2 In Columns2 Do
		
		Item1 = Columns1.Find(Item1.Name);
		Types2 = Item2.ValueType.Types();
		For Each Type In Types2 Do
			If Not Item1.ValueType.ContainsType (Type) Then
				Return False;
			EndIf;
		EndDo;
		
	EndDo;
	
	Return True;
	
EndFunction

// Function compares values of two lines (by value) and returns
// True,  if lines are identical, else returns False
// It's supposed that the metadata structure of the tabular section is equivalent.
//
Function RowsOfTSAreEqual(TSLine1, TSLine2, Columns)
	
	For Each Column In Columns Do
		ColumnName = Column.Name;
		ValueFromTS1 = TSLine1[ColumnName];
		ValueFromTS2 = TSLine2[ColumnName];
		If ValueFromTS1 <> ValueFromTS2 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Function tryes to get attribute presentation by the presentation of attribute type
//
Function DefinePresentation(DetailsValue, FieldDescription, AttributeDetails)
	
	If FieldDescription = "Date" Then
		ArrayOfTypes = New Array;
		ArrayOfTypes.Add(Type("Date"));
		DateTypeDetails = New TypeDescription(ArrayOfTypes);
		AttributeDetails = DateTypeDetails;
	EndIf;
	
	If (AttributeDetails <> Undefined) Then
		AttributeTypeDetails = AttributeDetails.Type;
		// trying to find direct map
		AttributeValuePresentation = 
		         GeneratePresentationByTypeDescription(AttributeTypeDetails,
		                                                 DetailsValue);
	EndIf;
	
	If AttributeValuePresentation = "" Then
		AttributeValuePresentation = DetailsValue;
		If AttributeValuePresentation = "" Then
			AttributeValuePresentation = " ";
		EndIf;
	EndIf;
	
	Return AttributeValuePresentation;
	
EndFunction

// Function tryes to cast attribute value by its value type
// to the user presentation
//
Function CastToPresentationByTypeAndValue(ValueType, Value)
	
	Presentation = Value;
	
	Try
		GUID = New UUID (Value);
	Except
		Return Presentation;
	EndTry;
	
	If Left(ValueType, 10) = "CatalogRef" Then
		CatalogName = Right(ValueType, StrLen(ValueType) - 11);
		Presentation = FindCatalogItemByGUIDAndMakePresentation(
		                           GUID,
		                           CatalogName);
	ElsIf Left(ValueType, 11) = "DocumentRef" Then
		DocumentName = Right(ValueType, StrLen(ValueType) - 12);
		Presentation = FindDocumentByGUIDAndMakePresentation(
		                           GUID,
		                           DocumentName);
	ElsIf Left(ValueType, 29) = "ChartOfCharacteristicTypesRef" Then
		ChartOfCharacteristicKindName = Right(ValueType, StrLen(ValueType) - 30);
		Presentation = FindChartOfCharacteristicTypesByGUIDAndMakePresentation(
		                           GUID,
		                           ChartOfCharacteristicKindName);
	ElsIf Left(ValueType, 18) = "ChartOfAccountsRef" Then
		ChartOfAccountsName = Right(ValueType, StrLen(ValueType) - 19);
		Presentation = FindChartOfAccountsByGUIDAndMakePresentation(
		                           GUID,
		                           ChartOfAccountsName);
	ElsIf Left(ValueType, 26) = "ChartOfCalculationTypesRef" Then
		ChartOfCalculationTypesName = Right(ValueType, StrLen(ValueType) - 27);
		Presentation = FindChartOfCalculationTypesByGUIDAndMakePresentation(
		                           GUID,
		                           ChartOfCalculationTypesName);
	ElsIf Left(ValueType, 18) = "BusinessProcessRef" Then
		BusinessProcessName = Right(ValueType, StrLen(ValueType) - 19);
		Presentation = FindBusinessProcessByGUIDAndMakePresentation(
		                           GUID,
		                           BusinessProcessName);
	ElsIf Left(ValueType, 7) = "TaskRef" Then
		TaskName = Right(ValueType, StrLen(ValueType) - 8);
		Presentation = FindTaskByGUIDAndMakePresentation(GUID, TaskName);
	ElsIf Left(ValueType, 15) = "ExchangePlanRef" Then
		ExchangePlanName = Right(ValueType, StrLen(ValueType) - 16);
		Presentation = FindExchangePlanByGUIDAndMakePresentation(GUID, ExchangePlanName);
	EndIf;
	
	Return Presentation;
	
EndFunction

// Gets description presentation of the system attribute
//
Function GetAttributePresentationInLanguage(Val AttributeName)
	
	If      AttributeName = "Number" Then
		Return NStr("en = 'Number'");
	ElsIf AttributeName = "Name" Then
		Return NStr("en = 'Description'");
	ElsIf AttributeName = "Code" Then
		Return NStr("en = 'Code'");
	ElsIf AttributeName = "IsFolder" Then
		Return NStr("en = 'IsFolder'");
	ElsIf AttributeName = "Description" Then
		Return NStr("en = 'Description'");
	ElsIf AttributeName = "Date" Then
		Return NStr("en = 'Date'");
	ElsIf AttributeName = "Posted" Then
		Return NStr("en = 'Posted'");
	ElsIf AttributeName = "DeletionMark" Then
		Return NStr("en = 'DeletionMark'");
	ElsIf AttributeName = "Ref" Then
		Return NStr("en = 'Ref'");
	ElsIf AttributeName = "Parent" Then
		Return NStr("en = 'Parent'");
	Else
		Return AttributeName;
	EndIf;
	
EndFunction

// Is used tor output text into the spreadsheet document area
// with conditional appearance
//
Procedure SetTextProperties(SectionArea, Text,
                                   Val TextColor = Undefined,
                                   Val BackColor = Undefined,
                                   Val Size = 9,
                                   Val Bold = False,
                                   Val ShowBoundaries = False)
	
	SectionArea.Text = Text;
	
	If TextColor = Undefined Then
		TextColor = WebColors.Black;
	EndIf;
	
	SectionArea.TextColor = TextColor;
	
	If BackColor <> Undefined Then
		SectionArea.BackColor = BackColor;
	EndIf;
	
	SectionArea.Font = New Font(, Size, Bold, , , );
	
	If ShowBoundaries Then
		SectionArea.TopBorder 		= New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.BottomBorder  	= New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.LeftBorder  	= New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.RightBorder 	= New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.HorizontalAlign = HorizontalAlign.Center;
	EndIf;
	
EndProcedure

// Gets description of the stored object version as string
//
Function GetDescriptionByVersion(VersionNo)
	
	Query = New Query;
	Query.Text = "SELECT VersionAuthor, VersionDate
	                |FROM InformationRegister.ObjectVersions
	                |WHERE Object = &Ref
	                |And VersionNo = &VerNum";
	Query.SetParameter("Ref", ObjectReference);
	Query.SetParameter("VerNum", Number(VersionNo));
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	StoredVersionDetails = "#"+ VersionNo + " / (" 
	                       + String(Selection.VersionDate) + " ) / " 
	                       + TrimAll(Selection.VersionAuthor.Description);
	
	Return StoredVersionDetails;
	
EndFunction

// Calculates number of the modified attributes in the table of modified attributes
//
Function CalculateQuantityOfChangedAttributes(AttributesChangesTable, VersionNumbersArray)
	
	Result = 0;
	
	For Each VTItem In AttributesChangesTable Do
		If VTItem._Modification <> Undefined And VTItem._Modification = True Then
			Result = Result + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Increments value of end-to-end counter for the table
//
Function IncrementCounter(CounterUniqueId, TableName);
	
	CounterUniqueId[TableName] = CounterUniqueId[TableName] + 1;
	
	Return counterUniqueId[TableName];
	
EndFunction

// Returns unique number for the line identification from the table by version
//
Function GetUniqueUniqueId(TableOfTSChanges, VersionColumnName)
	
	MapUniqueID = New Map;
	
	For Each ItemMap In TableOfTSChanges Do
		MapUniqueID[ItemMap.Key] = Number(ItemMap.Value[VersionColumnName].Count());
	EndDo;
	
	Return MapUniqueID;
	
EndFunction

// Fills the report table based on the comparison results at some step
//
// Parameters:
// ChangesCheck - string - "a" - attribute was inserted
//                         "d" - attribute was deleted
//                         "m" - attribute was modified
//
Procedure FillAttributeChangeCharacteristic(AttributeChangesTable, 
                                                    ChangesCheck,
                                                    AttributesChangesTable,
                                                    CurrentVersionColumnName,
                                                    ObjectVersion)
	
	For Each Item In AttributeChangesTable Do
		Description = Item.Value;
		AttributeChange = AttributesChangesTable.Find (Description, "Description");
		
		If AttributeChange = Undefined Then
			AttributeChange = AttributesChangesTable.Add();
			AttributeChange.Description = Description;
		EndIf;
		
		ChangeParameters = New Structure;
		ChangeParameters.Insert("ChangeType", ChangesCheck);
		
		If ChangesCheck = "u" Then
			ChangeParameters.Insert("Value", "deleted2");
		Else
			ChangeParameters.Insert("Value", ObjectVersion.Attributes.Find(Description, "AttributeDescription"));
		EndIf;
		
		AttributeChange[CurrentVersionColumnName] = ChangeParameters;
		AttributeChange._Modification = True;
	EndDo;
	
EndProcedure

// Tryes to generate value presentation using its type description
//
Function GeneratePresentationByTypeDescription(AttributeTypeDetails, ValueDetails)
	
	If TypeOf(ValueDetails) <> Type("String") Then
		Return String(ValueDetails);
	EndIf;
	
	Text = "";
	If AttributeTypeDetails.ContainsType(Type("Date")) Then
		DateValue = XMLValue(Type("Date"),ValueDetails);
		
		If Year(DateValue) <> 1 Then
			Text = Format(DateValue, "ND1=2; NLZ=; DF=dd.MM.yyyy");
		EndIf;
		
		If NOT (Second(DateValue) = 0 And Minute(DateValue) = 0 And Hour(DateValue) = 0) Then
			Text = Text + " " + Format(DateValue, "NLZ=; DLF=T");
		EndIf;
		
		Text = ?(IsBlankString(Text), " ", Text);
		
		Return Text;
	EndIf;
	
	ValueIsFound = False;
	
	If AttributeTypeDetails.ContainsType(Type("Boolean")) Then
		If ValueDetails = "true" Then
			Text = "True";
		Else
			Text = "False";
		EndIf;
		ValueIsFound = True;
	EndIf;
	
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	If AttributeTypeDetails.ContainsType(Type("Number")) Then
		If ValueDetails = Undefined Then
			ValueDetails = 0;
		EndIf;
		Text = Format(Number(ValueDetails), "NFD="+String(AttributeTypeDetails.NumberQualifiers.FractionDigits));
		ValueIsFound = True;
	EndIf;
	
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	Try
		GUID = New UUID(ValueDetails);
	Except
		Return ValueDetails;
	EndTry;
	
	For Each Item In Metadata.Catalogs Do
		Op = New TypeDescription("CatalogRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindCatalogItemByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
		
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	For Each Item In Metadata.Documents Do
		Op = New TypeDescription("DocumentRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindDocumentByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	For Each Item In Metadata.BusinessProcesses Do
		Op = New TypeDescription("BusinessProcessRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindBusinessProcessByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	For Each Item In Metadata.BusinessProcesses Do
		Op = New TypeDescription("BusinessProcessRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindBusinessProcessByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
		
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	For Each Item In Metadata.Tasks Do
		Op = New TypeDescription("TaskRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindTaskByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	For Each Item In Metadata.ChartsOfCharacteristicTypes Do
		Op = New TypeDescription("ChartOfCharacteristicTypesRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindChartOfCharacteristicTypesByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
		
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	For Each Item In Metadata.ChartsOfCalculationTypes Do
		Op = New TypeDescription("ChartOfCalculationTypesRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindChartOfCalculationTypesByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
		
	If ValueIsFound Then
		Return Text;
	EndIf;
	
	For Each Item In Metadata.ChartsOfAccounts Do
		Op = New TypeDescription("ChartOfAccountsRef." + Item.Name);
		If AttributeTypeDetails.ContainsType(Op.Types()[0]) Then
			Text = FindChartOfAccountsByGUIDAndMakePresentation(GUID, Item.Name, ValueIsFound);
			If ValueIsFound Then
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ValueIsFound OR ValueIsFilled(Text) or Text = " " Then
		Return Text;
	EndIf;
	
	Return ValueDetails;
	
EndFunction

// Gets ref to the object - exchange plan by GUID
//
Function FindExchangePlanByGUIDAndMakePresentation(GUID, ExchangePlanName, ValueIsFound = False)
	
	If String(GUID) = XMLString(ExchangePlans[ExchangePlanName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = ExchangePlans[ExchangePlanName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "ExchangePlan", ExchangePlanName);
	Return String(Ref);
	
EndFunction

// Gets ref to the object - chart of accounts by GUID
//
Function FindChartOfAccountsByGUIDAndMakePresentation(GUID, ChartOfAccountsName, ValueIsFound = False)
	
	If String(GUID) = XMLString(ChartsOfAccounts[ChartOfAccountsName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = ChartsOfAccounts[ChartOfAccountsName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "ChartOfAccounts", ChartOfAccountsName);
	Return String(Ref);
	
EndFunction

// Gets ref to the object - chart of calculation types by GUID
//
Function FindChartOfCalculationTypesByGUIDAndMakePresentation(GUID, ChartOfCalculationTypesName, ValueIsFound = False)
	
	If String(GUID) = XMLString(ChartsOfCalculationTypes[ChartOfCalculationTypesName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = ChartsOfCalculationTypes[ChartOfCalculationTypesName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "ChartOfCalculationTypes", ChartOfCalculationTypesName);
	Return String(Ref);
	
EndFunction

// Gets ref to the object - chart of characteristic types by GUID
//
Function FindChartOfCharacteristicTypesByGUIDAndMakePresentation(GUID, ChartOfCharacteristicTypesName, ValueIsFound = False)
	
	If String(GUID) = XMLString(ChartsOfCharacteristicTypes[ChartOfCharacteristicTypesName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = ChartsOfCharacteristicTypes[ChartOfCharacteristicTypesName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "ChartOfCharacteristicTypes", ChartOfCharacteristicTypesName);
	Return String(Ref);
	
EndFunction

// Gets ref to the object - task by GUID
//
Function FindTaskByGUIDAndMakePresentation(GUID, TaskName, ValueIsFound = False)
	
	If String(GUID) = XMLString(Tasks[TaskName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = Tasks[TaskName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "Task", TaskName);
	Return String(Ref);
	
EndFunction

// Gets ref to the object - business process by GUID
//
Function FindBusinessProcessByGUIDAndMakePresentation(GUID, BusinessProcessName, ValueIsFound = False)
	
	If String(GUID) = XMLString(BusinessProcesses[BusinessProcessName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = BusinessProcesses[BusinessProcessName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "BusinessProcess", BusinessProcessName);
	Return String(Ref);
	
EndFunction

// Gets ref to the object - document by GUID
//
Function FindDocumentByGUIDAndMakePresentation(GUID, DocumentName, ValueIsFound = False)
	
	If String(GUID) = XMLString(Documents[DocumentName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = Documents[DocumentName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "Document", DocumentName);
	Return String(Ref);
	
EndFunction

// Gets ref to the object - catalog by GUID
//
Function FindCatalogItemByGUIDAndMakePresentation(GUID, CatalogName, ValueIsFound = False)
	
	If String(GUID) = XMLString(Catalogs[CatalogName].EmptyRef()) Then
		Return " ";
	EndIf;
	
	Ref = Catalogs[CatalogName].GetRef(GUID);
	ValueIsFound = ObjectExists(Ref, "Catalog", CatalogName);
	Return String(Ref);
	
EndFunction

Function ObjectExists(Ref, ClassifierString, MOName)
	
	Query = New Query;
	Query.Text = "SELECT Ref FROM " + ClassifierString + "." + MOName + " WHERE Ref=&Ref";
	Query.Parameters.Insert("Ref", Ref);
	
	Selection = Query.Execute().Choose();
	
	If Selection.Next() Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Outputs text to the spreadsheet document area with the specific appearance
//
Procedure OutputTextToReport(ReportTS,
                             Val Section,
                             Val State,
                             Val Text,
                             Val TextColor = Undefined,
                             Val BackColor   = Undefined,
                             Val Size     = 9,
                             Val Bold     = False)
	
	If TextColor = Undefined Then
		TextColor = WebColors.Black;
	EndIf;
	
	If BackColor = Undefined Then
		BackColor = WebColors.White;
	EndIf;
	
	Section.Area(State).Text      = Text;
	Section.Area(State).BackColor   = BackColor;
	Section.Area(State).TextColor = TextColor;
	Section.Area(State).Font      = New Font(, Size, Bold, , , );
	
	Section.Area(State).TopBorder = New Line(SpreadsheetDocumentCellLineType.None);
	Section.Area(State).BottomBorder  = New Line(SpreadsheetDocumentCellLineType.None);
	Section.Area(State).LeftBorder  = New Line(SpreadsheetDocumentCellLineType.None);
	Section.Area(State).RightBorder = New Line(SpreadsheetDocumentCellLineType.None);
	
	ReportTS.Put(Section);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
//  SECTION OF SERVICE FUNCTIONS (INNER LOGICS)

// Function gets object from the information register by the object version number and
// object ref, writes it to the disk and calls for the function parsing object
// XML presentation.
// Parameters:
// VersionNo  - number - document version number in the information register
// Ref        - CatalogRef/DocumentRef - ref to the instance
//              of the metadata object
// Value returned:
// Structure:
//
Function SaveFileByVersion(VersionNo)
	
	Query = New Query;
	Query.Text = "SELECT VersionAuthor, VersionDate, ObjectVersion 
	                |FROM InformationRegister.ObjectVersions
	                |WHERE Object = &Ref
	                |And VersionNo = &VerNum";
	Query.SetParameter("Ref", ObjectReference);
	Query.SetParameter("VerNum", Number(VersionNo));
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	ObjectVersion = Selection.ObjectVersion.Get();
	
	If ObjectVersion = Undefined Then
		Raise NStr("en = 'Error receiving the object version from information base'");
	Else
		Return ObjectVersion;
	EndIf;
	
EndFunction

// Restores object serialized in XML.
// Parameters
// FileName - string - file path, where object serialized presentation
//                     is stored
//
Function GetObjectFromXML(BinaryData)
	
	XMLReader = New FastInfosetReader;
	XMLReader.SetBinaryData(BinaryData);
	If XMLReader.Read() Then
		If CanReadXML(XMLReader) Then
			Object = ReadXML(XMLReader);
			XMLReader.Close();
			Return Object;
		Else
			XMLReader.Close();
			Raise NStr("en = 'An error occurred while restoring the object'");
		EndIf;
	Else
		XMLReader.Close();
		Raise NStr("en = 'Data reading error'");
	EndIf;
	
EndFunction

// FillValue - array of lines
// OutputType - string :
//           	"m" - modification
//           	"a" - insert
//           	"d" - deletion
//           	""  - normal output
Function GenerateTSRowSector(Val FillValue,Val OutputType = "")
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If   OutputType = ""  Then
		Pattern = Common_Template.GetArea("InitialAttributeValue");
	ElsIf OutputType = "I" Then
		Pattern = Common_Template.GetArea("ModifiedAttributeValue");
	ElsIf OutputType = "D" Then
		Pattern = Common_Template.GetArea("AddedAttribute");
	ElsIf OutputType = "U" Then
		Pattern = Common_Template.GetArea("DeletedAttribute");
	EndIf;
	
	For Each NextValue In FillValue Do
		Pattern.Parameters.DetailsValue = NextValue;
		SpreadsheetDocument.Put(Pattern);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generates empty sector for output into the report. Is used,
// if line has not been modified in one of the versions.
//
Function GenerateEmptySector(Val RowsQuantity, Val OutputType = "")
	
	FillValue = New Array;
	
	For IndexOf = 1 To RowsQuantity Do
		FillValue.Add(" ");
	EndDo;
	
	Return GenerateTSRowSector(FillValue, OutputType);
	
EndFunction

// Function returns subtract result of the items of table multitude
// TableDeductible from MainTable.
//
Function SubtractTable(Val MainTable,
                       Val TableDeductible,
                       Val MainTableCompareColumn = "",
                       Val DeductibleTableCompareColumn = "")
	
	If Not ValueIsFilled(MainTableCompareColumn) Then
		MainTableCompareColumn = "Value";
	EndIf;
	
	If Not ValueIsFilled(DeductibleTableCompareColumn) Then
		DeductibleTableCompareColumn = "Value";
	EndIf;
	
	TableResult = New ValueTable;
	TableResult = MainTable.Copy();
	
	For Each Item In TableDeductible Do
		Value = Item[MainTableCompareColumn];
		StringFound = TableResult.Find(Value, MainTableCompareColumn);
		If StringFound <> Undefined Then
			TableResult.Delete(StringFound);
		EndIf;
	EndDo;
	
	Return TableResult;
	
EndFunction

// Function returns table created based on the InitializationTable.
// If InitializationTable is not specified, then create empty table.
//
Function CreateComparisonTable(InitializationTable = Undefined,
                                ComparisonColumnName = "Value")
	
	Table = New ValueTable;
	Table.Columns.Add(ComparisonColumnName);
	
	If InitializationTable <> Undefined Then
		
		ValuesArray = InitializationTable.UnloadColumn(ComparisonColumnName);
		
		For Each Item In InitializationTable Do
			NewRow = Table.Add();
			NewRow.Set(0, Item[ComparisonColumnName]);
		EndDo;
		
	EndIf;
	
	Return Table;

EndFunction
