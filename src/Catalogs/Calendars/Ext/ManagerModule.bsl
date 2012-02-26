
////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Function reads calendar data from register
//
// Parameters
//	Calendar		- Current catalog item ref
//	YearNumber		- Year number, to read calendar for
//
// Value to return:
//	ValueList		- value list, containing the dates, entering the calendar
//
Function ReadScheduleDataFromRegister(Calendar, YearNumber) Export
	
	Query = New Query;
	Query.SetParameter("Calendar",	Calendar);
	Query.SetParameter("CurrentYear",	YearNumber);
	Query.Text =
	"SELECT
	|	Calendars.ScheduleDate AS CalendarDate
	|FROM
	|	InformationRegister.CalendarData AS Calendars
	|WHERE
	|	Calendars.Calendar = &Calendar
	|	And Calendars.Year = &CurrentYear
	|	And Calendars.DayIncludedInSchedule";
	
	Return Query.Execute().Unload().UnloadColumn("CalendarDate");
	
EndFunction

// Procedure writes graph data to the register
//
// Parameters
//	Calendar	- Current catalog item ref
//	YearNumber	- Year number, to write the calendar for
//	ListOfDates	- value list, where is specified, which dates enter the calendar
//
// Value to return:
//	No
//
Procedure WriteScheduleDataToRegister(Calendar, YearNumber, ListOfDates) Export
	
	RecordSet = InformationRegisters.CalendarData.CreateRecordSet();
	RecordSet.Filter.Calendar.Set(Calendar);
	RecordSet.Filter.Year.Set(YearNumber);
	
	QuantityWorkingDaysFromBegginingOfTheYear = 0;
	
	For MonthNumber = 1 To 12 Do
		For DayNumber = 1 To Day(EndOfMonth(Date(YearNumber, MonthNumber, 1))) Do
			ScheduleDate = Date(YearNumber, MonthNumber, DayNumber);
			
			RegisterTableRow = ListOfDates.FindByValue(ScheduleDate);
			
			If RegisterTableRow <> Undefined Then
				QuantityWorkingDaysFromBegginingOfTheYear = QuantityWorkingDaysFromBegginingOfTheYear + 1;
			EndIf;
			
			String = RecordSet.Add();
			String.Calendar											= Calendar;
			String.Year												= YearNumber;
			String.ScheduleDate										= ScheduleDate;
			String.DayIncludedInSchedule							= RegisterTableRow <> Undefined;
			String.DaysCountInScheduleSinceTheBeginningOfTheYear	= QuantityWorkingDaysFromBegginingOfTheYear;
		EndDo;
	EndDo;
	
	RecordSet.Write(True);
	
EndProcedure

