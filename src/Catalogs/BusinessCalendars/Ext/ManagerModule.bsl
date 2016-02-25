#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Reads business calendar data from registry.
//
// Parameters:
// BussinessCalendar - CatalogRef.BussinessCalendar, current catalog item reference. 
// YearNumber       - Number, business calendar year number.
//
// Returns:
// BusinessCalendarData	- value table that stores a map between calendar date and day kind.
//
Function BusinessCalendarData(BusinessCalendar, YearNumber) Export
	
	Query = New Query;
	
	Query.SetParameter("BusinessCalendar",	BusinessCalendar);
	Query.SetParameter("CurrentYear",	YearNumber);
	Query.Text =
	"SELECT
	|	BusinessCalendarData.Date,
	|	BusinessCalendarData.DayKind,
	|	BusinessCalendarData.ReplacementDate
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|WHERE
	|	BusinessCalendarData.Year = &CurrentYear
	|	AND BusinessCalendarData.BusinessCalendar = &BusinessCalendar";
	
	Return Query.Execute().Unload();
	
EndFunction

// Prepares the result of filling the business calendar with default data.
// If the configuration contains a template with predefined data 
// for the specified year, the template  data is used, 
// otherwise business calendar data is based on information
// about holidays and holiday replacements.
//
Function BusinessCalendarFillingByDefaultResult(BusinessCalendarCode, YearNumber) Export
	
	DayLength = 24 * 3600;
	
	BusinessCalendarData = New ValueTable;
	BusinessCalendarData.Columns.Add("Date", New TypeDescription("Date"));
	BusinessCalendarData.Columns.Add("DayKind", New TypeDescription("EnumRef.BusinessCalendarDayKinds"));
	BusinessCalendarData.Columns.Add("ReplacementDate", New TypeDescription("Date"));
	
	// If data is in the template, use it
	PredefinedData = BusinessCalendarsDataFromTemplate().FindRows(
								New Structure("BusinessCalendarCode, Year", BusinessCalendarCode, YearNumber));
	If PredefinedData.Count() > 0 Then
		CommonUseClientServer.SupplementTable(PredefinedData, BusinessCalendarData);
		Return BusinessCalendarData;
	EndIf;
	
	// If not, fill holidays and holiday replacements
	Holidays = BusinessCalendarHolidays(BusinessCalendarCode, YearNumber);
	
	DayKinds = New Map;
	
	DayDate = Date(YearNumber, 1, 1);
	While DayDate <= Date(YearNumber, 12, 31) Do
		// If day is "NonHoliday", define its kind according to the week day
		WeekDayNumber = WeekDay(DayDate);
		If WeekDayNumber <= 5 Then
			DayKinds.Insert(DayDate, Enums.BusinessCalendarDayKinds.Workday);
		ElsIf WeekDayNumber = 6 Then
			DayKinds.Insert(DayDate, Enums.BusinessCalendarDayKinds.Saturday);
		ElsIf WeekDayNumber = 7 Then
			DayKinds.Insert(DayDate, Enums.BusinessCalendarDayKinds.Sunday);
		EndIf;
		DayDate = DayDate + DayLength;
	EndDo;
	//PARTIALLY_DELETED
	//Raise("CHECK ON TEST"); // adjust in accordance with US standards
	// If a weekend day matches a nonworking holiday, the holiday replaces the next working day
	
	HolidayReplacements = New Map;
	For Each TableRow In Holidays Do
		Holiday = TableRow.Date;
		If DayKinds[Holiday] <> Enums.BusinessCalendarDayKinds.Workday 
			And TableRow.ReplaceHoliday Then
			// If the holiday falls on a weekend and it must replace another day,
			// the holiday replaces the nearest workday
			DayDate = Holiday;
			While True Do
				DayDate = DayDate + DayLength;
				If DayKinds[DayDate] = Enums.BusinessCalendarDayKinds.Workday 
					And Holidays.Find(DayDate, "Date") = Undefined Then
					DayKinds.Insert(DayDate, DayKinds[Holiday]);
					HolidayReplacements.Insert(DayDate, Holiday);
					HolidayReplacements.Insert(Holiday, DayDate);
					Break;
				EndIf;
			EndDo;
		EndIf;
		DayKinds.Insert(Holiday, Enums.BusinessCalendarDayKinds.Holiday);
		// Mark the day that is previous to the holiday as a preholiday
		HolidayDate = Holiday - DayLength;
		If DayKinds[HolidayDate] = Enums.BusinessCalendarDayKinds.Workday 
			And Holidays.Find(HolidayDate, "Date") = Undefined 
			And Year(HolidayDate) = Year(Holiday) Then
			DayKinds.Insert(HolidayDate, Enums.BusinessCalendarDayKinds.Preholiday);
		EndIf;
	EndDo;
	
	For Each KeyAndValue In DayKinds Do
		NewRow = BusinessCalendarData.Add();
		NewRow.Date = KeyAndValue.Key;
		NewRow.DayKind = KeyAndValue.Value;
		ReplacementDate = HolidayReplacements[NewRow.Date];
		If ReplacementDate <> Undefined Then
			NewRow.ReplacementDate = ReplacementDate;
		EndIf;
	EndDo;
	
	BusinessCalendarData.Sort("Date");
	
	Return BusinessCalendarData;
	
