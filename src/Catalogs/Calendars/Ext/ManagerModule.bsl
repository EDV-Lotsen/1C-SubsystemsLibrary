#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// The function reads the work schedule data from the register
//
// Parameters
// WorkSchedule	- Current catalog item reference 
// YearNumber	  - The year number for which to read the schedule
//
// Returns       - map, where Key is the date
//
Function ReadScheduleDataFromRegister(WorkSchedule, YearNumber) Export
	
	QueryText =
	"SELECT
	|	CalendarSchedules.ScheduleDate AS CalendarDate
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule
	|	AND CalendarSchedules.Year = &CurrentYear
	|	AND CalendarSchedules.DayAddedToSchedule
	|
	|ORDER BY
	|	CalendarDate";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkSchedule", WorkSchedule);
	Query.SetParameter("CurrentYear",  YearNumber);
	
	DaysIncludedInSchedule = New Map;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DaysIncludedInSchedule.Insert(Selection.CalendarDate, True);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

// The procedure writes the schedule data to the register
//
// Parameters
// WorkSchedule           - Current catalog item reference
// YearNumber             - The number of the year for which to write the schedule 
// DaysIncludedInSchedule - map of the date and the data related thereto
//
// Returns:
// No
//
Procedure WriteScheduleDataToRegister(WorkSchedule, DaysIncludedInSchedule, StartDate, EndDate, ReplaceManualChanges = False) Export
	
	SetDays = InformationRegisters.CalendarSchedules.CreateRecordSet();
	SetDays.Filter.Calendar.Set(WorkSchedule);
	
	// Fill the calendar by years
	// Select the years
	// For each year 
	// - read the set, 
	// - modify taking the written data into consideration  
	// - write
	
	DataByYear = New Map;
	
	DayDate = StartDate;
	While DayDate <= EndDate Do
		DataByYear.Insert(Year(DayDate), True);
		DayDate = DayDate + 86400;
	EndDo;
	
	ManualChanges = Undefined;
	If Not ReplaceManualChanges Then
		ManualChanges = ScheduleManualChanges(WorkSchedule);
	EndIf;
	
	// process data by years
	For Each KeyAndValue In DataByYear Do
		Year = KeyAndValue.Key;
		
		// Read sets for the year
		SetDays.Filter.Year.Set(Year);
		SetDays.Read();
		
		// fill the contents of the set according to the dates to allow a fast access
		SetRowsDays = New Map;
		For Each SetRow In SetDays Do
			SetRowsDays.Insert(SetRow.ScheduleDate, SetRow);
		EndDo;
		
		BegOfYear = Date(Year, 1, 1);
		EndOfYear = Date(Year, 12, 31);
		
		TraversalStart = ?(StartDate > BegOfYear, StartDate, BegOfYear);
		TraversalEnd = ?(EndDate < EndOfYear, EndDate, EndOfYear);
		
		// The data in the set should be replaced for the traversal period
		DayDate = TraversalStart;
		While DayDate <= TraversalEnd Do
			
			If ManualChanges <> Undefined And ManualChanges[DayDate] <> Undefined Then
				// leave without change in the manual adjustment set
				DayDate = DayDate + 86400;
				Continue;
			EndIf;
			
			// If the set has no row for date, create it
			SetRowDays = SetRowsDays[DayDate];
			If SetRowDays = Undefined Then
				SetRowDays = SetDays.Add();
				SetRowDays.Calendar = WorkSchedule;
				SetRowDays.Year = Year;
				SetRowDays.ScheduleDate = DayDate;
				SetRowsDays.Insert(DayDate, SetRowDays);
			EndIf;
			
			// If the day is included in the schedule, fill in the intervals
			DayData = DaysIncludedInSchedule.Get(DayDate);
			If DayData = Undefined Then
				// Remove the row from the set if it is a holiday
				SetDays.Delete(SetRowDays);
				SetRowsDays.Delete(DayDate);
			Else
				SetRowDays.DayAddedToSchedule = True;
			EndIf;
			DayDate = DayDate + 86400;
		EndDo;
		
		// Fill in with the secondary data to optimize calendrical calculations
		TraversalDate = BegOfYear;
		DayNumberInScheduleSinceYearBeginning = 0;
		While TraversalDate <= EndOfYear Do
			SetRowDays = SetRowsDays[TraversalDate];
			If SetRowDays <> Undefined Then
				// The day is included in the schedule
				DayNumberInScheduleSinceYearBeginning = DayNumberInScheduleSinceYearBeginning + 1;
			Else
				// The day is not included in the schedule
				SetRowDays = SetDays.Add();
				SetRowDays.Calendar = WorkSchedule;
				SetRowDays.Year = Year;
				SetRowDays.ScheduleDate = TraversalDate;
			EndIf;
			SetRowDays.DayNumberInScheduleSinceYearBeginning = DayNumberInScheduleSinceYearBeginning;
			TraversalDate = TraversalDate + 86400;
		EndDo;
		
		SetDays.Write();
		
	EndDo;
	
