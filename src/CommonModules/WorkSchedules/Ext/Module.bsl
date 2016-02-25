////////////////////////////////////////////////////////////////////////////////
// Work schedules subsystem
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the array of dates where the difference between each array element and the 
// specified date is equal to the number of schedule days
//
// Parameters
// WorkSchedule                  - the schedule that should be used, the CatologRef.Calendars 
//                                 type
// DateFrom                      - the date that is used as a start point to calculate
//                                 the number of days, the Date type
// DayArray                      - the day array where each element is a number of days 
//                                 to be added to the start date, the Array type, Number
// CalculateNextDateFromPrevious - Boolean – if True, each date is calculated based on the 
//                                 previous date. If False, each date is calculated based on 
//                                 the start date
//  RaiseException               - Boolean - if True, raise an exception if the schedule is 
//                                 not filled
//
// Returns:
// Array		- the array of dates advanced by the number of schedule days 
// If the specified schedule is not filled and RaiseException = False, returns Undefined
//
Function DatesBySchedule(Val WorkSchedule, Val DateFrom, Val DayArray, Val CalculateFollowingDateFromPrevious = False, RaiseException = True) Export
	
	TempTablesManager = New TempTablesManager;
	
	CalendarSchedules.CreateDayIncrementTT(TempTablesManager, DayArray, CalculateFollowingDateFromPrevious);
	
	// The algorithm works as follows:
	// Get the number of days included in the schedule for the start date
	// For all the following years get the offset of day number as a sum 
	// of day number of the previous years
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	CalendarSchedules.Year,
	|	MAX(CalendarSchedules.DayNumberInScheduleFromYearBeginning) AS DaysInSchedule
	|INTO DayNumberInScheduleByYearTT
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.ScheduleDate >= &DateFrom
	|	AND CalendarSchedules.Calendar = &WorkSchedule
	|	AND CalendarSchedules.DayAddedToSchedule
	|
	|GROUP BY
	|	CalendarSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DayNumberInScheduleByYear.Year,
	|	SUM(ISNULL(PreviousYearsDayNumber.DaysInSchedule, 0)) AS DaysInSchedule
	|INTO DayNumberConsiderPreviousYearsTT
	|FROM
	|	DayNumberInScheduleByYearTT AS DayNumberInScheduleByYear
	|		LEFT JOIN DayNumberInScheduleByYearTT AS PreviousYearsDayNumber
	|		ON (PreviousYearsDayNumber.Year < DayNumberInScheduleByYear.Year)
	|
	|GROUP BY
	|	DayNumberInScheduleByYear.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(CalendarSchedules.DayNumberInScheduleFromYearBeginning) AS DayNumberInScheduleFromYearBeginning
	|INTO DayNumberInScheduleForStartDateTT
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.ScheduleDate >= &DateFrom
	|	AND CalendarSchedules.Year = YEAR(&DateFrom)
	|	AND CalendarSchedules.Calendar = &WorkSchedule
	|	AND CalendarSchedules.DayAddedToSchedule
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DayIncrement.LineIndex,
	|	ISNULL(CalendarSchedules.ScheduleDate, UNDEFINED) AS DateByCalendar
	|FROM
	|	DayIncrementTT AS DayIncrement
	|		INNER JOIN DayNumberInScheduleForStartDateTT AS DayNumberInScheduleForStartDate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|			INNER JOIN DayNumberConsiderPreviousYearsTT AS DayNumberConsiderPreviousYears
	|			ON (DayNumberConsiderPreviousYears.Year = CalendarSchedules.Year)
	|		ON (CalendarSchedules.DayNumberInScheduleFromYearBeginning = DayNumberInScheduleForStartDate.DayNumberInScheduleFromYearBeginning - DayNumberConsiderPreviousYears.DaysInSchedule + DayIncrement.DayNumber)
	|			AND (CalendarSchedules.ScheduleDate >= &DateFrom)
	|			AND (CalendarSchedules.Calendar = &WorkSchedule)
	|			AND (CalendarSchedules.DayAddedToSchedule)
	|
	|ORDER BY
	|	DayIncrement.LineIndex";
	
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	DateArray = New Array;
	
	While Selection.Next() Do
		If Selection.DateByCalendar = Undefined Then
			ErrorMessage = NStr("en = 'The %1 work schedule is not filled in since %2 date for a specified number of workdays.'");
			If RaiseException Then
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					ErrorMessage,
					WorkSchedule, Format(DateFrom, "DLF=D"));
			Else
				Return Undefined;
			EndIf;
		EndIf;
		
		DateArray.Add(Selection.DateByCalendar);
	EndDo;
	
	Return DateArray;
	
