////////////////////////////////////////////////////////////////////////////////
// Calendar schedules subsystem.
// 
////////////////////////////////////////////////////////////////////////////////
#Region Interface
// Returns the array of dates where the difference between each array element and
// the specified date is equal to the number of schedule days.
//
// Parameters:
// WorkSchedule                  - CatalogRef.Calendars or CatalogRef.BusinessCalendars
//                               - work schedule or business calendar used in the algorithm. 
// DateFrom			                 - Date - date that is used as a start point for calculating the array of dates. 
// DayArray	                    - Array, Number - array where each element is a number of days to be added to the start date. 
// CalculateNextDateFromPrevious - Boolean – if True, each date is calculated based on the previous date. 
// 										                If False, each date is calculated based on the start date. 
// RaiseException                - Boolean - if True, raise an exception if the schedule is not filled.
//
// Returns:
// Array - array of dates advanced by the number of schedule days. 
// If the specified schedule is not filled and RaiseException = False, returns Undefined.
//
Function GetDateArrayByCalendar(Val WorkSchedule, Val DateFrom, Val DayArray, Val CalculateNextDateFromPrevious = False, RaiseException = True) Export
	
	If TypeOf(WorkSchedule) <> Type("CatalogRef.BusinessCalendars") Then
		If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
			Return WorkSchedulesModule.DatesBySchedule(
				WorkSchedule, DateFrom, DayArray, CalculateNextDateFromPrevious, RaiseException);
		EndIf;
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	CreateDayIncrementTT(TempTablesManager, DayArray, CalculateNextDateFromPrevious);
	
	// The algorithm works as follows:
	// Get all calendar days following the start date.
	// For each day calculate the number of schedule days since the start date.
	// Select the calculated number of days based on the day increment table.
	
	Query = New Query;
	
	Query.TablesManager = TempTablesManager;
	
	// Based on the business calendar
	Query.Text =
	"SELECT
	|	CalendarSchedules.Date AS ScheduleDate
	|INTO SubsequentScheduleDatesTT
	|FROM
	|	InformationRegister.BusinessCalendarData AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Date >= &DateFrom
	|	AND CalendarSchedules.BusinessCalendar = &WorkSchedule
	|	AND CalendarSchedules.DayKind IN (VALUE(Enum.BusinessCalendarDayKinds.Work), VALUE(Enum.BusinessCalendarDayKinds.Preholiday))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubsequentScheduleDates.ScheduleDate,
	|	COUNT(CalendarSchedules.ScheduleDate) - 1 AS NumberOfDaysInSchedule
	|INTO SubsequentScheduleDatesWithDayCountTT
	|FROM
	|	SubsequentScheduleDatesTT AS SubsequentScheduleDates
	|		INNER JOIN SubsequentScheduleDatesTT AS CalendarSchedules
	|		ON (CalendarSchedules.ScheduleDate <= SubsequentScheduleDates.ScheduleDate)
	|
	|GROUP BY
	|	SubsequentScheduleDates.ScheduleDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DayIncrement.LineIndex,
	|	ISNULL(SubsequentDays.ScheduleDate, UNDEFINED) AS DateByCalendar
	|FROM
	|	DayIncrementTT AS DayIncrement
	|		LEFT JOIN SubsequentScheduleDatesWithDayCountTT AS SubsequentDays
	|		ON DayIncrement.DayCount = SubsequentDays.NumberOfDaysInSchedule
	|
	|ORDER BY
	|	DayIncrement.LineIndex";
	
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	DateArray = New Array;
	
	While Selection.Next() Do
		If Selection.DateByCalendar = Undefined Then
			ErrorMessage = NStr("en = 'Business calendar ""%1"" is required for the period beginning from %2 and lasting the specified number of days.'");
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
// Returns the date that is different from the specified date by the number of
// days included in the specified schedule.
//
//Parameters:
// WorkSchedule   - CatalogRef.Calendars or CatalogRef.BusinessCalendars
//                - work schedule or business calendar used in the algorithm. 
// DateFrom			  - Date - date that is used as a start point. 
// DayCount       - Number – number of days to be added to the start date.
// RaiseException - Boolean - if True, raise an exception if the schedule is not filled.
//
// Returns:
// Date - date advanced by the number of schedule days.
// If the specified schedule is not filled and RaiseException = False, returns Undefined.
//
Function GetDateByCalendar(Val WorkSchedule, Val DateFrom, Val DayCount, RaiseException = True) Export
	
	DateFrom = BegOfDay(DateFrom);
	
	If DayCount = 0 Then
		Return DateFrom;
	EndIf;
	
	DayArray = New Array;
	DayArray.Add(DayCount);
	
	DateArray = GetDateArrayByCalendar(WorkSchedule, DateFrom, DayArray, , RaiseException);
	
	Return ?(DateArray <> Undefined, DateArray[0], Undefined);
	
EndFunction
// Gets the number of schedule days for the specified period.
//
// Parameters:
// WorkSchedule   - CatalogRef.Calendars or CatalogRef.BusinessCalendars
//                - work schedule or business calendar used in the algorithm.
// StartDate		    - start date of the period. 
// EndDate	       - end date of the period. 
// RaiseException - Boolean - if True, raise an exception if the schedule is not filled.
//
// Returns:
// Number - the number of days between the start and end dates.
// If the specified schedule is not filled and RaiseException = False, returns Undefined.
//
Function GetDateDiffByCalendar(Val WorkSchedule, Val StartDate, Val EndDate, RaiseException = True) Export
	
	StartDate = BegOfDay(StartDate);
	EndDate = BegOfDay(EndDate);
	
	ScheduleDates = New Array;
	ScheduleDates.Add(StartDate);
	If Year(StartDate) <> Year(EndDate) And EndOfDay(StartDate) <> EndOfYear(StartDate) Then
		// If the dates belong to different years, adding year "boundaries"
		For YearNumber = Year(StartDate) To Year(EndDate) - 1 Do
			ScheduleDates.Add(Date(YearNumber, 12, 31));
		EndDo;
	EndIf;
	ScheduleDates.Add(EndDate);
	
	// Generating the text of the query to the temporary table that contains the specified dates
	QueryText = "";
	For Each ScheduleDate In ScheduleDates Do
		If IsBlankString(QueryText) Then
			UnionTemplate = 
			"SELECT
			|	DATETIME(%1) AS ScheduleDate
			|INTO ScheduleDatesTT
			|";
		Else
			UnionTemplate = 
			"UNION ALL
			|
			|SELECT
			|	DATETIME(%1)";
		EndIf;
		QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersInString(
										UnionTemplate, Format(ScheduleDate, "DF='yyyy, MM, d'"));
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
	// Preparing source data temporary tables
	Query.Text =
	"SELECT DISTINCT
	|	ScheduleDates.ScheduleDate
	|INTO DifferentScheduleDatesTT
	|FROM
	|	ScheduleDatesTT AS ScheduleDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	YEAR(ScheduleDates.ScheduleDate) AS Year
	|INTO DifferentScheduleYearsTT
	|FROM
	|	ScheduleDatesTT AS ScheduleDates";
	
	Query.Execute();
	
	If TypeOf(WorkSchedule) = Type("CatalogRef.BusinessCalendars") Then
		// Based on the business calendar
		Query.Text = 
		"SELECT
		|	CalendarSchedules.Year,
		|	CalendarSchedules.Date AS ScheduleDate,
		|	CASE
		|		WHEN CalendarSchedules.DayKind IN (VALUE(Enum.BusinessCalendarDayKinds.Work), VALUE(Enum.BusinessCalendarDayKinds.Preholiday))
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS DayAddedToSchedule
		|INTO CalendarSchedulesTT
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarSchedules
		|		INNER JOIN DifferentScheduleYearsTT AS ScheduleYears
		|		ON (ScheduleYears.Year = CalendarSchedules.Year)
		|WHERE
		|	CalendarSchedules.BusinessCalendar = &WorkSchedule";
		Query.SetParameter("WorkSchedule", WorkSchedule);
		Query.Execute();
	Else
		// Based on the work schedule
		If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
			WorkSchedulesModule.CreateScheduleDataTT(TempTablesManager, WorkSchedule);
		EndIf;
	EndIf;
	
	Query.Text =
	"SELECT
	|	ScheduleDates.ScheduleDate,
	|	COUNT(DaysIncludedInSchedule.ScheduleDate) AS DayNumberInScheduleSinceYearBeginning
	|INTO NumberOfDaysInScheduleTT
	|FROM
	|	DifferentScheduleDatesTT AS ScheduleDates
	|		LEFT JOIN CalendarSchedulesTT AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (DaysIncludedInSchedule.ScheduleDate <= ScheduleDates.ScheduleDate)
	|			AND (DaysIncludedInSchedule.DayAddedToSchedule)
	|
	|GROUP BY
	|	ScheduleDates.ScheduleDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ScheduleDates.ScheduleDate,
	|	ISNULL(ScheduleData.DayAddedToSchedule, FALSE) AS DayAddedToSchedule,
	|	DaysIncludedInSchedule.DayNumberInScheduleSinceYearBeginning
	|FROM
	|	ScheduleDatesTT AS ScheduleDates
	|		LEFT JOIN CalendarSchedulesTT AS ScheduleData
	|		ON (ScheduleData.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (ScheduleData.ScheduleDate = ScheduleDates.ScheduleDate)
	|		LEFT JOIN NumberOfDaysInScheduleTT AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.ScheduleDate = ScheduleDates.ScheduleDate)
	|
	|ORDER BY
	|	ScheduleDates.ScheduleDate";
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		If RaiseException Then
			ErrorMessage = NStr("en = 'Work schedule %1 is required for the following period: %2.'");
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				ErrorMessage,
				WorkSchedule, PeriodPresentation(StartDate, EndOfDay(EndDate)));
		Else
			Return Undefined;
		EndIf;
	EndIf;
	Selection = Result.Select();
	
 // Getting selection that contains the mapping between start dates and
 // the number of schedule days since the beginning of the year.
 // Subtracting all subsequent values from the value mapped to the first date in the selection. 
 // The subtraction result is the number of schedule days in the entire period, with the minus sign.
 // If the first day in the selection is a workday and the next one is a weekend day, the
 // number of days included in the schedule is identical for both dates,
 // therefore adding 1 day to correct the result.
	
	DayCountInSchedule = Undefined;
	AddFirstDay = False;
	
	While Selection.Next() Do
		If DayCountInSchedule = Undefined Then
			DayCountInSchedule = Selection.DayNumberInScheduleSinceYearBeginning;
			AddFirstDay = Selection.DayAddedToSchedule;
		Else
			DayCountInSchedule = DayCountInSchedule - Selection.DayNumberInScheduleSinceYearBeginning;
		EndIf;
	EndDo;
	
	Return - DayCountInSchedule + ?(AddFirstDay, 1, 0);
	