EndProcedure

// Uses business calendar data to update work schedules 
//
// Parameters:
// 	- UpdateConditions      - value table with the following columns 
// 	- BusinessCalendarCode  - business calendar code
// 	- Year                  - data update enforcement year
//
Procedure UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions) Export
	
	// Identify the schedules that require updating
	// get the data for the schedules
	// update the data for each year
	
	QueryText = 
	"SELECT
	|	UpdateConditions.BusinessCalendarCode,
	|	UpdateConditions.Year,
	|	DATEADD(DATETIME(1, 1, 1), YEAR, UpdateConditions.Year - 1) AS BegOfYear,
	|	DATEADD(DATETIME(1, 12, 31), YEAR, UpdateConditions.Year - 1) AS EndOfYear
	|INTO UpdateConditions
	|FROM
	|	&UpdateConditions AS UpdateConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkSchedule,
	|	UpdateConditions.Year,
	|	Calendars.FillingMethod,
	|	Calendars.BusinessCalendar,
	|	CASE
	|		WHEN Calendars.StartDate < UpdateConditions.BegOfYear
	|			THEN UpdateConditions.BegOfYear
	|		ELSE Calendars.StartDate
	|	END AS StartDate,
	|	CASE
	|		WHEN Calendars.EndDate > UpdateConditions.EndOfYear
	|				OR Calendars.EndDate = DATETIME(1, 1, 1)
	|			THEN UpdateConditions.EndOfYear
	|		ELSE Calendars.EndDate
	|	END AS EndDate,
	|	Calendars.PeriodStartDate,
	|	Calendars.ConsiderHolidays
	|INTO UpdatableWorkSchedules
	|FROM
	|	Catalog.Calendars AS Calendars
	|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
	|		ON (BusinessCalendars.Ref = Calendars.BusinessCalendar)
	|			AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks)
	|				OR Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods)
	|					AND Calendars.ConsiderHolidays)
	|		INNER JOIN UpdateConditions AS UpdateConditions
	|		ON (UpdateConditions.BusinessCalendarCode = BusinessCalendars.Code)
	|			AND Calendars.StartDate <= UpdateConditions.EndOfYear
	|			AND (Calendars.EndDate >= UpdateConditions.BegOfYear
	|				OR Calendars.EndDate = DATETIME(1, 1, 1))
	|		LEFT JOIN InformationRegister.ManualWorkScheduleChanges AS ManualChangesForAllYears
	|		ON (ManualChangesForAllYears.WorkSchedule = Calendars.Ref)
	|			AND (ManualChangesForAllYears.Year = 0)
	|WHERE
	|	ManualChangesForAllYears.WorkSchedule IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UpdatableWorkSchedules.WorkSchedule,
	|	UpdatableWorkSchedules.Year,
	|	UpdatableWorkSchedules.FillingMethod,
	|	UpdatableWorkSchedules.BusinessCalendar,
	|	UpdatableWorkSchedules.StartDate,
	|	UpdatableWorkSchedules.EndDate,
	|	UpdatableWorkSchedules.PeriodStartDate,
	|	UpdatableWorkSchedules.ConsiderHolidays
	|FROM
	|	UpdatableWorkSchedules AS UpdatableWorkSchedules
	|
	|ORDER BY
	|	UpdatableWorkSchedules.WorkSchedule,
	|	UpdatableWorkSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FillingTemplate.Ref AS WorkSchedule,
	|	FillingTemplate.LineNumber AS LineNumber,
	|	FillingTemplate.DayAddedToSchedule
	|FROM
	|	Catalog.Calendars.FillingTemplate AS FillingTemplate
	|WHERE
	|	FillingTemplate.Ref IN
	|			(SELECT
	|				UpdatableWorkSchedules.WorkSchedule
	|			FROM
	|				UpdatableWorkSchedules)
	|
	|ORDER BY
	|	WorkSchedule,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkSchedule.Ref AS WorkSchedule,
	|	WorkSchedule.DayNumber AS DayNumber,
	|	WorkSchedule.BeginTime,
	|	WorkSchedule.EndTime
	|FROM
	|	Catalog.Calendars.WorkSchedule AS WorkSchedule
	|WHERE
	|	WorkSchedule.Ref IN
	|			(SELECT
	|				UpdatableWorkSchedules.WorkSchedule
	|			FROM
	|				UpdatableWorkSchedules)
	|
	|ORDER BY
	|	WorkSchedule,
	|	WorkSchedule.DayNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("UpdateConditions", UpdateConditions);
	
	QueryResults = Query.ExecuteBatch();
	SelectionBySchedule = QueryResults[QueryResults.UBound() - 2].Select();
	SelectionByTemplate = QueryResults[QueryResults.UBound() - 1].Select();
	SelectionByTimetable = QueryResults[QueryResults.UBound()].Select();
	
	FillingTemplate = New ValueTable;
	FillingTemplate.Columns.Add("DayAddedToSchedule", New TypeDescription("Boolean"));
	
	WorkSchedule = New ValueTable;
	WorkSchedule.Columns.Add("DayNumber", New TypeDescription("Number", New NumberQualifiers(7)));
	WorkSchedule.Columns.Add("BeginTime", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Time)));
	WorkSchedule.Columns.Add("EndTime",   New TypeDescription("Date", , , New DateQualifiers(DateFractions.Time)));
	
	While SelectionBySchedule.NextByFieldValue("WorkSchedule") Do
		FillingTemplate.Clear();
		While SelectionByTemplate.FindNext(SelectionBySchedule.WorkSchedule, "WorkSchedule") Do
			NewRow = FillingTemplate.Add();
			NewRow.DayAddedToSchedule = SelectionByTemplate.DayAddedToSchedule;
		EndDo;
		WorkSchedule.Clear();
		While SelectionByTimetable.FindNext(SelectionBySchedule.WorkSchedule, "WorkSchedule") Do
			NewInterval = WorkSchedule.Add();
			NewInterval.DayNumber = SelectionByTimetable.DayNumber;
			NewInterval.BeginTime = SelectionByTimetable.BeginTime;
			NewInterval.EndTime   = SelectionByTimetable.EndTime;
		EndDo;
		While SelectionBySchedule.NextByFieldValue("StartDate") Do
			// If the end date is not specified, it will be selected in the business calendar
			FillingEndDate = SelectionBySchedule.EndDate;
			DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
										SelectionBySchedule.StartDate, 
										SelectionBySchedule.FillingMethod, 
										FillingTemplate, 
										WorkSchedule,
										FillingEndDate,
										SelectionBySchedule.BusinessCalendar, 
										SelectionBySchedule.ConsiderHolidays, 
										SelectionBySchedule.PeriodStartDate);
			Catalogs.Calendars.WriteScheduleDataToRegister(SelectionBySchedule.WorkSchedule, DaysIncludedInSchedule, SelectionBySchedule.StartDate, FillingEndDate);
		EndDo;
	EndDo;
	
EndProcedure

// Creates a set of workdays taking into consideration the business calendar, 
// the filling method and other settings
//
// Parameters:
// - Year             - year number
// - BusinessCalendar - the business calendar that is used to define the days
// - FillingMethod    - filling method
// - FillingTemplate  - filling template on a per-day basis
// - ConsiderHolidays - Boolean, if True, then public holidays will be excluded 
// - StartDate        - optional, is specified only for arbitrary length periods
//
// Returns - Map, where Key is the date, structure array describing time intervals 
// for the specified date
//
Function DaysIncludedInSchedule(StartDate, FillingMethod, FillingTemplate, WorkSchedule = Undefined, EndDate = Undefined, BusinessCalendar = Undefined, ConsiderHolidays = True, Val PeriodStartDate = Undefined) Export
	
	DaysIncludedInSchedule = New Map;

	If FillingTemplate.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	If Not ValueIsFilled(EndDate) Then
		// If the end date is not specified, then fill it in till the end of the year
		EndDate = EndOfYear(StartDate);
		If ValueIsFilled(BusinessCalendar) Then
			// If the business calendar is specified, filling it
			FillingEndDate = Catalogs.BusinessCalendars.BusinessCalendarFillingEndDate(BusinessCalendar);
			If FillingEndDate <> Undefined 
				And FillingEndDate > EndDate Then
				EndDate = FillingEndDate;
			EndIf;
		EndIf;
	EndIf;
	
	// It is filled in with data on an annual basis
	CurrentYear = Year(StartDate);
	While CurrentYear <= Year(EndDate) Do
		YearBeginDate = StartDate;
		YearEndDate = EndDate;
		AdjustStartDatesEndDates(CurrentYear, YearBeginDate, YearEndDate);	
		// Get schedule information for the year
		If FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks Then
			DaysPerYear = DaysIncludedInScheduleByWeeks(CurrentYear, BusinessCalendar, FillingTemplate, ConsiderHolidays, WorkSchedule, YearBeginDate, YearEndDate);
		Else
			DaysPerYear = DaysIncludedInScheduleArbitraryLength(CurrentYear, BusinessCalendar, FillingTemplate, ConsiderHolidays, PeriodStartDate, WorkSchedule, YearBeginDate, YearEndDate);
		EndIf;
		// Add to the shared set
		For Each KeyAndValue In DaysPerYear Do
			DaysIncludedInSchedule.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		CurrentYear = CurrentYear + 1;
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Function DaysIncludedInScheduleByWeeks(Year, BusinessCalendar, FillingTemplate, ConsiderHolidays = True, WorkSchedule = Undefined, Val StartDate = Undefined, Val EndDate = Undefined)
	
	// Fill in the work schedule by weeks
	
	DaysIncludedInSchedule = New Map;
	
	FillInAccordingToBusinessCalendar = ValueIsFilled(BusinessCalendar);
	
	DaysPerYear = DayOfYear(Date(Year, 12, 31));
	BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, Year);
	If FillInAccordingToBusinessCalendar 
		And BusinessCalendarData.Count() <> DaysPerYear Then
		// If the business calendar is selected but filled incorrectly, it will not be filled on a weekly basis
		Return DaysIncludedInSchedule;
	EndIf;
	
	BusinessCalendarData.Indexes.Add("Date");
	
	DayLength = 24 * 3600;
	
	DayDate = StartDate;
	While DayDate <= EndDate Do
		
		Holiday = False;
		If Not FillInAccordingToBusinessCalendar Then
			DayNumber = WeekDay(DayDate);
		Else
			DayData = BusinessCalendarData.FindRows(New Structure("Date", DayDate))[0];
			If DayData.DayKind = Enums.BusinessCalendarDayKinds.Saturday Then
				DayNumber = 6;
			ElsIf DayData.DayKind = Enums.BusinessCalendarDayKinds.Sunday Then
				DayNumber = 7;
			Else
				DayNumber = WeekDay(?(ValueIsFilled(DayData.ReplacementDate), DayData.ReplacementDate, DayData.Date));
			EndIf;
			Holiday = ConsiderHolidays And DayData.DayKind = Enums.BusinessCalendarDayKinds.Holiday;
		EndIf;
		
		DayRow = FillingTemplate[DayNumber - 1];
		If DayRow.DayAddedToSchedule And Not Holiday Then
			DaysIncludedInSchedule.Insert(DayDate, True);
		EndIf;
		
		DayDate = DayDate + DayLength;
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Function DaysIncludedInScheduleArbitraryLength(Year, BusinessCalendar, FillingTemplate, ConsiderHolidays, PeriodStartDate, WorkSchedule = Undefined, Val StartDate = Undefined, Val EndDate = Undefined)
	
	DaysIncludedInSchedule = New Map;
	
	DayLength = 24 * 3600;
	
	DayDate = PeriodStartDate;
	While DayDate <= EndDate Do
		For Each DayRow In FillingTemplate Do
			If DayRow.DayAddedToSchedule 
				And DayDate >= StartDate Then
				DaysIncludedInSchedule.Insert(DayDate, True);
			EndIf;
			DayDate = DayDate + DayLength;
		EndDo;
	EndDo;
	
	If Not ConsiderHolidays Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	// Exclude holidays
	
	BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, Year);
	If BusinessCalendarData.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	PublicHolidaysData = BusinessCalendarData.FindRows(New Structure("DayKind", Enums.BusinessCalendarDayKinds.Holiday));
	
	For Each DayData In PublicHolidaysData Do
		DaysIncludedInSchedule.Delete(DayData.Date);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Procedure AdjustStartDatesEndDates(Year, StartDate, EndDate)
	
	BegOfYear = Date(Year, 1, 1);
	EndOfYear = Date(Year, 12, 31);
	
	If StartDate <> Undefined Then
		StartDate = Max(StartDate, BegOfYear);
	Else
		StartDate = BegOfYear;
	EndIf;
	
	If EndDate <> Undefined Then
		EndDate = Min(EndDate, EndOfYear);
	Else
		EndDate = EndOfYear;
	EndIf;
	
EndProcedure

// Defines the dates of the specified schedule manual changes
//
Function ScheduleManualChanges(WorkSchedule)
	
	Query = New Query(
	"SELECT
	|	ManualChanges.WorkSchedule,
	|	ManualChanges.Year,
	|	ManualChanges.ScheduleDate,
	|	ISNULL(CalendarSchedules.DayAddedToSchedule, FALSE) AS DayAddedToSchedule
	|FROM
	|	InformationRegister.ManualWorkScheduleChanges AS ManualChanges
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|		ON (CalendarSchedules.Calendar = ManualChanges.WorkSchedule)
	|			AND (CalendarSchedules.Year = ManualChanges.Year)
	|			AND (CalendarSchedules.ScheduleDate = ManualChanges.ScheduleDate)
	|WHERE
	|	ManualChanges.WorkSchedule = &WorkSchedule
	|	AND ManualChanges.ScheduleDate <> DATETIME(1, 1, 1)");

	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	ManualChanges = New Map;
	While Selection.Next() Do
		ManualChanges.Insert(Selection.ScheduleDate, Selection.DayAddedToSchedule);
	EndDo;
	
	Return ManualChanges;
	
EndFunction

#EndRegion

#EndIf