EndFunction

// Converts business calendar data from a configuration template.
//
// Parameters:
// - None.
//
// Returns: 
// Value table with columns. 
// For more information, see BusinessCalendarsDataFromXML function comment.
//
Function BusinessCalendarsDataFromTemplate() Export
	
	TextDocument = InformationRegisters.BusinessCalendarData.GetTemplate("BusinessCalendarsData");
	
	Return BusinessCalendarsDataFromXML(TextDocument.GetText());
	
EndFunction

// Converts business calendar data from an XML file.
//
// Parameters:
// - XML - data file.
//
// Returns:
// Value table with the following columns:
// - BusinessCalendarCode
// - DayKind
// - Year
// - Date
// - ReplacementDate
//
Function BusinessCalendarsDataFromXML(Val XML) Export
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("BusinessCalendarCode", New TypeDescription("String", , New StringQualifiers(2)));
	DataTable.Columns.Add("DayKind", New TypeDescription("EnumRef.BusinessCalendarDayKinds"));
	DataTable.Columns.Add("Year", New TypeDescription("Number"));
	DataTable.Columns.Add("Date", New TypeDescription("Date"));
	DataTable.Columns.Add("ReplacementDate", New TypeDescription("Date"));
	
	ClassifierTable = CommonUse.ReadXMLToTable(XML).Data;
	
	For Each ClassifierString In ClassifierTable Do
		NewRow = DataTable.Add();
		NewRow.BusinessCalendarCode = ClassifierString.Calendar;
		NewRow.DayKind = Enums.BusinessCalendarDayKinds[ClassifierString.DayType];
		NewRow.Year    = Number(ClassifierString.Year);
		NewRow.Date    = Date(ClassifierString.Date);
		If ValueIsFilled(ClassifierString.SwapDate) Then
			NewRow.ReplacementDate = Date(ClassifierString.SwapDate);
		EndIf;
	EndDo;
	
	Return DataTable;
	
EndFunction

