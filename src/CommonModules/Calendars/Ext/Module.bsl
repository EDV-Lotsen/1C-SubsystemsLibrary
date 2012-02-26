
////////////////////////////////////////////////////////////////////////////////
// LIBRARY FUNCTIONS

// Function returns array of dates, which differ from the date specified for a number of days,
// being a part of specified schedule
//
// Parameters:
//	Calendar		- calendar, that should be used, type CatalogRef.Calendars
//	StartDate			- date, number of days should be calculated starting from this date, type Date
//	DaysArray		- array with number of days, for which start date should be incremented, type Array,Number
//	CalculateNextStartDatePrevious	- if next date should be calculated based on previous date or
//											  all dates are being calculated based on the passed date
//
// Value to return:
//	Array		- array of dates, incremented by number of days, being a part of schedule
//
Function GetDatesArrayByCalendar(Val Calendar, Val StartDate, Val DaysArray, Val CalculateNextStartDatePrevious = False) Export
	
	StartDate = BegOfDay(StartDate);
	
	DatesTable = New ValueTable;
	DatesTable.Columns.Add("RowIndex", New TypeDescription("Number"));
	DatesTable.Columns.Add("DaysCount", New TypeDescription("Number"));
	
	DaysCount = 0;
	LineNumber = 0;
	For Each StringDays In DaysArray Do
		DaysCount = DaysCount + StringDays;
		
		String = DatesTable.Add();
		String.RowIndex			= LineNumber;
		If CalculateNextStartDatePrevious Then
			String.DaysCount	= DaysCount;
		Else
			String.DaysCount	= StringDays;
		EndIf;
			
		LineNumber = LineNumber + 1;
	EndDo;
	
	Query = New Query;
	
	Query.SetParameter("Calendar", Calendar);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("Table",	DatesTable);
		
	// This algorithm works in the following way:
	// Calculate the days count from the beginning of the year till StartDate,
	// adding to this value the days count given as count of days to be added
	// to the start date. Checking if the received day is bigger than the numberEndDate till EndDate. If the start date and end date are in the same
	// of days in the current year working with the next year.
	// Searching for the earliest date which corresponds the required day of the
	// year.
	
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT
	|	DatesTable.RowIndex,
	|	DatesTable.DaysCount
	|INTO TT_DatesTable
	|FROM
	|	&Table AS DatesTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(ScheduleForYear.DaysCountInScheduleSinceTheBeginningOfTheYear) AS DaysCountTotal
	|INTO TT_QuantityOfWorkingDaysInYear
	|FROM
	|	InformationRegister.CalendarData AS ScheduleForYear
	|WHERE
	|	ScheduleForYear.Calendar = &Calendar
	|	AND ScheduleForYear.Year = YEAR(&StartDate)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ScheduleForYear.Year,
	|	ScheduleForYear.DaysCountInScheduleSinceTheBeginningOfTheYear AS DaysCountInScheduleSinceTheBeginningOfTheYear,
	|	NumberOfWorkingDaysInYear.DaysCountTotal
	|INTO TT_CalendarSchedule
	|FROM
	|	InformationRegister.CalendarData AS ScheduleForYear
	|		INNER JOIN TT_QuantityOfWorkingDaysInYear AS NumberOfWorkingDaysInYear
	|		ON (ScheduleForYear.Calendar = &Calendar)
	|			AND (ScheduleForYear.ScheduleDate = &StartDate)
	|
	|INDEX BY
	|	DaysCountInScheduleSinceTheBeginningOfTheYear
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedule.RowIndex,
	|	CalendarSchedule.DaysCount,
	|	ISNULL(CalendarSchedule.DateInCalendar, UNDEFINED) AS DateInCalendar
	|FROM
	|	(SELECT
	|		ScheduleForYearStartDate.RowIndex AS RowIndex,
	|		ScheduleForYearStartDate.DaysCount AS DaysCount,
	|		MIN(ScheduleForYear.ScheduleDate) AS DateInCalendar
	|	FROM
	|		(SELECT
	|			DatesTable.RowIndex AS RowIndex,
	|			DatesTable.DaysCount AS DaysCount,
	|			CASE
	|				WHEN CalendarSchedule.DaysCountTotal IS NULL 
	|						OR CalendarSchedule.DaysCountTotal >= CalendarSchedule.DaysCountInScheduleSinceTheBeginningOfTheYear + DatesTable.DaysCount
	|					THEN YEAR(&StartDate)
	|				ELSE YEAR(&StartDate) + 1
	|			END AS EndDateYear,
	|			CalendarSchedule.DaysCountInScheduleSinceTheBeginningOfTheYear + DatesTable.DaysCount - CASE
	|				WHEN CalendarSchedule.DaysCountTotal < CalendarSchedule.DaysCountInScheduleSinceTheBeginningOfTheYear + DatesTable.DaysCount
	|					THEN CalendarSchedule.DaysCountTotal
	|				ELSE 0
	|			END AS DaysCountForDateTo
	|		FROM
	|			TT_DatesTable AS DatesTable
	|				LEFT JOIN TT_CalendarSchedule AS CalendarSchedule
	|				ON (TRUE)) AS ScheduleForYearStartDate
	|			LEFT JOIN InformationRegister.CalendarData AS ScheduleForYear
	|			ON (ScheduleForYear.Calendar = &Calendar)
	|				AND ScheduleForYearStartDate.DaysCountForDateTo = ScheduleForYear.DaysCountInScheduleSinceTheBeginningOfTheYear
	|				AND ScheduleForYearStartDate.EndDateYear = ScheduleForYear.Year
	|	
	|	GROUP BY
	|		ScheduleForYearStartDate.RowIndex,
	|		ScheduleForYearStartDate.DaysCount) AS CalendarSchedule
	|
	|ORDER BY
	|	CalendarSchedule.RowIndex";
	Selection = Query.Execute().Choose();
	
	DatesArray = New Array;
	
	While Selection.Next() Do
		If Selection.DateInCalendar = Undefined Then
			ErrorMessage = NStr("en = '''%1'' calendar does not have specified number of working days starting from %2!'");
			Raise StringFunctionsClientServer.SubstitureParametersInString(
				ErrorMessage,
				Calendar, Format(StartDate, "DLF=D"));
		EndIf;
		
		DatesArray.Add(Selection.DateInCalendar);
	EndDo;
	
	Return DatesArray;
	
EndFunction

// Function returns date, which differ from the specified date for a number days,
// being a part of specified schedule
//
// Parameters
//	Calendar		- calendar, that should be used, type CatalogRef.Calendars
//	StartDate			- date, number of days should be calculated starting from this date, type Date
//	DaysCount	- number of days, to be added to start date, type Number
//
// Value to return
//	Date			- date, incremented for a number of days, being a part of schedule
//
Function GetDateByCalendar(Val Calendar, Val StartDate, Val DaysCount) Export
	
	StartDate = BegOfDay(StartDate);
	
	If DaysCount = 0 Then
		Return StartDate;
	EndIf;
	
	DaysArray = New Array;
	DaysArray.Add(DaysCount);
	
	DatesArray = GetDatesArrayByCalendar(Calendar, StartDate, DaysArray);
	
	Return DatesArray[0];
	
EndFunction

// Function determines number of days, being a part of calendar, for specified period
//
// Parameters:
//	Calendar	- calendar, that should be used, type CatalogRef.Calendars
//	StartDate	- period start date
//	EndDate		- period end date
//
// Value to return:
//	Array		- array of dates, incremented by number of days, being a part of schedule
//
Function GetDatesDifferenceByCalendar(Val Calendar, Val StartDate, Val EndDate) Export
	
	StartDate	= BegOfDay(StartDate);
	EndDate		= BegOfDay(EndDate);
	
	If StartDate = EndDate Then
		Return 0;
	EndIf;
	
	DifferentYears = Year(StartDate) <> Year(EndDate);
	
	Query = New Query;
	
	StartDatesArray = New Array;
	StartDatesArray.Add(StartDate);
	If DifferentYears Then
		StartDatesArray.Add(BegOfDay(EndOfYear(StartDate)));
	EndIf;
	
	Query.SetParameter("Calendar",			Calendar);
	Query.SetParameter("StartDatesArray",	StartDatesArray);
	Query.SetParameter("StartDateYear",		Year(StartDate));
	
	Query.SetParameter("EndDate",			EndDate);
	Query.SetParameter("EndDateYear",   	Year(EndDate));
	
	Query.Text = "SELECT
	             |	Calendars.DaysCountInScheduleSinceTheBeginningOfTheYear AS DaysCount,
	             |	Calendars.ScheduleDate AS ScheduleDate
	             |FROM
	             |	InformationRegister.CalendarData AS Calendars
	             |WHERE
	             |	Calendars.Calendar = &Calendar
	             |	AND (Calendars.Year = &StartDateYear
	             |				AND Calendars.ScheduleDate IN (&StartDatesArray)
	             |			OR Calendars.Year = &EndDateYear
	             |				AND Calendars.ScheduleDate = &EndDate)
	             |
	             |ORDER BY
	             |	ScheduleDate";
	TableOfDays = Query.Execute().Unload();
	
	If TableOfDays.Count() < ?(DifferentYears, 3, 2) Then
		ErrorMessage = NStr("en = 'Calendar %1 is not filled for the %2 period.'");
		Raise StringFunctionsClientServer.SubstitureParametersInString(
			ErrorMessage,
			Calendar, PeriodPresentation(StartDate, EndOfDay(EndDate)));
	EndIf;
	
	DaysCountOfBeginDate = TableOfDays[0].DaysCount;
	DaysCountOfEndDate   = TableOfDays[?(DifferentYears, 2, 1)].DaysCount + ?(DifferentYears, TableOfDays[1].DaysCount, 0);
	
	Return DaysCountOfEndDate - DaysCountOfBeginDate;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// INFOBASE UPDATE

