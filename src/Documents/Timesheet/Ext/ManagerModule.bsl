
// Generates a value tables that contains document tabular section data.
// Value tables are saved in the AdditionalProperties structure properties.
//
Procedure DataInitializationDocument(DocumentTimesheet, StructureAdditionalProperties) Export

	If DocumentTimesheet.DataInputMethod = Enums.TimeDataInputMethods.TotalForPeriod Then
	
		QueryText = "";
		For Counter = 1 To 6 Do
		
			QueryText = 	QueryText + ?(Counter > 1, "	
			|UNION ALL
			| 
			|", "") + 
			"SELECT
			|	&Company AS Company,
			|	TimesheetTimeWorkedPerPeriod.Ref.AccountingPeriod 	AS Period,
			|	TimesheetTimeWorkedPerPeriod.Employee 					AS Employee,
			|	TRUE													AS TotalForPeriod,
			|	TimesheetTimeWorkedPerPeriod.Position 					AS Position,
			|	TimesheetTimeWorkedPerPeriod.TimeKind" 	+ Counter + " 	AS TimeKind,
			|	TimesheetTimeWorkedPerPeriod.Days" 		+ Counter + " 	AS Days,
			|	TimesheetTimeWorkedPerPeriod.Hours" 	+ Counter + " 	AS Hours
			|FROM
			|	Document.Timesheet.TimeWorkedPerPeriod AS TimesheetTimeWorkedPerPeriod
			|WHERE
			|	TimesheetTimeWorkedPerPeriod.TimeKind" + Counter + " <> VALUE(Catalog.WorkTimeTypes.EmptyRef)
			|	And TimesheetTimeWorkedPerPeriod.Ref = &Ref
			|";
		
		EndDo; 
		
	Else        
		
		QueryText = "";
		For Counter = 1 To 31 Do
		
			QueryText = QueryText + ?(Counter > 1, "	
			|UNION ALL
			| 
			|", "") + 
			"SELECT
			|	&Company 													AS Company,
			|	TimesheetTimeWorkedByDays.Employee 								AS Employee,
			|	FALSE									 						AS TotalForPeriod,
			|	TimesheetTimeWorkedByDays.Position 								AS Position,
			|	DATEADD(TimesheetTimeWorkedByDays.Ref.AccountingPeriod, DAY, " + (Counter - 1) + ") AS Period,
			|	1 																AS Days,
			|	TimesheetTimeWorkedByDays.FirstTimeKind" 	+ Counter + " 		AS TimeKind,
			|	TimesheetTimeWorkedByDays.FirstHours" 		+ Counter + " 		AS Hours
			|FROM
			|	Document.Timesheet.TimeWorkedByDays AS TimesheetTimeWorkedByDays
			|WHERE
			|	TimesheetTimeWorkedByDays.Ref = &Ref
			|	And TimesheetTimeWorkedByDays.FirstTimeKind" + Counter + " <> VALUE(Catalog.WorkTimeTypes.EmptyRef)
			|		
			|UNION ALL
			|
			|SELECT
			|	&Company,
			|	TimesheetTimeWorkedByDays.Employee,
			|	FALSE,
			|	TimesheetTimeWorkedByDays.Position,
			|	DATEADD(TimesheetTimeWorkedByDays.Ref.AccountingPeriod, DAY, " + (Counter - 1) + "),
			|	1,
			|	TimesheetTimeWorkedByDays.SecondTimeKind" + Counter + ",
			|	TimesheetTimeWorkedByDays.SecondHours" + Counter + "
			|FROM
			|	Document.Timesheet.TimeWorkedByDays AS TimesheetTimeWorkedByDays
			|WHERE
			|	TimesheetTimeWorkedByDays.Ref = &Ref
			|	And TimesheetTimeWorkedByDays.SecondTimeKind" + Counter + " <> VALUE(Catalog.WorkTimeTypes.EmptyRef)
			|		
			|UNION ALL
			|
			|SELECT
			|	&Company,
			|	TimesheetTimeWorkedByDays.Employee,
			|	FALSE,
			|	TimesheetTimeWorkedByDays.Position,
			|	DATEADD(TimesheetTimeWorkedByDays.Ref.AccountingPeriod, DAY, " + (Counter - 1) + "),
			|	1,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind" + Counter + ",
			|	TimesheetTimeWorkedByDays.ThirdHours" + Counter + "
			|FROM
			|	Document.Timesheet.TimeWorkedByDays AS TimesheetTimeWorkedByDays
			|WHERE
			|	TimesheetTimeWorkedByDays.Ref = &Ref
			|	And TimesheetTimeWorkedByDays.ThirdTimeKind" + Counter + " <> VALUE(Catalog.WorkTimeTypes.EmptyRef)
			|";	
		
		EndDo;
		
	EndIf; 
		
	Query = New Query(QueryText);
	
	Query.SetParameter("Ref", DocumentTimesheet);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTimesheet", Query.Execute().Unload());
	
EndProcedure

// Checks whether the data must be added to worked time.
//
Function AddToWorkedTime(TimeKind)
	
	If TimeKind = Catalogs.WorkTimeTypes.Holidays
		OR TimeKind = Catalogs.WorkTimeTypes.Overtime
		OR TimeKind = Catalogs.WorkTimeTypes.Work Then
	
		Return True;	
	Else	
		Return False;	
	EndIf; 
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR PRINTING THE FORM

Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Timesheet";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		LineNumberBegin = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		Query.Text = 
		"SELECT
		|	Timesheet.Date AS DocumentDate,
		|	Timesheet.AccountingPeriod AS AccountingPeriod,
		|	Timesheet.Number,
		|	Timesheet.Company.Description AS CompanyPrintedName,
		|	Timesheet.Company,
		|	Timesheet.DataInputMethod
		|FROM
		|	Document.Timesheet AS Timesheet
		|WHERE
		|	Timesheet.Ref = &CurrentDocument";
		
		Header = Query.Execute().Choose();
		Header.Next();
		
		If Header.DataInputMethod = Enums.TimeDataInputMethods.Daily Then
			SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_Timesheet_Template";		
			Template = _DemoPrintManagement.GetTemplate("Document.Timesheet.PF_MXL_Template");
		Else
			SpreadsheetDocument.PrintParametersKey = "PRINT_PARAMETERS_Timesheet_TemplateConsolidated";		
			Template = _DemoPrintManagement.GetTemplate("Document.Timesheet.PF_MXL_SummaryTemplate");
		EndIf;
		
		AreaDocumentHeader  = Template.GetArea("DocumentHeader");
		AreaHeader          = Template.GetArea("Header");
		AreaDetails         = Template.GetArea("Details");
		FooterArea          = Template.GetArea("Footer");
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNo = _DemoPayrollAndHRServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNo = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		AreaDocumentHeader.Parameters.CompanyName 	    = Header.CompanyPrintedName;
		AreaDocumentHeader.Parameters.DocumentNo 		= DocumentNo;
		AreaDocumentHeader.Parameters.FillingDate 		= Header.DocumentDate;
		AreaDocumentHeader.Parameters.DateBeg 			= Header.AccountingPeriod;
		AreaDocumentHeader.Parameters.DateEnd 			= EndOfMonth(Header.AccountingPeriod);
				
		SpreadsheetDocument.Put(AreaDocumentHeader);
		SpreadsheetDocument.Put(AreaHeader);
		                                             
		Query = New Query;
		Query.SetParameter("Ref",   				CurrentDocument);
		Query.SetParameter("AccountingPeriod",    Header.AccountingPeriod);
		
		If Header.DataInputMethod = Enums.TimeDataInputMethods.Daily Then
				
			Query.Text =
			"SELECT
			|	TimesheetTimeWorkedByDays.Employee.Description As Surname,
			|	TimesheetTimeWorkedByDays.Employee,
			|	TimesheetTimeWorkedByDays.Position,
			|	TimesheetTimeWorkedByDays.FirstTimeKind1,
			|	TimesheetTimeWorkedByDays.FirstTimeKind2,
			|	TimesheetTimeWorkedByDays.FirstTimeKind3,
			|	TimesheetTimeWorkedByDays.FirstTimeKind4,
			|	TimesheetTimeWorkedByDays.FirstTimeKind5,
			|	TimesheetTimeWorkedByDays.FirstTimeKind6,
			|	TimesheetTimeWorkedByDays.FirstTimeKind7,
			|	TimesheetTimeWorkedByDays.FirstTimeKind8,
			|	TimesheetTimeWorkedByDays.FirstTimeKind9,
			|	TimesheetTimeWorkedByDays.FirstTimeKind10,
			|	TimesheetTimeWorkedByDays.FirstTimeKind11,
			|	TimesheetTimeWorkedByDays.FirstTimeKind12,
			|	TimesheetTimeWorkedByDays.FirstTimeKind13,
			|	TimesheetTimeWorkedByDays.FirstTimeKind14,
			|	TimesheetTimeWorkedByDays.FirstTimeKind15,
			|	TimesheetTimeWorkedByDays.FirstTimeKind16,
			|	TimesheetTimeWorkedByDays.FirstTimeKind17,
			|	TimesheetTimeWorkedByDays.FirstTimeKind18,
			|	TimesheetTimeWorkedByDays.FirstTimeKind19,
			|	TimesheetTimeWorkedByDays.FirstTimeKind20,
			|	TimesheetTimeWorkedByDays.FirstTimeKind21,
			|	TimesheetTimeWorkedByDays.FirstTimeKind22,
			|	TimesheetTimeWorkedByDays.FirstTimeKind23,
			|	TimesheetTimeWorkedByDays.FirstTimeKind24,
			|	TimesheetTimeWorkedByDays.FirstTimeKind25,
			|	TimesheetTimeWorkedByDays.FirstTimeKind26,
			|	TimesheetTimeWorkedByDays.FirstTimeKind27,
			|	TimesheetTimeWorkedByDays.FirstTimeKind28,
			|	TimesheetTimeWorkedByDays.FirstTimeKind29,
			|	TimesheetTimeWorkedByDays.FirstTimeKind30,
			|	TimesheetTimeWorkedByDays.FirstTimeKind31,
			|	TimesheetTimeWorkedByDays.SecondTimeKind1,
			|	TimesheetTimeWorkedByDays.SecondTimeKind2,
			|	TimesheetTimeWorkedByDays.SecondTimeKind3,
			|	TimesheetTimeWorkedByDays.SecondTimeKind4,
			|	TimesheetTimeWorkedByDays.SecondTimeKind5,
			|	TimesheetTimeWorkedByDays.SecondTimeKind6,
			|	TimesheetTimeWorkedByDays.SecondTimeKind7,
			|	TimesheetTimeWorkedByDays.SecondTimeKind8,
			|	TimesheetTimeWorkedByDays.SecondTimeKind9,
			|	TimesheetTimeWorkedByDays.SecondTimeKind10,
			|	TimesheetTimeWorkedByDays.SecondTimeKind11,
			|	TimesheetTimeWorkedByDays.SecondTimeKind12,
			|	TimesheetTimeWorkedByDays.SecondTimeKind13,
			|	TimesheetTimeWorkedByDays.SecondTimeKind14,
			|	TimesheetTimeWorkedByDays.SecondTimeKind15,
			|	TimesheetTimeWorkedByDays.SecondTimeKind16,
			|	TimesheetTimeWorkedByDays.SecondTimeKind17,
			|	TimesheetTimeWorkedByDays.SecondTimeKind18,
			|	TimesheetTimeWorkedByDays.SecondTimeKind19,
			|	TimesheetTimeWorkedByDays.SecondTimeKind20,
			|	TimesheetTimeWorkedByDays.SecondTimeKind21,
			|	TimesheetTimeWorkedByDays.SecondTimeKind22,
			|	TimesheetTimeWorkedByDays.SecondTimeKind23,
			|	TimesheetTimeWorkedByDays.SecondTimeKind24,
			|	TimesheetTimeWorkedByDays.SecondTimeKind25,
			|	TimesheetTimeWorkedByDays.SecondTimeKind26,
			|	TimesheetTimeWorkedByDays.SecondTimeKind27,
			|	TimesheetTimeWorkedByDays.SecondTimeKind28,
			|	TimesheetTimeWorkedByDays.SecondTimeKind29,
			|	TimesheetTimeWorkedByDays.SecondTimeKind30,
			|	TimesheetTimeWorkedByDays.SecondTimeKind31,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind1,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind2,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind3,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind4,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind5,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind6,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind7,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind8,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind9,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind10,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind11,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind12,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind13,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind14,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind15,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind16,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind17,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind18,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind19,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind20,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind21,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind22,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind23,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind24,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind25,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind26,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind27,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind28,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind29,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind30,
			|	TimesheetTimeWorkedByDays.ThirdTimeKind31,
			|	TimesheetTimeWorkedByDays.FirstHours1,
			|	TimesheetTimeWorkedByDays.FirstHours2,
			|	TimesheetTimeWorkedByDays.FirstHours3,
			|	TimesheetTimeWorkedByDays.FirstHours4,
			|	TimesheetTimeWorkedByDays.FirstHours5,
			|	TimesheetTimeWorkedByDays.FirstHours6,
			|	TimesheetTimeWorkedByDays.FirstHours7,
			|	TimesheetTimeWorkedByDays.FirstHours8,
			|	TimesheetTimeWorkedByDays.FirstHours9,
			|	TimesheetTimeWorkedByDays.FirstHours10,
			|	TimesheetTimeWorkedByDays.FirstHours11,
			|	TimesheetTimeWorkedByDays.FirstHours12,
			|	TimesheetTimeWorkedByDays.FirstHours13,
			|	TimesheetTimeWorkedByDays.FirstHours14,
			|	TimesheetTimeWorkedByDays.FirstHours15,
			|	TimesheetTimeWorkedByDays.FirstHours16,
			|	TimesheetTimeWorkedByDays.FirstHours17,
			|	TimesheetTimeWorkedByDays.FirstHours18,
			|	TimesheetTimeWorkedByDays.FirstHours19,
			|	TimesheetTimeWorkedByDays.FirstHours20,
			|	TimesheetTimeWorkedByDays.FirstHours21,
			|	TimesheetTimeWorkedByDays.FirstHours22,
			|	TimesheetTimeWorkedByDays.FirstHours23,
			|	TimesheetTimeWorkedByDays.FirstHours24,
			|	TimesheetTimeWorkedByDays.FirstHours25,
			|	TimesheetTimeWorkedByDays.FirstHours26,
			|	TimesheetTimeWorkedByDays.FirstHours27,
			|	TimesheetTimeWorkedByDays.FirstHours28,
			|	TimesheetTimeWorkedByDays.FirstHours29,
			|	TimesheetTimeWorkedByDays.FirstHours30,
			|	TimesheetTimeWorkedByDays.FirstHours31,
			|	TimesheetTimeWorkedByDays.SecondHours1,
			|	TimesheetTimeWorkedByDays.SecondHours2,
			|	TimesheetTimeWorkedByDays.SecondHours3,
			|	TimesheetTimeWorkedByDays.SecondHours4,
			|	TimesheetTimeWorkedByDays.SecondHours5,
			|	TimesheetTimeWorkedByDays.SecondHours6,
			|	TimesheetTimeWorkedByDays.SecondHours7,
			|	TimesheetTimeWorkedByDays.SecondHours8,
			|	TimesheetTimeWorkedByDays.SecondHours9,
			|	TimesheetTimeWorkedByDays.SecondHours10,
			|	TimesheetTimeWorkedByDays.SecondHours11,
			|	TimesheetTimeWorkedByDays.SecondHours12,
			|	TimesheetTimeWorkedByDays.SecondHours13,
			|	TimesheetTimeWorkedByDays.SecondHours14,
			|	TimesheetTimeWorkedByDays.SecondHours15,
			|	TimesheetTimeWorkedByDays.SecondHours16,
			|	TimesheetTimeWorkedByDays.SecondHours17,
			|	TimesheetTimeWorkedByDays.SecondHours18,
			|	TimesheetTimeWorkedByDays.SecondHours19,
			|	TimesheetTimeWorkedByDays.SecondHours20,
			|	TimesheetTimeWorkedByDays.SecondHours21,
			|	TimesheetTimeWorkedByDays.SecondHours22,
			|	TimesheetTimeWorkedByDays.SecondHours23,
			|	TimesheetTimeWorkedByDays.SecondHours24,
			|	TimesheetTimeWorkedByDays.SecondHours25,
			|	TimesheetTimeWorkedByDays.SecondHours26,
			|	TimesheetTimeWorkedByDays.SecondHours27,
			|	TimesheetTimeWorkedByDays.SecondHours28,
			|	TimesheetTimeWorkedByDays.SecondHours29,
			|	TimesheetTimeWorkedByDays.SecondHours30,
			|	TimesheetTimeWorkedByDays.SecondHours31,
			|	TimesheetTimeWorkedByDays.ThirdHours1,
			|	TimesheetTimeWorkedByDays.ThirdHours2,
			|	TimesheetTimeWorkedByDays.ThirdHours3,
			|	TimesheetTimeWorkedByDays.ThirdHours4,
			|	TimesheetTimeWorkedByDays.ThirdHours5,
			|	TimesheetTimeWorkedByDays.ThirdHours6,
			|	TimesheetTimeWorkedByDays.ThirdHours7,
			|	TimesheetTimeWorkedByDays.ThirdHours8,
			|	TimesheetTimeWorkedByDays.ThirdHours9,
			|	TimesheetTimeWorkedByDays.ThirdHours10,
			|	TimesheetTimeWorkedByDays.ThirdHours11,
			|	TimesheetTimeWorkedByDays.ThirdHours12,
			|	TimesheetTimeWorkedByDays.ThirdHours13,
			|	TimesheetTimeWorkedByDays.ThirdHours14,
			|	TimesheetTimeWorkedByDays.ThirdHours15,
			|	TimesheetTimeWorkedByDays.ThirdHours16,
			|	TimesheetTimeWorkedByDays.ThirdHours17,
			|	TimesheetTimeWorkedByDays.ThirdHours18,
			|	TimesheetTimeWorkedByDays.ThirdHours19,
			|	TimesheetTimeWorkedByDays.ThirdHours20,
			|	TimesheetTimeWorkedByDays.ThirdHours21,
			|	TimesheetTimeWorkedByDays.ThirdHours22,
			|	TimesheetTimeWorkedByDays.ThirdHours23,
			|	TimesheetTimeWorkedByDays.ThirdHours24,
			|	TimesheetTimeWorkedByDays.ThirdHours25,
			|	TimesheetTimeWorkedByDays.ThirdHours26,
			|	TimesheetTimeWorkedByDays.ThirdHours27,
			|	TimesheetTimeWorkedByDays.ThirdHours28,
			|	TimesheetTimeWorkedByDays.ThirdHours29,
			|	TimesheetTimeWorkedByDays.ThirdHours30,
			|	TimesheetTimeWorkedByDays.ThirdHours31,
			|	TimesheetTimeWorkedByDays.Employee.Code AS TabNumber
			|FROM
			|	Document.Timesheet.TimeWorkedByDays AS TimesheetTimeWorkedByDays
			|WHERE
			|	TimesheetTimeWorkedByDays.Ref = &Ref
			|
			|ORDER BY
			|	TimesheetTimeWorkedByDays.LineNumber";
			
			Selection = Query.Execute().Choose();
            				
			CON = 0;
			While Selection.Next() Do
				HoursFirstHalf = 0;
				DaysFirstHalf = 0;
				HoursSecondHalf = 0;
				DaysSecondHalf = 0;
				CON = CON + 1;				
				AreaDetails.Parameters.NumberPP = CON;
				AreaDetails.Parameters.Fill(Selection);
				If ValueIsFilled(Selection.Surname) Then
					NAMEANDSURNAME = Selection.Surname;
				Else
					NAMEANDSURNAME = "";
				EndIf;
				AreaDetails.Parameters.DescriptionEmployee = ?(ValueIsFilled(NAMEANDSURNAME), NAMEANDSURNAME, Selection.Employee);
				
				For Counter = 1 To 15 Do
					
				    StringTimeKind = "" + Selection["FirstTimeKind" + Counter] + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "" + Selection["SecondTimeKind" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "" + Selection["ThirdTimeKind" + Counter], "");
					StringHours = "" 	+ ?(Selection["FirstHours" 	+ Counter] = 0, "", Selection["FirstHours" + Counter]) + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "" + Selection["SecondHours" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "" + Selection["ThirdHours" + Counter], "");
								 
					AreaDetails.Parameters["Char" + Counter] = StringTimeKind;			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = StringHours;			 
								 
					Hours = ?(AddToWorkedTime(Selection	 ["FirstTimeKind"  + Counter]), Selection["FirstHours"  + Counter], 0) 
							+ ?(AddToWorkedTime(Selection["SecondTimeKind" + Counter]), Selection["SecondHours" + Counter], 0) 
							+ ?(AddToWorkedTime(Selection["ThirdTimeKind"  + Counter]), Selection["ThirdHours"  + Counter], 0);
					HoursFirstHalf = HoursFirstHalf + Hours;
					DaysFirstHalf = DaysFirstHalf + ?(Hours > 0, 1, 0);
					
				EndDo; 
				
				For Counter = 16 To Day(EndOfMonth(CurrentDocument.AccountingPeriod)) Do
					
				    StringTimeKind 	= "" + Selection["FirstTimeKind" + Counter] + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "" + Selection["SecondTimeKind" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "" + Selection["ThirdTimeKind" + Counter], "");
					StringHours 	= "" + ?(Selection["FirstHours"  + Counter] = 0, "", Selection["FirstHours" + Counter])  + ?(ValueIsFilled(Selection ["SecondTimeKind" + Counter]), "" + Selection["SecondHours" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "" + Selection["ThirdHours" + Counter], "");
								 
					AreaDetails.Parameters["Char" + Counter] = StringTimeKind;			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = StringHours;			 
								 
					Hours = ?(AddToWorkedTime	(Selection["FirstTimeKind"  + Counter]), Selection["FirstHours"  + Counter], 0) 
							+ ?(AddToWorkedTime (Selection["SecondTimeKind" + Counter]), Selection["SecondHours" + Counter], 0) 
							+ ?(AddToWorkedTime (Selection["ThirdTimeKind" 	+ Counter]), Selection["ThirdHours"  + Counter], 0);
					HoursSecondHalf = HoursSecondHalf + Hours;
					DaysSecondHalf = DaysSecondHalf + ?(Hours > 0, 1, 0);
					
				EndDo; 
				
				For Counter = Day(EndOfMonth(CurrentDocument.AccountingPeriod)) + 1 To 31 Do
					
				    AreaDetails.Parameters["Char" + Counter] = "X";			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = "X";
					
				EndDo; 
				
				AreaDetails.Parameters.HoursFirstHalf 	= HoursFirstHalf;
				AreaDetails.Parameters.DaysFirstHalf 	= DaysFirstHalf;
				AreaDetails.Parameters.HoursSecondHalf 	= HoursSecondHalf;
				AreaDetails.Parameters.DaysSecondHalf 	= DaysSecondHalf;
				AreaDetails.Parameters.DaysForMonth 	= DaysFirstHalf  + DaysSecondHalf;
				AreaDetails.Parameters.HoursForMonth 	= HoursFirstHalf + HoursSecondHalf;
				
				SpreadsheetDocument.Put(AreaDetails);
			EndDo;
			
		Else
		
			Query.Text =
			"SELECT
			|	TimesheetTimeWorkedPerPeriod.Employee.Surname,
			|	TimesheetTimeWorkedPerPeriod.Employee,
			|	TimesheetTimeWorkedPerPeriod.Position,
			|	TimesheetTimeWorkedPerPeriod.Employee.Code AS TabNumber,
			|	TimesheetTimeWorkedPerPeriod.TimeKind1,
			|	TimesheetTimeWorkedPerPeriod.Hours1,
			|	TimesheetTimeWorkedPerPeriod.Days1,
			|	TimesheetTimeWorkedPerPeriod.TimeKind2,
			|	TimesheetTimeWorkedPerPeriod.Hours2,
			|	TimesheetTimeWorkedPerPeriod.Days2,
			|	TimesheetTimeWorkedPerPeriod.TimeKind3,
			|	TimesheetTimeWorkedPerPeriod.Hours3,
			|	TimesheetTimeWorkedPerPeriod.Days3,
			|	TimesheetTimeWorkedPerPeriod.TimeKind4,
			|	TimesheetTimeWorkedPerPeriod.Hours4,
			|	TimesheetTimeWorkedPerPeriod.Days4,
			|	TimesheetTimeWorkedPerPeriod.TimeKind5,
			|	TimesheetTimeWorkedPerPeriod.Hours5,
			|	TimesheetTimeWorkedPerPeriod.Days5,
			|	TimesheetTimeWorkedPerPeriod.TimeKind6,
			|	TimesheetTimeWorkedPerPeriod.Hours6,
			|	TimesheetTimeWorkedPerPeriod.Days6
			|FROM
			|	Document.Timesheet.TimeWorkedPerPeriod AS TimesheetTimeWorkedPerPeriod
			|WHERE
			|	TimesheetTimeWorkedPerPeriod.Ref = &Ref
			|
			|ORDER BY
			|	TimesheetTimeWorkedPerPeriod.LineNumber";
			
			Selection = Query.Execute().Choose();		
				
			CON = 0;
			While Selection.Next() Do
				CON = CON + 1;
				AreaDetails.Parameters.NumberPP = CON;
				AreaDetails.Parameters.Fill(Selection);
				If ValueIsFilled(Selection.Surname) Then
					NAMEANDSURNAME = Selection.Surname;
				Else
					NAMEANDSURNAME = "";
				EndIf;
				AreaDetails.Parameters.DescriptionEmployee = ?(ValueIsFilled(NAMEANDSURNAME), NAMEANDSURNAME, Selection.Employee);
				
				StringTimeKind 	= "" + Selection.TimeKind1 + ?(ValueIsFilled(Selection.TimeKind2), "" + Selection.TimeKind2, "") + ?(ValueIsFilled(Selection.TimeKind3), "" + Selection.TimeKind3, "") + ?(ValueIsFilled(Selection.TimeKind4), "" + Selection.TimeKind4, "") + ?(ValueIsFilled(Selection.TimeKind5), "" + Selection.TimeKind5, "") + ?(ValueIsFilled(Selection.TimeKind6), "" + Selection.TimeKind6, "");
				StringHours 	= "" + ?(Selection.TimeKind1 = 0, "", Selection.Hours1) + ?(ValueIsFilled(Selection.TimeKind2), "" + Selection.Hours2, "") + ?(ValueIsFilled(Selection.TimeKind3), "" + Selection.Hours3, "") + ?(ValueIsFilled(Selection.TimeKind4), "" + Selection.Hours4, "") + ?(ValueIsFilled(Selection.TimeKind5), "" + Selection.Hours5, "") + ?(ValueIsFilled(Selection.TimeKind6), "" + Selection.Hours6, "");
							 
				AreaDetails.Parameters.Char1 = StringTimeKind;			 
				AreaDetails.Parameters.AdditionalValue1 = StringHours;			 
					 
				AreaDetails.Parameters.HoursForMonth = ?(AddToWorkedTime(Selection.TimeKind1), Selection.Hours1, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind2), Selection.Hours2, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind3), Selection.Hours3, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind4), Selection.Hours4, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind5), Selection.Hours5, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind6), Selection.Hours6, 0);
					
				AreaDetails.Parameters.DaysForMonth = ?(AddToWorkedTime(Selection.TimeKind1), Selection.Days1, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind2), Selection.Days2, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind3), Selection.Days3, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind4), Selection.Days4, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind5), Selection.Days5, 0) 
							+ ?(AddToWorkedTime(Selection.TimeKind6), Selection.Days6, 0);
								
				SpreadsheetDocument.Put(AreaDetails);
			EndDo;
		
		EndIf; 			
		Heads = _DemoPayrollAndHRServer.CompanyResponsiblePersons(CurrentDocument.Company, CurrentDocument.Date);
		FooterArea.Parameters.Fill(Heads);
		SpreadsheetDocument.Put(FooterArea);
		
		_DemoPrintManagement.SetDocumentPrintArea(SpreadsheetDocument, LineNumberBegin, PrintObjects, CurrentDocument);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generates object print forms.
//
// INCOMING:
//  TemplateNames   - String - template names separated by commas.
//  ObjectsArray    - Array - array of reference to objects to be printed.
//  PrintParameters - Structure - structure of additional printing parameters.
//
// OUTGOING:
//  PrintFormsCollection - Value table - generated spreadsheet documents.
//  OutputParameters     - Structure - generated spreadsheet document parameters.
//
Procedure Print(ObjectsArray, PrintParameters, 
	
	PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	OutputParameters.AvailablePrintingByKits = True;
	
	If _DemoPrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Template") Then
		_DemoPrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Template", "Timesheet", PrintForm(ObjectsArray, PrintObjects));
	EndIf;
	
EndProcedure

Function GetPrintData(Val DocumentsArray, Val TemplateNamesArray) Export
	
	AllObjectsData 			= New Map;
	AreasDetails 	= New Map;
	BinaryDataOfLayouts 	= New Map;
	TemplateTypes 			= New Map;
	
	Return New Structure("Data, Templates",
							AllObjectsData,
							New Structure("AreasDetails, TemplateTypes, BinaryDataOfLayouts",
											AreasDetails,
											TemplateTypes,
											BinaryDataOfLayouts));
	
EndFunction
