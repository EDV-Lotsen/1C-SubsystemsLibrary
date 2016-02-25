&AtClient
Var ChoiceContext;

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	If Not Object.Ref.IsEmpty() Then
		Return;
	EndIf;	
	
	// If there is only one business calendar in the system, fill it in by default
	BusinessCalendars = Catalogs.BusinessCalendars.BusinessCalendarList();
	If BusinessCalendars.Count() = 1 Then
		Object.BusinessCalendar = BusinessCalendars[0];
	EndIf;
	
	Object.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
	
	PeriodLength = 7;
	
	Object.StartDate = BegOfYear(CurrentSessionDate());
	Object.PeriodStartDate = BegOfYear(CurrentSessionDate());
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.PeriodStartDate);
	
	FillSchedulePresentation();
	
	SetEnabledConsiderHolidays(ThisObject);
	
	SpecifyFillDate();
	
	FillWithCurrentYearData(Parameters.CopyingValue);
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, True);
	
	SetEnabledPreholidaySchedule(ThisObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	PeriodLength = Object.FillingTemplate.Count();
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.PeriodStartDate);
	
	FillSchedulePresentation();
	
	SetEnabledConsiderHolidays(ThisObject);
	
	SpecifyFillDate();
	
	FillWithCurrentYearData();
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, True);
	SetRemoveTemplateModified(ThisObject, False);
	
	SetEnabledPreholidaySchedule(ThisObject);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.Calendars.Form.WorkSchedule") Then
		
		If SelectedValue = Undefined Or ReadOnly Then
			Return;
		EndIf;
		
		// Delete the previously filled schedule for the day
		DayRows = New Array;
		For Each ScheduleString In Object.WorkSchedule Do
			If ScheduleString.DayNumber = ChoiceContext.DayNumber Then
				DayRows.Add(ScheduleString.GetID());
			EndIf;
		EndDo;
		For Each RowID In DayRows Do
			Object.WorkSchedule.Delete(Object.WorkSchedule.FindByID(RowID));
		EndDo;
		
		// Fill in the work schedule for a day
		For Each IntervalDetails In SelectedValue.WorkSchedule Do
			NewRow = Object.WorkSchedule.Add();
			FillPropertyValues(NewRow, IntervalDetails);
			NewRow.DayNumber = ChoiceContext.DayNumber;
		EndDo;
		
		SetRemoveResultsToTemplateMappingFlag(ThisObject, False);
		SetRemoveTemplateModified(ThisObject, True);
		
		If ChoiceContext.Source = "FillingTemplateChoice" Then
			
			TemplateRow = Object.FillingTemplate.FindByID(ChoiceContext.TemplateRowID);
			TemplateRow.DayAddedToSchedule = SelectedValue.WorkSchedule.Count() > 0; // The schedule is filled in
			TemplateRow.SchedulePresentation = DaySchedulePresentation(ThisObject, ChoiceContext.DayNumber);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	Var YearNumber;
	
	If Not WriteParameters.Property("YearNumber", YearNumber) Then
		YearNumber = CurrentYearNumber;
	EndIf;
	
	// If the current year data is edited manually, 
	// write it "as is" and update other periods by template
	
	If ResultModified Then
		Catalogs.Calendars.WriteScheduleDataToRegister(CurrentObject.Ref, ScheduleDays, Date(YearNumber, 1, 1), Date(YearNumber, 12, 31), True);
	EndIf;
	SaveManualEditingFlag(CurrentObject, YearNumber);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	PeriodLength = Object.FillingTemplate.Count();
	
	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.PeriodStartDate);
	
	FillSchedulePresentation();
	
	SpecifyFillDate();
	
	SetRemoveTemplateModified(ThisObject, False);
	
	FillWithCurrentYearData();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, AttributesToCheck)
	
	If Object.FillingMethod = Enums.WorkScheduleFillingMethods.ByArbitraryLengthPeriods Then
		AttributesToCheck.Add("PeriodLength");
		AttributesToCheck.Add("PeriodStartDate");
	EndIf;
	
	If Object.FillingTemplate.FindRows(New Structure("DayAddedToSchedule", True)).Count() = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'The days included in the work schedule are not highlighted'"), , "Object.FillingTemplate", , Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure FillByTemplate(Command)
	
	FillByTemplateAtServer();
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure FillingResult(Command)
	
	Items.Pages.CurrentPage = Items.FillingResultPage;
	
	If Not ResultFilledByTemplate Then
		FillByTemplateAtServer(True);
	EndIf;
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure FillingSettings(Command)
	
	Items.Pages.CurrentPage = Items.FillingSettingsPage;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM ITEM EVENT HANDLERS

&AtClient
Procedure BusinessCalendarOnChange(Item)
	
	SetEnabledConsiderHolidays(ThisObject);
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure FillingMethodOnChange(Item)

	ConfigureFillingSettingItems(ThisObject);
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.PeriodStartDate);
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure StartDateOnChange(Item)
	
	If Object.StartDate < Date(1900, 1, 1) Then
		Object.StartDate = BegOfYear(CommonUseClient.SessionDate());
	EndIf;
	
EndProcedure

&AtClient
Procedure PeriodStartDateOnChange(Item)
	
	If Object.PeriodStartDate < Date(1900, 1, 1) Then
		Object.PeriodStartDate = BegOfYear(CommonUseClient.SessionDate());
	EndIf;
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.PeriodStartDate);
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure PeriodLengthOnChange(Item)
	
	GenerateFillingTemplate(Object.FillingMethod, Object.FillingTemplate, PeriodLength, Object.PeriodStartDate);
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure ConsiderHolidaysOnChange(Item)
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
	SetEnabledPreholidaySchedule(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetEnabledPreholidaySchedule(Form)
	Form.Items.PreholidaySchedule.Enabled = Form.Object.ConsiderHolidays;
EndProcedure

&AtClient
Procedure FillingTemplateChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	TemplateRow = Object.FillingTemplate.FindByID(SelectedRow);
	
	ChoiceContext = New Structure;
	ChoiceContext.Insert("Source", "FillingTemplateChoice");
	ChoiceContext.Insert("DayNumber", TemplateRow.LineNumber);
	ChoiceContext.Insert("SchedulePresentation", TemplateRow.SchedulePresentation);
	ChoiceContext.Insert("TemplateRowID", SelectedRow);
	
	FormParameters = New Structure;
	FormParameters.Insert("WorkSchedule", WorkSchedule(ChoiceContext.DayNumber));
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("Catalog.Calendars.Form.WorkSchedule", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure FillingTemplateDayAddedToScheduleOnChange(Item)
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, False);
	SetRemoveTemplateModified(ThisObject, True);
	
EndProcedure

&AtClient
Procedure PreholidayScheduleClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceContext = New Structure;
	ChoiceContext.Insert("Source", "PreholidayScheduleClick");
	ChoiceContext.Insert("DayNumber", 0);
	ChoiceContext.Insert("SchedulePresentation", PreholidaySchedule);
	
	FormParameters = New Structure;
	FormParameters.Insert("WorkSchedule", WorkSchedule(ChoiceContext.DayNumber));
	FormParameters.Insert("ReadOnly", ReadOnly);
	
	OpenForm("Catalog.Calendars.Form.WorkSchedule", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure PlanningHorizonOnChange(Item)
	
	AdjustScheduleFilled(ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Details");
	
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChange(Item)
	
	If CurrentYearNumber < Year(Object.StartDate)
		Or (ValueIsFilled(Object.EndDate) And CurrentYearNumber > Year(Object.EndDate)) Then
		CurrentYearNumber = PreviousYearNumber;
		Return;
	EndIf;
	
	WriteScheduleData = False;
	
	If ResultModified Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'Do you want to save changed data for year %1?'"), 
							Format(PreviousYearNumber, "NG=0"));
		
		Notification = New NotifyDescription("CurrentYearNumberOnChangeCompletion", ThisObject);
		ShowQueryBox(Notification, MessageText, QuestionDialogMode.YesNo);
		Return;
		
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	
	SetRemoveResultModified(ThisObject, False);
	
	Items.WorkSchedule.Refresh();
	
EndProcedure

&AtClient
Procedure WorkScheduleOnPeriodOutput(Item, PeriodAppearance)
	
	For Each PeriodAppearanceString In PeriodAppearance.Dates Do
		If ScheduleDays.Get(PeriodAppearanceString.Date) = Undefined Then
			DayTextColor = CommonUseClient.StyleColor("BusinessCalendarDayKindNotSetColor");
		Else
			DayTextColor = CommonUseClient.StyleColor("BusinessCalendarDayKindWorkdayColor");
		EndIf;
		PeriodAppearanceString.TextColor = DayTextColor;
		// Manual editing
		If ChangedDays.Get(PeriodAppearanceString.Date) = Undefined Then
			DayBgColor = CommonUseClient.StyleColor("FieldBackColor");
		Else
			DayBgColor = CommonUseClient.StyleColor("ChangedScheduleDateBackground");
		EndIf;
		PeriodAppearanceString.BackColor = DayBgColor;
	EndDo;
	
EndProcedure

&AtClient
Procedure WorkScheduleChoice(Item, SelectedDate)
	
	If ScheduleDays.Get(SelectedDate) = Undefined Then
		// Including in the schedule
		WorkSchedulesClientServer.InsertIntoFixedMap(ScheduleDays, SelectedDate, True);
		DayAddedToSchedule = True;
	Else
		// Excluding from the schedule
		WorkSchedulesClientServer.DeleteFromFixedMap(ScheduleDays, SelectedDate);
		DayAddedToSchedule = False;
	EndIf;
	
	// Save the manual date change
	WorkSchedulesClientServer.InsertIntoFixedMap(ChangedDays, SelectedDate, DayAddedToSchedule);
	
	Items.WorkSchedule.Refresh();
	
	SetRemoveManualEditingFlag(ThisObject, True);
	SetRemoveResultModified(ThisObject, True);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingTemplateSchedulePresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingTemplate.SchedulePresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingTemplate.DayAddedToSchedule");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Fill in the schedule'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingTemplateLineNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.FillingMethod");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.WorkScheduleFillingMethods.ByWeeks;

	Item.Appearance.SetParameterValue("Visible", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.IsFilledInformationText.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RequiresFilling");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.FillingResultInformationText.Name);

	FilterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ResultFilledByTemplate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	ItemFilter = FilterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ManualEditing");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PreholidaySchedule.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PreholidaySchedule");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.ConsiderHolidays");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Fill in the schedule'"));