// Updates business calendar catalog from an XML file.
//
// Parameters:
// CalendarTable - value table with business calendar descriptions.
//
Procedure UpdateBusinessCalendars(CalendarTable) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CAST(ClassifierTable.Code AS STRING(2)) AS Code,
	|	CAST(ClassifierTable.Description AS STRING(100)) AS Description
	|INTO ClassifierTable
	|FROM
	|	&ClassifierTable AS ClassifierTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ClassifierTable.Code,
	|	ClassifierTable.Description,
	|	BusinessCalendars.Ref AS Ref,
	|	ISNULL(BusinessCalendars.Code, """") AS BusinessCalendarCode,
	|	ISNULL(BusinessCalendars.Description, """") AS BusinessCalendarDescription
	|FROM
	|	ClassifierTable AS ClassifierTable
	|		LEFT JOIN Catalog.BusinessCalendars AS BusinessCalendars
	|		ON ClassifierTable.Code = BusinessCalendars.Code";
	
	Query.SetParameter("ClassifierTable", CalendarTable);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If TrimAll(Selection.Code) = TrimAll(Selection.BusinessCalendarCode)
			And Selection.Description = Selection.BusinessCalendarDescription Then
			Continue;
		EndIf;
		If ValueIsFilled(Selection.Ref) Then
			CatalogObject = Selection.Ref.GetObject();
		Else
			CatalogObject = Catalogs.BusinessCalendars.CreateItem();
		EndIf;
		CatalogObject.Code = TrimAll(Selection.Code);
		CatalogObject.Description = TrimAll(Selection.Description);
		CatalogObject.Write();
	EndDo;
	
EndProcedure

// Updates business calendar data according to a data table.
//
Procedure UpdateBusinessCalendarsData(DataTable) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ClassifierTable.BusinessCalendarCode AS CalendarCode,
	|	ClassifierTable.Date,
	|	ClassifierTable.Year,
	|	ClassifierTable.DayKind,
	|	ClassifierTable.ReplacementDate
	|INTO ClassifierTable
	|FROM
	|	&ClassifierTable AS ClassifierTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BusinessCalendars.Ref AS BusinessCalendar,
	|	ClassifierTable.Year,
	|	ClassifierTable.Date,
	|	ClassifierTable.DayKind,
	|	ClassifierTable.ReplacementDate
	|FROM
	|	ClassifierTable AS ClassifierTable
	|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
	|		ON ClassifierTable.CalendarCode = BusinessCalendars.Code
	|		LEFT JOIN InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		ON (BusinessCalendars.Ref = BusinessCalendarData.BusinessCalendar)
	|			AND ClassifierTable.Year = BusinessCalendarData.Year
	|			AND ClassifierTable.Date = BusinessCalendarData.Date
	|WHERE
	|	(BusinessCalendarData.DayKind IS NULL 
	|			OR ClassifierTable.DayKind <> BusinessCalendarData.DayKind
	|			OR ClassifierTable.ReplacementDate <> BusinessCalendarData.ReplacementDate)";
	
	Query.SetParameter("ClassifierTable", DataTable);
	
	RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
	
	RegisterKeys = New Array;
	RegisterKeys.Add("BusinessCalendar");
	RegisterKeys.Add("Year");
	RegisterKeys.Add("Date");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		RecordSet.Clear();
		FillPropertyValues(RecordSet.Add(), Selection);
		For Each Key In RegisterKeys Do 
			RecordSet.Filter[Key].Set(Selection[Key]);
		EndDo;
		RecordSet.Write(True);
	EndDo;
	
	DataTable.GroupBy("BusinessCalendarCode, Year");
	DistributeBusinessCalendarsDataChanges(DataTable);
	
EndProcedure

// Writes business calendar data for one year.
//
// Parameters:
// BussinessCalendar    - current catalog item reference. 
// YearNumber           - business calendar year number. 
// BusinessCalendarData - value table that stores map between calendar date and day kind.
//
// Returns:
// None.
//
Procedure WriteBusinessCalendarData(BusinessCalendar, YearNumber, BusinessCalendarData) Export
	
	RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
	
	For Each KeyAndValue In BusinessCalendarData Do
		FillPropertyValues(RecordSet.Add(), KeyAndValue);
	EndDo;
	
	FilterValues = New Structure("BusinessCalendar, Year", BusinessCalendar, YearNumber);
	
	For Each KeyAndValue In FilterValues Do
		RecordSet.Filter[KeyAndValue.Key].Set(KeyAndValue.Value);
	EndDo;
	
	For Each SetRow In RecordSet Do
		FillPropertyValues(SetRow, FilterValues);
	EndDo;
	
	RecordSet.Write(True);
	
	UpdateConditions = WorkScheduleUpdateConditions(BusinessCalendar, YearNumber);
	DistributeBusinessCalendarsDataChanges(UpdateConditions);
	
EndProcedure

// Updates items related to a business calendar, for example, Work schedules.
//
// Parameters:
// ChangeTable - table with the following columns:
// 	- BusinessCalendarCode - business calendar code.
// 	- Year                 - data update enforcement year.
//
Procedure DistributeBusinessCalendarsDataChanges(ChangeTable) Export
	
	// Updating schedules that are automatically filled according to the business calendar
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		If CommonUseCached.DataSeparationEnabled() Then
			WorkSchedulesModule.ScheduleWorkScheduleUpdate(ChangeTable);
		Else
			WorkSchedulesModule.UpdateWorkSchedulesAccordingToBusinessCalendars(ChangeTable);
		EndIf;
	EndIf;
	
	EventHandlers = CommonUse.InternalEventHandlers(
		"StandardSubsystems.CalendarSchedules\OnUpdateBusinessCalendars");
	For Each Handler In EventHandlers Do
		Handler.Module.OnUpdateBusinessCalendars(ChangeTable);
	EndDo;
	
	CalendarSchedulesOverridable.OnUpdateBusinessCalendars(ChangeTable);
	
EndProcedure

// Defines the map between business calendar day kind and 
// calendar field appearance color for this day.
//
// Returns:
// AppearanceColors - map between days and appearance colors.
//
Function BusinessCalendarDayKindAppearanceColors() Export
	
	AppearanceColors = New Map;
	
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Workday,    StyleColors.BusinessCalendarDayKindWorkdayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Saturday,   StyleColors.BusinessCalendarDayKindSaturdayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Sunday,     StyleColors.BusinessCalendarDayKindSundayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Preholiday, StyleColors.BusinessCalendarDayKindDayPreholidayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDayKinds.Holiday,    StyleColors.BusinessCalendarDayKindHolidayColor);
	
	Return AppearanceColors;
	
EndFunction

// Generates a list of business calendar day kinds by BusinessCalendarDayKinds enumeration metadata.
//
// Returns:
// DayKindList - value list that contains enumeration values 
//               and their synonyms (as presentations).
//
Function DayKindList() Export
	
	DayKindList = New ValueList;
	
	For Each DayKindMetadata In Metadata.Enums.BusinessCalendarDayKinds.EnumValues Do
		DayKindList.Add(Enums.BusinessCalendarDayKinds[DayKindMetadata.Name], DayKindMetadata.Synonym);
	EndDo;
	
	Return DayKindList;
	
EndFunction

// Creates an array of available business calendars to use as a template.
//
Function BusinessCalendarList() Export

	Query = New Query(
	"SELECT
	|	BusinessCalendars.Ref
	|FROM
	|	Catalog.BusinessCalendars AS BusinessCalendars
	|WHERE
	|	(NOT BusinessCalendars.DeletionMark)");
		
	BusinessCalendarList = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		BusinessCalendarList.Add(Selection.Ref);
	EndDo;
	
	Return BusinessCalendarList;
	
EndFunction

// Finds the last date filled with data in the specified business calendar.
//
// Parameters:
//  Business calendar - CatalogRef.BusinessCalendar type.
//
Function BusinessCalendarFillingEndDate(BusinessCalendar) Export
	
	QueryText = 
	"SELECT
	|	MAX(BusinessCalendarData.Date) AS Date
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|WHERE
	|	BusinessCalendarData.BusinessCalendar = &BusinessCalendar
	|
	|HAVING
	|	MAX(BusinessCalendarData.Date) IS NOT NULL ";
	
	Query = New Query(QueryText);
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Date;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Fills a holidays array according to a business calendar for a specific calendar year.
// 
Function BusinessCalendarHolidays(BusinessCalendarCode, YearNumber)
	
	Holidays = New ValueTable;
	Holidays.Columns.Add("Date", New TypeDescription("Date"));
	Holidays.Columns.Add("ReplaceHoliday", New TypeDescription("Boolean"));
	//Raise("CHECK ON TEST"); // adjust in accordance with US standards
	If BusinessCalendarCode = "US" Then
		
		// Adding local holidays
		
		If YearNumber = 2016 Then
			
			AddHoliday(Holidays, "01.01", YearNumber, False);//New Year's Day
			AddHoliday(Holidays, "18.01", YearNumber, False);//Martin Luther King, Jr. Day
			AddHoliday(Holidays, "15.02", YearNumber, False);//Presidents Day
			AddHoliday(Holidays, "27.03", YearNumber, False);//Easter
			AddHoliday(Holidays, "30.05", YearNumber, False);//Memorial Day
			AddHoliday(Holidays, "04.07", YearNumber, False);//Independence Day
			AddHoliday(Holidays, "05.09", YearNumber, False);//Labor Day			
			AddHoliday(Holidays, "10.10", YearNumber, False);//Columbus Day
			AddHoliday(Holidays, "11.11", YearNumber, False);//Veterans Day
			AddHoliday(Holidays, "24.11", YearNumber, False);//Thanksgiving Day
			AddHoliday(Holidays, "25.11", YearNumber, False);//Friday after Thanksgiving
			AddHoliday(Holidays, "26.12", YearNumber, False);//Christmas Day
		
		ElsIf YearNumber = 2017 Then 
		
			AddHoliday(Holidays, "02.01", YearNumber, False);//New Year's Day
			AddHoliday(Holidays, "16.01", YearNumber, False);//Martin Luther King, Jr. Day
			AddHoliday(Holidays, "20.02", YearNumber, False);//Presidents Day
			AddHoliday(Holidays, "16.04", YearNumber, False);//Easter
			AddHoliday(Holidays, "29.05", YearNumber, False);//Memorial Day
			AddHoliday(Holidays, "04.07", YearNumber, False);//Independence Day
			AddHoliday(Holidays, "04.09", YearNumber, False);//Labor Day			
			AddHoliday(Holidays, "09.10", YearNumber, False);//Columbus Day
			AddHoliday(Holidays, "10.11", YearNumber, False);//Veterans Day
			AddHoliday(Holidays, "23.11", YearNumber, False);//Thanksgiving Day
			AddHoliday(Holidays, "24.11", YearNumber, False);//Friday after Thanksgiving
			AddHoliday(Holidays, "25.12", YearNumber, False);//Christmas Day
		
		EndIf;
				
	EndIf;
	
	Return Holidays;
	
EndFunction

Procedure AddHoliday(Holidays, Holiday, YearNumber, ReplaceHoliday = True)
	
	DayMonth = StringFunctionsClientServer.SplitStringIntoSubstringArray(Holiday, ".");
	
	NewRow = Holidays.Add();
	NewRow.Date = Date(YearNumber, DayMonth[1], DayMonth[0]);
	NewRow.ReplaceHoliday = ReplaceHoliday;
	
EndProcedure

Function WorkScheduleUpdateConditions(BusinessCalendar, Year)
	
	UpdateConditions = New ValueTable;
	UpdateConditions.Columns.Add("BusinessCalendarCode", New TypeDescription("String", , New StringQualifiers(3)));
	UpdateConditions.Columns.Add("Year", New TypeDescription("Number", New NumberQualifiers(4)));
	
	NewRow = UpdateConditions.Add();
	NewRow.BusinessCalendarCode = CommonUse.ObjectAttributeValue(BusinessCalendar, "Code");
	NewRow.Year = Year;

	Return UpdateConditions;
	
EndFunction

// Returns catalog attributes that are natural keys for catalog items.
//
// Returns: Array(String) - attribute name array that creates natural keys.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Code");
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Business calendar print form.

// Generates print forms.
//
// Parameters:
//  (input)
//   ObjectArray         - Array     - references to objects to be printed.
//   PrintParameters     - Structure - additional print settings.
//  (output)
//   PrintFormCollection - ValueTable - generated spreadsheet documents. 
//   PrintObject         - ValueList  - Value - reference to an object.
//                                    - Presentation - name of the area where the object is displayed.
//   OutputParameters    - Structure - additional parameters of generated spreadsheet documents.
//
Procedure Print(ObjectArray, PrintParameters, PrintFormCollection, PrintObjects, OutputParameters) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.Print") Then
		PrintManagementModule = CommonUse.CommonModule("PrintManagement");
		PrintManagementModule.OutputSpreadsheetDocumentToCollection(
				PrintFormCollection,
				"BusinessCalendar", NStr("en = 'Business calendar'"),
				Catalogs.BusinessCalendars.BusinessCalendarPrintForm(PrintParameters),
				,
				"Catalog.BusinessCalendars.PF_MXL_BusinessCalendar");
	EndIf;
	
EndProcedure

Function BusinessCalendarPrintForm(PrintedFormPreparationParameters) Export
	
	QueryText = 
	"SELECT
	|	YEAR(CalendarData.Date) AS CalendarYear,
	|	QUARTER(CalendarData.Date) AS CalendarQuarter,
	|	MONTH(CalendarData.Date) AS CalendarMonth,
	|	COUNT(DISTINCT CalendarData.Date) AS CalendarDays,
	|	CalendarData.DayKind AS DayKind
	|FROM
	|	InformationRegister.BusinessCalendarData AS CalendarData
	|WHERE
	|	CalendarData.Year = &Year
	|	AND CalendarData.BusinessCalendar = &BusinessCalendar
	|
	|GROUP BY
	|	CalendarData.DayKind,
	|	YEAR(CalendarData.Date),
	|	QUARTER(CalendarData.Date),
	|	MONTH(CalendarData.Date)
	|
	|ORDER BY
	|	CalendarYear,
	|	CalendarQuarter,
	|	CalendarMonth
	|TOTALS BY
	|	CalendarYear,
	|	CalendarQuarter,
	|	CalendarMonth";
	
	BusinessCalendar = PrintedFormPreparationParameters.BusinessCalendar;
	YearNumber = PrintedFormPreparationParameters.YearNumber;
	
	Template = Catalogs.BusinessCalendars.GetTemplate("PF_MXL_BusinessCalendar");
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	PrintTitle = Template.GetArea("Title");
	PrintTitle.Parameters.BusinessCalendar = BusinessCalendar;
	PrintTitle.Parameters.Year = Format(YearNumber, "NG=");
	SpreadsheetDocument.Put(PrintTitle);
	
	// Initial values, which do not depend on query execution result
	WorkTime40Year = 0;
	WorkTime36Year = 0;
	WorkTime24Year = 0;
	
	NonWorkdayKinds = New Array;
	NonWorkdayKinds.Add(Enums.BusinessCalendarDayKinds.Saturday);
	NonWorkdayKinds.Add(Enums.BusinessCalendarDayKinds.Sunday);
	NonWorkdayKinds.Add(Enums.BusinessCalendarDayKinds.Holiday);
	
	Query = New Query(QueryText);
	Query.SetParameter("Year", YearNumber);
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	Result = Query.Execute();
	
	SelectionByYear = Result.Select(QueryResultIteration.ByGroups);
	While SelectionByYear.Next() Do
		
		SelectionByQuarter = SelectionByYear.Select(QueryResultIteration.ByGroups);
		While SelectionByQuarter.Next() Do
			QuarterNumber = Template.GetArea("Quarter");
			QuarterNumber.Parameters.QuarterNumber = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'quarter %1'"), SelectionByQuarter.CalendarQuarter);
			SpreadsheetDocument.Put(QuarterNumber);
			
			QuarterHeader = Template.GetArea("QuarterHeader");
			SpreadsheetDocument.Put(QuarterHeader);
			
			CalendarDaysQuarter  = 0;
			WorkTime40Quarter = 0;
			WorkTime36Quarter = 0;
			WorkTime24Quarter = 0;
			WorkdaysQuarter   = 0;
			WeekendDaysQuarter   = 0;
			
			If SelectionByQuarter.CalendarQuarter = 1 
				Or SelectionByQuarter.CalendarQuarter = 3 Then
				CalendarDaysHalfYear1  = 0;
				WorkTime40HalfYear1 = 0;
				WorkTime36HalfYear1 = 0;
				WorkTime24HalfYear1 = 0;
				WorkdaysHalfYear1   = 0;
				WeekendDaysHalfYear1   = 0;
			EndIf;
			
			If SelectionByQuarter.CalendarQuarter = 1 Then
				CalendarDaysYear  = 0;
				WorkTime40Year = 0;
				WorkTime36Year = 0;
				WorkTime24Year = 0;
				WorkdaysYear   = 0;
				WeekendDaysYear   = 0;
			EndIf;
			
			SelectionByMonth = SelectionByQuarter.Select(QueryResultIteration.ByGroups);
			While SelectionByMonth.Next() Do
				
				WeekendDays   = 0;
				WorkTime40 = 0;
				WorkTime36 = 0;
				WorkTime24 = 0;
				CalendarDays  = 0;
				Workdays   = 0;
				SelectionByDayType = SelectionByMonth.Select(QueryResultIteration.Linear);
				
				While SelectionByDayType.Next() Do
					If SelectionByDayType.DayKind = Enums.BusinessCalendarDayKinds.Saturday 
						Or SelectionByDayType.DayKind = Enums.BusinessCalendarDayKinds.Sunday
						Or SelectionByDayType.DayKind = Enums.BusinessCalendarDayKinds.Holiday Then
						 WeekendDays = WeekendDays + SelectionByDayType.CalendarDays
					 ElsIf SelectionByDayType.DayKind = Enums.BusinessCalendarDayKinds.Workday Then 
						 WorkTime40 = WorkTime40 + SelectionByDayType.CalendarDays * 8;
						 WorkTime36 = WorkTime36 + SelectionByDayType.CalendarDays * 36 / 5;
						 WorkTime24 = WorkTime24 + SelectionByDayType.CalendarDays * 24 / 5;
						 Workdays   = Workdays   + SelectionByDayType.CalendarDays;
					 ElsIf SelectionByDayType.DayKind = Enums.BusinessCalendarDayKinds.Preholiday Then
						 WorkTime40 = WorkTime40 + SelectionByDayType.CalendarDays * 7;
						 WorkTime36 = WorkTime36 + SelectionByDayType.CalendarDays * 36 / 5 - 1;
						 WorkTime24 = WorkTime24 + SelectionByDayType.CalendarDays * 24 / 5 - 1;
						 Workdays   = Workdays   + SelectionByDayType.CalendarDays;
					 EndIf;
					 CalendarDays = CalendarDays + SelectionByDayType.CalendarDays;
				EndDo;
				
				CalendarDaysQuarter  = CalendarDaysQuarter  + CalendarDays;
				WorkTime40Quarter = WorkTime40Quarter + WorkTime40;
				WorkTime36Quarter = WorkTime36Quarter + WorkTime36;
				WorkTime24Quarter = WorkTime24Quarter + WorkTime24;
				WorkdaysQuarter   = WorkdaysQuarter   + Workdays;
				WeekendDaysQuarter   = WeekendDaysQuarter   + WeekendDays;
				
				CalendarDaysHalfYear1  = CalendarDaysHalfYear1  + CalendarDays;
				WorkTime40HalfYear1 = WorkTime40HalfYear1 + WorkTime40;
				WorkTime36HalfYear1 = WorkTime36HalfYear1 + WorkTime36;
				WorkTime24HalfYear1 = WorkTime24HalfYear1 + WorkTime24;
				WorkdaysHalfYear1   = WorkdaysHalfYear1   + Workdays;
				WeekendDaysHalfYear1   = WeekendDaysHalfYear1   + WeekendDays;
				
				CalendarDaysYear  = CalendarDaysYear  + CalendarDays;
				WorkTime40Year = WorkTime40Year + WorkTime40;
				WorkTime36Year = WorkTime36Year + WorkTime36;
				WorkTime24Year = WorkTime24Year + WorkTime24;
				WorkdaysYear   = WorkdaysYear   + Workdays;
				WeekendDaysYear   = WeekendDaysYear   + WeekendDays;
				
				MonthColumn = Template.GetArea("MonthColumn");
				MonthColumn.Parameters.WeekendDays = WeekendDays;
				MonthColumn.Parameters.WorkTime40 = WorkTime40;
				MonthColumn.Parameters.WorkTime36 = WorkTime36;
				MonthColumn.Parameters.WorkTime24 = WorkTime24;
				MonthColumn.Parameters.CalendarDays  = CalendarDays;
				MonthColumn.Parameters.Workdays   = Workdays;
				MonthColumn.Parameters.MonthName     = Format(Date(YearNumber, SelectionByMonth.CalendarMonth, 1), "DF='MMMM'");
				SpreadsheetDocument.Join(MonthColumn);
				
			EndDo;
			MonthColumn = Template.GetArea("MonthColumn");
			MonthColumn.Parameters.WeekendDays   = WeekendDaysQuarter;
			MonthColumn.Parameters.WorkTime40 = WorkTime40Quarter;
			MonthColumn.Parameters.WorkTime36 = WorkTime36Quarter;
			MonthColumn.Parameters.WorkTime24 = WorkTime24Quarter;
			MonthColumn.Parameters.CalendarDays  = CalendarDaysQuarter;
			MonthColumn.Parameters.Workdays   = WorkdaysQuarter;
			MonthColumn.Parameters.MonthName     = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'quarter %1'"), SelectionByQuarter.CalendarQuarter);
			SpreadsheetDocument.Join(MonthColumn);
			
			If SelectionByQuarter.CalendarQuarter = 2 
				Or SelectionByQuarter.CalendarQuarter = 4 Then 
				MonthColumn = Template.GetArea("MonthColumn");
				MonthColumn.Parameters.WeekendDays   = WeekendDaysHalfYear1;
				MonthColumn.Parameters.WorkTime40 = WorkTime40HalfYear1;
				MonthColumn.Parameters.WorkTime36 = WorkTime36HalfYear1;
				MonthColumn.Parameters.WorkTime24 = WorkTime24HalfYear1;
				MonthColumn.Parameters.CalendarDays  = CalendarDaysHalfYear1;
				MonthColumn.Parameters.Workdays   = WorkdaysHalfYear1;
				MonthColumn.Parameters.MonthName     = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'half year %1'"), SelectionByQuarter.CalendarQuarter / 2);
				SpreadsheetDocument.Join(MonthColumn);
			EndIf;
			
		EndDo;
		
		MonthColumn = Template.GetArea("MonthColumn");
		MonthColumn.Parameters.WeekendDays   = WeekendDaysYear;
		MonthColumn.Parameters.WorkTime40 = WorkTime40Year;
		MonthColumn.Parameters.WorkTime36 = WorkTime36Year;
		MonthColumn.Parameters.WorkTime24 = WorkTime24Year;
		MonthColumn.Parameters.CalendarDays  = CalendarDaysYear;
		MonthColumn.Parameters.Workdays   = WorkdaysYear;
		MonthColumn.Parameters.MonthName     = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'year %1'"), Format(SelectionByYear.CalendarYear, "NG="));
		SpreadsheetDocument.Join(MonthColumn);
		
	EndDo;
	
	MonthColumn = Template.GetArea("AverageMonthly");
	MonthColumn.Parameters.WorkTime40 = WorkTime40Year;
	MonthColumn.Parameters.WorkTime36 = WorkTime36Year;
	MonthColumn.Parameters.WorkTime24 = WorkTime24Year;
	MonthColumn.Parameters.MonthName     = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'year %1'"), Format(YearNumber, "NG="));
	SpreadsheetDocument.Output(MonthColumn);
	
	MonthColumn = Template.GetArea("MonthColumnAverage");
	MonthColumn.Parameters.WorkTime40 = Format(WorkTime40Year / 12, "NFD=2; NG=0");
	MonthColumn.Parameters.WorkTime36 = Format(WorkTime36Year / 12, "NFD=2; NG=0");
	MonthColumn.Parameters.WorkTime24 = Format(WorkTime24Year / 12, "NFD=2; NG=0");
	MonthColumn.Parameters.MonthName     = NStr("en = 'Average monthly count'");
	SpreadsheetDocument.Join(MonthColumn);
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndIf