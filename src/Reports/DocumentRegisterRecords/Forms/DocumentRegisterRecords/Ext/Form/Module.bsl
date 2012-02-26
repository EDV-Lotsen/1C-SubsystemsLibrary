

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Function returns not empty document register records.
//
Function DefineIfThereAreRegisterRecordsByRegistrator() 
	
	QueryText = "";	
	DocumentRegisterRecords = Report.Document.Metadata().RegisterRecords;
	
	If DocumentRegisterRecords.Count() = 0 Then
		Return New ValueTable;
	EndIf;
	
	For Each Record IN DocumentRegisterRecords Do
		
		QueryText = QueryText + "
		|" + ?(QueryText = "", "", "UNION ALL ") + "
		|SELECT TOP 1 CAST(""" + Record.FullName() 
		+  """ AS String(200)) AS Name FROM " + Record.FullName() 
		+ " WHERE Recorder = &Recorder";
		
	EndDo;
	
	Query = New Query(QueryText);
	Query.SetParameter("Recorder", Report.Document);
	
	QueryTable = Query.Execute().Unload();
	QueryTable.Indexes.Add("Name");
	
	For Each RecordsTableRow In QueryTable Do		
		RecordsTableRow.Name = Upper(TrimAll(RecordsTableRow.Name));
	EndDo;
	
	Return QueryTable;			
		
EndFunction

&AtServer
// Function returns register type.
//
Function DefineRegisterKind(RegisterMetadata)
	
	If Metadata.AccumulationRegisters.IndexOf(RegisterMetadata) >= 0 Then
		Return "Accumulation";
		
	ElsIf Metadata.InformationRegisters.IndexOf(RegisterMetadata) >= 0 Then
		Return "Information";	
		
	ElsIf Metadata.AccountingRegisters.IndexOf(RegisterMetadata) >= 0 Then
		Return "Accounting";
		
	Else
		Return "";
			
	EndIf;
    	
EndFunction

&AtServer
// Procedure generates list of the fields for the query.
//
Procedure GenerateFieldList(ResourceMetadata, FieldsTable, FieldList)
	
	For Each Resource In ResourceMetadata Do
		                           
		FieldList = FieldList + ", "+ Resource.Name;
		FieldsTable.Columns.Add(Resource.Name, , Resource.Synonym);
		
	EndDo;
			 
			 
EndProcedure

&AtServer
// Procedure adds period to list of the fields for the query.
//
Procedure AddPeriodToFieldList(FieldsTable, FieldList)
	
	FieldList = FieldList + ", Period";
	FieldsTable.Columns.Add("Period", , "Period");
	
EndProcedure

