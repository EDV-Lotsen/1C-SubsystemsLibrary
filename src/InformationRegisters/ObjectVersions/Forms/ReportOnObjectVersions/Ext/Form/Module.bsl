
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ObjectRef = Parameters.Ref;
	
	CommonTemplate = InformationRegisters.ObjectVersions.GetTemplate("StandardObjectPresentationTemplate");
	
	ColorLightGray = StyleColors.InaccessibleDataColor;
	ColorVioletRed = StyleColors.DeletedAttributeTitleBackground;
	
	If TypeOf(Parameters.ComparedVersions) = Type("Array") Then
		// Numbers of versions to be compared (retrieved from the ObjectVersions register), 
		// or one version number in case of a single object report

		ComparedVersions = New FixedArray(SortAsc(Parameters.ComparedVersions));
		
		If ComparedVersions.Count() > 1 Then
			VersionNumberString = "";
			
			VLVersionsToCompare = New ValueList;
			VLVersionsToCompare.LoadValues(Parameters.ComparedVersions);
			VLVersionsToCompare.SortByValue();
			
			For Each VersionListItem In VLVersionsToCompare Do
				VersionNumberString = VersionNumberString + String(VersionListItem.Value) + ", ";
			EndDo;
			
			VersionNumberString = Left(VersionNumberString, StrLen(VersionNumberString) - 2);
			
			Title = StringFunctionsClientServer.SubstituteParametersInString(
			                 NStr("en = 'Comparing versions ""%1"" (## %2)'"),
			                 CommonUse.SubjectString(ObjectRef),
			                 VersionNumberString);
		Else
			Title = StringFunctionsClientServer.SubstituteParametersInString(
			                 NStr("en = 'Object version ""%1"" #%2'"),
			                 ObjectRef,
			                 String(ComparedVersions[0]));
		EndIf;
		
		GenerateReport(ReportTable, ComparedVersions);
		
	Else // Using the passed object version
		
		SerializedXML = GetFromTempStorage(Parameters.SerializedObjectAddress);
		
		If Parameters.ByVersion Then // Using the single-version report
			GenerateReportOnPassedVersion(ReportTable, SerializedXML);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// The main function of the module used for report generation.
// Depending on the number of versions in the array, it initiates either 
// single-version report generation, or multiple-version difference report generation.
//
Procedure GenerateReport(ReportTS, ComparedVersions)
	
	If ComparedVersions.Count() = 1 Then
		GenerateReportOnObjectVersion(ReportTS, ComparedVersions[0]);
	Else
		GenerateReportOnChanges(ReportTS, ComparedVersions);
	EndIf;
	
EndProcedure

Procedure GenerateReportOnPassedVersion(ReportTS, SerializedXML)
	
	If ObjectRef.Metadata().Templates.Find("ObjectTemplate") <> Undefined Then
		Template = CommonUse.ObjectManagerByRef(ObjectRef).GetTemplate("ObjectTemplate");
	Else
		Template = Undefined;
	EndIf;
	
	If Template = Undefined Then
		
		ObjectVersion = ObjectVersioning.XMLObjectPresentationParsing(SerializedXML, ObjectRef);
		ObjectVersion.Insert("ObjectName",   String(ObjectRef));
		ObjectVersion.Insert("ChangeAuthor", "");
		ObjectVersion.Insert("ChangeDate",   CurrentSessionDate());
		
		Section = ReportTS.GetArea("R2");
		PutTextToReport(ReportTS, Section, "R2C2", ObjectRef.Metadata().Synonym,,,16, True);
		
		///////////////////////////////////////////////////////////////////////////////
		// Displaying the list of changed attributes
		
		ReportTS.Area("C2").ColumnWidth = 30;
		ReportTS.Area("C3").ColumnWidth = 50;
		
		DisplayedRowNumber = DisplayParsedObjectAttributes(ReportTS, ObjectVersion);
		DisplayedRowNumber = DisplayParsedObjectTabularSections(ReportTS, ObjectVersion, DisplayedRowNumber+7);
	Else
		GenerateByStandardTemplate(ReportTS, Template, GetObjectFromXML(SerializedXML), "");
	EndIf;
	
EndProcedure

// This function is used for object version report generation.
//
// Parameters:
//   ReportTS  - SpreadsheetDocument - spreadsheet document used to display the report.
//   VersionID - string/number       - object version number.
//
Procedure GenerateReportOnObjectVersion(ReportTS, VersionID)
	
	If ObjectRef.Metadata().Templates.Find("ObjectTemplate") <> Undefined Then
		Template = CommonUse.ObjectManagerByRef(ObjectRef).GetTemplate("ObjectTemplate");
	Else
		Template = Undefined;
	EndIf;
	
	VersionDetails = GetVersionDetails(VersionID).Description;
	
	If Template = Undefined Then
		ObjectVersion = ParseVersion(VersionID, ObjectRef);
		
		Section = ReportTS.GetArea("R2");
		PutTextToReport(ReportTS, Section, "R2C2", ObjectRef.Metadata().Synonym,,,16, True);
		
		///////////////////////////////////////////////////////////////////////////////
		// Displaying the list of changed attributes
		
		ReportTS.Area("C2").ColumnWidth = 30;
		OutputHeaderForVersion(ReportTS, VersionDetails, 4, 3);
		OutputHeaderForVersion(ReportTS, ObjectVersion.Comment, 5, 3);
		
		DisplayedRowNumber = DisplayParsedObjectAttributes(ReportTS, ObjectVersion);
		DisplayedRowNumber = DisplayParsedObjectTabularSections(ReportTS, ObjectVersion, DisplayedRowNumber+7);
	Else
		VersionInfo = GetObjectFromXML(ObjectVersioning.ObjectVersionDetails(ObjectRef, VersionID).ObjectVersion);
		GenerateByStandardTemplate(ReportTS, Template, VersionInfo, VersionDetails);
	EndIf;
	
EndProcedure

// Generates an object report using a standard template.
//
// Parameters:
//   ReportTS          - SpreadsheetDocument - spreadsheet document used to display the report.
//   ObjectVersion     - CatalogObject, DocumentObject - object to be displayed in the report.
//   ObjectDescription - String - object description.
//
Procedure GenerateByStandardTemplate(ReportTS, Template, ObjectVersion, Val VersionDetails)
	
	ObjectMetadata = ObjectRef.Metadata();
	
	ObjectDescription = ObjectMetadata.Name;
	
	ReportTS = New SpreadsheetDocument;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(ObjectRef)) Then
		Template = Catalogs[ObjectDescription].GetTemplate("ObjectTemplate");
	Else
		Template = Documents[ObjectDescription].GetTemplate("ObjectTemplate");
	EndIf;
	
	// Title
	Area = Template.GetArea("Title");
	ReportTS.Put(Area);
	
	Region = ReportTS.GetArea("R3");
	SetTextProperties(Area.Area("R1C2"), VersionDetails, , , , True);
	ReportTS.Put(Area);
	
	Region = ReportTS.GetArea("R5");
	ReportTS.Put(Area);
	
	// Header
	Header = Template.GetArea("Header");
	Header.Parameters.Fill(ObjectVersion);
	ReportTS.Put(Header);
	
	For Each TSMetadata In ObjectMetadata.TabularSections Do
		If ObjectVersion[TSMetadata.Name].Count() > 0 Then
			Region = Template.GetArea(TSMetadata.Name+"Header");
			ReportTS.Put(Area);
			
			AreaDetailsArrivalOfGoods = Template.GetArea(TSMetadata.Name);
			For Each CurRowGoodsReceiptDetails In ObjectVersion[TSMetadata.Name] Do
				AreaDetailsArrivalOfGoods.Parameters.Fill(CurRowGoodsReceiptDetails);
				ReportTS.Put(AreaDetailsArrivalOfGoods);
			EndDo;
		EndIf;
	EndDo;
	
	ReportTS.ShowGrid = False;
	ReportTS.Protection = True;
	ReportTS.ReadOnly = True;
	ReportTS.ShowHeaders = False;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions related to single-version object report generation

// Displays the changed attributes in the report and gets their presentation.
//
Function DisplayParsedObjectAttributes(ReportTS, ObjectVersion)
	
	Section = ReportTS.GetArea("R6");
	PutTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	PutTextToReport(ReportTS, Section, "R1C2", "Attributes", , , 11, True);
	ReportTS.StartRowGroup("AttributeGroup");
	PutTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
	
	NumberOfRowsToOutput = 0;
	
	For Each AttributeItem In ObjectVersion.Attributes Do
		
		AttributeDescription = ObjectVersioning.GetAttributePresentationInLanguage(AttributeItem.AttributeDescription);
		
		AttributeDetails = ObjectRef.Metadata().Attributes.Find(AttributeDescription);
		
		If AttributeDetails = Undefined Then
			For Each StandardAttributeDescription In ObjectRef.Metadata().StandardAttributes Do
				If StandardAttributeDescription.Name = AttributeDescription Then
					AttributeDetails = StandardAttributeDescription;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		AttributeValue = ?(AttributeItem.AttributeValue = Undefined, "", AttributeItem.AttributeValue);
		
		DisplayedDescription = AttributeDescription;
		ValuePresentation = String(AttributeValue);
		
		SetTextProperties(Section.Area("R1C2"), DisplayedDescription, , , , True);
		SetTextProperties(Section.Area("R1C3"), ValuePresentation);
		Section.Area("R1C2:R1C3").BottomBorder = New Line(SpreadsheetDocumentCellLineType.Solid, 1, 0);
		Section.Area("R1C2:R1C3").BorderColor = ColorLightGray;
		
		ReportTS.Output(Section);
		
		NumberOfRowsToOutput = NumberOfRowsToOutput + 1;
	EndDo;
	
	ReportTS.EndRowGroup();
	
	Return NumberOfRowsToOutput;
	
EndFunction

// Displays tabular sections of the parsed object (in case of a single-object report)
//
Function DisplayParsedObjectTabularSections(ReportTS, ObjectVersion, OutputRowNumber);
	
	NumberOfRowsToOutput = 0;
	
	If ObjectVersion.TabularSections.Count() <> 0 Then
		
		For Each StringTabularSection In ObjectVersion.TabularSections Do
			TabularSectionDescription = StringTabularSection.Key;
			TabularSection            = StringTabularSection.Value;
			If TabularSection.Count() > 0 Then
				
				TSMetadata = ObjectRef.Metadata().TabularSections.Find(TabularSectionDescription);
				
				TSSynonym = Undefined;
				If TSMetadata <> Undefined Then
					TSSynonym = TSMetadata.Synonym;
				EndIf;
				TSSynonym = ?(ValueIsFilled(TSSynonym), TSSynonym, TabularSectionDescription);
				
				Section = ReportTS.GetArea("R" + String(OutputRowNumber));
				PutTextToReport(ReportTS, Section, "R1C1:R1C100", " ");
				OutputArea = PutTextToReport(ReportTS, Section, "R1C2", TSSynonym, , , 11, True);
				ReportTS.Area("R"+OutputArea.Top+"C2").CreateFormatOfRows();
				ReportTS.Area("R"+OutputArea.Top+"C2").ColumnWidth = Round(StrLen(TSSynonym)*2, 0, RoundMode.Round15as20);
				ReportTS.StartRowGroup("RowGroup");
				
				PutTextToReport(ReportTS, Section, "R1C1:R1C3", " ");
				
				NumberOfRowsToOutput = NumberOfRowsToOutput + 1;
				
				OutputRowNumber = OutputRowNumber + 3;
				
				TSToAdd = New SpreadsheetDocument;
				
				TSToAdd.Join(GenerateEmptySector(TabularSection.Count()+1));
				
				ColumnNumber = 2;
				
				ColumnDimensionMapping = New Map;
				
				Section = New SpreadsheetDocument;
				
				SetTextProperties(Section.Area("R1C1"),"N", , ColorLightGray, , True, True);
				
				LineNumber = 1;
				For Each TabularSectionRow In TabularSection Do
					LineNumber = LineNumber + 1;
					SetTextProperties(Section.Area("R" + LineNumber + "C1"), String(LineNumber-1), , , , , True);
				EndDo;
				TSToAdd.Join(Section);
				
				ColumnNumber = 3;
				
				For Each TabularSectionColumn In TabularSection.Columns Do
					Section = New SpreadsheetDocument;
					FieldDescription = TabularSectionColumn.Name;
					
					FieldDetails = Undefined;
					If TSMetadata <> Undefined Then
						FieldDetails = TSMetadata.Attributes.Find(FieldDescription);
					EndIf;
					
					If FieldDetails = Undefined Or Not ValueIsFilled(FieldDetails.Synonym) Then
						DisplayedFieldDescription = FieldDescription;
					Else
						DisplayedFieldDescription = FieldDetails.Synonym;
					EndIf;
					ColumnHeaderColor = ?(FieldDetails = Undefined, ColorVioletRed, ColorLightGray);
					SetTextProperties(Section.Area("R1C1"), DisplayedFieldDescription, , ColumnHeaderColor, , True, True);
					ColumnDimensionMapping.Insert(ColumnNumber, StrLen(FieldDescription) + 4);
					LineNumber = 1;
					For Each TabularSectionRow In TabularSection Do
						LineNumber = LineNumber + 1;
						Value = ?(TabularSectionRow[FieldDescription] = Undefined, "", TabularSectionRow[FieldDescription]);
						ValuePresentation = String(Value);
						
						SetTextProperties(Section.Area("R" + LineNumber + "C1"), ValuePresentation, , , , , True);
						If StrLen(ValuePresentation) > (ColumnDimensionMapping[ColumnNumber] - 4) Then
							ColumnDimensionMapping[ColumnNumber] = StrLen(ValuePresentation) + 4;
						EndIf;
					EndDo; // For Each TabularSectionRow From TabularSection Do
					
					TSToAdd.Join(Section);
					ColumnNumber = ColumnNumber + 1;
				EndDo; // For Each TabularSectionColumn From TabularSection.Columns Do
				
				OutputArea = ReportTS.Output(TSToAdd);
				ReportTS.Area("R"+OutputArea.Top+"C1:R"+OutputArea.Bottom+"C"+ColumnNumber).CreateFormatOfRows();
				ReportTS.Area("R"+OutputArea.Top+"C2").ColumnWidth = 7;
				For CurrentColumnNumber = 3 To ColumnNumber-1 Do
					ReportTS.Area("R"+OutputArea.Top+"C"+CurrentColumnNumber).ColumnWidth = ColumnDimensionMapping[CurrentColumnNumber];
				EndDo;
				ReportTS.EndRowGroup();
				
			EndIf; // If TabularSection.Number.() > 0 Then
		EndDo; // For Each StringTabularSection From ObjectVersion.TabularSections Do
		
	EndIf;
	
EndFunction

// Displays a report header (in case of a single-object report)
//
Procedure OutputHeaderForVersion(ReportTS, Val Text, Val LineNumber, Val ColumnNumber)
	
	If Not IsBlankString(Text) Then
		
		ReportTS.Area("C"+String(ColumnNumber)).ColumnWidth = 50;
		
		State = "R" + String(LineNumber) + "C"+String(ColumnNumber);
		ReportTS.Area(State).Text = Text;
		ReportTS.Area(State).BgColor = ColorLightGray;
		ReportTS.Area(State).Font = New Font(, 8, True, , , );
		ReportTS.Area(State).TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(State).BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(State).LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		ReportTS.Area(State).RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions related to multiple-version change report generation

// The main function used for change report generation.
//
Procedure GenerateReportOnChanges(ReportTS, Val VersionArray)
	
	// Stores a temporary parsed object version that can be used to reduce the number of XML parse cycles

	Var ObjectVersion;
	
	// Global ID used for string changes between versions
	Var CounterUUID;
	
	ReportTS.Clear();
	
	// Creating an array of version numbers sorted in ascending order 
	// (this is necessary because some versions can be missing and some can be in mixed order)
	VersionNumberArray = VersionArray;
	
	// Number of object versions (k) stored in the infobase.
	// Report generation requires (k-1) comparison operations.
	// In other words, the change tables have (k) columns each. 
	//ObjectVersionCount = VersionCount;
	ObjectVersionCount = VersionNumberArray.Count();
	
	// This table stores all attribute changes and has two dimensions:
	// rows contain the names of the object attributes, 
	// and columns contain the object version IDs and change information. 
	// Version ID is a unique identifier string assigned to each object version 
	// and containing additional change information.
	AttributeChangeTable = New ValueTable;
	PrepareAttributeChangeTableColumns(AttributeChangeTable, VersionNumberArray);
	
	// This table stores all tabular section changes as a map 
	// between the names of object value tables and the change history of these value tables.
	// The map is a list of tabular sections where
	// rows contain the names of the tabular section fields, 
	// and columns contain the object version IDs. 
	// Version ID is a unique identifier string assigned to each object version 
	// and containing additional change information.
	TabularSectionChangeTable = New Map;
	
	// Generating the initial object versions.
	// The values of these versions are always displayed if any further changes are made.
	ObjectVersion_Pre = CountInitialAttributeAndTabularSectionValues(
	                               AttributeChangeTable,
	                               TabularSectionChangeTable,
	                               ObjectVersionCount,
	                               VersionNumberArray);
	
	CounterUUID = GetUUID(TabularSectionChangeTable, "Ver" + Format(VersionNumberArray[0], "NG=0"));
	
	For VersionIndex = 2 To VersionNumberArray.Count() Do
		VersionNumber = VersionNumberArray[VersionIndex-1];
		PreviousVersionNumber = "Ver" + (Format(VersionNumberArray[VersionIndex-2], "NG=0"));
		CurrentVersionColumnName = "Ver" + Format(VersionNumber, "NG=0");
		
		ComparisonResult = CalculateChanges(VersionNumber, ObjectVersion_Pre, ObjectVersion);
		
		ModAttr = ComparisonResult["Attributes"]["m"];
		AddAttr = ComparisonResult["Attributes"]["a"];
		DelAttr = ComparisonResult["Attributes"]["d"];
		
		// Filling the attribute report table
		FillAttributeChangingCharacteristic(ModAttr, "M", AttributeChangeTable, CurrentVersionColumnName, ObjectVersion);
		FillAttributeChangingCharacteristic(AddAttr, "A", AttributeChangeTable, CurrentVersionColumnName, ObjectVersion);
		FillAttributeChangingCharacteristic(DelAttr, "D", AttributeChangeTable, CurrentVersionColumnName, ObjectVersion);
		
		// Changes in tabular sections
		ModTS = ComparisonResult["TabularSections"]["m"];
		
		// This functionality is not yet implemented
		AddTS = ComparisonResult["TabularSections"]["a"];
		DelTS = ComparisonResult["TabularSections"]["d"];
		
		For Each MapItem In ObjectVersion.TabularSections Do
			TableName = MapItem.Key;
			
			If ValueIsFilled(AddTS.Find(TableName))
			 Or ValueIsFilled(DelTS.Find(TableName)) Then
				Continue;
			EndIf;
			
			TabularSectionChangeTable[TableName][CurrentVersionColumnName] = 
			        ObjectVersion.TabularSections[TableName].Copy();
			TableVersionRef = TabularSectionChangeTable[TableName][CurrentVersionColumnName];
			TableVersionRef.Columns.Add("Versioning_RowID");
			TableVersionRef.FillValues(Undefined, "Versioning_RowID");
			TableVersionRef.Columns.Add("Versioning_RowID");
			TableVersionRef.FillValues(Undefined, "Versioning_RowID");
			TableWithChanges = ModTS.Get(TableName);
			If TableWithChanges <> Undefined Then
				ModTS_MRows = TableWithChanges["M"];
				ModTS_ARows = TableWithChanges["A"];
				ModTS_DRows = TableWithChanges["D"];
				
				DimensionInTS0 = ObjectVersion_Pre.TabularSections[TableName].Count();
				If DimensionInTS0 = 0 Then
					SelectedInTS0 = New Array;
				Else
					SelectedInTS0 = New Array(DimensionInTS0);
				EndIf;
				
				DimensionInTS1 = ObjectVersion.TabularSections[TableName].Count();
				If DimensionInTS1 = 0 Then
					SelectedInTS1 = New Array;
				Else
					SelectedInTS1 = New Array(DimensionInTS1);
				EndIf;
				
				For Each TSItem In ModTS_MRows Do
					VCTRow = TabularSectionChangeTable[TableName][PreviousVersionNumber][TSItem.IndexInTS0-1];
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_RowID = VCTRow.Versioning_RowID;
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_Modification = "M";
				EndDo;
				
				For Each TSItem In ModTS_ARows Do
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_RowID = IncreaseCounter(CounterUUID, TableName);
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_Modification = "A";
				EndDo;
				
				// UniqueID must be assigned for each item, for comparison with previous versions
				For Index = 1 To TableVersionRef.Count() Do
					If TableVersionRef[Index-1].Versioning_RowID = Undefined Then
						// Found a row that must be looked up for mapping in the previous table
						TSRow = TableVersionRef[Index-1];
						
						FilterParameters = New Structure;
						CommonColumns = FindCommonColumns(TableVersionRef, TabularSectionChangeTable[TableName][PreviousVersionNumber]);
						For Each ColumnName In CommonColumns Do
							If (ColumnName <> "Versioning_RowID") And (ColumnName <> "Versioning_RowID") Then
								FilterParameters.Insert(ColumnName, TSRow[ColumnName]);
							EndIf;
						EndDo;
						
						PreviousTSRowArray = TabularSectionChangeTable[TableName][PreviousVersionNumber].FindRows(FilterParameters);
						
						FilterParameters.Insert("Versioning_RowID", Undefined);
						CurrentTSRowArray = TableVersionRef.FindRows(FilterParameters);
						
						For IDByVT_Current = 1 To CurrentTSRowArray.Count() Do
							If IDByVT_Current <= PreviousTSRowArray.Count() Then
								CurrentTSRowArray[IDByVT_Current-1].Versioning_RowID = PreviousTSRowArray[IDByVT_Current-1].Versioning_RowID;
							EndIf;
							CurrentTSRowArray[IDByVT_Current-1].Versioning_Modification = False;
						EndDo;
					EndIf;
				EndDo;
				For Each TSItem In ModTS_DRows Do
					RowImaginary = TableVersionRef.Add();
					RowImaginary.Versioning_RowID = TabularSectionChangeTable[TableName][PreviousVersionNumber][TSItem.IndexInTS0-1].Versioning_RowID;
					RowImaginary.Versioning_Modification = "D";
				EndDo;
			EndIf;
		EndDo;
		ObjectVersion_Pre = ObjectVersion;
	EndDo;
	
	// Passing all available data to the function that displays this data in the report
	DisplayCompositionResultsInReportLayout(AttributeChangeTable,
									  TabularSectionChangeTable,
									  CounterUUID,
									  VersionNumberArray,
									  ReportTS);
	
	TemplateLegend = CommonTemplate.GetArea("Legend");
	ReportTS.Output(TemplateLegend);
	
EndProcedure

Procedure DisplayAttributeChanges(ReportTS,
                                  AttributeChangeTable,
                                  VersionNumberArray)
	
	AttributeHeaderArea = CommonTemplate.GetArea("AttributeHeader");
	ReportTS.Output(AttributeHeaderArea);
	ReportTS.StartRowGroup("AttributeGroup");
	
	For Each ModAttributeItem In AttributeChangeTable Do
		If ModAttributeItem.Versioning_Modification = True Then
			// Getting attribute name
			AttributeDescription = ModAttributeItem.Description;
			// Displaying attribute name (first replacing it if the name is predefined)
			DisplayedDescription = ObjectVersioning.GetAttributePresentationInLanguage(AttributeDescription);
			
			AttributeDetails = ObjectRef.Metadata().Attributes.Find(DisplayedDescription);
			
			If AttributeDetails = Undefined Then
				For Each StandardAttributeDescription In ObjectRef.Metadata().StandardAttributes Do
					If StandardAttributeDescription.Name = ObjectVersioning.GetAttributePresentationInLanguage(AttributeDescription) Then
						AttributeDetails = StandardAttributeDescription;
						Break;
					EndIf;
				EndDo;
			EndIf;
			
			EmptyCell = CommonTemplate.GetArea("EmptyCell");
			ReportTS.Output(EmptyCell);;
			
			AttributeDescription = CommonTemplate.GetArea("FieldAttributeDescription");
			AttributeDescription.Parameters.FieldAttributeDescription = DisplayedDescription;
			ReportTS.Join(AttributeDescription);
			
			IndexByAttributeVersions = VersionNumberArray.Count();
			
			While IndexByAttributeVersions >= 1 Do
				StructureChangeCharacteristic = ModAttributeItem["Ver" + Format(VersionNumberArray[IndexByAttributeVersions-1], "NG=0")];
				
				AttributeValuePresentation = "";
				AttributeValue = "";
				Update = Undefined;
				ValueType = "";
				
				// Skipping to the next version if the attribute was not changed in the current version
				If TypeOf(StructureChangeCharacteristic) = Type("String") Then
					
					AttributeValuePresentation = String(AttributeValue);
					
				ElsIf StructureChangeCharacteristic <> Undefined Then
					If StructureChangeCharacteristic.ChangeType = "D" Then
					Else
						AttributeValue = StructureChangeCharacteristic.Value.AttributeValue;
						AttributeValuePresentation = String(AttributeValue);
					EndIf;
					// Getting the attribute change structure for the current version
					Update = StructureChangeCharacteristic.ChangeType;
				EndIf;
				
				If AttributeValuePresentation = "" Then
					AttributeValuePresentation = AttributeValue;
					If AttributeValuePresentation = "" Then
						AttributeValuePresentation = " ";
					EndIf;
				EndIf;
				
				If      Update = Undefined Then
					AttributeValueRegion = CommonTemplate.GetArea("AttributeSourceValue");
					AttributeValueRegion.Parameters.AttributeValue = AttributeValuePresentation;
				ElsIf Update = "M" Then
					AttributeValueRegion = CommonTemplate.GetArea("AttributeChangedValue");
					AttributeValueRegion.Parameters.AttributeValue = AttributeValuePresentation;
				ElsIf Update = "D" Then
					AttributeValueRegion = CommonTemplate.GetArea("DeletedAttribute");
					AttributeValueRegion.Parameters.AttributeValue = AttributeValuePresentation;
				ElsIf Update = "A" Then
					AttributeValueRegion = CommonTemplate.GetArea("AddedAttribute");
					AttributeValueRegion.Parameters.AttributeValue = AttributeValuePresentation;
				EndIf;
				
				ReportTS.Join(AttributeValueRegion);
				
				IndexByAttributeVersions = IndexByAttributeVersions - 1;
			EndDo;
		EndIf; // If ItemModAttribute.Versioning_Modification = True Then
	EndDo;
	
	ReportTS.EndRowGroup();
	
