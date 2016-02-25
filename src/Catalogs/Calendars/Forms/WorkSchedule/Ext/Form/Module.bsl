
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skip the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	DaySchedule = Parameters.WorkSchedule;
	
	For Each IntervalDetails In DaySchedule Do
		FillPropertyValues(WorkSchedule.Add(), IntervalDetails);
	EndDo;
	WorkSchedule.Sort("BeginTime");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectAndClose();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Modified = False;
	NotifyChoice(Undefined);
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure WorkScheduleOnEditEnd(Item, NewRow, CancelEdit)
		
	If CancelEdit Then
		Return;
	EndIf;
	
	WorkSchedulesClientServer.RestoreCollectionRowOrderAfterEditing(WorkSchedule, "BeginTime", Item.CurrentData);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Function DaySchedule()
	
	Cancel = False;
	
	DaySchedule = New Array;
	
	EndDay = Undefined;
	
	For Each ScheduleString In WorkSchedule Do
		LineIndex = WorkSchedule.IndexOf(ScheduleString);
		If ScheduleString.BeginTime > ScheduleString.EndTime 
			And ValueIsFilled(ScheduleString.EndTime) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Begin time is more than end time'"), ,
				StringFunctionsClientServer.SubstituteParametersInString("WorkSchedule[%1].EndTime", LineIndex), ,
				Cancel);
		EndIf;
		If ScheduleString.BeginTime = ScheduleString.EndTime Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Interval duration is not defined'"), ,
				StringFunctionsClientServer.SubstituteParametersInString("WorkSchedule[%1].EndTime", LineIndex), ,
				Cancel);
		EndIf;
		If EndDay <> Undefined Then
			If EndDay > ScheduleString.BeginTime 
				Or Not ValueIsFilled(EndDay) Then
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Overlapping intervals are detected'"), ,
					StringFunctionsClientServer.SubstituteParametersInString("WorkSchedule[%1].BeginTime", LineIndex), ,
					Cancel);
			EndIf;
		EndIf;
		EndDay = ScheduleString.EndTime;
		DaySchedule.Add(New Structure("BeginTime, EndTime", ScheduleString.BeginTime, ScheduleString.EndTime));
	EndDo;
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	Return DaySchedule;
	
EndFunction

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	DaySchedule = DaySchedule();
	If DaySchedule = Undefined Then
		Return;
	EndIf;
	
	Modified = False;
	NotifyChoice(New Structure("WorkSchedule", DaySchedule));
	
EndProcedure

#EndRegion
