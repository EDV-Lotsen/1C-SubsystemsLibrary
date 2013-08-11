
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

// Function reads data of the calendar graph for the specified year
//
&AtServerNoContext
Function ReadCalendarSchedule(Calendar, YearNumber)
	
	Return Catalogs.Calendars.ReadScheduleDataFromRegister(Calendar, YearNumber);
	
EndFunction

// Procedure writes data of the calendar graph for the specified year
//
&AtServer
Procedure WriteCalendarSchedule(Val YearNumber, Val CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = FormAttributeToValue("Object");
	EndIf;
	
	Catalogs.Calendars.WriteScheduleDataToRegister(CurrentObject.Ref, YearNumber, RegisterTable);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

// Procedure - handler of event "OnCreateAtServer" of form
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	CurrentYearNumber	= Year(CurrentDate());
	PreviousYearNumber	= CurrentYearNumber;
	
	Items.Calendar.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.Calendar.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
	
	If Not ValueIsFilled(Parameters.CopyingValue) Then
		RefToCalendar = Object.Ref;
	Else
		RefToCalendar = Parameters.CopyingValue;
	EndIf;
	
	RegisterTable.LoadValues(Catalogs.Calendars.ReadScheduleDataFromRegister(RefToCalendar, CurrentYearNumber));
	
EndProcedure

// Procedure - handler of event "OnWriteAtServer" of form
//
&AtServer
Procedure OnWriteAtServer(Cancellation, CurrentObject, WriteParameters)
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	WriteCalendarSchedule(YearNumber, CurrentObject);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(ChoiceResult, ChoiceSource)
	
	If TypeOf(ChoiceResult) = Type("CatalogRef.Calendars") Then
		RegisterTable.LoadValues(ReadCalendarSchedule(ChoiceResult, CurrentYearNumber));
		
		Items.Calendar.Refresh();
	EndIf;
	
	Return;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF FORM COMMAND BARS

// Procedure - handler of event of command "FillCalendar"
//
&AtClient
Procedure FillCalendar()
	
	RegisterTable.Clear();
	
	For Month = 1 To 12 Do
		For DayNumber = 1 To Day(EndOfMonth(Date(CurrentYearNumber, Month, 1))) Do
			CalendarDate = Date(CurrentYearNumber, Month, DayNumber);
			
			If Weekday(CalendarDate) = 6 Or Weekday(CalendarDate) = 7 Then
				Continue;
			EndIf;
			
			RegisterTable.Add(CalendarDate);
		EndDo;
	EndDo;
	
	Items.Calendar.Refresh();
	
EndProcedure

// Procedure - handler of event of command "FillByCalendar"
//
&AtClient
Procedure FillByCalendar(Command)
	
	OpenForm("Catalog.Calendars.ChoiceForm", , ThisForm, UniqueKey);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

// Procedure - handler of event "OnChange" of form item "CurrentYearNumber"
//
&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	If CurrentYearNumber < 1900 Then
		CurrentYearNumber = PreviousYearNumber;
		Return;
	EndIf;
	
	If Modified Then
		TextOfMessage = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Write modified data for %1 year?'"), Format(PreviousYearNumber, "NG=0"));
		
		If DoQueryBox(TextOfMessage, QuestionDialogMode.YesNo) = DialogReturnCode.Yes Then
			If Object.Ref.IsEmpty() Then
				Write(New Structure("YearNumber", PreviousYearNumber));
			Else
				WriteCalendarSchedule(PreviousYearNumber);
			EndIf;
		EndIf;
	EndIf;
	
	PreviousYearNumber = CurrentYearNumber;
	
	Items.Calendar.BeginOfDisplayPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.Calendar.EndOfDisplayPeriod	= Date(CurrentYearNumber, 12, 31);
	
	RegisterTable.LoadValues(ReadCalendarSchedule(Object.Ref, CurrentYearNumber));
	
	Modified = False;
	
	Items.Calendar.Refresh();
	
EndProcedure

// Procedure - handler of event "OnPeriodOutput" of form item "Calendar"
//
&AtClient
Procedure CalendarOnPeriodOutput(Item, PeriodAppearance)
	
	For Each PeriodDecorationRow In PeriodAppearance.Dates Do
		RegisterTableRow = RegisterTable.FindByValue(PeriodDecorationRow.Date);
		
		If RegisterTableRow = Undefined Then
			PeriodDecorationRow.TextColor = WebColors.Red;
		Else
			PeriodDecorationRow.TextColor = WebColors.Black;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure - handler of event "Selection" of form item "Calendar"
//
&AtClient
Procedure CalendarSelection(Item, SelectedDate)
	
	RegisterTableRow = RegisterTable.FindByValue(SelectedDate);
	
	If RegisterTableRow = Undefined Then
		RegisterTable.Add(SelectedDate);
	Else
		RegisterTable.Delete(RegisterTableRow);
	EndIf;
	
	If Not Modified Then
		Modified = True;
	EndIf;
	
	Item.Refresh();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// MAIN PROGRAM OPERANDS
