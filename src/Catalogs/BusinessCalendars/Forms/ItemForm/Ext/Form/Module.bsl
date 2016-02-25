
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		FillWithCurrentYearData(Parameters.CopyingValue);
	EndIf;
	
	DayKindColors = New FixedMap(Catalogs.BusinessCalendars.BusinessCalendarDayKindAppearanceColors());
	
	DayKindList = Catalogs.BusinessCalendars.DayKindList();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaSOperations.DataExchangeSaaS") Then
		ModuleStandaloneMode = CommonUse.CommonModule("StandaloneMode");
		ModuleStandaloneMode.ObjectOnReadAtServer(CurrentObject, ThisObject.ReadOnly);
	EndIf;
	
	FillWithCurrentYearData();
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectDate") Then
		If SelectedValue = Undefined Then
			Return;
		EndIf;
		SelectedDates = Items.Calendar.SelectedDates;
		If SelectedDates.Count() = 0 Or Year(SelectedDates[0]) <> CurrentYearNumber Then
			Return;
		EndIf;
		ReplacementDate = SelectedDates[0];
		ReplaceDayKind(ReplacementDate, SelectedValue);
		Items.Calendar.Refresh();
	EndIf;
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	WriteBusinessCalendarData(YearNumber, CurrentObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	WriteScheduleData = False;
	If Modified Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Do you want to save changed data for year %1?'"), 
							Format(PreviousYearNumber, "NG=0"));
		
		Notification = New NotifyDescription("CurrentYearNumberOnChangeCompletion", ThisObject);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	
	Modified = False;
	
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure CalendarOnPeriodOutput(Item, PeriodAppearance)
	
	For Each PeriodAppearanceRow In PeriodAppearance.Dates Do
		DayAppearanceColor = DayKindColors.Get(DayKinds.Get(PeriodAppearanceRow.Date));
		If DayAppearanceColor = Undefined Then
			DayAppearanceColor = CommonUseClient.StyleColor("BusinessCalendarDayKindNotSetColor");
		EndIf;
		PeriodAppearanceRow.TextColor = DayAppearanceColor;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChangeDay(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() > 0 And Year(SelectedDates[0]) = CurrentYearNumber Then
		Notification = New NotifyDescription("ChangeDayCompletion", ThisObject, SelectedDates);
		ShowChooseFromList(Notification, DayKindList, , DayKindList.FindByValue(DayKinds.Get(SelectedDates[0])));
	EndIf;
	
EndProcedure

&AtClient
Procedure ReplaceDay(Command)
	
	SelectedDates = Items.Calendar.SelectedDates;
	
	If SelectedDates.Count() = 0 Or Year(SelectedDates[0]) <> CurrentYearNumber Then
		Return;
	EndIf;
		
	ReplacementDate = SelectedDates[0];
	DayKind = DayKinds.Get(ReplacementDate);
	
	DateSelectionParameters = New Structure;
	DateSelectionParameters.Insert("InitialValue",			           ReplacementDate);
	DateSelectionParameters.Insert("BeginOfRepresentationPeriod", BegOfYear(Calendar));
	DateSelectionParameters.Insert("EndOfRepresentationPeriod",		EndOfYear(Calendar));
	DateSelectionParameters.Insert("Title",					               NStr("en = 'Select replacement date.'"));
	DateSelectionParameters.Insert("InformationText",				       StringFunctionsClientServer.SubstituteParametersInString(
																NStr("en = 'Select date to be replaced by %1 (%2).'"), 
																Format(ReplacementDate, "DF='MMMM d'"), 
																DayKind));
	
	OpenForm("CommonForm.SelectDate", DateSelectionParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillByDefault(Command)
	
	FillWithDefaultData();
	
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	If Object.Ref.IsEmpty() Then
		Handler = New NotifyDescription("PrintCompletion", ThisObject);
		ShowQueryBox(
			Handler,
			NStr("en = 'Business calendar data is not yet saved.
                  |Printing is only available after you save the data.
                  |
                  |Do you want to save it?'"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.Yes);
		Return;
	EndIf;
	
	PrintCompletion(-1);
		
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Fills a form with the current year data.
//
&AtServer
Procedure FillWithCurrentYearData(CopyingValue = Undefined)
	
	SetCalendarField();
	
	If ValueIsFilled(CopyingValue) Then
		CalendarRef = CopyingValue;
	Else
		CalendarRef = Object.Ref;
	EndIf;
	
	ReadBusinessCalendarData(CalendarRef, CurrentYearNumber);
		
EndProcedure

// Imports business calendar data for the specified year.
//
&AtServer
Procedure ReadBusinessCalendarData(BusinessCalendar, YearNumber)
	
		ConvertBusinessCalendarData(
		Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, YearNumber));
	
EndProcedure

// Fills the form with business calendar data that is generated based on 
// holidays and holiday replacements.
&AtServer
Procedure FillWithDefaultData()
	
	ConvertBusinessCalendarData(
		Catalogs.BusinessCalendars.BusinessCalendarFillingByDefaultResult(Object.Code, CurrentYearNumber));

	Modified = True;
	
EndProcedure

// Business calendar data is stored in the form 
// as a mapping between DayKinds and HolidayReplacements. 
// The procedure fills the map.
//
&AtServer
Procedure ConvertBusinessCalendarData(BusinessCalendarData)
		
	DayKindsMap = New Map;
	HolidayReplacementMap = New Map;
	
	For Each TableRow In BusinessCalendarData Do
		DayKindsMap.Insert(TableRow.Date, TableRow.DayKind);
		If ValueIsFilled(TableRow.ReplacementDate) Then
			HolidayReplacementMap.Insert(TableRow.Date, TableRow.ReplacementDate);
		EndIf;
	EndDo;
	
	DayKinds = New FixedMap(DayKindsMap);
	HolidayReplacements = New FixedMap(HolidayReplacementMap);
	
	FillReplacementPresentation(ThisObject);
	
	Items.ReplacementList.Visible = ReplacementList.Count() > 0;
	
EndProcedure
 
// Writes business calendar data for the specified year.
//
&AtServer
Procedure WriteBusinessCalendarData(Val YearNumber, Val CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = FormAttributeToValue("Object");
	EndIf;
	
	BusinessCalendarData = New ValueTable;
	BusinessCalendarData.Columns.Add("Date",            New TypeDescription("Date"));
	BusinessCalendarData.Columns.Add("DayKind",         New TypeDescription("EnumRef.BusinessCalendarDayKinds"));
	BusinessCalendarData.Columns.Add("ReplacementDate", New TypeDescription("Date"));
	
	For Each KeyAndValue In DayKinds Do
		
		TableRow = BusinessCalendarData.Add();
		TableRow.Date = KeyAndValue.Key;
		TableRow.DayKind = KeyAndValue.Value;
		
		// If it is a replaced holiday, insert the replacement date
		ReplacementDate = HolidayReplacements.Get(TableRow.Date);
		If ReplacementDate <> Undefined 
			And ReplacementDate <> TableRow.Date Then
			TableRow.ReplacementDate = ReplacementDate;
		EndIf;
		
	EndDo;
	
	Catalogs.BusinessCalendars.WriteBusinessCalendarData(CurrentObject.Ref, YearNumber, BusinessCalendarData);
	
EndProcedure

&AtServer
Procedure ProcessYearChange(WriteScheduleData)
	
	If Not WriteScheduleData Then
		FillWithCurrentYearData();
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		Write(New Structure("YearNumber", PreviousYearNumber));
	Else
		WriteBusinessCalendarData(PreviousYearNumber);
	EndIf;
	
	FillWithCurrentYearData();	
	
EndProcedure
 
// Sets a specific day kind for all dates in an array.
//
&AtClient
Procedure ChangeDayKinds(DayDates, DayKind)
	
	DayKindsMap = New Map(DayKinds);
	
	For Each SelectedDate In DayDates Do
		DayKindsMap.Insert(SelectedDate, DayKind);
	EndDo;
	
	DayKinds = New FixedMap(DayKindsMap);
	
EndProcedure

&AtClient
Procedure ReplaceDayKind(ReplacementDate, PurposeDate)
	
	// Swapping two days in a calendar includes:
	// - swapping day kind;
	// - recording destination date.
	// * if the replaced day has a destination date (it has already been replaced),
	// 	 use the current destination date,
	//	* if the dates are equal (the day has been swapped back), delete the record.
	
	DayKindsMap = New Map(DayKinds);
	
	DayKindsMap.Insert(PurposeDate, DayKinds.Get(ReplacementDate));
	DayKindsMap.Insert(ReplacementDate, DayKinds.Get(PurposeDate));
	
	HolidayReplacementMap = New Map(HolidayReplacements);
	
	EnterReplacementDate(HolidayReplacementMap, ReplacementDate, PurposeDate);
	EnterReplacementDate(HolidayReplacementMap, PurposeDate, ReplacementDate);
	
	DayKinds = New FixedMap(DayKindsMap);
	HolidayReplacements = New FixedMap(HolidayReplacementMap);
	
	FillReplacementPresentation(ThisObject);
	
EndProcedure
 
// Fills the final replacement date according to the holiday replacement map.
//
&AtClient
Procedure EnterReplacementDate(HolidayReplacementMap, ReplacementDate, PurposeDate)
		
	PurposeDateDaySource = HolidayReplacements.Get(PurposeDate);
	If PurposeDateDaySource = Undefined Then
		PurposeDateDaySource = PurposeDate;
	EndIf;
	
	If ReplacementDate = PurposeDateDaySource Then
		HolidayReplacementMap.Delete(ReplacementDate);
	Else	
		HolidayReplacementMap.Insert(ReplacementDate, PurposeDateDaySource);
	EndIf;
	
EndProcedure

// Generates a holiday replacement presentation value list.
//
&AtClientAtServerNoContext
Procedure FillReplacementPresentation(Form)
		
	Form.ReplacementList.Clear();
	For Each KeyAndValue In Form.HolidayReplacements Do
		// From the applied logic point of view, a weekday is always replaced by a holiday,
   // so let us select the date that previously was a holiday (and now is a weekday)
		SourceDate = KeyAndValue.Key;
		TargetDate = KeyAndValue.Value;
		DayKind = Form.DayKinds.Get(SourceDate);
		If DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Saturday")
			Or DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Sunday") Then
			// Swapping dates to show holiday replacement information as "A replaces B" instead of "B replaces A"
			ReplacementDate = TargetDate;
			TargetDate      = SourceDate;
			SourceDate      = ReplacementDate;
		EndIf;
		If Form.ReplacementList.FindByValue(SourceDate) <> Undefined 
			Or Form.ReplacementList.FindByValue(TargetDate) <> Undefined Then
			// Holiday replacement is already added, skipping it
			Continue;
		EndIf;
		SourceDayKind = ReplacementDayKindPresentation(Form.DayKinds.Get(TargetDate), SourceDate);
		TargetDayKind = ReplacementDayKindPresentation(Form.DayKinds.Get(SourceDate), TargetDate);
		Form.ReplacementList.Add(SourceDate, StringFunctionsClientServer.SubstituteParametersInString(
															NStr("en = '%1 (%3) replaces %2(%4)'"),
															Format(SourceDate, "DF='MMMM d'"),
															Format(TargetDate, "DF='MMMM d'"),
															SourceDayKind,
															TargetDayKind));
	EndDo;
	Form.ReplacementList.SortByValue();
	
EndProcedure

&AtClientAtServerNoContext
Function ReplacementDayKindPresentation(DayKind, Date)
	
	// If a day is a weekday or a holiday, displaying the day of the week as its presentation
	
	If DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Workday") 
		Or DayKind = PredefinedValue("Enum.BusinessCalendarDayKinds.Holiday") Then
		DayKind = Format(Date, "DF='dddd'");
	EndIf;
	
	Return Lower(String(DayKind));
	
EndFunction	

&AtServer
Procedure SetCalendarField()
	
	If CurrentYearNumber = 0 Then
		CurrentYearNumber = Year(CurrentSessionDate());
	EndIf;
	PreviousYearNumber = CurrentYearNumber;
	
	Items.Calendar.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.Calendar.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
		
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChangeCompletion(Answer, AdditionalParameters) Export
	
	ProcessYearChange(Answer = DialogReturnCode.Yes);
	Modified = False;
	Items.Calendar.Refresh();
	
EndProcedure

&AtClient
Procedure ChangeDayCompletion(SelectedItem, SelectedDates) Export
	
	If SelectedItem <> Undefined Then
		ChangeDayKinds(SelectedDates, SelectedItem.Value);
		Items.Calendar.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintCompletion(ProposalToWriteAnswer, ExecutionParameters = Undefined) Export
	
	If ProposalToWriteAnswer <> -1 Then
		If ProposalToWriteAnswer <> DialogReturnCode.Yes Then
			Return;
		EndIf;
		Written = Write();
		If Not Written Then
			Return;
		EndIf;
	EndIf;
	
	PrintParameters = New Structure;
	PrintParameters.Insert("BusinessCalendar", Object.Ref);
	PrintParameters.Insert("YearNumber", CurrentYearNumber);
	
	CommandParameter = New Array;
	CommandParameter.Add(Object.Ref);
	
	If CommonUseClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagementClient = CommonUseClient.CommonModule("PrintManagementClient");
		ModulePrintManagementClient.ExecutePrintCommand("Catalog.BusinessCalendars", "BusinessCalendar", 
			CommandParameter, ThisObject, PrintParameters);
	EndIf;
	
EndProcedure

#EndRegion
