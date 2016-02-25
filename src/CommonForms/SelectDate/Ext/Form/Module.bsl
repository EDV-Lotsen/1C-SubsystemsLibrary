&AtClient
Var ActionSelected;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;

	InitialValue = Parameters.InitialValue;
	
	If Not ValueIsFilled(InitialValue) Then
		InitialValue = CurrentSessionDate();
	EndIf;
	
	Parameters.Property("BeginOfRepresentationPeriod", Items.Calendar.BeginOfRepresentationPeriod);
	Parameters.Property("EndOfRepresentationPeriod", Items.Calendar.EndOfRepresentationPeriod);
	
	Calendar = InitialValue;
	
	Parameters.Property("Title", Title);
	
	If Parameters.Property("InformationText") Then
		Items.InformationText.Title = Parameters.InformationText;
	Else
		Items.InformationText.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not ActionSelected Then
		NotifyChoice(Undefined);
	EndIf;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure CalendarChoice(Item, SelectedDate)
	
	ActionSelected = True;
	NotifyChoice(SelectedDate);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'The date is not specified.'"));
		Return;
	EndIf;
	
	ActionSelected = True;
	NotifyChoice(SelectedDates[0]);
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	ActionSelected = True;
	NotifyChoice(Undefined);
	
EndProcedure

#EndRegion

ActionSelected = False;
