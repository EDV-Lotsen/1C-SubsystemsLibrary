////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServerNoContext
// Retrieves a data set from the server for the DateOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("Datediff", _DemoPayrollAndHRServer.CheckDocumentNo(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Retrieves a record set from the server for the AgreementOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", Company);
	
	Return StructureData;
	
EndFunction

&AtClient
// Sets week days in the header of the table.
//
Procedure SetWeekDays()
	
	If Object.DataInputMethod <> InputMethodForPeriod Then
	
		MapOfWeekDays = New Map;
		MapOfWeekDays.Insert(1, "Mo");
		MapOfWeekDays.Insert(2, "Tu");
		MapOfWeekDays.Insert(3, "We");
		MapOfWeekDays.Insert(4, "Th");
		MapOfWeekDays.Insert(5, "Fr");
		MapOfWeekDays.Insert(6, "Sa");
		MapOfWeekDays.Insert(7, "Su"); 
		
		For Day = 1 To Day(EndOfMonth(Object.AccountingPeriod)) Do
			Items["TimeWorkedByDaysFirstHours" + Day].Title = MapOfWeekDays.Get(Weekday(Date(Year(Object.AccountingPeriod), Month(Object.AccountingPeriod), Day)));
		EndDo;
		
		For Day = 29 To Day(EndOfMonth(Object.AccountingPeriod)) Do
			Items["TimeWorkedByDaysFirstHours" 		+ Day].Visible 	= True;
			Items["TimeWorkedByDaysSecondHours" 	+ Day].Visible 	= True;
			Items["TimeWorkedByDaysThirdHours" 		+ Day].Visible 	= True;
			Items["TimeWorkedByDaysFirstTimeKind" 	+ Day].Visible 	= True;
			Items["TimeWorkedByDaysSecondTimeKind" 	+ Day].Visible	= True;
			Items["TimeWorkedByDaysThirdTimeKind" 	+ Day].Visible 	= True;
		EndDo;
		
		For Day = Day(EndOfMonth(Object.AccountingPeriod)) + 1 To 31 Do
			Items["TimeWorkedByDaysFirstHours" 		+ Day].Visible = False;
			Items["TimeWorkedByDaysSecondHours" 	+ Day].Visible = False;
			Items["TimeWorkedByDaysThirdHours" 		+ Day].Visible = False;
			Items["TimeWorkedByDaysFirstTimeKind" 	+ Day].Visible = False;
			Items["TimeWorkedByDaysSecondTimeKind" 	+ Day].Visible = False;
			Items["TimeWorkedByDaysThirdTimeKind" 	+ Day].Visible = False;
		EndDo;
		
	EndIf;
	
EndProcedure

