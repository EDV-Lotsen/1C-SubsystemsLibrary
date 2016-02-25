#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not ConsiderHolidays Then
		// If the work schedule does not take holidays into consideration, then 
		// pre-holiday intervals should be deleted
		PreholidaySchedule = WorkSchedule.FindRows(New Structure("DayNumber", 0));
		For Each ScheduleString In PreholidaySchedule Do
			WorkSchedule.Delete(ScheduleString);
		EndDo;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	// If the end date is not specified, it will be selected in the business calendar
	FillingEndDate = EndDate;
	
	DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
									StartDate, 
									FillingMethod, 
									FillingTemplate, 
									WorkSchedule,
									FillingEndDate,
									BusinessCalendar, 
									ConsiderHolidays, 
									PeriodStartDate);
									
	Catalogs.Calendars.WriteScheduleDataToRegister(
		Ref, DaysIncludedInSchedule, StartDate, FillingEndDate);
	
EndProcedure

#EndRegion

#EndIf