EndFunction

// Returns the array of dates where the difference between each array element and the 
// specified date is equal to the number of schedule days
//
// Parameters
// WorkSchedule   - the schedule that should be used, the CatologRef.Calendars type
// DateFrom       - the date that is used as a start point for calculating the array of dates, 
//                  the Date type
// DayNumber      - the number of days to be added to the start date, the Number type
// RaiseException - Boolean - if True, raise an exception if the schedule is not filled.
//
// Returns:
// Date			- the date that is increased on included in schedule day number. 
// If the specified schedule is not filled and RaiseException = False, returns Undefined.
//
Function DateAccordingToSchedule(Val WorkSchedule, Val DateFrom, Val DayNumber, RaiseException = True) Export
	
	DateFrom = BegOfDay(DateFrom);
	
	If DayNumber = 0 Then
		Return DateFrom;
	EndIf;
	
	DayArray = New Array;
	DayArray.Add(DayNumber);
	
	DateArray = DatesBySchedule(WorkSchedule, DateFrom, DayArray, , RaiseException);
	
	Return ?(DateArray <> Undefined, DateArray[0], Undefined);
	
EndFunction

// Generates work schedules for schedule dates within the specified period.
// If the schedule for the day before holiday is not set, it is determined as if it is a workday.
//
// Parameters
// Schedules - the array of CatalogRef.Calendars
// StartDate - the beginning date of the period for which a schedule is required.
// EndDate   - the period end date.
//
// Returns - value table with the following columns:
// WorkSchedule
// ScheduleDate
// BeginTime
// EndTime
//
Function WorkSchedulesForPeriod(Schedules, StartDate, EndDate) Export
	
	TempTablesManager = New TempTablesManager;
	
	// Create a temporary schedule table
	CreateWorkSchedulesForPeriodTT(TempTablesManager, Schedules, StartDate, EndDate);
	
	QueryText = 
	"SELECT
	|	WorkSchedules.WorkSchedule,
	|	WorkSchedules.ScheduleDate,
	|	WorkSchedules.BeginTime,
	|	WorkSchedules.EndTime
	|FROM
	|	WorkScheduleTT AS WorkSchedules";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