// Returns the employee position.
//
&AtServerNoContext
Function FillPosition(Structure)

	Query = New Query("SELECT
	                      |	EmployeesSliceLast.Position
	                      |FROM
	                      |	InformationRegister.EmployeePositionsAndPayRates.SliceLast(
	                      |			&Date,
	                      |			Company = &Company
	                      |				And Employee = &Employee) AS EmployeesSliceLast");
						  
	Query.SetParameter("Date",		Structure.Date);					  
	Query.SetParameter("Company",	Structure.Company);					  
	Query.SetParameter("Employee",	Structure.Employee);					  
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return Catalogs.Positions.EmptyRef();
	Else
		Return Result.Unload()[0].Position;	
	EndIf; 

EndFunction

&AtServer
// Fills the tabular section with division employees based on the production calendar.
//
Procedure FillTimesheet()
	
	Query = New Query;
		
	Query.SetParameter("Company",   Company);
	Query.SetParameter("Calendar",  Company.RegularCalendar);
	Query.SetParameter("StartDate", Object.AccountingPeriod);
	Query.SetParameter("EndDate",   EndOfMonth(Object.AccountingPeriod));
	
	Query.Text =
	"SELECT
	|	EmployeesSliceLast.Employee AS Employee,
	|	EmployeesSliceLast.Position AS Position
	|INTO NeededEmployees
	|FROM
	|	InformationRegister.EmployeePositionsAndPayRates.SliceLast(&StartDate, Company = &Company) AS EmployeesSliceLast
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Employees.Employee,
	|	Employees.Position
	|FROM
	|	InformationRegister.EmployeePositionsAndPayRates AS Employees
	|WHERE
	|	Employees.Company = &Company
	|	And Employees.Period BETWEEN &StartDate And &EndDate
	|;
	|
	|
	|SELECT
	|	EmployeeCalendar.Employee AS Employee,
	|	EmployeeCalendar.Position AS Position,
	|	EmployeeCalendar.ScheduleDate AS ScheduleDate,
	|	Employees.Period AS Period,
	|	CASE
	|		WHEN Employees.Position = EmployeeCalendar.Position
	|			THEN 8
	|		ELSE 0
	|	END AS Hours,
	|	CASE
	|		WHEN Employees.Position = EmployeeCalendar.Position
	|			THEN 1
	|		ELSE 0
	|	END AS Days
	|FROM
	|	(SELECT
	|		NeededEmployees.Employee AS Employee,
	|		NeededEmployees.Position AS Position,
	|		Calendars.ScheduleDate AS ScheduleDate
	|	FROM
	|		NeededEmployees AS NeededEmployees
	|			LEFT JOIN InformationRegister.CalendarData AS Calendars
	|			ON (TRUE)
	|	WHERE
	|		Calendars.Calendar = &Calendar
	|		And Calendars.ScheduleDate BETWEEN &StartDate And &EndDate
	|		And Calendars.DayIncludedInSchedule) AS EmployeeCalendar
	|		LEFT JOIN (SELECT
	|			&StartDate AS Period,
	|			EmployeesSliceLast.Employee AS Employee,
	|			EmployeesSliceLast.Position AS Position
	|		FROM
	|			InformationRegister.EmployeePositionsAndPayRates.SliceLast(
	|					&StartDate,
	|					Company = &Company) AS EmployeesSliceLast
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			Employees.Period,
	|			Employees.Employee,
	|			Employees.Position
	|		FROM
	|			InformationRegister.EmployeePositionsAndPayRates AS Employees
	|		WHERE
	|			Employees.Company = &Company
	|			And Employees.Period BETWEEN DATEADD(&StartDate, DAY, 1) And &EndDate) AS Employees
	|		ON EmployeeCalendar.Employee = Employees.Employee
	|			And EmployeeCalendar.ScheduleDate >= Employees.Period
	|
	|ORDER BY
	|	Employee,
	|	Position,
	|	ScheduleDate,
	|	Period DESC
	|TOTALS BY
	|	Employee,
	|	Position,
	|	ScheduleDate";
				   
	QueryResult = Query.ExecuteBatch();
	
	TimeKind = Catalogs.WorkTimeTypes.Work;
	
	If Object.DataInputMethod = Enums.TimeDataInputMethods.Daily Then
		
		Object.TimeWorkedByDays.Clear();
		
		SelectionEmployee = QueryResult[1].Choose(QueryResultIteration.ByGroups, "Employee");
		While SelectionEmployee.Next() Do
		
			SelectionPosition = SelectionEmployee.Choose(QueryResultIteration.ByGroups, "Position");	
			While SelectionPosition.Next() Do
				
				NewRow 				= Object.TimeWorkedByDays.Add();
				NewRow.Employee 	= SelectionPosition.Employee;
				NewRow.Position 	= SelectionPosition.Position;
				
				SelectionScheduleDate = SelectionPosition.Choose(QueryResultIteration.ByGroups, "ScheduleDate");	
				While SelectionScheduleDate.Next() Do
				
					Selection = SelectionScheduleDate.Choose();
					While Selection.Next() Do
						
						If Selection.Hours > 0 Then
						
							Day = Day(SelectionScheduleDate.ScheduleDate);
							
							NewRow["FirstTimeKind" + Day] 	= TimeKind;
							NewRow["FirstHours" + Day] 		= Selection.Hours;	
						
						EndIf; 
						
						Break;
						
					EndDo; 
				
				EndDo; 
				
			EndDo;			
			
		EndDo;
		
	Else		
		
		Object.TimeWorkedPerPeriod.Clear();					   
					   
		SelectionEmployee = QueryResult[1].Choose(QueryResultIteration.ByGroups, "Employee");
		While SelectionEmployee.Next() Do
		
			SelectionPosition = SelectionEmployee.Choose(QueryResultIteration.ByGroups, "Position");	
			While SelectionPosition.Next() Do
				
				DaysNumber = 0;
				NumberOfHours = 0;
				
				SelectionScheduleDate = SelectionPosition.Choose(QueryResultIteration.ByGroups, "ScheduleDate");	
				While SelectionScheduleDate.Next() Do
				
					Selection = SelectionScheduleDate.Choose();
					While Selection.Next() Do
						DaysNumber 	= DaysNumber + Selection.Days;
						NumberOfHours = NumberOfHours + Selection.Hours;
						Break;
					EndDo; 
				
				EndDo; 
				
				NewRow           = Object.TimeWorkedPerPeriod.Add();
				NewRow.Employee  = SelectionPosition.Employee;
				NewRow.Position  = SelectionPosition.Position;
				NewRow.TimeKind1 = TimeKind;
				NewRow.Days1     = DaysNumber;
				NewRow.Hours1    = NumberOfHours;
				
			EndDo;			
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// Fills the list of time types that can be chosen.
// Clears the document number and sets parameters of form functional options.
// Overrides the corresponding form parameter.
//
Function GetChoiceList(RestrictionsArray)

	Query = New Query("SELECT
	                      |	WorkTimeTypes.Ref
	                      |FROM
	                      |	Catalog.WorkTimeTypes AS WorkTimeTypes
	                      |WHERE
	                      |	(NOT WorkTimeTypes.Ref In (&RestrictionsArray))
	                      |
	                      |ORDER BY
	                      |	WorkTimeTypes.Description");
						  
	Query.SetParameter("RestrictionsArray", RestrictionsArray);					  
	Selection = Query.Execute().Select();
	
	ChoiceList = New ValueList;
	
	While Selection.Next() Do
		ChoiceList.Add(Selection.Ref);	
	EndDo; 
	
	Return ChoiceList

EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS REQUIRED FOR MANAGING THE FORM INTERFACE

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
// OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	_DemoPayrollAndHRServer.FillDocumentHeader(Object,
	Parameters.CopyingValue,
	Parameters.Basis,
	DocumentStatus,
	PictureDocumentStatus,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	If NOT ValueIsFilled(Object.Ref)
		And NOT (Parameters.FillingValues.Property("AccountingPeriod") And ValueIsFilled(Parameters.FillingValues.AccountingPeriod)) Then
		Object.AccountingPeriod 	= BegOfMonth(CurrentDate());
	EndIf;
	
	// Timesheet filling methods
	InputMethodForPeriod = Enums.TimeDataInputMethods.TotalForPeriod;
	
	// Setting form attributes
	DocumentDate = Object.Date;
	If NOT ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;	
	
	Company = Object.Company;
	
	If Object.DataInputMethod = InputMethodForPeriod Then	
		Items.Pages.CurrentPage = Items.GroupTimeWorkedPerPeriod;	
	Else	
		Items.Pages.CurrentPage = Items.GroupTimeWorkedByDays;	
	EndIf;
	
	If Object.DataInputMethod <> InputMethodForPeriod Then
	
		MapOfWeekDays = New Map;
		MapOfWeekDays.Insert(1, "Mo");
		MapOfWeekDays.Insert(2, "Tu");
		MapOfWeekDays.Insert(3, "We");
		MapOfWeekDays.Insert(4, "Th");
		MapOfWeekDays.Insert(5, "Fr");
		MapOfWeekDays.Insert(6, "Sa");
		MapOfWeekDays.Insert(7, "Su"); 
		
		For Day = 1 To Day(EndOfMonth(Object.AccountingPeriod)) Do
			Items["TimeWorkedByDaysFirstHours" + Day].Title = MapOfWeekDays.Get(Weekday(Date(Year(Object.AccountingPeriod), Month(Object.AccountingPeriod), Day)));
		EndDo;
		
		For Day = 28 To Day(EndOfMonth(Object.AccountingPeriod)) Do
			Items["TimeWorkedByDaysFirstHours" 		+ Day].Visible = True;
			Items["TimeWorkedByDaysSecondHours" 	+ Day].Visible = True;
			Items["TimeWorkedByDaysThirdHours" 		+ Day].Visible = True;
			Items["TimeWorkedByDaysFirstTimeKind" 	+ Day].Visible = True;
			Items["TimeWorkedByDaysSecondTimeKind" 	+ Day].Visible = True;
			Items["TimeWorkedByDaysThirdTimeKind" 	+ Day].Visible = True;
		EndDo;
		
		For Day = Day(EndOfMonth(Object.AccountingPeriod)) + 1 To 31 Do
			Items["TimeWorkedByDaysFirstHours" 		+ Day].Visible = False;
			Items["TimeWorkedByDaysSecondHours" 	+ Day].Visible = False;
			Items["TimeWorkedByDaysThirdHours" 		+ Day].Visible = False;
			Items["TimeWorkedByDaysFirstTimeKind" 	+ Day].Visible = False;
			Items["TimeWorkedByDaysSecondTimeKind" 	+ Day].Visible = False;
			Items["TimeWorkedByDaysThirdTimeKind" 	+ Day].Visible = False;
		EndDo;
		
	EndIf;
	
	If Items.Find("TimeWorkedPerPeriodEmployeeCode") <> Undefined Then		
		Items.TimeWorkedPerPeriodEmployeeCode.Visible = False;		
	EndIf;
	If Items.Find("TimeWorkedByDaysEmployeeCode") <> Undefined Then		
		Items.TimeWorkedByDaysEmployeeCode.Visible = False;		
	EndIf;
	
EndProcedure

&AtClient
// AfterWrite event handler.
//
Procedure AfterWrite(WriteParameters)
	
	_DemoPayrollAndHRClient.RefreshDocumentStatus(Object, DocumentStatus, PictureDocumentStatus, PostingIsAllowed);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND BAR ACTION HANDLERS

////////////////////////////////////////////////////////////////////////////////
// HEADER ATTRIBUTE EVENT HANDLER

&AtClient
// AccountingPeriod attribute OnChange event handler.
//
Procedure AccountingPeriodOnChange(Item)
	
	_DemoPayrollAndHRClient.OnChangeAccountingPeriod(ThisForm);
	SetWeekDays();
	
EndProcedure

&AtClient
// DataInputMethod attribute OnChange event handler.
//
Procedure DataInputMethodOnChange(Item)
	
	If Object.DataInputMethod = InputMethodForPeriod Then	
		Items.Pages.CurrentPage = Items.GroupTimeWorkedPerPeriod;	
	Else	
		Items.Pages.CurrentPage = Items.GroupTimeWorkedByDays;	
	EndIf;
	
	If Object.DataInputMethod = InputMethodForPeriod Then
		Object.TimeWorkedByDays.Clear();
	Else
		Object.TimeWorkedPerPeriod.Clear();
	EndIf;

EndProcedure

&AtClient
// The Date input field OnChange event handler.
// Assigns a new unique number to the document if it is moved to the another numbering 
// period because its date was changed.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Processing the date change event.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.Datediff <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Company input field OnChange event handler.
// Clears the document number and sets parameters of form functional options.
// Overrides the  corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Processing the Company change event.
	Object.Number 	= "";
	Company = Object.Company;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// TABULAR SECTION EVENT HANDLER

&AtClient
// Employee input field OnChange event handler.
// Clears the document number and sets parameters of form functional options.
// Overrides the corresponding form parameter.
//
Procedure TimeWorkedPerPeriodEmployeeOnChange(Item)
	
	If NOT ValueIsFilled(Object.AccountingPeriod) Then
		Return;
	EndIf; 
	
	CurrentData = Items.TimeWorkedPerPeriod.CurrentData;
	
	Structure = New Structure;
	Structure.Insert("Date", 		EndOfMonth(Object.AccountingPeriod));
	Structure.Insert("Company",		Object.Company);
	Structure.Insert("Employee",	CurrentData.Employee);
	CurrentData.Position = 			FillPosition(Structure);
	
EndProcedure

&AtClient
// Employee input field OnChange event handler.
// Clears the document number and sets parameters of form functional options.
// Overrides the corresponding form parameter.
//
Procedure TimeWorkedByDaysEmployeeOnChange(Item)
	
	If NOT ValueIsFilled(Object.AccountingPeriod) Then
		Return;
	EndIf; 
	
	CurrentData = Items.TimeWorkedByDays.CurrentData;
	
	Structure = New Structure;
	Structure.Insert("Date", 		EndOfMonth(Object.AccountingPeriod));
	Structure.Insert("Company",		Object.Company);
	Structure.Insert("Employee",	CurrentData.Employee);
	CurrentData.Position = FillPosition(Structure);
	
EndProcedure

&AtClient
// Fill command handler.
// Clears the document number and sets parameters of form functional options.
// Overrides the corresponding form parameter.
//
Procedure Fill(Command)
	
	If Object.AccountingPeriod = '00010101000000' Then
		_DemoPayrollAndHRServer.ShowErrorMessage(Object, "Accounting period is not specified.");
		Return;
	EndIf;
	
	Mode = QuestionDialogMode.YesNo;
	If Object.TimeWorkedByDays.Count() > 0
	 OR Object.TimeWorkedPerPeriod.Count() > 0 Then
		Response = DoQueryBox(NStr("en = 'Tabular sections will be cleared. Do you want to continue?'"), Mode, 0);
		If Response = DialogReturnCode.Yes Then
			FillTimesheet();
		Else 
			Return;
		EndIf;
	Else
		FillTimesheet();
	EndIf;
	
EndProcedure

&AtClient
// TimeKind1 input field OnChange event handler.
// Clears the document number and sets parameters of form functional options.
// Overrides the corresponding form parameter.
Procedure TimeWorkedPerPeriodTimeKindStartChoice(Item, ChoiceData, StandardProcessing)	
	
	StandardProcessing = False;
	
	CurrentRow = Items.TimeWorkedPerPeriod.CurrentData;
	ItemNumber = Right(Item.Name, 1);
	
	RestrictionsArray = New Array;
	For Counter = 1 To 6 Do
		If Counter = ItemNumber Then
			Continue;		
		EndIf; 
		RestrictionsArray.Add(CurrentRow["TimeKind" + Counter]);	
	EndDo; 
	
	ChoiceData = GetChoiceList(RestrictionsArray);
	
EndProcedure

&AtClient
// FirstTimeKind input field OnChange event handler.
//
Procedure TimeWorkedByDaysFirstTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.TimeWorkedByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "TimeWorkedByDaysFirstTimeKind", "");
	
	RestrictionsArray = New Array;
	RestrictionsArray.Add(CurrentRow["SecondTimeKind" + ItemNumber]);
	RestrictionsArray.Add(CurrentRow["ThirdTimeKind"  + ItemNumber]);
	
	ChoiceData = GetChoiceList(RestrictionsArray);
	
EndProcedure

&AtClient
// SecondTimeKind input field OnChange event handler.
//
Procedure TimeWorkedByDaysSecondTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.TimeWorkedByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "TimeWorkedByDaysSecondTimeKind", "");
	
	RestrictionsArray = New Array;
	RestrictionsArray.Add(CurrentRow["FirstTimeKind" + ItemNumber]);
	RestrictionsArray.Add(CurrentRow["ThirdTimeKind" + ItemNumber]);
	
	ChoiceData = GetChoiceList(RestrictionsArray);
	
EndProcedure

&AtClient
// ThirdTimeKind input field OnChange event handler.
//
Procedure TimeWorkedByDaysThirdTimeKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentRow = Items.TimeWorkedByDays.CurrentData;
	ItemNumber = StrReplace(Item.Name, "TimeWorkedByDaysThirdTimeKind", "");
	
	RestrictionsArray = New Array;
	RestrictionsArray.Add(CurrentRow["SecondTimeKind" + ItemNumber]);
	RestrictionsArray.Add(CurrentRow["FirstTimeKind"  + ItemNumber]);
	
	ChoiceData = GetChoiceList(RestrictionsArray);
	
EndProcedure