EndProcedure

&AtClientAtServerNoContext
Procedure ConfigureFillingSettingItems(Form)
	
	CanChangeSetting = Form.Object.FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods");
	
	Form.Items.PeriodLength.ReadOnly = Not CanChangeSetting;
	Form.Items.PeriodStartDate.ReadOnly = Not CanChangeSetting;
	
	Form.Items.PeriodStartDate.AutoMarkIncomplete = CanChangeSetting;
	Form.Items.PeriodStartDate.MarkIncomplete = CanChangeSetting And Not ValueIsFilled(Form.Object.PeriodStartDate);
	
EndProcedure

&AtClientAtServerNoContext
Procedure GenerateFillingTemplate(FillingMethod, FillingTemplate, Val PeriodLength, Val PeriodStartDate = Undefined)
	
	// Generates the table for editing the template used for filling by days
	
	If FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		PeriodLength = 7;
	EndIf;
	
	While FillingTemplate.Count() > PeriodLength Do
		FillingTemplate.Delete(FillingTemplate.Count() - 1);
	EndDo;

	While FillingTemplate.Count() < PeriodLength Do
		FillingTemplate.Add();
	EndDo;
	
	If FillingMethod = PredefinedValue("Enum.WorkScheduleFillingMethods.ByWeeks") Then
		FillingTemplate[0].DayPresentation = NStr("en = 'Monday'");
		FillingTemplate[1].DayPresentation = NStr("en = 'Tuesday'");
		FillingTemplate[2].DayPresentation = NStr("en = 'Wednesday'");
		FillingTemplate[3].DayPresentation = NStr("en = 'Thursday'");
		FillingTemplate[4].DayPresentation = NStr("en = 'Friday'");
		FillingTemplate[5].DayPresentation = NStr("en = 'Saturday'");
		FillingTemplate[6].DayPresentation = NStr("en = 'Sunday'");
	Else
		DayDate = PeriodStartDate;
		For Each DayRow In FillingTemplate Do
			DayRow.DayPresentation = Format(DayDate, "DF=d.MM");
			DayDate = DayDate + 86400;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSchedulePresentation()
	
	For Each TemplateRow In Object.FillingTemplate Do
		TemplateRow.SchedulePresentation = DaySchedulePresentation(ThisObject, TemplateRow.LineNumber);
	EndDo;
	
	PreholidaySchedule = DaySchedulePresentation(ThisObject, 0);
	
EndProcedure

&AtClientAtServerNoContext
Function DaySchedulePresentation(Form, DayNumber)
	
	IntervalPresentation = "";
	Seconds = 0;
	For Each ScheduleString In Form.Object.WorkSchedule Do
		If ScheduleString.DayNumber <> DayNumber Then
			Continue;
		EndIf;
		IntervalPresentation = IntervalPresentation 
			+ StringFunctionsClientServer.SubstituteParametersInString("%1-%2, ", 
				Format(ScheduleString.BeginTime, "DF=HH:mm; DE="), 
				Format(ScheduleString.EndTime, "DF=HH:mm; DE="));
		If Not ValueIsFilled(ScheduleString.EndTime) Then
			IntervalInSeconds = EndOfDay(ScheduleString.EndTime) - ScheduleString.BeginTime + 1;
		Else
			IntervalInSeconds = ScheduleString.EndTime - ScheduleString.BeginTime;
		EndIf;
		Seconds = Seconds + IntervalInSeconds;
	EndDo;
	StringFunctionsClientServer.DeleteLastCharsInString(IntervalPresentation, 2);
	
	If Seconds = 0 Then
		Return NStr("en = 'Fill in the schedule'");
	EndIf;
	
	Hours = Round(Seconds / 3600, 1);
	
	Return StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 h. (%2)'"), Hours, IntervalPresentation);
	
EndFunction

&AtClient
Function WorkSchedule(DayNumber)
	
	DaySchedule = New Array;
	
	For Each ScheduleString In Object.WorkSchedule Do
		If ScheduleString.DayNumber = DayNumber Then
			DaySchedule.Add(New Structure("BeginTime, EndTime", ScheduleString.BeginTime, ScheduleString.EndTime));
		EndIf;
	EndDo;
	
	Return DaySchedule;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetEnabledConsiderHolidays(Form)
	
	Form.Items.ConsiderHolidays.Enabled = ValueIsFilled(Form.Object.BusinessCalendar);
	If Not Form.Items.ConsiderHolidays.Enabled Then
		Form.Object.ConsiderHolidays = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure SpecifyFillDate()
	
	QueryText = 
	"SELECT
	|	MAX(CalendarSchedules.ScheduleDate) AS Date
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkSchedule", Object.Ref);
	Selection = Query.Execute().Select();
	
	FillDate = Undefined;
	If Selection.Next() Then
		FillDate = Selection.Date;
	EndIf;	
	
	AdjustScheduleFilled(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure AdjustScheduleFilled(Form)
	
	Form.RequiresFilling = False;
	
	If Form.Parameters.Key.IsEmpty() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Form.FillDate) Then
		Form.IsFilledInformationText = NStr("en = 'The work schedule is not filled in'");
		Form.RequiresFilling = True;
	Else	
		If Not ValueIsFilled(Form.Object.PlanningHorizon) Then
			Form.IsFilledInformationText = StringFunctionsClientServer.SubstituteParametersInString(
													NStr("en = 'The work schedule is filled till %1'"), 
													Format(Form.FillDate, "DLF=D"));
		Else											
			#If Client Then
				CurrentDate = CommonUseClient.SessionDate();
			#Else
				CurrentDate = CurrentSessionDate();
			#EndIf
			EndPlanningHorizon = AddMonth(CurrentDate, Form.Object.PlanningHorizon);
			Form.IsFilledInformationText = StringFunctionsClientServer.SubstituteParametersInString(
													NStr("en = 'The work schedule is filled till %1, and the planning horizon requires filling the schedule till %2'"), 
													Format(Form.FillDate, "DLF=D"),
													Format(EndPlanningHorizon, "DLF=D"));
			If EndPlanningHorizon > Form.FillDate Then
				Form.RequiresFilling = True;
			EndIf;
		EndIf;
	EndIf;
	Form.Items.FillDecoration.Picture = ?(Form.RequiresFilling, PictureLib.Warning, PictureLib.Information);
	
EndProcedure

&AtServer
Procedure FillByTemplateAtServer(PreserveManualEditing = False)

	DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
								Object.StartDate, 
								Object.FillingMethod, 
								Object.FillingTemplate, 
								Object.WorkSchedule,
								Object.EndDate,
								Object.BusinessCalendar, 
								Object.ConsiderHolidays, 
								Object.PeriodStartDate);
	
	If ManualEditing Then
		If PreserveManualEditing Then
			// Applying manual adjustments 
			For Each KeyAndValue In ChangedDays Do
				ChangeDate = KeyAndValue.Key;
				DayAddedToSchedule = KeyAndValue.Value;
				If DayAddedToSchedule Then
					DaysIncludedInSchedule.Insert(ChangeDate, True);
				Else
					DaysIncludedInSchedule.Delete(ChangeDate);
				EndIf;
			EndDo;
		Else
			SetRemoveResultModified(ThisObject, True);
			SetRemoveManualEditingFlag(ThisObject, False);
		EndIf;
	EndIf;
	
	// Copying the result to the original filling map to ensure that the dates outside of the filling interval are not cleared
	ScheduleDaysMap = New Map(ScheduleDays);
	DayDate = Object.StartDate;
	EndDate = Object.EndDate;
	If Not ValueIsFilled(EndDate) Then
		EndDate = EndOfYear(Object.StartDate);
	EndIf;
	While DayDate <= EndDate Do
		DayAddedToSchedule = DaysIncludedInSchedule[DayDate];
		If DayAddedToSchedule = Undefined Then
			ScheduleDaysMap.Delete(DayDate);
		Else
			ScheduleDaysMap.Insert(DayDate, DayAddedToSchedule);
		EndIf;
		DayDate = DayDate + 86400;
	EndDo;
	
	ScheduleDays = New FixedMap(ScheduleDaysMap);
	
	SetRemoveResultsToTemplateMappingFlag(ThisObject, True);
	
EndProcedure

&AtServer
Procedure FillWithCurrentYearData(CopyingValue = Undefined)
	
	// Fills a form with the current year data
	
	SetCalendarField();
	
	If ValueIsFilled(CopyingValue) Then
		ScheduleRef = CopyingValue;
	Else
		ScheduleRef = Object.Ref;
	EndIf;
	
	ScheduleDays = New FixedMap(
		Catalogs.Calendars.ReadScheduleDataFromRegister(ScheduleRef, CurrentYearNumber));

	ReadManualEditingFlag(Object, CurrentYearNumber);
	
	// If there are no manual adjustments or data, generate the result by the selected year template
	If ScheduleDays.Count() = 0 And ChangedDays.Count() = 0 Then
		DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
									Object.StartDate, 
									Object.FillingMethod, 
									Object.FillingTemplate, 
									Object.WorkSchedule,
									Date(CurrentYearNumber, 12, 31),
									Object.BusinessCalendar, 
									Object.ConsiderHolidays, 
									Object.PeriodStartDate);
		ScheduleDays = New FixedMap(DaysIncludedInSchedule);
	EndIf;
	
	SetRemoveResultModified(ThisObject, False);
	SetRemoveResultsToTemplateMappingFlag(ThisObject, Not TemplateModified);

EndProcedure

&AtServer
Procedure ReadManualEditingFlag(CurrentObject, YearNumber)
	
	If CurrentObject.Ref.IsEmpty() Then
		SetRemoveManualEditingFlag(ThisObject, False);
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ManualChanges.ScheduleDate
	|FROM
	|	InformationRegister.ManualWorkScheduleChanges AS ManualChanges
	|WHERE
	|	ManualChanges.WorkSchedule = &WorkSchedule
	|	AND ManualChanges.Year = &Year");
	
	Query.SetParameter("WorkSchedule", CurrentObject.Ref);
	Query.SetParameter("Year", YearNumber);
	
	Map = New Map;
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Map.Insert(Selection.ScheduleDate, True);
	EndDo;
	ChangedDays = New FixedMap(Map);
	
	SetRemoveManualEditingFlag(ThisObject, ChangedDays.Count() > 0);
	
EndProcedure

&AtServer
Procedure SaveManualEditingFlag(CurrentObject, YearNumber)
	
	RecordSet = InformationRegisters.ManualWorkScheduleChanges.CreateRecordSet();
	RecordSet.Filter.WorkSchedule.Set(CurrentObject.Ref);
	RecordSet.Filter.Year.Set(YearNumber);
	
	For Each KeyAndValue In ChangedDays Do
		SetRow = RecordSet.Add();
		SetRow.ScheduleDate = KeyAndValue.Key;
		SetRow.WorkSchedule = CurrentObject.Ref;
		SetRow.Year = YearNumber;
	EndDo;
	
	RecordSet.Write();
	