EndFunction
// Defines the nearest workday for each date.
//
//	Parameters:
//	Line 						         - reference to a work schedule or a business calendar.
//	InitialDates 	         - array of dates.
//	GetPrevious		         - method of getting the nearest date. If True, the function returns working dates 
//                          that precede the dates specified in the InitialDates parameter,
//                          otherwise it returns dates that are equal to or later than the start date. 
//	RaiseException 	       - Boolean - if True, raises an exception if the schedule is not filled.
//	IgnoreUnfilledSchedule - Boolean - if True, always returns a map. 
//								              Start dates that do not have matching values because the schedule is not fully filled are not included.
//
//	Returns:
//	WorkDates - Map:
//              Key - date from the passed array. 
//              Value - the nearest working date (if a working day is passed, the same day is returned).
// If the selected schedule is not filled and RaiseException = False, returns Undefined.
//
Function GetWorkdayDates(Line, InitialDates, GetPrevious = False, RaiseException = True, IgnoreUnfilledSchedule = False) Export
	
	TTQueryText = "";
	FirstPart = True;
	For Each InitialDate In InitialDates Do
		If Not ValueIsFilled(InitialDate) Then
			Continue;
		EndIf;
		If Not FirstPart Then
			TTQueryText = TTQueryText + "
			|UNION ALL
			|";
		EndIf;
		TTQueryText = TTQueryText + "
		|SELECT
		|	DATETIME(" + Format(InitialDate, "DF=M/d/yyyy") + ")";
		If FirstPart Then
			TTQueryText = TTQueryText + " AS Date INTO InitialDates
			|";
		EndIf;
		FirstPart = False;
	EndDo;
	If IsBlankString(TTQueryText) Then
		Return New Map;
	EndIf;
	
	Query = New Query(TTQueryText);
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	If TypeOf(Line) = Type("CatalogRef.BusinessCalendars") Then
		QueryText = 
		"SELECT
		|	InitialDates.Date,
		|	%Function%(CalendarDates.Date) AS EarliestDate
		|FROM
		|	InitialDates AS InitialDates
		|		LEFT JOIN InformationRegister.BusinessCalendarData AS CalendarDates
		|		ON (CalendarDates.Date %ConditionSign% InitialDates.Date)
		|			AND (CalendarDates.BusinessCalendar = &Line)
		|			AND (CalendarDates.DayKind IN (
		|			VALUE(Enum.BusinessCalendarDayKinds.Work), 
		|			VALUE(Enum.BusinessCalendarDayKinds.Preholiday)
		|			))
		|
		|GROUP BY
		|	InitialDates.Date";
	Else
		// Based on a work schedule
		If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
			QueryText = WorkSchedulesModule.NextDatesAccordingToWorkScheduleDefinitionQueryTextTemplate();
		EndIf;
	EndIf;
	
	QueryText = StrReplace(QueryText, "%Function%", 				?(GetPrevious, "MAX", "MIN"));
	QueryText = StrReplace(QueryText, "%ConditionSign%", 			?(GetPrevious, "<=", ">="));
	
	Query.Text = QueryText;
	Query.SetParameter("Line", Line);
	
	Selection = Query.Execute().Select();
	
	WorkdayDates = New Map;
	While Selection.Next() Do
		If ValueIsFilled(Selection.EarliestDate) Then
			WorkdayDates.Insert(Selection.Date, Selection.EarliestDate);
		Else 
			If IgnoreUnfilledSchedule Then
				Continue;
			EndIf;
			If RaiseException Then
				ErrorMessage = StringFunctionsClientServer.SubstituteParametersInString(
									NStr("en = 'Cannot determine the nearest working date for date %1. Probably the work schedule is not filled.'"), 
									Format(Selection.Date, "DLF=D"));
				Raise(ErrorMessage);
			Else
				Return Undefined;
			EndIf;
		EndIf;
	EndDo;
	
	Return WorkdayDates;
	
EndFunction
// Generates work schedules for schedule dates within the specified period.
// If the schedule is not set for a day before holiday, the day is considered a working day.
//
// ATTENTION! The method requires the WorkSchedules subsystem.
//
// Parameters
// Schedules - Array of CatalogRef.BusinessCalendars elements.
// StartDate - Date - start date of the period. 
// EndDate   - Date - end date of the period.
//
// Returns: value table with the following columns:
//          WorkSchedule, ScheduleDate, StartTime, EndTime.
//
Function WorkSchedulesForPeriod(Schedules, StartDate, EndDate) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		Return WorkSchedulesModule.WorkSchedulesForPeriod(Schedules, StartDate, EndDate);
	EndIf;
	
	Raise NStr("en = 'The Work schedules subsystem is not found.'");
	
EndFunction
// Creates the WorkScheduleTT temporary table in the manager.
// For more information, see WorkSchedulesForPeriod function description.
//
// ATTENTION! The method requires the WorkSchedules subsystem.
//
Procedure CreateWorkSchedulesForPeriodTT(TempTablesManager, Schedules, StartDate, EndDate) Export
	
	If CommonUse.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		WorkSchedulesModule = CommonUse.CommonModule("WorkSchedules");
		WorkSchedulesModule.CreateWorkSchedulesForPeriodTT(TempTablesManager, Schedules, StartDate, EndDate);
		Return;
	EndIf;
	
	Raise NStr("en = 'The Work schedules subsystem is not found.'");
	
EndProcedure
// Fills an attribute in the form if a single business calendar is used.
//
// Parameters
// Form          - Form.
// AttributePath - String - path to the data, example: "Object.BusinessCalendar".
//
Procedure FillBusinessCalendarInForm(Form, AttributePath) Export
	
	If GetFunctionalOption("UseMultipleBusinessCalendars") Then
		Return;
	EndIf;
	
	UsedCalendars = Catalogs.BusinessCalendars.BusinessCalendarList();
	
	If UsedCalendars.Count() > 0 Then
		CommonUseClientServer.SetFormAttributeByPath(Form, AttributePath, UsedCalendars[0]);
	EndIf;
	
EndProcedure
// Returns the business calendar that is generated according to the United States laws.
//
// Returns: reference to a BusinessCalendars catalog item, or Undefined if the business calendar is not found.
//
Function USABusinessCalendar() Export
		
	BusinessCalendar = Catalogs.BusinessCalendars.FindByCode("US");
	
	If BusinessCalendar.IsEmpty() Then 
 
		Return Undefined;
	EndIf;
	Return BusinessCalendar;
	
EndFunction
#EndRegion
#Region InternalInterface
// Declares internal events of the CalendarSchedules subsystem.
//
// Server events:
//   OnUpdateBusinessCalendars.
//
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS
	
	// The procedure is called when business calendar data is changed.
	//
	// Parameters:
	// UpdateConditions - value table with the following columns: 
	// 	 BusinessCalendarCode - business calendar code.
	// 	 Year                 - year of changed data.
	//
	// Syntax:
	// Procedure OnUpdateBusinessCalendars(UpdateConditions) Export
	//
	// (the same as CalendarSchedulesOverridable.OnUpdateBusinessCalendars).
	//
	ServerEvents.Add("StandardSubsystems.CalendarSchedules\OnUpdateBusinessCalendars");
	
EndProcedure
// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	ServerHandlers[
		"StandardSubsystems.InfobaseVersionUpdate\OnAddUpdateHandlers"
	].Add("CalendarSchedules");
	
	If CommonUse.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillCommonDataTypesSupportingRefMappingOnExport"
		].Add("CalendarSchedules");
	EndIf;
	
	ServerHandlers[
		"StandardSubsystems.BaseFunctionality\OnGetMandatoryExchangePlanObjects"
	].Add("CalendarSchedules");
	
EndProcedure
#EndRegion
#Region InternalProceduresAndFunctions
// Fills an array of shared data types that describe data included in reference mapping
// when data is imported to another infobase.
//
// Parameters:
//  Types - Array of MetadataObject.
//
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.BusinessCalendars);
	
EndProcedure
// The procedure is used when getting metadata objects that are mandatory for the exchange plan.

// If the subsystem includes metadata objects that must be included in the exchange plan content, add these metadata objects to the Objects parameter.

//
// Parameters:
// Objects - Array - array of configuration metadata objects to be included 
//           in the exchange plan content.
// DistributedInfobase (read only) - Boolean - flag that shows whether DIB exchange plan objects are retrieved.
//                                  If True, the list of objects for a DIB exchange plan is retrieved, 
//                                  otherwise the list of objects for a non-DIB exchange plan is retrieved.
//
Procedure OnGetMandatoryExchangePlanObjects(Objects, Val DistributedInfobase) Export
	
	If DistributedInfobase Then
		
		Objects.Add(Metadata.Catalogs.BusinessCalendars);
		Objects.Add(Metadata.InformationRegisters.BusinessCalendarData);
		
	EndIf;
	
EndProcedure
// Creates the DayIncrementTT temporary table. Each table row contains a DayArray element, its index, and the number of days.
// 
// Parameters
// TempTablesManager.
// DayArray - Array – number of days.
// CalculateNextDateFromPrevious - optional, the default value is False.
//
Procedure CreateDayIncrementTT(TempTablesManager, Val DayArray, Val CalculateNextDateFromPrevious = False) Export
	
	DayIncrement = New ValueTable;
	DayIncrement.Columns.Add("LineIndex", New TypeDescription("Number"));
	DayIncrement.Columns.Add("DayCount", New TypeDescription("Number"));
	
	DayCount = 0;
	LineNumber = 0;
	For Each DayArrayElement In DayArray Do
		DayCount = DayCount + DayArrayElement;
		
		Row = DayIncrement.Add();
		Row.LineIndex			= LineNumber;
		If CalculateNextDateFromPrevious Then
			Row.DayCount	= DayCount;
		Else
			Row.DayCount	= DayArrayElement;
		EndIf;
			
		LineNumber = LineNumber + 1;
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	DayIncrement.LineIndex,
	|	DayIncrement.DayCount
	|INTO DayIncrementTT
	|FROM
	|	&DayIncrement AS DayIncrement";
	
	Query.SetParameter("DayIncrement",	DayIncrement);
	
	Query.Execute();
	
EndProcedure
////////////////////////////////////////////////////////////////////////////////
// Infobase update.
// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function in the InfobaseUpdate common module.
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendars";
	Handler.SharedData = True;
 
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendarsData";
	Handler.ExecutionMode = "Exclusive";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "CalendarSchedules.UpdateMultipleBusinessCalendarUse";
	//PARTIALLY_DELETED
	//Handler = Handlers.Add();
	//Handler.Version = "2.1.3.7";
	//Handler.Procedure = "CalendarSchedules.UpdateMultipleBusinessCalendarUse";
	
	//Handler = Handlers.Add();
	//Handler.Version = "2.2.1.32";
	//Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendarsData";
	//Handler.ExecutionMode = "Exclusive";
	//Handler.SharedData = True;
	
EndProcedure
// Updates the BusinessCalendars catalog from the template.
//
Procedure UpdateBusinessCalendars() Export
	
	TextDocument = Catalogs.BusinessCalendars.GetTemplate("CalendarDetails");
	CalendarTable = CommonUse.ReadXMLToTable(TextDocument.GetText()).Data;
	
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(CalendarTable);
	
EndProcedure
// Updates business calendar data from BusinessCalendarsData template.
//  
Procedure UpdateBusinessCalendarsData() Export

	DataTable = Catalogs.BusinessCalendars.BusinessCalendarsDataFromTemplate();
	
	// Updating business calendar data
	Catalogs.BusinessCalendars.UpdateBusinessCalendarsData(DataTable);
	
EndProcedure
// Sets a constant value that shows whether multiple business calendars are used.
//
Procedure UpdateMultipleBusinessCalendarUse() Export
	
	UseMultipleCalendars = Catalogs.BusinessCalendars.BusinessCalendarList().Count() <> 1;
	If UseMultipleCalendars <> GetFunctionalOption("UseMultipleBusinessCalendars") Then
		Constants.UseMultipleBusinessCalendars.Set(UseMultipleCalendars);
	EndIf;
	
EndProcedure
 
#EndRegion