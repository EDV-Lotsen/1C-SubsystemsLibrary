////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Fills the indicator table with parameters.
//
Function FillIndicators(PaymentDeductionKind)

	ReturnStructure = New Structure;
	ReturnStructure.Insert("Indicator1", "");
	ReturnStructure.Insert("Presentation1", Catalogs.CalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value1", 0);
	ReturnStructure.Insert("Indicator2", "");
	ReturnStructure.Insert("Presentation2", Catalogs.CalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value2", 0);
	ReturnStructure.Insert("Indicator3", "");
	ReturnStructure.Insert("Presentation3", Catalogs.CalculationParameters.EmptyRef());
	ReturnStructure.Insert("Value3", 0);
	
	// 1. Checking
	If NOT ValueIsFilled(PaymentDeductionKind) Then
		Return ReturnStructure;
	EndIf; 
		
	// 2. Searching for all formula parameters
	StructureOfParameters = New Structure;
	_DemoPayrollAndHRServer.AddParametersToStructure(PaymentDeductionKind.Formula, StructureOfParameters);
		
	// 3. Adding indicators
	Counter = 0;
	For each StructureParameter In StructureOfParameters Do
		
		If StructureParameter.Key = "DaysWorked"
				OR StructureParameter.Key = "HoursWorked"
				OR StructureParameter.Key = "PayRate" Then
			Continue;
		EndIf; 
					
		CalculationParameter = Catalogs.CalculationParameters.FindByAttribute("Id", StructureParameter.Key);
		If NOT ValueIsFilled(CalculationParameter) Then		
			Message = New UserMessage();
			Message.Text = NStr("en = 'The '") + CalculationParameter + NStr("en = ' parameter for the accrual (deduction) formula is not found.'") + PaymentDeductionKind;
			Message.Message();
			Continue;
		EndIf; 
		
		Counter = Counter + 1;
		
		If Counter > 3 Then
			Break;
		EndIf; 
		
		ReturnStructure["Indicator" + Counter] = StructureParameter.Key;
		ReturnStructure["Presentation" + Counter] = CalculationParameter;
		
	EndDo;	

	Return ReturnStructure;
	
EndFunction

&AtServer
// Generates a table of accruals.
//
Function GeneratePaymentsTable()

	PaymentsTable = New ValueTable;

    Array = New Array;
	
	Array.Add(Type("CatalogRef.Employees"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	PaymentsTable.Columns.Add("Employee", TypeDescription);

	Array.Add(Type("CatalogRef.Positions"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	PaymentsTable.Columns.Add("Position", TypeDescription);
	
	Array.Add(Type("CatalogRef.PaymentDeductionKinds"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	PaymentsTable.Columns.Add("PaymentDeductionKind", TypeDescription);

	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	PaymentsTable.Columns.Add("StartDate", TypeDescription);
	  
	Array.Add(Type("Date"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	PaymentsTable.Columns.Add("EndDate", TypeDescription);
		        
	Array.Add(Type("ChartOfAccountsRef.ChartOfAccounts"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	PaymentsTable.Columns.Add("AccountOfExpenses", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();

	PaymentsTable.Columns.Add("Rate", TypeDescription);

	For each TSLine In Object.PaymentsDeductions Do

		NewRow = PaymentsTable.Add();
        NewRow.Employee = TSLine.Employee;
        NewRow.Position = TSLine.Position;
		NewRow.PaymentDeductionKind = TSLine.PaymentDeductionKind;
        NewRow.StartDate = TSLine.StartDate;
        NewRow.EndDate = TSLine.EndDate;
        NewRow.AccountOfExpenses = TSLine.AccountOfExpenses;
        NewRow.Rate = TSLine.Rate;

	EndDo;
    	    
	Return PaymentsTable;

EndFunction

&AtServer
// Fills the Employees tabular section using a filter by division.
//
Procedure FillByCompany()

	Object.PaymentsDeductions.Clear();		
	Query = New Query;
	
	Query.Parameters.Insert("BegOfMonth", Object.AccountingPeriod);
	Query.Parameters.Insert("EndOfMonth", EndOfMonth(Object.AccountingPeriod));
	Query.Parameters.Insert("Company", Object.Company);
	Query.Parameters.Insert("Currency", Object.DocumentCurrency);
		
	// 1. Determining the required employees
	// 2. Determining all records of the required employees and accruals in the required division.
	Query.Text = 
	"SELECT DISTINCT
	|	NestedSelect.Employee AS Employee
	|INTO CompanyEmployees
	|FROM
	|	(SELECT
	|		EmployeesSliceLast.Employee AS Employee
	|	FROM
	|		InformationRegister.EmployeePositionsAndPayRates.SliceLast(&BegOfMonth, Company = &Company) AS EmployeesSliceLast
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		Employees.Employee
	|	FROM
	|		InformationRegister.EmployeePositionsAndPayRates AS Employees
	|	WHERE
	|		Employees.Period BETWEEN &BegOfMonth AND &EndOfMonth
	|		AND Employees.Amount <> 0
	|		AND Employees.Company = &Company) AS NestedSelect
	|;
	|
	|
	|SELECT
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.Position AS Position,
	|	Employees.PaymentDeductionKind AS PaymentDeductionKind,
	|	Employees.Amount AS Amount,
	|	Employees.AccountOfExpenses AS AccountOfExpenses,
	|	NestedSelect.Period AS Period
	|INTO RegisterRecordsEmployees
	|FROM
	|	(SELECT
	|		CompanyEmployees.Employee AS Employee,
	|		Employees.Position AS Position,
	|		MAX(Employees.Period) AS PaymentsPeriod,
	|		Employees.Period AS Period,
	|		Employees.PaymentDeductionKind AS PaymentDeductionKind,
	|		Employees.Currency AS Currency
	|	FROM
	|		CompanyEmployees AS CompanyEmployees
	|			INNER JOIN InformationRegister.EmployeePositionsAndPayRates AS Employees
	|			ON CompanyEmployees.Employee = Employees.Employee
	|				AND (Employees.Currency = &Currency)
	|	WHERE
	|		Employees.Company = &Company
	|		AND Employees.Period BETWEEN DATEADD(&BegOfMonth, DAY, 1) AND &EndOfMonth
	|	
	|	GROUP BY
	|		CompanyEmployees.Employee,
	|		Employees.Position,
	|		Employees.Period,
	|		Employees.PaymentDeductionKind,
	|		Employees.Currency) AS NestedSelect
	|		LEFT JOIN InformationRegister.EmployeePositionsAndPayRates AS Employees
	|		ON NestedSelect.Employee = Employees.Employee
	|			AND (Employees.Currency = &Currency)
	|			AND (Employees.Company = &Company)
	|			AND NestedSelect.PaymentsPeriod = Employees.Period
	|			AND NestedSelect.PaymentDeductionKind = Employees.PaymentDeductionKind
	|;
	|
	|
	|SELECT
	|	NestedSelect.Employee,
	|	NestedSelect.Period,
	|	NestedSelect.PaymentDeductionKind,
	|	NestedSelect.Amount,
	|	NestedSelect.AccountOfExpenses,
	|	Employees.Position
	|INTO RegisterRecordsPaymentsPlan
	|FROM
	|	(SELECT
	|		Employees.Employee AS Employee,
	|		Employees.Period AS Period,
	|		Employees.PaymentDeductionKind AS PaymentDeductionKind,
	|		Employees.Amount AS Amount,
	|		CASE
	|			WHEN Employees.AccountOfExpenses = VALUE(ChartOfAccounts.ChartOfAccounts.EmptyRef)
	|				THEN Employees.PaymentDeductionKind.AccountOfExpenses
	|			ELSE Employees.AccountOfExpenses
	|		END AS AccountOfExpenses,
	|		MAX(Employees.Period) AS PeriodEmployees
	|	FROM
	|		CompanyEmployees AS CompanyEmployees
	|			LEFT JOIN InformationRegister.EmployeePositionsAndPayRates AS Employees
	|			ON CompanyEmployees.Employee = Employees.Employee
	|				AND (Employees.Currency = &Currency)
	|				AND (Employees.Period BETWEEN DATEADD(&BegOfMonth, DAY, 1) AND &EndOfMonth)
	|				AND (Employees.Company = &Company)
	|	
	|	GROUP BY
	|		CASE
	|			WHEN Employees.AccountOfExpenses = VALUE(ChartOfAccounts.ChartOfAccounts.EmptyRef)
	|				THEN Employees.PaymentDeductionKind.AccountOfExpenses
	|			ELSE Employees.AccountOfExpenses
	|		END,
	|		Employees.Period,
	|		Employees.PaymentDeductionKind,
	|		Employees.Employee,
	|		Employees.Amount) AS NestedSelect
	|		LEFT JOIN InformationRegister.EmployeePositionsAndPayRates AS Employees
	|		ON NestedSelect.PeriodEmployees = Employees.Period
	|			AND (Employees.Company = &Company)
	|			AND NestedSelect.Employee = Employees.Employee
	|;
	|
	|
	|SELECT
	|	NestedSelect.Employee AS Employee,
	|	NestedSelect.Position AS Position,
	|	NestedSelect.ActivityDateBegin AS ActivityDateBegin,
	|	NestedSelect.PaymentDeductionKind AS PaymentDeductionKind,
	|	NestedSelect.Rate AS Rate,
	|	NestedSelect.AccountOfExpenses AS AccountOfExpenses
	|FROM
	|	(SELECT
	|		CompanyEmployees.Employee AS Employee,
	|		EmployeesSliceLast.Position AS Position,
	|		&BegOfMonth AS ActivityDateBegin,
	|		EmployeesSliceLast.PaymentDeductionKind AS PaymentDeductionKind,
	|		EmployeesSliceLast.Amount AS Rate,
	|		CASE
	|			WHEN EmployeesSliceLast.AccountOfExpenses = VALUE(ChartOfAccounts.ChartOfAccounts.EmptyRef)
	|				THEN EmployeesSliceLast.PaymentDeductionKind.AccountOfExpenses
	|			ELSE EmployeesSliceLast.AccountOfExpenses
	|		END AS AccountOfExpenses
	|	FROM
	|		CompanyEmployees AS CompanyEmployees
	|			INNER JOIN InformationRegister.EmployeePositionsAndPayRates.SliceLast(
	|					&BegOfMonth,
	|					Company = &Company
	|						AND Currency = &Currency) AS EmployeesSliceLast
	|			ON CompanyEmployees.Employee = EmployeesSliceLast.Employee
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN PaymentDeductionKindsPlan.Employee
	|			ELSE Employees.Employee
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN PaymentDeductionKindsPlan.Position
	|			ELSE Employees.Position
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN PaymentDeductionKindsPlan.Period
	|			ELSE Employees.Period
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN PaymentDeductionKindsPlan.PaymentDeductionKind
	|			ELSE Employees.PaymentDeductionKind
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN PaymentDeductionKindsPlan.Amount
	|			ELSE Employees.Amount
	|		END,
	|		CASE
	|			WHEN Employees.Employee IS NULL 
	|				THEN CASE
	|						WHEN PaymentDeductionKindsPlan.AccountOfExpenses = VALUE(ChartOfAccounts.ChartOfAccounts.EmptyRef)
	|							THEN PaymentDeductionKindsPlan.PaymentDeductionKind.AccountOfExpenses
	|						ELSE PaymentDeductionKindsPlan.AccountOfExpenses
	|					END
	|			ELSE CASE
	|					WHEN Employees.AccountOfExpenses = VALUE(ChartOfAccounts.ChartOfAccounts.EmptyRef)
	|						THEN Employees.PaymentDeductionKind.AccountOfExpenses
	|					ELSE Employees.AccountOfExpenses
	|				END
	|		END
	|	FROM
	|		RegisterRecordsEmployees AS Employees
	|			FULL JOIN RegisterRecordsPaymentsPlan AS PaymentDeductionKindsPlan
	|			ON Employees.Employee = PaymentDeductionKindsPlan.Employee
	|				AND Employees.Period = PaymentDeductionKindsPlan.Period
	|				AND Employees.PaymentDeductionKind = PaymentDeductionKindsPlan.PaymentDeductionKind) AS NestedSelect
	|
	|ORDER BY
	|	Employee,
	|	ActivityDateBegin
	|TOTALS BY
	|	Employee";
	
	ResultsArray = Query.ExecuteBatch();
	
	// 3. Determining period ending dates, filling the value table.
	
	EndOfMonth = BegOfDay(EndOfMonth(Object.AccountingPeriod));
	SelectionEmployee = ResultsArray[3].Choose(QueryResultIteration.ByGroups, "Employee");
	While SelectionEmployee.Next() Do
		
		Selection = SelectionEmployee.Choose();
		
		While Selection.Next() Do
			
			ReplaceDateArray = Object.PaymentsDeductions.FindRows(New Structure("EndDate, Employee, PaymentDeductionKind", EndOfMonth, Selection.Employee, Selection.PaymentDeductionKind));
			For each ArrayItem In ReplaceDateArray Do
				ArrayItem.EndDate = Selection.ActivityDateBegin - 60*60*24;
			EndDo;
			
			If ValueIsFilled(Selection.PaymentDeductionKind) Then
			
				NewRow							= Object.PaymentsDeductions.Add();
				NewRow.Employee 				= Selection.Employee;
				NewRow.Position 				= Selection.Position;				 
										
				NewRow.PaymentDeductionKind 	= Selection.PaymentDeductionKind;
				NewRow.StartDate 				= Selection.ActivityDateBegin;
				NewRow.EndDate 					= EndOfMonth;
				NewRow.Rate 					= Selection.Rate;
				
				AccountKind = Selection.AccountOfExpenses.AccountType;
				If NOT (AccountKind = Enums.AccountTypes.CostOfSales
					OR AccountKind = Enums.AccountTypes.Expense
					OR AccountKind = Enums.AccountTypes.OtherCurrentAsset
					OR AccountKind = Enums.AccountTypes.OtherNonCurrentAsset
					OR AccountKind = Enums.AccountTypes.AccountsReceivable) Then
				
					NewRow.AccountOfExpenses = ChartsOfAccounts.ChartOfAccounts.EmptyRef();					
				Else
					NewRow.AccountOfExpenses = Selection.AccountOfExpenses;				
				EndIf;
					
			EndIf; 
					
		EndDo;
		
	EndDo;
	
	// 4. Filling hours worked
		
	Query.Parameters.Insert("TablePaymentsDeductions", GeneratePaymentsTable());
	
	Query.Text =
	"SELECT
	|	TablePaymentsDeductions.Employee,
	|	TablePaymentsDeductions.Position,
	|	TablePaymentsDeductions.PaymentDeductionKind,
	|	TablePaymentsDeductions.StartDate,
	|	TablePaymentsDeductions.EndDate,
	|	TablePaymentsDeductions.Rate,
	|	TablePaymentsDeductions.AccountOfExpenses
	|INTO TablePaymentsDeductions
	|FROM
	|	&TablePaymentsDeductions AS TablePaymentsDeductions
	|;
	|
	|
	|SELECT
	|	DocumentPayment.Employee AS Employee,
	|	DocumentPayment.Position AS Position,
	|	DocumentPayment.PaymentDeductionKind AS PaymentDeductionKind,
	|	DocumentPayment.StartDate AS StartDate,
	|	DocumentPayment.EndDate AS EndDate,
	|	DocumentPayment.Rate AS Rate,
	|	DocumentPayment.AccountOfExpenses AS AccountOfExpenses,
	|	TimesheetData.DaysWorked AS DaysWorked,
	|	TimesheetData.HoursWorked,
	|	TimesheetData.TotalForPeriod
	|FROM
	|	TablePaymentsDeductions AS DocumentPayment
	|		LEFT JOIN (SELECT
	|			DocumentPayment.Employee AS Employee,
	|			SUM(Timesheet.Days) AS DaysWorked,
	|			SUM(Timesheet.Hours) AS HoursWorked,
	|			DocumentPayment.StartDate AS StartDate,
	|			DocumentPayment.EndDate AS EndDate,
	|			MAX(Timesheet.TotalForPeriod) AS TotalForPeriod
	|		FROM
	|			(SELECT DISTINCT
	|				DocumentPayment.Employee AS Employee,
	|				DocumentPayment.StartDate AS StartDate,
	|				DocumentPayment.EndDate AS EndDate
	|			FROM
	|				TablePaymentsDeductions AS DocumentPayment) AS DocumentPayment
	|				LEFT JOIN AccumulationRegister.Timesheet AS Timesheet
	|				ON DocumentPayment.Employee = Timesheet.Employee
	|					And (Timesheet.TimeKind = VALUE(Catalog.WorkTimeTypes.Work))
	|					And (Timesheet.Company = &Company)
	|					And ((NOT Timesheet.TotalForPeriod)
	|							And DocumentPayment.StartDate <= Timesheet.Period
	|							And DocumentPayment.EndDate >= Timesheet.Period
	|						OR Timesheet.TotalForPeriod
	|							And Timesheet.Period = BEGINOFPERIOD(DocumentPayment.StartDate, MONTH))
	|		
	|		GROUP BY
	|			DocumentPayment.Employee,
	|			DocumentPayment.StartDate,
	|			DocumentPayment.EndDate) AS TimesheetData
	|		ON DocumentPayment.Employee = TimesheetData.Employee
	|			And DocumentPayment.StartDate = TimesheetData.StartDate
	|			And DocumentPayment.EndDate = TimesheetData.EndDate";
	
	QueryResult = Query.ExecuteBatch()[1].Unload();
	Object.PaymentsDeductions.Load(Query.ExecuteBatch()[1].Unload()); 
		
	Object.PaymentsDeductions.Sort("Employee Asc, StartDate Asc, PaymentDeductionKind Asc");
	
	For each TabularSectionLine In Object.PaymentsDeductions Do
		
		// 1. Checking
		If NOT ValueIsFilled(TabularSectionLine.PaymentDeductionKind) Then
			Continue;
		EndIf;
		ArrayOfRepeats = QueryResult.FindRows(New Structure("Employee, PaymentDeductionKind", TabularSectionLine.Employee, TabularSectionLine.PaymentDeductionKind));
		If ArrayOfRepeats.Count() > 1 And ArrayOfRepeats[0].TotalForPeriod Then
			TabularSectionLine.DaysWorked = 0;
			TabularSectionLine.HoursWorked = 0;
			Message = New UserMessage();
			Message.Text = NStr("en = '%Employee%, %PaymentKind%: The hours worked are specified as a total for the entire period. Calculation by accruals or deductions cannot be performed.'");
			Message.Text = StrReplace(Message.Text, "%Employee%", TabularSectionLine.Employee);
			Message.Text = StrReplace(Message.Text, "%PaymentKind%", TabularSectionLine.PaymentDeductionKind);
			Message.Field = "Object.PaymentsDeductions[" + Object.PaymentsDeductions.IndexOf(TabularSectionLine) + "].Employee";
			Message.SetData(Object);
			Message.Message();
		EndIf;
		
		// 2. Clearing
		For Counter = 1 To 3 Do		
			TabularSectionLine["Indicator" + Counter] = "";
			TabularSectionLine["Presentation" + Counter] = Catalogs.CalculationParameters.EmptyRef();
			TabularSectionLine["Value" + Counter] = 0;	
		EndDo;
		
		// 3. Searching for all formula parameters
		StructureOfParameters = New Structure;
		_DemoPayrollAndHRServer.AddParametersToStructure(TabularSectionLine.PaymentDeductionKind.Formula, StructureOfParameters);
		
		// 4. Adding the indicator
		Counter = 0;
		For each StructureParameter In StructureOfParameters Do
			
			If StructureParameter.Key = "DaysWorked"
					OR StructureParameter.Key = "HoursWorked"
					OR StructureParameter.Key = "PayRate" Then
			    Continue;
			EndIf; 
						
			CalculationParameter = Catalogs.CalculationParameters.FindByAttribute("Id", StructureParameter.Key);
		 	If NOT ValueIsFilled(CalculationParameter) Then		
				Message = New UserMessage();
				Message.Text = NStr("en = 'The '") + CalculationParameter + NStr("en = ' parameter is not found for the employee in the line #'") + (Object.PaymentsDeductions.IndexOf(TabularSectionLine) + 1);
				Message.Message();			
		    EndIf; 
			
			Counter = Counter + 1;
			
			If Counter > 3 Then
				Break;
			EndIf; 
			
			TabularSectionLine["Indicator" + Counter] = StructureParameter.Key;
			TabularSectionLine["Presentation" + Counter] = CalculationParameter;
			
			If CalculationParameter.SetValueDuringPayrollCalculation Then
				Continue;
			EndIf; 
			
			// 5. Calculating the indicator
			
			FiltersStructure = New Structure;
			FiltersStructure.Insert("AccountingPeriod", 	Object.AccountingPeriod);
			FiltersStructure.Insert("Company", 				Object.Company);
			FiltersStructure.Insert("Currency", 			Object.DocumentCurrency);
			FiltersStructure.Insert("PointInTime", 			EndOfDay(TabularSectionLine.EndDate));
			FiltersStructure.Insert("BeginOfPeriod", 		TabularSectionLine.StartDate);
			FiltersStructure.Insert("EndOfPeriod", 			EndOfDay(TabularSectionLine.EndDate));
			FiltersStructure.Insert("Employee",		 		TabularSectionLine.Employee);
			FiltersStructure.Insert("EmployeeNumber",		TabularSectionLine.Employee.Code);
			FiltersStructure.Insert("TabNumber",			TabularSectionLine.Employee.Code);
			FiltersStructure.Insert("Executor",		 		TabularSectionLine.Employee);
			FiltersStructure.Insert("Position", 			TabularSectionLine.Position);
			FiltersStructure.Insert("PaymentDeductionKind", TabularSectionLine.PaymentDeductionKind);
			FiltersStructure.Insert("CustomerOrder", 		TabularSectionLine.CustomerOrder);
			FiltersStructure.Insert("CustomerOrder", 		TabularSectionLine.CustomerOrder);
			FiltersStructure.Insert("AccountOfExpenses", 	TabularSectionLine.AccountOfExpenses);
			FiltersStructure.Insert("Rate",					TabularSectionLine.Rate);
			FiltersStructure.Insert("DaysWorked",			TabularSectionLine.DaysWorked);
			FiltersStructure.Insert("HoursWorked",			TabularSectionLine.HoursWorked);			
			
			TabularSectionLine["Value" + Counter] = _DemoPayrollAndHRServer.CalculateParameterValue(FiltersStructure, CalculationParameter, NStr("en = 'for the employee in the row #'") + (Object.PaymentsDeductions.IndexOf(TabularSectionLine) + 1));
		
		EndDo;
		
	EndDo; 
	
	RefreshFormFooter();
	
EndProcedure

&AtServer
// Calculates the amount of the accrual or deduction with the formula.
//
Procedure CalculateByFormulas()

	For each PaymentsRow In Object.PaymentsDeductions Do
		
		If PaymentsRow.ManualCorrection OR NOT ValueIsFilled(PaymentsRow.PaymentDeductionKind.Formula) Then
			Continue;
		EndIf; 
		
		// 1. Adding parameters and values to the structure
		
		StructureOfParameters = New Structure;
		StructureOfParameters.Insert("PayRate", PaymentsRow.Rate);
		StructureOfParameters.Insert("DaysWorked", PaymentsRow.DaysWorked);
		StructureOfParameters.Insert("HoursWorked", PaymentsRow.HoursWorked);
		
		For Counter = 1 To 3 Do
			If ValueIsFilled(PaymentsRow["Presentation" + Counter]) Then
				StructureOfParameters.Insert(PaymentsRow["Indicator" + Counter], PaymentsRow["Value" + Counter]);
			EndIf; 
		EndDo; 
		
		
		// 2. Calculating the amount with formulas
			 
		Formula = PaymentsRow.PaymentDeductionKind.Formula;
		For each Parameter In StructureOfParameters Do
			Formula = StrReplace(Formula, "[" + Parameter.Key + "]", Format(Parameter.Value, "NDS=.; NZ=0; NG=0"));
		EndDo;
		Try
			CalculatedAmount = Eval(Formula);
		Except
			Message = New UserMessage();
			Message.Text = NStr("en = 'Failed to calculate accrual amount in the row %LineNumber%. The formula contains an error or indicators are not filled.'");
			Message.Text = StrReplace(Message.Text, "%LineNumber%", (Object.PaymentsDeductions.IndexOf(PaymentsRow) + 1));
			Message.Field = "Object.PaymentsDeductions[" + Object.PaymentsDeductions.IndexOf(PaymentsRow) + "].PaymentDeductionKind";
			Message.SetData(Object);
    		Message.Message();
			CalculatedAmount = 0;
		EndTry;
		PaymentsRow.Amount = Round(CalculatedAmount, 2); 

	EndDo;
	
	RefreshFormFooter();

EndProcedure

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

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS REQUIRED FOR MANAGING THE FORM INTERFACE

&AtServer
// Updates data in the form footer.
//
Procedure RefreshFormFooter()
	
	Document = FormAttributeToValue("Object");
	TotalsStructure = Document.GetDocumentAmount();
	DocumentAmount = TotalsStructure.DocumentAmount;
	AmountAccrued = TotalsStructure.AmountAccrued;
	AmountWithheld = TotalsStructure.AmountWithheld;
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
// OnCreateAtServer event handler.
// Performs the following actions:
// - initializes form parameters;
// - sets parameters of form functional options.
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
		Object.AccountingPeriod = BegOfMonth(CurrentDate());
	EndIf;
	
	// Setting the form attributes.
	DocumentDate = Object.Date;
	If NOT ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	DocumentCurrency = Object.DocumentCurrency;
	Company = Object.Company;
	
	RefreshFormFooter();
	
	Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	Items.Pages.CurrentPage = Items.GroupPaymentDeductionKinds;
	
	If Items.Find("PaymentsDeductionsEmployeeCode") <> Undefined Then		
		Items.PaymentsDeductionsEmployeeCode.Visible = False;		
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

&AtClient
// Calculate command handler.
//
Procedure Calculate(Command)
	
	CalculateByFormulas();
	
EndProcedure

&AtClient
// Fills the Employees tabular section using a filter by division.
//
Procedure Fill(Command)
	
	If Object.PaymentsDeductions.Count() > 0 Then
		Response = DoQueryBox(NStr("en = 'The document tabular section will be cleared. Do you want to continue?'"), QuestionDialogMode.YesNo, 0);				
		If Response <> DialogReturnCode.Yes Then
			Return;
		EndIf; 
	EndIf;
        
	FillByCompany();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ATTRIBUTE EVENT HANDLERS

&AtClient
// AccountingPeriod attribute OnChange event handler.
//
Procedure AccountingPeriodOnChange(Item)
	
	_DemoPayrollAndHRClient.OnChangeAccountingPeriod(ThisForm);
	
EndProcedure

&AtClient
// Date input field OnChange event handler.
// Assigns a new unique number to the document if it is moved to another numbering 
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
// Clears the document number and sets the form functional option parameters.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)

	// Processing the Company change event.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Company = StructureData.Company;
	
EndProcedure

&AtClient
// DocumentCurrency input field OnChange event handler.
//
Procedure DocumentCurrencyOnChange(Item)
	
	If Object.DocumentCurrency = DocumentCurrency Then
		Return;
	EndIf; 
	
	If Object.PaymentsDeductions.Count() > 0 Then
	
		Mode = QuestionDialogMode.YesNo;
		Response = DoQueryBox(NStr("en = 'The tabular sections will be cleared. Do you want to continue?'"), Mode, 0);
		If Response = DialogReturnCode.Yes Then
			Object.PaymentsDeductions.Clear();
		EndIf;		
	
	EndIf; 

	DocumentCurrency = Object.DocumentCurrency;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// TABULAR SECTION EVENT HANDLERS

&AtClient
// Payments tabular section OnStartEdit event handler.
//
Procedure PaymentsDeductionsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		
		If NOT Clone Then
			
			CurrentData 				= Items.PaymentsDeductions.CurrentData;
			
			CurrentData.StartDate 	= Object.AccountingPeriod;
			CurrentData.EndDate = EndOfMonth(Object.AccountingPeriod);
			CurrentData.ManualCorrection = True;
			
		EndIf; 
		
	EndIf;

EndProcedure

&AtClient
// Payments tabular section OnChange event handler.
//
Procedure PaymentsDeductionsOnChange(Item)
	
	RefreshFormFooter();
	
EndProcedure

&AtClient
// PaymentsDeductions tabular section PaymentDeductionKind attribute OnChange event handler.
//
Procedure PaymentsDeductionsPaymentDeductionKindOnChange(Item)

	CurrentRow = Items.PaymentsDeductions.CurrentData;
	FillPropertyValues(CurrentRow, FillIndicators(CurrentRow.PaymentDeductionKind));

    _DemoPayrollAndHRClient.PutExpensesAccountByDefault(ThisForm);

EndProcedure