EndProcedure

&AtServer
Procedure WriteWorkScheduleDataForYear(YearNumber)
	
	Catalogs.Calendars.WriteScheduleDataToRegister(Object.Ref, ScheduleDays, Date(YearNumber, 1, 1), Date(YearNumber, 12, 31), True);
	SaveManualEditingFlag(Object, YearNumber);
	
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
		WriteWorkScheduleDataForYear(PreviousYearNumber);
		FillWithCurrentYearData();	
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveManualEditingFlag(Form, ManualEditing)
	
	Form.ManualEditing = ManualEditing;
	
	If Not ManualEditing Then
		Form.ChangedDays = New FixedMap(New Map);
	EndIf;
	
	FillFillingResultInformationText(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveResultsToTemplateMappingFlag(Form, ResultFilledByTemplate)
	
	Form.ResultFilledByTemplate = ResultFilledByTemplate;
	
	FillFillingResultInformationText(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveTemplateModified(Form, TemplateModified)
	
	Form.TemplateModified = TemplateModified;
	
	Form.Modified = Form.TemplateModified Or Form.ResultModified;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetRemoveResultModified(Form, ResultModified)
	
	Form.ResultModified = ResultModified;
	
	Form.Modified = Form.TemplateModified Or Form.ResultModified;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillFillingResultInformationText(Form)
	
	InformationText = "";
	InformationPicture = New Picture;
	CanFillByTemplate = False;
	If Form.ManualEditing Then
		InformationText = NStr("en = 'The work schedule for the current year is changed manually. Click ""Fill by template"" to return to automatic filling.'");
		InformationPicture = PictureLib.Warning;
		CanFillByTemplate = True;
	Else
		If Form.ResultFilledByTemplate Then
			If ValueIsFilled(Form.Object.BusinessCalendar) Then
				InformationText = NStr("en = 'The work schedule is updated automatically when the business calendar for the current year is changed.'");
				InformationPicture = PictureLib.Information;
			EndIf;
		Else
			InformationText = NStr("en = 'The displayed result does not correspond to the template settings. Click ""Fill by template"" to view the work schedule with the template applied.'");
			InformationPicture = PictureLib.Warning;
			CanFillByTemplate = True;
		EndIf;
	EndIf;
	
	Form.FillingResultInformationText = InformationText;
	Form.Items.FillingResultDecoration.Picture = InformationPicture;
	Form.Items.FillByTemplate.Enabled = CanFillByTemplate;
	
	IsFilledInformationTextManualEditing(Form);
	
EndProcedure

&AtClientAtServerNoContext
Procedure IsFilledInformationTextManualEditing(Form)
	
	InformationText = "";
	InformationPicture = New Picture;
	If Form.ManualEditing Then
		InformationPicture = PictureLib.Warning;
		InformationText = NStr("en = 'The work schedule for the current year is changed manually. The changes are highlighted in the filling result.'");
	EndIf;
	
	Form.ManualEditingInformationText = InformationText;
	Form.Items.ManualEditingDecoration.Picture = InformationPicture;
	
EndProcedure

&AtServer
Procedure SetCalendarField()
	
	If CurrentYearNumber = 0 Then
		CurrentYearNumber = Year(CurrentSessionDate());
	EndIf;
	PreviousYearNumber = CurrentYearNumber;
	
	WorkSchedule = Date(CurrentYearNumber, 1, 1);
	Items.WorkSchedule.BeginOfRepresentationPeriod	= Date(CurrentYearNumber, 1, 1);
	Items.WorkSchedule.EndOfRepresentationPeriod	= Date(CurrentYearNumber, 12, 31);
		
EndProcedure

&AtClient
Procedure CurrentYearNumberOnChangeCompletion(Answer, AdditionalParameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		WriteScheduleData = True;
	EndIf;
	
	ProcessYearChange(WriteScheduleData);
	SetRemoveResultModified(ThisObject, False);
	Items.WorkSchedule.Refresh();
	
EndProcedure

#EndRegion