EndProcedure

Procedure DisplayTabularSectionChanges(ReportTS,
                                       TabularSectionChangeTable,
                                       VersionNumberArray,
                                       CounterUUID)
	
	TabularSectionAreaHeaderDisplayed = False;
	
	EmptyRowTemplate = CommonTemplate.GetArea("EmptyRow");
	NextTSRowTemplate = CommonTemplate.GetArea("TabularSectionRowHeader");
	
	ReportTS.Output(EmptyRowTemplate);
	
	// Repeating for each changed item
	For Each ChangedTSItem In TabularSectionChangeTable Do
		TabularSectionName = ChangedTSItem.Key;
		CurrentTSVersions = ChangedTSItem.Value;
		
		CurrentTabularSectionChanged = False;
		
		For CurrCounterUUID = 1 To CounterUUID[TabularSectionName] Do
			
			UUIDStringChanged = False;
			// If any changes are found, it is necessary to display the initial version (before the change)
			InitialVersionFilled = False;
			
			// Searching for the current row (UniqueID = CurrCounterUUID) through all change history.
			// If the row is deleted you can cancel the search, color-mark the "deleted" flag,
			// and proceed to the next row.
			IndexByVersions = VersionNumberArray.Count();
			
			// ---------------------------------------------------------------------------------
			// Browsing the versions to make sure that changes are found ---
			
			RowModified = False;
			
			While IndexByVersions >= 1 Do
				CurrentTSVersionColumn = "Ver" + Format(VersionNumberArray[IndexByVersions-1], "NG=0");
				CurrentVersionTS = CurrentTSVersions[CurrentTSVersionColumn];
				
				FoundRow = Undefined;
				If CurrentVersionTS.Columns.Find("Versioning_RowID") <> Undefined Then
					FoundRow = CurrentVersionTS.Find(CurrCounterUUID, "Versioning_RowID");
				EndIf;
				
				If FoundRow <> Undefined Then
					If (FoundRow.Versioning_Modification <> Undefined) Then
						If (TypeOf(FoundRow.Versioning_Modification) = Type("String")
							Or (TypeOf(FoundRow.Versioning_Modification) = Type("Boolean")
							      And FoundRow.Versioning_Modification = True)) Then
							RowModified = True;
						EndIf;
					EndIf;
				EndIf;
				IndexByVersions = IndexByVersions - 1;
			EndDo;
			
			If Not RowModified Then
				Continue;
			EndIf;
			
			// ---------------------------------------------------------------------------------
			
			// Displaying the versions as a spreadsheet document
			IndexByVersions = VersionNumberArray.Count();
			
			IntervalBetweenFillings = 0;
			
			// Searching each version for the changed row by its UUID
			While IndexByVersions >= 1 Do
				IntervalBetweenFillings = IntervalBetweenFillings + 1;
				CurrentTSVersionColumn = "Ver" + Format(VersionNumberArray[IndexByVersions-1]);
				// Tabular section of the current version (table of modified values)
				CurrentVersionTS = CurrentTSVersions[CurrentTSVersionColumn];
				FoundRow = CurrentVersionTS.Find(CurrCounterUUID, "Versioning_RowID");
				
				// Changed row found in a version (this change is possibly the latest)
				If FoundRow <> Undefined Then
					
					// This section displays common header for the tabular sections area
					If Not TabularSectionAreaHeaderDisplayed Then
						TabularSectionAreaHeaderDisplayed = True;
						CommonTSSectionHeaderTemplate = CommonTemplate.GetArea("TabularSectionsHeader");
						ReportTS.Output(CommonTSSectionHeaderTemplate);
						ReportTS.StartRowGroup("TabularSectionGroup");
						ReportTS.Output(EmptyRowTemplate);
					EndIf;
					
					// This section displays header for the current tabular section
					If Not CurrentTabularSectionChanged Then
						CurrentTabularSectionChanged = True;
						CurrentTSHeaderTemplate = CommonTemplate.GetArea("TabularSectionHeader");
						CurrentTSHeaderTemplate.Parameters.TabularSectionDescription = TabularSectionName;
						ReportTS.Output(CurrentTSHeaderTemplate);
						ReportTS.StartRowGroup("TabularSection"+TabularSectionName);
						ReportTS.Output(EmptyRowTemplate);
					EndIf;
					
					Modification = FoundRow.Versioning_Modification;
					
					If UUIDStringChanged = False Then
						UUIDStringChanged = True;
						
						TSRowHeaderTemplate = CommonTemplate.GetArea("TabularSectionRowHeader");
						TSRowHeaderTemplate.Parameters.TabularSectionRowNumber = CurrCounterUUID;
						ReportTS.Output(TSRowHeaderTemplate);
						ReportTS.StartRowGroup("RowGroup"+TabularSectionName+CurrCounterUUID);
						
						OutputType = "";
						If Modification = "D" Then
							OutputType = "D"
						EndIf;
						FillArray = New Array;
						For Each Column In CurrentVersionTS.Columns Do
							If Column.Name = "Versioning_RowID"
							 Or Column.Name = "Versioning_RowID" Then
								Continue;
							EndIf;
							FillArray.Add(Column.Name);
						EndDo;
						
						EmptySector = GenerateEmptySector(CurrentVersionTS.Columns.Count()-2);
						EmptySectorToFill = GenerateEmptySector(CurrentVersionTS.Columns.Count()-2, OutputType);
						Section = GenerateTSRowSector(FillArray, OutputType);
						
						ReportTS.Join(EmptySector);
						ReportTS.Join(Section);
					EndIf;
					
					While IntervalBetweenFillings > 1 Do
						ReportTS.Join(EmptySectorToFill);
						IntervalBetweenFillings = IntervalBetweenFillings - 1;
					EndDo;
					
					IntervalBetweenFillings = 0;
					
					// Filling the next changed table row
					FillArray = New Array;
					For Each Column In CurrentVersionTS.Columns Do
						If Column.Name = "Versioning_RowID"
						 Or Column.Name = "Versioning_RowID" Then
							Continue;
						EndIf;
						
						Presentation = String(FoundRow[Column.Name]);
						FillArray.Add(Presentation);
						
					EndDo;
					
					If TypeOf(Modification) = Type("Boolean") Then
						OutputType = "";
					Else
						OutputType = Modification;
					EndIf;
					
					Section = GenerateTSRowSector(FillArray, OutputType);
					
					ReportTS.Join(Section);
					
				EndIf; // FoundRow <> Undefined
				IndexByVersions = IndexByVersions - 1;
			EndDo;
			
			If UUIDStringChanged Then
				ReportTS.EndRowGroup();
				ReportTS.Output(EmptyRowTemplate);
			EndIf;
			
		EndDo;
		
		If CurrentTabularSectionChanged Then
			ReportTS.EndRowGroup();
			ReportTS.Output(EmptyRowTemplate);
		EndIf;
		
	EndDo;
	
	If TabularSectionAreaHeaderDisplayed Then
		ReportTS.EndRowGroup();
		ReportTS.Output(EmptyRowTemplate);
	EndIf;
	
EndProcedure

Function DisplayCompositionResultsInReportLayout(AttributeChangeTable,
                                                 TabularSectionChangeTable,
                                                 CounterUUID,
                                                 VersionNumberArray,
                                                 ReportTS)
	
	ChangedAttributeCount = CalculateChangedAttributeCount(AttributeChangeTable, VersionNumberArray);
	NumberOfVersions = VersionNumberArray.Count();
	
	///////////////////////////////////////////////////////////////////////////////
	//                           DISPLAYING REPORT                                  // 
	///////////////////////////////////////////////////////////////////////////////
	
	ReportTS.Clear();
	
	OutputHeader(ReportTS, VersionNumberArray, NumberOfVersions);
	
	If ChangedAttributeCount = 0 Then
		AttributeHeaderArea = CommonTemplate.GetArea("AttributeHeader");
		ReportTS.Output(AttributeHeaderArea);
		ReportTS.StartRowGroup("AttributeGroup");
		AttributesUnchangedSection = CommonTemplate.GetArea("AttributesUnchanged");
		ReportTS.Output(AttributesUnchangedSection);
		ReportTS.EndRowGroup();
	Else
		DisplayAttributeChanges(ReportTS,
		                        AttributeChangeTable,
		                        VersionNumberArray);
		
	EndIf;
	
	DisplayTabularSectionChanges(ReportTS,
	                             TabularSectionChangeTable,
	                             VersionNumberArray,
	                             CounterUUID);
	
	ReportTS.TotalsBelow = False;
	ReportTS.ShowGrid = False;
	ReportTS.Protection = False;
	ReportTS.ReadOnly = True;
	
EndFunction

Function OutputHeader(ReportTS, VersionNumberArray, NumberOfVersions)
	
	SectionHeader = CommonTemplate.GetArea("Header");
	SectionHeader.Parameters.ReportDescription = NStr("en = 'Object version change report'");
	SectionHeader.Parameters.ObjectDescription = String(ObjectRef);
	
	ReportTS.Output(SectionHeader);
	
	EmptyCell = CommonTemplate.GetArea("EmptyCell");
	VersionArea = CommonTemplate.GetArea("VersionTitle");
	ReportTS.Join(EmptyCell);
	ReportTS.Join(VersionArea);
	VersionArea = CommonTemplate.GetArea("VersionPresentation");
	
	VersionComments = New Structure;
	HasComments = False;
	
	IndexByVersions = NumberOfVersions;
	While IndexByVersions > 0 Do
		
		VersionInfo = GetVersionDetails(VersionNumberArray[IndexByVersions-1]);
		VersionArea.Parameters.VersionPresentation = VersionInfo.Description;
		
		VersionComments.Insert("Comment" + IndexByVersions, VersionInfo.Comment);
		If Not IsBlankString(VersionInfo.Comment) Then
			HasComments = True;
		EndIf;
		
		ReportTS.Join(VersionArea);
		ReportTS.Area("C"+String(IndexByVersions+2)).ColumnWidth = 50;
		IndexByVersions = IndexByVersions - 1;
		
	EndDo;
	
	If HasComments Then
		
		CommentArea = CommonTemplate.GetArea("TitleComment");
		ReportTS.Output(EmptyCell);
		ReportTS.Join(CommentArea);
		CommentArea = CommonTemplate.GetArea("Comment");
		
		IndexByVersions = NumberOfVersions;
		While IndexByVersions > 0 Do
			
			CommentArea.Parameters.Comment = VersionComments["Comment" + IndexByVersions];
			ReportTS.Join(CommentArea);
			IndexByVersions = IndexByVersions - 1;
			
		EndDo;
		
	EndIf;
	
	EmptyRowArea = CommonTemplate.GetArea("EmptyRow");
	ReportTS.Output(EmptyRowArea);
	
EndFunction

// Report engine. Generates the report by the passed version number.
// Compares version passed in the ParseVersionResult_0 parameter
// and version specified in the VersionNumber parameter.
// The procedure steps are:
//  1. Parsing the object versions to be compared
//  2. Creating the list of attributes and tabular sections that were
//    - changed
//    - added
//    - deleted
//
Function CalculateChanges(VersionNumber,
                           ParseVersionResult_0,
                           ParseVersionResult_1)
	
	IsDocument = False;
	
	If Metadata.Documents.Contains(ObjectRef.Metadata()) Then
		IsDocument = True;
	EndIf;
	
	// Parsing the previous version
	Attributes_0      = ParseVersionResult_0.Attributes;
	TabularSections_0 = ParseVersionResult_0.TabularSections;
	
	// Parsing the latest version
	ParseVersionResult_1 = ParseVersion(VersionNumber, ObjectRef);
	AddRowNumbersToTabularSections(ParseVersionResult_1.TabularSections);
	
	Attributes_1      = ParseVersionResult_1.Attributes;
	TabularSections_1 = ParseVersionResult_1.TabularSections;
	
	///////////////////////////////////////////////////////////////////////////////
	//           Generating the list of changed tabular sections           
	/////////////////////////////////////////////////////////////////////////////////
	TabularSectionList_0	= CreateComparisonChart();
	For Each Item In TabularSections_0 Do
		NewRow = TabularSectionList_0.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	TabularSectionList_1	= CreateComparisonChart();
	For Each Item In TabularSections_1 Do
		NewRow = TabularSectionList_1.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	// Metadata structure is possibly changed (attributes were added or deleted)
	TSToAddList = SubtractTable(TabularSectionList_1, TabularSectionList_0);
	DeletedTSList  = SubtractTable(TabularSectionList_0, TabularSectionList_1);
	
	// List of unchanged attributes, used to search for matches or discrepancies
	RemainingTSList = SubtractTable(TabularSectionList_1, TSToAddList);
	
	// List of attributes that were changed
	ChangedTSList = FindChangedTabularSections(RemainingTSList,
	                                                       TabularSections_0,
	                                                       TabularSections_1);
	
	///////////////////////////////////////////////////////////////////////////////
	//           Forming a list of attributes that were changed                 
	/////////////////////////////////////////////////////////////////////////////////
	AttributeList0 = CreateComparisonChart();
	For Each Attribute In ParseVersionResult_0.Attributes Do
		NewRow = AttributeList0.Add();		
		NewRow.Set(0, TrimAll(String(Attribute.AttributeDescription)));
	EndDo;
	
	AttributeList1 = CreateComparisonChart();
	For Each Attribute In ParseVersionResult_1.Attributes Do
		NewRow = AttributeList1.Add();
		NewRow.Set(0, TrimAll(String(Attribute.AttributeDescription)));
	EndDo;
	
	// Metadata structure is possibly changed (attributes were added or deleted)
	AddedAttributeList = SubtractTable(AttributeList1, AttributeList0);
	DeletedAttributeList  = SubtractTable(AttributeList0, AttributeList1);
	
	// List of unchanged attributes, used to search for matches or discrepancies
	RemainingAttributeList = SubtractTable(AttributeList1, AddedAttributeList);
	
	// List of attributes that were changed
	ChangedAttributeList = CreateComparisonChart();
	
	ChangesInAttributes = New Map;
	ChangesInAttributes.Insert("a", AddedAttributeList);
	ChangesInAttributes.Insert("d", DeletedAttributeList);
	ChangesInAttributes.Insert("m", ChangedAttributeList);
	
	For Each ValueTableRow In RemainingAttributeList Do
		
		Attribute = ValueTableRow.Value;
		Val_0 = Attributes_0.Find(Attribute, "AttributeDescription").AttributeValue;
		Val_1 = Attributes_1.Find(Attribute, "AttributeDescription").AttributeValue;
		
		If TypeOf(Val_0) <> Type("ValueStorage")
			And TypeOf(Val_1) <> Type("ValueStorage") Then
			If Val_0 <> Val_1 Then
				NewRow = ChangedAttributeList.Add();
				NewRow.Set(0, Attribute);
			EndIf;
		EndIf;
		
	EndDo;
	
	ChangesInTables = CalculateChangesInTabularSections(
	                              ChangedTSList,
	                              TabularSections_0,
	                              TabularSections_1);
	
	TabularSectionModifications = New Structure;
	TabularSectionModifications.Insert("a", TSToAddList);
	TabularSectionModifications.Insert("d", DeletedTSList);
	TabularSectionModifications.Insert("m", ChangesInTables);
	
	ChangesComposition = New Map;
	ChangesComposition.Insert("Attributes",      ChangesInAttributes);
	ChangesComposition.Insert("TabularSections", TabularSectionModifications);
	
	Return ChangesComposition;
	
EndFunction

// This function adds a column for each object version.
// The column names are "Ver<Number>" where <Number> increases from 1 
// to the number of saved versions of the object.
// The numbering is strictly local; for example, a column named Ver1 is not necessarily related to
// the initial version of the object.
//
Procedure PrepareAttributeChangeTableColumns(ValueTable,
                                             VersionNumberArray)
	
	ValueTable = New ValueTable;
	
	ValueTable.Columns.Add("Description");
	ValueTable.Columns.Add("Versioning_RowID");
	ValueTable.Columns.Add("Versioning_ValueType"); // Expected value type
	
	For Index = 1 To VersionNumberArray.Count() Do
		ValueTable.Columns.Add("Ver" + Format(VersionNumberArray[Index-1], "NG=0"));
	EndDo;
	
EndProcedure

Function CalculateChangesInTabularSections(ChangedTSList,
                                           TabularSections_0,
                                           TabularSections_1)
	
	ChangesInTables = New Map;
	
	// Repeating for each tabular section
	For Index = 1 To ChangedTSList.Count() Do
		
		ChangesInTables.Insert(ChangedTSList[Index-1].Value, New Map);
		
		TableToAnalyze = ChangedTSList[Index-1].Value;
		TS0 = TabularSections_0[TableToAnalyze];
		TS1 = TabularSections_1[TableToAnalyze];
		
		ChangedRowsTable = New ValueTable;
		ChangedRowsTable.Columns.Add("IndexInTS0");
		ChangedRowsTable.Columns.Add("IndexInTS1");
		
		TS0RowsAndTS1RowsMapping = FindSimilarTableRows(TS0, TS1);
		TS1RowsAndTS0RowsMapping = New Map;
		ColumnsToCheck = FindCommonColumns(TS0, TS1);
		For Each Map In TS0RowsAndTS1RowsMapping Do
			TableRow0 = Map.Key;
			TableRow1 = Map.Value;
			If RowsHaveDifferences(TableRow0, TableRow1, ColumnsToCheck) Then
					NewRow = ChangedRowsTable.Add();
					NewRow["IndexInTS0"] = LineIndex(TableRow0) + 1;
					NewRow["IndexInTS1"] = LineIndex(TableRow1) + 1;
			EndIf;
			TS1RowsAndTS0RowsMapping.Insert(TableRow1, TableRow0);
		EndDo;
		
		AddedRowTable = New ValueTable;
		AddedRowTable.Columns.Add("IndexInTS1");
		
		For Each TableRow In TS1 Do
			If TS1RowsAndTS0RowsMapping[TableRow] = Undefined Then
				NewRow = AddedRowTable.Add();
				NewRow.IndexInTS1 = TS1.IndexOf(TableRow) + 1;
			EndIf;
		EndDo;
		
		DeletedRowTable = New ValueTable;
		DeletedRowTable.Columns.Add("IndexInTS0");
		
		For Each TableRow In TS0 Do
			If TS0RowsAndTS1RowsMapping[TableRow] = Undefined Then
				NewRow = DeletedRowTable.Add();
				NewRow.IndexInTS0 = TS0.IndexOf(TableRow) + 1;
			EndIf;
		EndDo;
		
		ChangesInTables[ChangedTSList[Index-1].Value].Insert("A", AddedRowTable);
		ChangesInTables[ChangedTSList[Index-1].Value].Insert("D", DeletedRowTable);
		ChangesInTables[ChangedTSList[Index-1].Value].Insert("M", ChangedRowsTable);
		
	EndDo;
	
	Return ChangesInTables;
	
EndFunction

// Compares two tabular sections from the list passed in the first parameter,
// and attempts to find any differences between them.
// If any differences are found, generates the list of changed tabular sections.
//
Function FindChangedTabularSections(RemainingTSList,
                                        TabularSections_0,
                                        TabularSections_1)
	
	ChangedTSList = CreateComparisonChart();
	
	// Searching for tabular sections with changed rows
	For Each Item In RemainingTSList Do
		
		TS_0 = TabularSections_0[Item.Value];
		TS_1 = TabularSections_1[Item.Value];
		
		If TS_0.Count() = TS_1.Count() Then
			
			DifferenceFound = False;
			
			// Making sure the column structure remains the same
			If TabularSectionsEqual (TS_0.Columns, TS_1.Columns) Then
				
				// Searching for differing items (rows)
				For Index = 0 To TS_0.Count() - 1 Do
					String_0 = TS_0[Index];
					String_1 = TS_1[Index];
					
					If Not TSRowsEqual(String_0, String_1, TS_0.Columns) Then
						DifferenceFound = True;
						Break;
					EndIf
				EndDo;
				
			Else
				DifferenceFound = True;
			EndIf;
			
			If DifferenceFound Then
				NewRow = ChangedTSList.Add();
				NewRow.Set(0, Item.Value);
			EndIf;
			
		Else
			NewRow = ChangedTSList.Add();
			NewRow.Set(0, Item.Value);
		EndIf;
			
	EndDo;
	
	Return ChangedTSList;
	
EndFunction

// Gets an object from the information register by object version number and reference,
// writes the object to the hard disk, and calls the XML object presentation parsing function.
// Parameters:
//   VersionNumber - Number - document version in the information register.
//   Ref           - CatalogRef/DocumentRef - reference to the metadata object instance.
// Returns:
//   Structure.
//
Function ParseVersion(VersionNumber, Ref)
	
	VersionInfo = ObjectVersioning.ObjectVersionDetails(Ref, VersionNumber);
	
	Result = ObjectVersioning.XMLObjectPresentationParsing(VersionInfo.ObjectVersion, Ref);
	Result.Insert("ObjectName",     String(Ref));
	Result.Insert("ChangeAuthor", TrimAll(String(VersionInfo.VersionAuthor)));
	Result.Insert("ChangeDate",  VersionInfo.VersionDate);
	Result.Insert("Comment",    VersionInfo.Comment);
	
	Return Result;
	
EndFunction

// Reads the initial values of attributes and tabular sections of a document.
// The attribute data structure is in the following format:
// AttributeTable - ValueTable
// Columns 
// |-Ver<junior version number> 
// |-...
// |-Ver<senior version number>
// |-Versioning_Modification (Boolean) 
// |-Description
//
// Rows contain lists of attributes and their changes over time.
// Versioning_Modification column contains the row modification flag:
//   false - row is unchanged
//   "m"   - row was modified
//   "a"   - row was added
//   "d"   - row was deleted
//
// Format of the generated data structure for value tables:
// TableTS - Map
// |- <Tabular section name 1> - Map
//    |-Ver<junior version number> - ValueTable
//       Columns
//       |Basic columns of the matching object part table
//       |Versioning_RowID        - row ID, unique within the table
//       |Versioning_Modification - row modification flag:
//                                    false - row is unchanged
//                                    "m"   - row was modified
//                                    "a"   - row was added
//                                    "d"   - row was deleted
//    |-...
//    |-Ver<senior version number> 
// |-...
// |- <Tabular section name N>
//
Function CountInitialAttributeAndTabularSectionValues(AttributeTable,
                                                      TableTS,
                                                      VersionCount,
                                                      VersionNumberArray)
	
	JuniorObjectVersion = VersionNumberArray[0];
	
	// Parsing the first version
	ObjectVersion  = ParseVersion(JuniorObjectVersion, ObjectRef);
	AddRowNumbersToTabularSections(ObjectVersion.TabularSections);
	
	Attributes      = ObjectVersion.Attributes;
	TabularSections = ObjectVersion.TabularSections;
	
	Column = "Ver" + Format(VersionNumberArray[0], "NG=0");
	
	For Each ValueTableRow In Attributes Do
		
		NewRow = AttributeTable.Add();
		NewRow[Column] = New Structure("ChangeType, Value", "M", ValueTableRow);
		NewRow.Description = ValueTableRow.AttributeDescription;
		NewRow.Versioning_Modification = False;
		NewRow.Versioning_ValueType = ValueTableRow.AttributeType;
		
	EndDo;
	
	For Each TSItem In TabularSections Do
		
		TableTS.Insert(TSItem.Key, New Map);
		PrepareChangeTableColumnsForMapping(TableTS[TSItem.Key], VersionNumberArray);
		TableTS[TSItem.Key]["Ver" + Format(JuniorObjectVersion, "NG=0")] = TSItem.Value.Copy();
		
		CurrentVT = TableTS[TSItem.Key]["Ver" + Format(JuniorObjectVersion, "NG=0")];
		
		// This is a special row ID used to distinguish between rows.
		// This ID is unique within a value table.
		
		CurrentVT.Columns.Add("Versioning_RowID");
		CurrentVT.Columns.Add("Versioning_RowID");
		
		For Index = 1 To CurrentVT.Count() Do
			CurrentVT[Index-1].Versioning_RowID = Index;
			CurrentVT[Index-1].Versioning_Modification = False;
		EndDo;
	
	EndDo;
	
	Return ObjectVersion;
	
EndFunction

Procedure PrepareChangeTableColumnsForMapping(Map, VersionNumberArray)
	
	Quantity = VersionNumberArray.Count();
	
	For Index = 1 To Quantity Do
		Map.Insert("Ver" + Format(VersionNumberArray[Index-1], "NG=0"), New ValueTable);
	EndDo;
	
EndProcedure

// Returns True if the tabular sections are equal, or False otherwise.
// Two tabular sections are considered to be equal 
// if they have identical number of fields, identical field names and types. 
// Different order of columns is not considered as a difference between tabular sections.
//
Function TabularSectionsEqual(FirstTableColumns, SecondTableColumns)
	If FirstTableColumns.Count() <> SecondTableColumns.Count() Then
		Return False;
	EndIf;
	
	For Each Column In FirstTableColumns Do
		Found = SecondTableColumns.Find(Column.Name);
		If Found = Undefined Or Column.ValueType <> Found.ValueType Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

// Compares values of two rows and returns True if the rows are equal, or False otherwise.
// Metadata structure of both tabular sections is assumed to be equal.
//
Function TSRowsEqual(TSRow1, TSRow2, Columns)
	
	For Each Column In Columns Do
		ColumnName = Column.Name;
		If TSRow2.Owner().Columns.Find(ColumnName) = Undefined Then
			Continue;
		EndIf;
		ValueFromTS1 = TSRow1[ColumnName];
		ValueFromTS2 = TSRow2[ColumnName];
		If ValueFromTS1 <> ValueFromTS2 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

// Displays text with conditional appearance in the spreadsheet document area.
//
Procedure SetTextProperties(SectionArea, Text,
                                   Val TextColor = Undefined,
                                   Val BgColor = Undefined,
                                   Val Size = 9,
                                   Val Bold = False,
                                   Val ShowBorders = False)
	
	SectionArea.Text = Text;
	
	If TextColor <> Undefined Then
		SectionArea.TextColor = TextColor;
	EndIf;
	
	If BgColor <> Undefined Then
		SectionArea.BgColor = BgColor;
	EndIf;
	
	SectionArea.Font = New Font(, Size, Bold, , , );
	
	If ShowBorders Then
		SectionArea.TopBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.BottomBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.LeftBorder  = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.RightBorder = New Line(SpreadsheetDocumentCellLineType.Solid);
		SectionArea.HorizontalAlign = HorizontalAlign.Center;
	EndIf;
	
EndProcedure

// Gets stored object version details in string format.
//
Function GetVersionDetails(VersionNumber)
	
	VersionInfo = ObjectVersioning.ObjectVersionDetails(ObjectRef, VersionNumber);
	Description = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '# %1 / (%2) / %3'"), 
		VersionNumber, String(VersionInfo.VersionDate), TrimAll(String(VersionInfo.VersionAuthor)));
	VersionInfo.Insert("Description", Description);
	
	Return VersionInfo;
	
EndFunction

// Counts the number of changed attributes in the table of changed attributes.
//
Function CalculateChangedAttributeCount(AttributeChangeTable, VersionNumberArray)
	
	Result = 0;
	
	For Each VTItem In AttributeChangeTable Do
		If VTItem.Versioning_Modification <> Undefined And VTItem.Versioning_Modification = True Then
			Result = Result + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Increments the global counter for the table.
//
Function IncreaseCounter(CounterUUID, TableName);
	
	CounterUUID[TableName] = CounterUUID[TableName] + 1;
	
	Return CounterUUID[TableName];
	
EndFunction

// Returns a unique numerical ID for version table row identification.
//
Function GetUUID(TSChangeTable, VersionColumnName)
	
	MapUUID = New Map;
	
	For Each ItemMap In TSChangeTable Do
		MapUUID[ItemMap.Key] = Number(ItemMap.Value[VersionColumnName].Count());
	EndDo;
	
	Return MapUUID;
	
EndFunction

// Fills the report table with intermediate comparison results.
//
// Parameters:
//   ChangeFlag - String - "a" - attribute was added
//                         "d" - attribute was deleted
//                         "m" - attribute was modified
//
Procedure FillAttributeChangingCharacteristic(SingleAttributeChangeTable, 
                                                    ChangeFlag,
                                                    AttributeChangeTable,
                                                    CurrentVersionColumnName,
                                                    ObjectVersion)
	
	For Each Item In SingleAttributeChangeTable Do
		Description = Item.Value;
		AttributeChange = AttributeChangeTable.Find (Description, "Description");
		
		If AttributeChange = Undefined Then
			AttributeChange = AttributeChangeTable.Add();
			AttributeChange.Description = Description;
		EndIf;
		
		ChangeParameters = New Structure;
		ChangeParameters.Insert("ChangeType", ChangeFlag);
		
		If ChangeFlag = "d" Then
			ChangeParameters.Insert("Value", "deleted");
		Else
			ChangeParameters.Insert("Value", ObjectVersion.Attributes.Find(Description, "AttributeDescription"));
		EndIf;
		
		AttributeChange[CurrentVersionColumnName] = ChangeParameters;
		AttributeChange.Versioning_Modification = True;
	EndDo;
	
EndProcedure

// Displays the text with specific appearance in the tabular document area.
//
Function PutTextToReport(ReportTS,
                           Val Section,
                           Val State,
                           Val Text,
                           Val TextColor = Undefined,
                           Val BgColor   = Undefined,
                           Val Size      = 9,
                           Val Bold      = False)
	
	SectionArea = Section.Area(State);
	
	If TextColor <> Undefined Then
		SectionArea.TextColor = TextColor;
	EndIf;
	
	If BgColor <> Undefined Then
		SectionArea.BgColor = BgColor;
	EndIf;
	
	SectionArea.Text      = Text;
	SectionArea.Font      = New Font(, Size, Bold, , , );
	SectionArea.HorizontalAlign = HorizontalAlign.Left;
	
	SectionArea.TopBorder    = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.BottomBorder = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.LeftBorder   = New Line(SpreadsheetDocumentCellLineType.None);
	SectionArea.RightBorder  = New Line(SpreadsheetDocumentCellLineType.None);
	
	Return ReportTS.Output(Section);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other internal procedures and functions.

// Restores an object serialized to XML.
// Parameters:
//   FileName - String - path to the file which stores serialized object presentation.
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
			Raise NStr("en = 'Object restoration error'");
		EndIf;
	Else
		XMLReader.Close();
		Raise NStr("en = 'Data reading error'");
	EndIf;
	
EndFunction

// FillingValue - array of strings.
// OutputType - string with the following values:
//              "m" - modify
//              "a" - add
//              "d" - delete
//              ""  - regular output
Function GenerateTSRowSector(Val FillingValue,Val OutputType = "")
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If    OutputType = ""  Then
		Template = CommonTemplate.GetArea("AttributeSourceValue");
	ElsIf OutputType = "M" Then
		Template = CommonTemplate.GetArea("AttributeChangedValue");
	ElsIf OutputType = "A" Then
		Template = CommonTemplate.GetArea("AddedAttribute");
	ElsIf OutputType = "D" Then
		Template = CommonTemplate.GetArea("DeletedAttribute");
	EndIf;
	
	For Each NextValue In FillingValue Do
		Template.Parameters.AttributeValue = NextValue;
		SpreadsheetDocument.Put(Template);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generates an empty sector for report output.
// Used if the row was not changed in any version.
//
Function GenerateEmptySector(Val RowCount, Val OutputType = "")
	
	FillingValue = New Array;
	
	For Index = 1 To RowCount Do
		FillingValue.Add(" ");
	EndDo;
	
	Return GenerateTSRowSector(FillingValue, OutputType);
	
EndFunction

// Subtracts DeductedTable items from MainTable items.
//
Function SubtractTable(Val MainTable,
                       Val DeductedTable,
                       Val MainTableComparisonColumn = "",
                       Val SubtractTableComparisonColumn = "")
	
	If Not ValueIsFilled(MainTableComparisonColumn) Then
		MainTableComparisonColumn = "Value";
	EndIf;
	
	If Not ValueIsFilled(SubtractTableComparisonColumn) Then
		SubtractTableComparisonColumn = "Value";
	EndIf;
	
	ResultTable = New ValueTable;
	ResultTable = MainTable.Copy();
	
	For Each Item In DeductedTable Do
		Value = Item[MainTableComparisonColumn];
		FoundRow = ResultTable.Find(Value, MainTableComparisonColumn);
		If FoundRow <> Undefined Then
			ResultTable.Delete(FoundRow);
		EndIf;
	EndDo;
	
	Return ResultTable;
	
EndFunction

// Creates a table based on InitializationTable.
// If InitializationTable is not specified, creates an empty table.
//
Function CreateComparisonChart(InitializationTable = Undefined,
                                ComparisonColumnName = "Value")
	
	Table = New ValueTable;
	Table.Columns.Add(ComparisonColumnName);
	
	If InitializationTable <> Undefined Then
		
		ArrayOfValues = InitializationTable.UnloadColumn(ComparisonColumnName);
		
		For Each Item In InitializationTable Do
			NewRow = Table.Add();
			NewRow.Set(0, Item[ComparisonColumnName]);
		EndDo;
		
	EndIf;
	
	Return Table;

EndFunction

&AtServer
Function SortAsc(Val Array)
	ValueList = New ValueList;
	ValueList.LoadValues(Array);
	ValueList.SortByValue(SortDirection.Asc);
	Return ValueList.UnloadValues();
EndFunction

&AtServer
Function LineIndex(TableRow)
	Return TableRow.Owner().IndexOf(TableRow);
EndFunction

&AtServer
Procedure AddRowNumbersToTabularSections(TabularSections)
	
	For Each Map In TabularSections Do
		Table = Map.Value;
		If Table.Columns.Find("LineNumber") <> Undefined Then
			Continue;
		EndIf;
		Table.Columns.Insert(0, "LineNumber",,NStr("en = 'Row #'"));
		For LineNumber = 1 To Table.Count() Do
			Table[LineNumber-1].LineNumber = LineNumber;
		EndDo;
	EndDo;
	
EndProcedure

// Table comparison algorithm

// Compares Table1 rows and Table2 rows based on their values. Also checks whether the column names match. 
// Returns map between Table1 rows and Table2 rows. Rows that cannot be mapped are not returned.
// The map is generated for "similar" rows, i.e. rows with at least one value match.
// When comparing row values, collection values are compared by reference (not by collection item).
//
// Parameters:
//   Table1, Table2 - ValueTable - tables to be compared.
//
// Internal parameters:
//   RequiredDifferenceCount - Number - minimum percentage of differences between rows.
//   MaximumDifferences      - Number - RequiredDifferenceCount increment limit during recursive calls.
//   Table1RowsAndTable2RowsMapping - Map - row map created earlier.
//
// Returns:
//   Map - row map where keys are Table1 rows, and values are Table2 rows.
//
// Use:
//    RowMapping = FindSimilarTabularRows (Table1, Table2);
//
// Comment:
//  Internal parameters are used during recursive calls. 
//  It is not recommended to use them during normal function calls.
//  To search for rows with exact percentage of differences, 
//  use identical values for RequiredDifferenceCount and MaximumDifferences parameters.
//  For example, to search for fully identical rows, use the following function call:
//
//    RowMapping = FindSimilarTabularRows (Table1, Table2, 0, 0);
//
&AtServer
Function FindSimilarTableRows(Table1, Table2, Val RequiredDifferenceCount = 0, Val MaximumDifferences = Undefined, Table1RowsAndTable2RowsMapping = Undefined)
	
	If Table1RowsAndTable2RowsMapping = Undefined Then
		Table1RowsAndTable2RowsMapping = New Map;
	EndIf;
	
	If MaximumDifferences = Undefined Then
		MaximumDifferences = MaximumTableRowDifferenceCount(Table1, Table2);
	EndIf;
	
	// Calculating the inverse map for quick search by value
	Table2RowsAndTable1RowsMapping = New Map; // keys are Table2 rows, values are Table1 rows
	For Each Item In Table1RowsAndTable2RowsMapping Do
		Table2RowsAndTable1RowsMapping.Insert(Item.Value, Item.Key);
	EndDo;
	
	// Comparing each row with each other row
	For Each TableRow1 In Table1 Do
		For Each TableRow2 In Table2 Do
			If Table1RowsAndTable2RowsMapping[TableRow1] = Undefined 
			   And Table2RowsAndTable1RowsMapping[TableRow2] = Undefined Then // skip rows found
			
				// Counting differences
				DifferenceCount = DifferenceCountInTableRows(TableRow1, TableRow2);
				
				// Analyzing the result of row comparison
				If DifferenceCount = RequiredDifferenceCount Then
					Table1RowsAndTable2RowsMapping.Insert(TableRow1, TableRow2);
					Table2RowsAndTable1RowsMapping.Insert(TableRow2, TableRow1);
					Break;
				EndIf;
				
			EndIf;
		EndDo;
	EndDo;
	
	If RequiredDifferenceCount < MaximumDifferences Then
		FindSimilarTableRows(Table1, Table2, RequiredDifferenceCount + 1, MaximumDifferences, Table1RowsAndTable2RowsMapping);
	EndIf;
	
	Return Table1RowsAndTable2RowsMapping;
	
EndFunction

&AtServer
Function MaximumTableRowDifferenceCount(Table1, Table2)
	
	TableColumnNameArray1 = GetColumnNames(Table1);
	TableColumnNameArray2 = GetColumnNames(Table2);
	BothTablesColumnNameArray = MergeSets(TableColumnNameArray1, TableColumnNameArray2);
	TotalColumns = BothTablesColumnNameArray.Count();
	
	Return ?(TotalColumns = 0, 0, TotalColumns - 1);

EndFunction

&AtServer
Function MergeSets(Set1, Set2)
	
	Result = New Array;
	
	For Each Item In Set1 Do
		Index = Result.Find(Item);
		If Index = Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	For Each Item In Set2 Do
		Index = Result.Find(Item);
		If Index = Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;	
	
	Return Result;
	
EndFunction

&AtServer
Function GetColumnNames(Table)
	
	Result = New Array;
	
	For Each Column In Table.Columns Do
		Result.Add(Column.Name);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function DifferenceCountInTableRows(TableRow1, TableRow2)
	
	Result = 0;
	
	Table1 = TableRow1.Owner();
	Table2 = TableRow2.Owner();
	
	CommonColumns = FindCommonColumns(Table1, Table2);
	OtherColumns = FindNonmatchingColumns(Table1, Table2);
	
	// Counting each non-common column as one case of difference
	Result = Result + OtherColumns.Count();
	
	// Counting differences by non-matching values
	For Each ColumnName In CommonColumns Do
		If TableRow1[ColumnName] <> TableRow2[ColumnName] Then
			Result = Result + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function FindCommonColumns(Table1, Table2)
	NameArray1 = GetColumnNames(Table1);
	NameArray2 = GetColumnNames(Table2);
	Return SetIntersection(NameArray1, NameArray2);
EndFunction

&AtServer
Function FindNonmatchingColumns(Table1, Table2)
	NameArray1 = GetColumnNames(Table1);
	NameArray2 = GetColumnNames(Table2);
	Return SetDifference(NameArray1, NameArray2, True);
EndFunction

&AtServer
Function SetDifference(Set1, Val Set2, SymmetricDifference = False)
	
	Result = New Array;
	Set2 = CopyArray(Set2);
	
	For Each Item In Set1 Do
		Index = Set2.Find(Item);
		If Index = Undefined Then
			Result.Add(Item);
		Else
			Set2.Delete(Index);
		EndIf;
	EndDo;
	
	If SymmetricDifference Then
		For Each Item In Set2 Do
			Result.Add(Item);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function SetIntersection(Set1, Set2)
	
	Result = New Array;
	
	For Each Item In Set1 Do
		Index = Set2.Find(Item);
		If Index <> Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function CopyArray(Array)
	
	Result = New Array;
	
	For Each Item In Array Do
		Result.Add(Item);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function RowsHaveDifferences(String1, String2, ColumnsToCheck)
	For Each Column In ColumnsToCheck Do
		If TypeOf(String1[Column]) = Type("ValueStorage") Then
			Continue; // Attributes with the ValueStorage type are not compared
		EndIf;
		If String1[Column] <> String2[Column] Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

#EndRegion