&AtServer
// Procedure outputs records of the information and accumulation registers.
//
Procedure ProcessDataOutputByArray(FieldList, ResourcesTable, DimensionTable, AttributeTable, TableRecordsKind = Undefined, Val RegisterName, RegisterSynonym)
	
	If NOT ValueIsFilled(FieldList) Then
		Return;
	EndIf;
	
	Query = New Query;
    Query.Text = "SELECT " + FieldList +"
		|{SELECT " + FieldList +"}
		|FROM " + RegisterName + " AS Reg
		|WHERE Reg.Recorder = &ReportDocument
		|	 And Reg.Active";
		
	Query.SetParameter("ReportDocument", Report.Document);	
        	
    TableQueryResult = Query.Execute().Unload();
	
	For each ResultString In TableQueryResult Do
		If TableRecordsKind <> Undefined Then
			NewRow = TableRecordsKind.Add();
			FillPropertyValues(NewRow, ResultString);
		EndIf;
		NewRow = ResourcesTable.Add();
		FillPropertyValues(NewRow, ResultString);
		NewRow = DimensionTable.Add();
		FillPropertyValues(NewRow, ResultString);
		NewRow = AttributeTable.Add();
		FillPropertyValues(NewRow, ResultString);
	EndDo; 
	
	Template = Reports.DocumentRegisterRecords.GetTemplate("Template");
	AreaTitle = Template.GetArea("ReportTitle");
		
	AreaTitle.Parameters.RegisterSynonym = String(RegisterSynonym);
	SpreadsheetDocument.Put(AreaTitle);
	SpreadsheetDocument.StartRowGroup();
	 
	ResultRowsNumber = TableQueryResult.Count();	
		
	If Report.ReportOutputMethods = Enums.ReportOutputMethods.Horizontal Then
	
		// Output into string
		
		HeaderAreaCells	 	= Template.GetArea("CellTitle");
		AreaCell			= Template.GetArea("Cell");
		AreaIndent 			= Template.GetArea("Indent1");
		
		SpreadsheetDocument.Put(AreaIndent);
		If TableRecordsKind <> Undefined Then
			HeaderAreaCells.Parameters.ColumnTitle = "Register record type";
	        SpreadsheetDocument.Join(HeaderAreaCells);
		EndIf;
		For each Column In DimensionTable.Columns Do
			HeaderAreaCells.Parameters.ColumnTitle = Column.Title;
	        SpreadsheetDocument.Join(HeaderAreaCells);
		EndDo; 
		For each Column In ResourcesTable.Columns Do
			HeaderAreaCells.Parameters.ColumnTitle = Column.Title;
	        SpreadsheetDocument.Join(HeaderAreaCells);
		EndDo;
	    For each Column In AttributeTable.Columns Do
			HeaderAreaCells.Parameters.ColumnTitle = Column.Title;
	        SpreadsheetDocument.Join(HeaderAreaCells);
		EndDo;
		
		For LineNumber = 1 To ResultRowsNumber Do
			
			SpreadsheetDocument.Put(AreaIndent);
			If TableRecordsKind <> Undefined Then
				AreaCell.Parameters.Value = TableRecordsKind[LineNumber-1].RecordType;
				SpreadsheetDocument.Join(AreaCell);
				If TableRecordsKind[LineNumber-1].RecordType = AccumulationRecordType.Expense Then
					Area = SpreadsheetDocument.Area("Cell");
					Area.TextColor = New Color(255, 0, 0);
				Else
				    Area = SpreadsheetDocument.Area("Cell");
					Area.TextColor = New Color(0, 0, 255);
				EndIf;
			EndIf;
			For each Column In DimensionTable.Columns Do
				Value = DimensionTable[LineNumber-1][Column.Name]; 
				AreaCell.Parameters.Value = Value;
		        If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
					And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
					AreaCell.Parameters.ValueOfDetails = Value;
				Else
					AreaCell.Parameters.ValueOfDetails = Undefined;				
				EndIf; 
		        SpreadsheetDocument.Join(AreaCell);
			EndDo; 
			For each Column In ResourcesTable.Columns Do
				Value = ResourcesTable[LineNumber-1][Column.Name]; 
				AreaCell.Parameters.Value = Value;
				If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
					And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
					AreaCell.Parameters.ValueOfDetails = Value;
				Else
					AreaCell.Parameters.ValueOfDetails = Undefined;
				EndIf; 
		        SpreadsheetDocument.Join(AreaCell);
			EndDo; 
			For each Column In AttributeTable.Columns Do
				Value = AttributeTable[LineNumber-1][Column.Name]; 
				AreaCell.Parameters.Value = Value;
		        If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
					And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
					AreaCell.Parameters.ValueOfDetails = Value;
				Else
					AreaCell.Parameters.ValueOfDetails = Undefined;				
				EndIf; 
		        SpreadsheetDocument.Join(AreaCell);
			EndDo; 
			
		EndDo; 
		
	Else
	
		// Table output
		
		If TableRecordsKind <> Undefined Then
			HeaderArea 					= Template.GetArea("TableHeader");
			AreaDetailsHeader 			= Template.GetArea("HeaderDetails");
			AreaDetails 				= Template.GetArea("Details");
			HeaderAreaRecordKind 		= Template.GetArea("TableHeaderRecordKind");
			AreaDetailsHeaderRecordKind = Template.GetArea("HeaderDetailsRecordKind");
			AreaDetailsRecordKind 		= Template.GetArea("DetailsRecordKind");
			AreaIndent 					= Template.GetArea("Indent");
		Else	
		    HeaderArea 					= Template.GetArea("TableHeader_1");
			AreaDetailsHeader 			= Template.GetArea("HeaderDetails1");
			AreaDetails 				= Template.GetArea("Details1");
			AreaIndent 					= Template.GetArea("Indent2");
		EndIf;
		
			
		
		SpreadsheetDocument.Put(AreaIndent);
		
		If TableRecordsKind <> Undefined Then
			SpreadsheetDocument.Join(HeaderAreaRecordKind);
		EndIf;
		SpreadsheetDocument.Join(HeaderArea);
	 	
		HeaderRowsNumber = Max(ResourcesTable.Columns.Count(), DimensionTable.Columns.Count(), AttributeTable.Columns.Count());
		ThickLine = New Line(SpreadsheetDocumentCellLineType.Solid,2);
		ThinLine = New Line(SpreadsheetDocumentCellLineType.Solid,1);
		
		For LineNumber = 1 To HeaderRowsNumber Do
			
			AreaDetailsHeader.Parameters.Resources = "";
			AreaDetailsHeader.Parameters.Dimensions = "";
			AreaDetailsHeader.Parameters.Attributes = "";
			
			If ResourcesTable.Columns.Count() >= LineNumber Then
				AreaDetailsHeader.Parameters.Resources = ResourcesTable.Columns[LineNumber-1].Title;
			EndIf; 	
			If DimensionTable.Columns.Count() >= LineNumber Then
				AreaDetailsHeader.Parameters.Dimensions = DimensionTable.Columns[LineNumber-1].Title;
			EndIf; 	
			If AttributeTable.Columns.Count() >= LineNumber Then
				AreaDetailsHeader.Parameters.Attributes = AttributeTable.Columns[LineNumber-1].Title;
			EndIf;
						
			SpreadsheetDocument.Put(AreaIndent);
			If TableRecordsKind <> Undefined Then
				SpreadsheetDocument.Join(AreaDetailsHeaderRecordKind);	
			EndIf;
			SpreadsheetDocument.Join(AreaDetailsHeader);	
						
			If LineNumber = HeaderRowsNumber Then
			    If TableRecordsKind <> Undefined Then
					Area = SpreadsheetDocument.Area("HeaderDetailsRecordKind");
					Area.Outline(ThickLine, , ThickLine, ThickLine);
					Area = SpreadsheetDocument.Area("HeaderDetails");
					Area.Outline(ThickLine, , ThickLine, ThickLine);
				Else	
					Area = SpreadsheetDocument.Area("HeaderDetails1");
					Area.Outline(ThickLine, , ThickLine, ThickLine);
				EndIf;
				
			EndIf; 
			
		EndDo; 
		
		For LineNumber = 1 To ResultRowsNumber Do
			
			FlagRecordKindOutput = False;
			
			For ColumnNumber = 1 To HeaderRowsNumber Do
			
				AreaDetails.Parameters.Resources = "";
				AreaDetails.Parameters.Dimensions = "";
				AreaDetails.Parameters.Attributes = "";
				
				If ResourcesTable.Columns.Count() >= ColumnNumber Then
					ColumnName = ResourcesTable.Columns[ColumnNumber-1].Name;
					Value = ResourcesTable[LineNumber-1][ColumnName]; 
					AreaDetails.Parameters.Resources = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaDetails.Parameters.ResourcesDetails = Value;
					Else
						AreaDetails.Parameters.ResourcesDetails = Undefined;
					EndIf;
				EndIf; 	
				If DimensionTable.Columns.Count() >= ColumnNumber Then
					ColumnName = DimensionTable.Columns[ColumnNumber-1].Name;
					Value = DimensionTable[LineNumber-1][ColumnName]; 
					AreaDetails.Parameters.Dimensions = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaDetails.Parameters.DimensionsDetails = Value;
					Else
						AreaDetails.Parameters.DimensionsDetails = Undefined;
					EndIf;
				EndIf; 	
				If AttributeTable.Columns.Count() >= ColumnNumber Then
					ColumnName = AttributeTable.Columns[ColumnNumber-1].Name;
					Value = AttributeTable[LineNumber-1][ColumnName]; 
					AreaDetails.Parameters.Attributes = Value;
					If ValueIsFilled(Value) And TypeOf(Value) <> Type("Date") And TypeOf(Value) <> Type("Number")
						And TypeOf(Value) <> Type("Boolean") And TypeOf(Value) <> Type("String") Then
						AreaDetails.Parameters.AttributesDetails = Value;
					Else
						AreaDetails.Parameters.AttributesDetails = Undefined;
					EndIf;
				EndIf;
				
				SpreadsheetDocument.Put(AreaIndent);
				
				If TableRecordsKind <> Undefined Then

					If FlagRecordKindOutput Then
						ValueOfParameter = "";
					Else
						ValueOfParameter = TableRecordsKind[LineNumber-1]["RecordType"];
						FlagRecordKindOutput = True;
					EndIf;

					AreaDetailsRecordKind.Parameters.RecordType = ValueOfParameter;
					SpreadsheetDocument.Join(AreaDetailsRecordKind);

                    If ValueOfParameter = AccumulationRecordType.Expense Then
						Area = SpreadsheetDocument.Area("DetailsRecordKind");
						Area.TextColor = New Color(255, 0, 0);
					ElsIf ValueOfParameter = AccumulationRecordType.Receipt Then
					    Area = SpreadsheetDocument.Area("DetailsRecordKind");
						Area.TextColor = New Color(0, 0, 255);
					EndIf;
				EndIf;
				
				SpreadsheetDocument.Join(AreaDetails);
				
                If ColumnNumber = HeaderRowsNumber Then
				    If TableRecordsKind <> Undefined Then
						Area = SpreadsheetDocument.Area("DetailsRecordKind");
						Area.Outline(ThinLine, , ThinLine, ThinLine);
                        Area = SpreadsheetDocument.Area("Details");
						Area.Outline(ThinLine, , ThinLine, ThinLine);
                    Else
                        Area = SpreadsheetDocument.Area("Details1");
						Area.Outline(ThinLine, , ThinLine, ThinLine);
					EndIf;
					
				EndIf;

			EndDo;
			
		EndDo; 
		
	EndIf;	
		
	SpreadsheetDocument.EndRowGroup();
			    	
EndProcedure

&AtServer
// Procedure outputs records of the accounting register.
//
Procedure DoOutputPostingJournal()
		
	Template 					= Reports.DocumentRegisterRecords.GetTemplate("Template");
	TemplateAccountingRegister 	= Reports.DocumentRegisterRecords.GetTemplate("TemplateAccountingRegister");
	AreaTitle 					= Template.GetArea("ReportTitle");
	AreaHeader 					= TemplateAccountingRegister.GetArea("Header");
	AreaDetails 				= TemplateAccountingRegister.GetArea("Details");
		
	AreaTitle.Parameters.RegisterSynonym = "Accounting register ""Managerial""";
	SpreadsheetDocument.Put(AreaTitle);
	SpreadsheetDocument.StartRowGroup();
	
    SpreadsheetDocument.Put(AreaHeader);	
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Managerial.Period AS Period,
	|	Managerial.Recorder AS Recorder,
	|	Managerial.LineNumber AS LineNumber,
	|	Managerial.Active AS Active,
	|	Managerial.AccountDr AS AccountDr,
	|	Managerial.AccountCr AS AccountCr,
	|	Managerial.Company AS Company,
	|	Managerial.CurrencyDr AS CurrencyDr,
	|	Managerial.CurrencyCr AS CurrencyCr,
	|	Managerial.Amount AS Amount,
	|	Managerial.AmountCurDr AS AmountCurrencyDr,
	|	Managerial.AmountCurCr AS AmountCurrencyCr,
	|	Managerial.Content AS Content
	|FROM
	|	AccountingRegister.Managerial AS Managerial
	|WHERE
	|	Managerial.Recorder = &ReportDocument
	|
	|ORDER BY
	|	LineNumber";
    
	Query.SetParameter("ReportDocument", 	Report.Document);	
			
	TableQueryResult = Query.Execute().Unload();
	For each ResultString In TableQueryResult Do
			
        FillPropertyValues(AreaDetails.Parameters, ResultString);
        SpreadsheetDocument.Put(AreaDetails);

	EndDo; 
	
	SpreadsheetDocument.EndRowGroup();
			    	
