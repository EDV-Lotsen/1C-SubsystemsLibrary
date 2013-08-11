// BeforeWrite event handler.
//
Procedure BeforeWrite(Cancellation, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Employees.Total("PaymentAmount");
	
EndProcedure 

// Fills the Employees tabular section by accrual balance.
//
Procedure FillByBalanceAtServer() Export	
	
	Query = New Query;
	Query.Text = "SELECT
	             |	HumanResourcesAccountingBalances.Employee,
	             |	SUM(CASE
	             |			WHEN &AccountsCurrency = &DocumentCurrency
	             |				THEN HumanResourcesAccountingBalances.AmountCurBalance
	             |			ELSE CAST(HumanResourcesAccountingBalances.AmountCurBalance * &ExchangeRate / &Multiplicity AS NUMBER(15, 2))
	             |		END) AS PaymentAmount,
	             |	SUM(HumanResourcesAccountingBalances.AmountCurBalance) AS AccountsAmount
	             |FROM
	             |	AccumulationRegister.HumanResourcesAccounting.Balance(
	             |			,
	             |			Company = &Company
	             |				AND AccountingPeriod = &AccountingPeriod
	             |				AND Currency = &AccountsCurrency) AS HumanResourcesAccountingBalances
	             |WHERE
	             |	HumanResourcesAccountingBalances.AmountCurBalance > 0
	             |
	             |GROUP BY
	             |	HumanResourcesAccountingBalances.Employee
	             |
	             |ORDER BY
	             |	HumanResourcesAccountingBalances.Employee.Description";
	
	Query.SetParameter("AccountingPeriod",	AccountingPeriod);
	Query.SetParameter("Company",			Company);
	Query.SetParameter("AccountsCurrency",	AccountsCurrency);
	Query.SetParameter("DocumentCurrency",	DocumentCurrency);
	Query.SetParameter("ExchangeRate",		ExchangeRate);
	Query.SetParameter("Multiplicity",		Multiplicity);
	
	Employees.Load(Query.Execute().Unload());
	
EndProcedure

// Fills tabular section Employees by the division.
//
Procedure FillByCompanyAtServer() Export	
		
	Query = New Query;
	Query.Text = "SELECT DISTINCT
	             |	Employees.Employee AS Employee
	             |FROM
	             |	(SELECT
	             |		EmployeesSliceLast.Employee AS Employee
	             |	FROM
	             |		InformationRegister.EmployeePositionsAndPayRates.SliceLast(&AccountingPeriod, Company = &Company) AS EmployeesSliceLast
	             |	
	             |	UNION ALL
	             |	
	             |	SELECT
	             |		Employees.Employee
	             |	FROM
	             |		InformationRegister.EmployeePositionsAndPayRates AS Employees
	             |	WHERE
	             |		Employees.Company = &Company
	             |		AND Employees.Period BETWEEN &AccountingPeriod AND ENDOFPERIOD(&AccountingPeriod, MONTH)) AS Employees
	             |
	             |GROUP BY
	             |	Employees.Employee
	             |
	             |ORDER BY
	             |	Employee";
	
	Query.SetParameter("AccountingPeriod", 		AccountingPeriod);
	Query.SetParameter("Company", 				Company);
	
	Employees.Load(Query.Execute().Unload());
	
EndProcedure
