#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CalendarSchedules.UpdateMultipleBusinessCalendarUse();
	
EndProcedure

#EndRegion
	
#EndIf