// Creates the WorkScheduleTT temporary table in the manager
// For more information, see WorkSchedulesForPeriod function description
//
Procedure CreateWorkSchedulesForPeriodTT(TempTablesManager, Schedules, StartDate, EndDate) Export
	
	QueryText = 
	"SELECT
	|	FillingTemplate.Ref AS WorkSchedule,
	|	MAX(FillingTemplate.LineNumber) AS PeriodLength
	|INTO SchedulePeriodLengthTT
	|FROM
	|	Catalog.Calendars.FillingTemplate AS FillingTemplate
	|WHERE
	|	FillingTemplate.Ref IN(&Calendars)
	|
	|GROUP BY
	|	FillingTemplate.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkSchedule,
	|	BusinessCalendarData.Date AS ScheduleDate,
	|	BusinessCalendarData.ReplacementDate,
	|	CASE
	|		WHEN BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDayKinds.Preholiday)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS PreholidayDay
	|INTO CalendarDataTT
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON BusinessCalendarData.BusinessCalendar = Calendars.BusinessCalendar
	|			AND (Calendars.Ref IN (&Calendars))
	|			AND (BusinessCalendarData.Date BETWEEN &StartDate AND &EndDate)
	|			AND (BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDayKinds.Preholiday)
	|				OR BusinessCalendarData.ReplacementDate <> DATETIME(1, 1, 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Calendar AS WorkSchedule,
	|	CalendarSchedules.ScheduleDate AS ScheduleDate,
	|	DATEDIFF(Calendars.PeriodStartDate, CalendarSchedules.ScheduleDate, DAY) + 1 AS DaysFromPeriodStartDate,
	|	CalendarData.PreholidayDay,
	|	CalendarData.ReplacementDate
	|INTO DaysIncludedInScheduleTT
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON CalendarSchedules.Calendar = Calendars.Ref
	|			AND (CalendarSchedules.Calendar IN (&Calendars))
	|			AND (CalendarSchedules.ScheduleDate BETWEEN &StartDate AND &EndDate)
	|			AND (CalendarSchedules.DayAddedToSchedule)
	|		LEFT JOIN CalendarDataTT AS CalendarData
	|		ON (CalendarData.WorkSchedule = CalendarSchedules.Calendar)
	|			AND (CalendarData.ScheduleDate = CalendarSchedules.ScheduleDate)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.ModuloOperationResult = 0
	|			THEN DaysIncludedInSchedule.PeriodLength
	|		ELSE DaysIncludedInSchedule.ModuloOperationResult
	|	END AS DayNumber,
	|	DaysIncludedInSchedule.PreholidayDay
	|INTO DatesDayNumbersTT
	|FROM
	|	(SELECT
	|		DaysIncludedInSchedule.WorkSchedule AS WorkSchedule,
	|		DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|		DaysIncludedInSchedule.PreholidayDay AS PreholidayDay,
	|		DaysIncludedInSchedule.PeriodLength AS PeriodLength,
	|		DaysIncludedInSchedule.DaysFromPeriodStartDate - DaysIncludedInSchedule.DivisionOutputIntegerPart * DaysIncludedInSchedule.PeriodLength AS ModuloOperationResult
	|	FROM
	|		(SELECT
	|			DaysIncludedInSchedule.WorkSchedule AS WorkSchedule,
	|			DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|			DaysIncludedInSchedule.PreholidayDay AS PreholidayDay,
	|			DaysIncludedInSchedule.DaysFromPeriodStartDate AS DaysFromPeriodStartDate,
	|			PeriodsLength.PeriodLength AS PeriodLength,
	|			(CAST(DaysIncludedInSchedule.DaysFromPeriodStartDate / PeriodsLength.PeriodLength AS NUMBER(15, 0))) - CASE
	|				WHEN (CAST(DaysIncludedInSchedule.DaysFromPeriodStartDate / PeriodsLength.PeriodLength AS NUMBER(15, 0))) > DaysIncludedInSchedule.DaysFromPeriodStartDate / PeriodsLength.PeriodLength
	|					THEN 1
	|				ELSE 0
	|			END AS DivisionOutputIntegerPart
	|		FROM
	|			DaysIncludedInScheduleTT AS DaysIncludedInSchedule
	|				INNER JOIN Catalog.Calendars AS Calendars
	|				ON DaysIncludedInSchedule.WorkSchedule = Calendars.Ref
	|					AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods))
	|				INNER JOIN SchedulePeriodLengthTT AS PeriodsLength
	|				ON DaysIncludedInSchedule.WorkSchedule = PeriodsLength.WorkSchedule) AS DaysIncludedInSchedule) AS DaysIncludedInSchedule
	|
	|UNION ALL
	|
	|SELECT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.ReplacementDate IS NULL 
	|			THEN WEEKDAY(DaysIncludedInSchedule.ScheduleDate)
	|		ELSE WEEKDAY(DaysIncludedInSchedule.ReplacementDate)
	|	END,
	|	DaysIncludedInSchedule.PreholidayDay
	|FROM
	|	DaysIncludedInScheduleTT AS DaysIncludedInSchedule
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON DaysIncludedInSchedule.WorkSchedule = Calendars.Ref
	|WHERE
	|	Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	DaysIncludedInSchedule.DayNumber,
	|	ISNULL(PreholidayWorkSchedules.BeginTime, WorkSchedules.BeginTime) AS BeginTime,
	|	ISNULL(PreholidayWorkSchedules.EndTime, WorkSchedules.EndTime) AS EndTime
	|INTO WorkScheduleTT
	|FROM
	|	DatesDayNumbersTT AS DaysIncludedInSchedule
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS WorkSchedules
	|		ON (WorkSchedules.Ref = DaysIncludedInSchedule.WorkSchedule)
	|			AND (WorkSchedules.DayNumber = DaysIncludedInSchedule.DayNumber)
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS PreholidayWorkSchedules
	|		ON (PreholidayWorkSchedules.Ref = DaysIncludedInSchedule.WorkSchedule)
	|			AND (PreholidayWorkSchedules.DayNumber = 0)
	|			AND (DaysIncludedInSchedule.PreholidayDay)
	|
	|INDEX BY
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate";
	
	// To calculate a number in the arbitrary length period for a day included in the 
	// schedule, use the following formula:
	// Day number = Days from start date % Period length where % - modulo operation.
	
	// Modulo operation is based on the formula:
	// Dividend - Int(Dividend / Divisor) * Divisor, where Int() - integer part extraction
	//                                               function
	
	// To extract the integer part use the structure:
	// if the result of a number rounding to the nearest integer is larger than the 
	// original value, reduce it by 1
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("Calendars", Schedules);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.Execute();
	
EndProcedure

#EndRegion

#Region InternalInterface

// Uses business calendar data to update work schedules 
//
// Parameters:
// - UpdateConditions     - value table with the following columns: 
//      - BusinessCalendarCode - business calendar code.
//      - Year                 - data update enforcement year.
//
Procedure UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions) Export
	
	Catalogs.Calendars.UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions);
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"
	].Add("WorkSchedules");
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnGetMandatoryExchangePlanObjects"
	].Add("WorkSchedules");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// The procedure is used when getting metadata objects that are mandatory for the exchange plan.
// If the subsystem includes metadata objects that must be included in the exchange plan 
// content, add these metadata objects to the Objects parameter.
//
// Parameters:
// Objects                         - Array. Array of configuration metadata objects to be 
//                                   included in the exchange plan content.
// DistributedInfobase (read only) - Boolean. Flag that shows whether DIB exchange plan 
//                                   objects are retrieved.
// True                            - list of DIB exchange plan objects is retrieved.
// False                           - list of non-DIB exchange plan objects is retrieved.
//
Procedure OnGetMandatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Catalogs.Calendars);
		Objects.Add(Metadata.InformationRegisters.CalendarSchedules);
		
	EndIf;
	
EndProcedure

// Creates the temporary table CalendarSchedulesTT that contains the WorkSchedule data 
// for the years listed in the DifferentScheduleYearsTT
//
// Parameters
// - TempTablesManager - should contain DifferentScheduleYearsTT with the Year 
//                       field, the Number type (4, 0),
// - WorkSchedule      - the schedule that should be used, the CatologRef.Calendars type
//
Procedure CreateScheduleDataTT(TempTablesManager, WorkSchedule) Export
	
	QueryText = 
	"SELECT
	|	CalendarSchedules.Year,
	|	CalendarSchedules.ScheduleDate,
	|	CalendarSchedules.DayAddedToSchedule
	|INTO CalendarSchedulesTT
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN DifferentScheduleYearsTT AS ScheduleYears
	|		ON (ScheduleYears.Year = CalendarSchedules.Year)
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("WorkSchedule", WorkSchedule);
	Query.Execute();
	
EndProcedure

// Generates a query text template embedded in the CalendarSchedules.GetWorkdayDates method
//
Function NextDatesAccordingToWorkScheduleDefinitionQueryTextTemplate() Export
	
	Return
	"SELECT
	|	InitialDates.Date,
	|	%Function%(CalendarDates.ScheduleDate) AS NearestDate
	|FROM
	|	InitialDates AS InitialDates
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarDates
	|		ON (CalendarDates.ScheduleDate %ConditionSign% InitialDates.Date)
	|			AND (CalendarDates.Calendar = &Line)
	|			AND (CalendarDates.DayAddedToSchedule)
	|
	|GROUP BY
	|	InitialDates.Date";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Infobase update

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of the NewUpdateHandlerTable function 
//                          in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "WorkSchedules.CreateUSAFiveDayCalendar";
	//PARTIALLY_DELETED
	//Handler = Handlers.Add();
	//Handler.Version = "2.1.3.1";
	//Handler.Procedure = "WorkSchedules.FillWorkSchedulesFillingSettings";
	//
	//Handler = Handlers.Add();
	//Handler.Version = "2.2.2.14";
	//Handler.Procedure = "WorkSchedules.FillDayNumberInScheduleFromYearBeginning";
	
EndProcedure

// The procedure creates a work schedule on the basis of the USA business calendar 
// according to a five-day week template
//
Procedure CreateUSAFiveDayCalendar() Export
	
	BusinessCalendar = CalendarSchedules.USABusinessCalendar();
	If BusinessCalendar = Undefined Then 
		Return;
	EndIf;
	
	If Not Catalogs.Calendars.FindByAttribute("BusinessCalendar", BusinessCalendar).IsEmpty() Then
		Return;
	EndIf;
	
	NewWorkSchedule = Catalogs.Calendars.CreateItem();
	NewWorkSchedule.Description = CommonUse.ObjectAttributeValue(BusinessCalendar, "Description");
	NewWorkSchedule.BusinessCalendar = BusinessCalendar;
	NewWorkSchedule.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	NewWorkSchedule.StartDate = BegOfYear(CurrentSessionDate());
	NewWorkSchedule.ConsiderHolidays = True;
	
	// Fill in a week period as a five-day week
	For DayNumber = 1 To 7 Do
		NewWorkSchedule.FillingTemplate.Add().DayAddedToSchedule = DayNumber <= 5;
	EndDo;
	
	InfobaseUpdate.WriteData(NewWorkSchedule, True, True);
	
EndProcedure

// Fills in the business calendar for the work schedules that were not created 
// according to the template or were created prior to business calendars
//
Procedure FillWorkSchedulesFillingSettings() Export
	
	BusinessCalendarUSA = CalendarSchedules.USABusinessCalendar();
	
	If BusinessCalendarUSA = Undefined Then
		// If for some reason there is no business calendar by default,
   // it is impossible to fill in the settings
		Return;
	EndIf;
	
	QueryText = 
	"SELECT
	|	Calendars.Ref,
	|	Calendars.DeleteCalendarType AS CalendarType,
	|	Calendars.BusinessCalendar
	|FROM
	|	Catalog.Calendars AS Calendars
	|WHERE
	|	Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.EmptyRef)";
	
	Query = New Query(QueryText);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		WorkScheduleObject = Selection.Ref.GetObject();
		If Not ValueIsFilled(Selection.BusinessCalendar) Then
			// Set up the USA calendar
			WorkScheduleObject.BusinessCalendar = BusinessCalendarUSA;
		EndIf;
		WorkScheduleObject.StartDate = Date(2012, 1, 1);
		If Not ValueIsFilled(Selection.CalendarType) Then
			// If the calendar type was not specified, it is not possibile to write the exact filling settings
			WorkScheduleObject.FillingMethod = Enums.WorkScheduleFillingMethods.ByArbitraryLengthPeriods;
			WorkScheduleObject.PeriodStartDate = Date(2012, 1, 1);
		Else
			Raise("CHECK ON TEST");
			// For a five-day or a six-day week filling the corresponding settings
			WorkScheduleObject.ConsiderHolidays = True;
			WorkScheduleObject.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
			WorkdayCount = 5;
			//If Selection.CalendarType = Enums.DELETE.SixDays Then
				//WorkdayCount = 6;
			//EndIf;
			WorkScheduleObject.FillingTemplate.Clear();
			For DayNumber = 1 To 7 Do
				NewRow = WorkScheduleObject.FillingTemplate.Add();
				NewRow.DayAddedToSchedule = DayNumber <= WorkdayCount;
			EndDo;
		EndIf;
		InfobaseUpdate.WriteData(WorkScheduleObject);
	EndDo;
	
EndProcedure

// Fills in with secondary data to optimize calendrical calculations
//
Procedure FillDayNumberInScheduleFromYearBeginning() Export
	
	QueryText = 
	"SELECT DISTINCT
	|	BusinessCalendarData.Date,
	|	BusinessCalendarData.Year
	|INTO DatesTT
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Dates.Year,
	|	COUNT(Dates.Date) AS DayNumber
	|INTO DayNumberByYearsTT
	|FROM
	|	DatesTT AS Dates
	|
	|GROUP BY
	|	Dates.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Calendar,
	|	CalendarSchedules.Year,
	|	COUNT(CalendarSchedules.ScheduleDate) AS DayNumber
	|INTO DayNumberInScheduleTT
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|
	|GROUP BY
	|	CalendarSchedules.Calendar,
	|	CalendarSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DayNumberInSchedule.Calendar,
	|	DayNumberInSchedule.Year
	|INTO SchedulesYearsTT
	|FROM
	|	DayNumberInScheduleTT AS DayNumberInSchedule
	|		INNER JOIN DayNumberByYearsTT AS DayNumberByYears
	|		ON DayNumberInSchedule.Year = DayNumberByYears.Year
	|			AND DayNumberInSchedule.DayNumber < DayNumberByYears.DayNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SchedulesYears.Calendar AS Calendar,
	|	SchedulesYears.Year AS Year,
	|	Dates.Date AS ScheduleDate,
	|	ISNULL(CalendarSchedules.DayAddedToSchedule, FALSE) AS DayAddedToSchedule
	|FROM
	|	SchedulesYearsTT AS SchedulesYears
	|		INNER JOIN DatesTT AS Dates
	|		ON SchedulesYears.Year = Dates.Year
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|		ON (CalendarSchedules.Calendar = SchedulesYears.Calendar)
	|			AND (CalendarSchedules.Year = SchedulesYears.Year)
	|			AND (CalendarSchedules.ScheduleDate = Dates.Date)
	|
	|ORDER BY
	|	SchedulesYears.Calendar,
	|	SchedulesYears.Year,
	|	Dates.Date
	|TOTALS BY
	|	Calendar,
	|	Year";
	
	// Choose work schedules and years for which the DayNumberInScheduleSinceYearBeginning
	// resource value is not filled, fill them in computing the day number
	
	Query = New Query(QueryText);
	SelectionBySchedule = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionBySchedule.Next() Do
		SelectionByYears = SelectionBySchedule.Select(QueryResultIteration.ByGroups);
		While SelectionByYears.Next() Do
			RecordSet = InformationRegisters.CalendarSchedules.CreateRecordSet();
			DayNumberInScheduleFromYearBeginning = 0;
			Selection = SelectionByYears.Select();
			While Selection.Next() Do
				If Selection.DayAddedToSchedule Then
					DayNumberInScheduleFromYearBeginning = DayNumberInScheduleFromYearBeginning + 1;
				EndIf;
				SetRow = RecordSet.Add();
				FillPropertyValues(SetRow, Selection);
				SetRow.DayNumberInScheduleFromYearBeginning = DayNumberInScheduleFromYearBeginning;
			EndDo;
			RecordSet.Filter.Calendar.Set(SelectionByYears.Calendar);
			RecordSet.Filter.Year.Set(SelectionByYears.Year);
			InfobaseUpdate.WriteData(RecordSet);
		EndDo;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Handlers of conditional calls of other subsystems

// The procedure updates work schedules according to the data of business calendars
// on all areas of data
//
Procedure ScheduleWorkScheduleUpdate(Val UpdateConditions) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.CalendarSchedulesSaaS") Then
		CalendarSchedulesInternalSaaSModule = CommonUse.CommonModule("CalendarSchedulesInternalSaaS");
		CalendarSchedulesInternalSaaSModule.ScheduleWorkScheduleUpdate(UpdateConditions);
	EndIf;
	
EndProcedure

#EndRegion