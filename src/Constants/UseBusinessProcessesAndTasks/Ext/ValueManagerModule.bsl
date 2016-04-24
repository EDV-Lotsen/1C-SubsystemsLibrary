#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value = False Then
		Constants.UseSubordinateBusinessProcesses.Set(False);
		Constants.ChangeJobsBackdated.Set(False);
		Constants.UseTaskStartDate.Set(False);
		Constants.UseDateAndTimeInTaskDeadlines.Set(False);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf