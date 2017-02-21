
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.	
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;

	If Not Users.InfobaseUserWithFullAccess(, True) Then
		ReadOnly = True;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		SetSchedulePresentation(ThisObject);
		MethodParameters = CommonUse.ValueToXMLString(New Array);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ID = Object.Ref.UUID();
	
	Schedule = CurrentObject.Schedule.Get();
	SetSchedulePresentation(ThisObject);
	
	MethodParameters = CommonUse.ValueToXMLString(CurrentObject.Parameters.Get());
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.Schedule = New ValueStorage(Schedule);
	CurrentObject.Parameters = New ValueStorage(CommonUse.ValueFromXMLString(MethodParameters));
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ID = Object.Ref.UUID();
	
EndProcedure

&AtClient
Procedure SchedulePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	If ValueIsFilled(Object.Template) Then
		ShowMessageBox(, NStr("en = 'For a job made based on a template, the schedule is set in a template.'"));
		Return;
	EndIf;
	
	If Schedule = Undefined Then
		ScheduleBeingEdited = New JobSchedule;
	Else
		ScheduleBeingEdited = Schedule;
	EndIf;
	
	Dialog = New ScheduledJobDialog(ScheduleBeingEdited);
	NotifyOnCloseDescription = New NotifyDescription("ChangeSchedule", ThisObject);
	Dialog.Show(NotifyOnCloseDescription);
	
EndProcedure

&AtClient
Procedure ChangeSchedule(NewSchedule, Parameters) Export
	
	If NewSchedule = Undefined Then
		Return;
	EndIf;
	
	Schedule = NewSchedule;
	Modified = True;
	SetSchedulePresentation(ThisObject);
	
	ShowUserNotification(NStr("en = 'Rescheduling'"), , NStr("en = 'The new schedule will be taken into account during the next job execution'"));
	
EndProcedure

&AtClient
Procedure SchedulePresentationClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	Schedule = Undefined;
	Modified = True;
	SetSchedulePresentation(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetSchedulePresentation(Val Form)
	
	Schedule = Form.Schedule;
	
	If Schedule <> Undefined Then
		Form.SchedulePresentation = String(Schedule);
	ElsIf ValueIsFilled(Form.Object.Template) Then
		Form.SchedulePresentation = NStr("en = '<Can be set in template>'");
	Else
		Form.SchedulePresentation = NStr("en = '<Not set>'");
	EndIf;
	
EndProcedure







