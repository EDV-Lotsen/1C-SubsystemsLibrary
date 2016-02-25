
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;

	If Object.Ref.IsEmpty() Then
		Schedule = New JobSchedule;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ID = Object.Ref.UUID();
	
	Schedule = CurrentObject.Schedule.Get();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.Schedule = New ValueStorage(Schedule);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ID = Object.Ref.UUID();
	
EndProcedure

&AtClient
Procedure OpenJobSchedule(Command)
	
	Dialog = New ScheduledJobDialog(Schedule);
	Dialog.Show(New NotifyDescription("OpenScheduleEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure OpenScheduleEnd(NewSchedule, CurrentData) Export

	If NewSchedule = Undefined Then
		Return;
	EndIf;
	
	Schedule = NewSchedule;
	LockFormDataForEdit();
	Modified = True;
	
	ShowUserNotification(NStr("en = 'Rescheduling'"), , NStr("en = 'New schedule will come
		|into effect on the next job execution 
		|by template, or on infobase update'"));
	
EndProcedure