// Procedure creates calendar in the catalog Calendars, which corresponds to a regular
// calendar of the USA for year 2012, if there is no one calendar in the catalog
//
Procedure CreateRegularCalendarFor2012Year() Export
	
	Query = New Query;
	Query.Text = "SELECT TOP 1
	             |	Calendars.Ref
	             |FROM
	             |	Catalog.Calendars AS Calendars";
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		Return;
	EndIf;
	
	RegularCalendar = Catalogs.Calendars.CreateItem();
	RegularCalendar.Description = "USA Federal Calendar";
	RegularCalendar.Write();
	
	// Write data for a year 2012
	
	WorkDays = New Array;
	HolidayDays = New Array;
	
	// USA holidays
	//HolidayDays.Add(Date(2012, 1, 1));
	HolidayDays.Add(Date(2012, 1, 16));
	HolidayDays.Add(Date(2012, 2, 20));
	HolidayDays.Add(Date(2012, 5, 28));
	HolidayDays.Add(Date(2012, 7, 4));
	HolidayDays.Add(Date(2012, 9, 3));
	HolidayDays.Add(Date(2012, 10, 8));
	HolidayDays.Add(Date(2012, 11, 12));
	HolidayDays.Add(Date(2012, 11, 22));
	HolidayDays.Add(Date(2012, 12, 25));
	
	// Moving holidays from weekend days
	HolidayDays.Add(Date(2012, 1, 2));
	//WorkDays.Add(Date(2012, 2, 27));
	
	YearNumber = 2012;
	
	RecordSet = InformationRegisters.CalendarData.CreateRecordSet();
	RecordSet.Filter.Calendar.Set(RegularCalendar.Ref);
	RecordSet.Filter.Year.Set(YearNumber);
	
	QuantityWorkingDaysFromBegginingOfTheYear = 0;
	
	For MonthNumber = 1 To 12 Do
		For DayNumber = 1 To Day(EndOfMonth(Date(YearNumber, MonthNumber, 1))) Do
			ScheduleDate = Date(YearNumber, MonthNumber, DayNumber);
			
			DayIncludedInSchedule = HolidayDays.Find(ScheduleDate) = Undefined
				And (WorkDays.Find(ScheduleDate) <> Undefined OR Weekday(ScheduleDate) <= 5);
			
			If DayIncludedInSchedule Then
				QuantityWorkingDaysFromBegginingOfTheYear = QuantityWorkingDaysFromBegginingOfTheYear + 1;
			EndIf;
			
			Row = RecordSet.Add();
			Row.Calendar										 = RegularCalendar.Ref;
			Row.Year											 = YearNumber;
			Row.ScheduleDate									 = ScheduleDate;
			Row.DayIncludedInSchedule							 = DayIncludedInSchedule;
			Row.DaysCountInScheduleSinceTheBeginningOfTheYear = QuantityWorkingDaysFromBegginingOfTheYear;
		EndDo;
	EndDo;
	
	RecordSet.Write(True);
	
EndProcedure