EndProcedure

&AtServer                                              
// Procedure generates report at server.
//
Procedure GenerateReport()
	
    If NOT ValueIsFilled(Report.Document) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Document not selected!'");
		Message.Message();
		Return;
	EndIf;

	SetPrivilegedMode(True);
	
	SpreadsheetDocument.Clear();
	Template = Reports.DocumentRegisterRecords.GetTemplate("Template");
	DocumentRegisterRecords = Report.Document.Metadata().RegisterRecords;
		
	// Output header
	AreaTitle = Template.GetArea("MainTitle");
	AreaTitle.Parameters.Document = String(Report.Document);
	SpreadsheetDocument.Put(AreaTitle);

	// Search registers, having any records
	RecordsTable1 = DefineIfThereAreRegisterRecordsByRegistrator();
	
    OutputPostingJournal = False;
			
	// Go over the records
	For Each PropertiesOfObject In DocumentRegisterRecords Do
		
		// Check, if there are any register records
		RowInRegisterTable = RecordsTable1.Find(Upper(PropertiesOfObject.FullName()), "Name");
		
		If RowInRegisterTable = Undefined Then
			Continue;
		EndIf;
		
		RegisterType = DefineRegisterKind(PropertiesOfObject);
 		RegisterName = RegisterType + "Register" + "." + PropertiesOfObject.Name;
		RegisterSynonym = RegisterType + " register """ + PropertiesOfObject.Synonym + """";
		
		If RegisterType = "Information" OR RegisterType = "Accumulation" Then
			
			FieldList = "";
			ResourcesTable = New ValueTable;                                            
			DimensionTable = New ValueTable;
			AttributeTable = New ValueTable;
			
			If RegisterType = "Information" And PropertiesOfObject.InformationRegisterPeriodicity = Metadata.ObjectProperties.InformationRegisterPeriodicity.Nonperiodical Then
			Else
				AddPeriodToFieldList(DimensionTable, FieldList);
			EndIf;
			GenerateFieldList(PropertiesOfObject.Resources, ResourcesTable, FieldList);
            GenerateFieldList(PropertiesOfObject.Dimensions, DimensionTable, FieldList);
			GenerateFieldList(PropertiesOfObject.Attributes, AttributeTable, FieldList);
            FieldList = Right(FieldList, StrLen(FieldList)-2);
			
			If (RegisterType = "Accumulation") And (PropertiesOfObject.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Balance) Then
				FieldList = FieldList + ", RecordType";
				TableRecordsKind = New ValueTable;
			    TableRecordsKind.Columns.Add("RecordType", , "Register record type");
            	ProcessDataOutputByArray(FieldList, ResourcesTable, DimensionTable, AttributeTable, TableRecordsKind, RegisterName, RegisterSynonym);
			Else
                ProcessDataOutputByArray(FieldList, ResourcesTable, DimensionTable, AttributeTable, , RegisterName, RegisterSynonym);
			EndIf; 
            
		ElsIf RegisterType = "Accounting" Then
         	
            OutputPostingJournal = True;

		EndIf;

	EndDo;	
	
	If OutputPostingJournal Then
		 DoOutputPostingJournal();
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
// Procedure - handler of event OnCreateAtServer of form.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)

	If Parameters.Property("Document") Then
		Report.Document = Parameters.Document;
	EndIf; 
	
	Report.ReportOutputMethods = Enums.ReportOutputMethods.Horizontal;
	GenerateReport();
	
EndProcedure

&AtClient
// Procedure - handler of click on button "Make".
//
Procedure MakeExecute()
	
	GenerateReport();
	
EndProcedure

