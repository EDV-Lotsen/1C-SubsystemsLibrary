
// Generates a value tables that contains document tabular section data.
// Value tables are saved in the AdditionalProperties structure properties.
//
Procedure DataInitializationDocument(DocumentRefPayroll, StructureAdditionalProperties) Export
            
	Query = New Query(        
	"SELECT
	|	&Company AS Company,
	|	PayrollPaymentsDeductions.LineNumber AS LineNumber,
	|	PayrollPaymentsDeductions.Ref.Date AS Period,
	|	PayrollPaymentsDeductions.Ref.AccountingPeriod AS AccountingPeriod,
	|	PayrollPaymentsDeductions.Ref.DocumentCurrency AS Currency,
	|	PayrollPaymentsDeductions.Employee AS Employee,
	|	PayrollPaymentsDeductions.AccountOfExpenses AS AccountOfExpenses,
	|	PayrollPaymentsDeductions.CustomerOrder AS CustomerOrder,
	|	PayrollPaymentsDeductions.StartDate AS StartDate,
	|	PayrollPaymentsDeductions.EndDate AS EndDate,
	|	PayrollPaymentsDeductions.DaysWorked AS DaysWorked,
	|	PayrollPaymentsDeductions.HoursWorked AS HoursWorked,
	|	PayrollPaymentsDeductions.Rate AS Rate,
	|	PayrollPaymentsDeductions.PaymentDeductionKind AS PaymentDeductionKind,
	|	CAST(PayrollPaymentsDeductions.Amount * AccountsCurrencyRates.ExchangeRate * AccountingCurrencyRates.Multiplicity / (AccountingCurrencyRates.ExchangeRate * AccountsCurrencyRates.Multiplicity) AS NUMBER(15, 2)) AS Amount,
	|	PayrollPaymentsDeductions.Amount AS AmountCur
	|INTO TablePayments
	|FROM
	|	Document.PayrollCalculation.PaymentsDeductions AS PayrollPaymentsDeductions
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						Constants.DefaultCurrency
	|					FROM
	|						Constants AS Constants)) AS AccountingCurrencyRates
	|		ON (TRUE)
	|		LEFT JOIN Constants AS Constants
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CurrencyRates.SliceLast(&PointInTime, ) AS AccountsCurrencyRates
	|		ON PayrollPaymentsDeductions.Ref.DocumentCurrency = AccountsCurrencyRates.Currency
	|WHERE
	|	PayrollPaymentsDeductions.Ref = &Ref
	|;
	|
	|
	|SELECT
	|	&Company AS Company,
	|	PayrollPaymentsDeductions.Period AS Period,
	|	PayrollPaymentsDeductions.AccountingPeriod AS AccountingPeriod,
	|	PayrollPaymentsDeductions.Currency AS Currency,
	|	PayrollPaymentsDeductions.Employee AS Employee,
	|	PayrollPaymentsDeductions.StartDate AS StartDate,
	|	PayrollPaymentsDeductions.EndDate AS EndDate,
	|	PayrollPaymentsDeductions.DaysWorked AS DaysWorked,
	|	PayrollPaymentsDeductions.HoursWorked AS HoursWorked,
	|	PayrollPaymentsDeductions.Rate AS Rate,
	|	PayrollPaymentsDeductions.PaymentDeductionKind AS PaymentDeductionKind,
	|	PayrollPaymentsDeductions.Amount AS Amount,
	|	PayrollPaymentsDeductions.AmountCur AS AmountCur
	|FROM
	|	TablePayments AS PayrollPaymentsDeductions
	|;
	|
	|
	|SELECT
	|	&Company AS Company,
	|	PayrollPaymentsDeductions.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollPaymentsDeductions.AccountingPeriod AS AccountingPeriod,
	|	PayrollPaymentsDeductions.Currency AS Currency,
	|	PayrollPaymentsDeductions.Employee AS Employee,
	|	CASE
	|		WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Payment)
	|			THEN PayrollPaymentsDeductions.AmountCur
	|		ELSE -1 * PayrollPaymentsDeductions.AmountCur
	|	END AS AmountCur,
	|	CASE
	|		WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Payment)
	|			THEN PayrollPaymentsDeductions.Amount
	|		ELSE -1 * PayrollPaymentsDeductions.Amount
	|	END AS Amount,
	|	PayrollPaymentsDeductions.Employee.HumanResourcesAccount AS Account,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindGeneralJournal,
	|	&Payroll AS ContentOfAccountingRecord
	|FROM
	|	TablePayments AS PayrollPaymentsDeductions
	|WHERE
	|	PayrollPaymentsDeductions.AmountCur <> 0
	|;
	|
	|
	|SELECT
	|	PayrollPaymentsDeductions.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PayrollPaymentsDeductions.Period AS Period,
	|	&Company AS Company,
	|	PayrollPaymentsDeductions.AccountOfExpenses AS AccountOfExpenses,
	|	PayrollPaymentsDeductions.AccountOfExpenses AS Account,
	|	PayrollPaymentsDeductions.CustomerOrder AS CustomerOrder,
	|	CASE
	|		WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Deduction)
	|			THEN -1 * PayrollPaymentsDeductions.Amount
	|		ELSE PayrollPaymentsDeductions.Amount
	|	END AS Amount,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindGeneralJournal,
	|	TRUE AS FixedCost,
	|	&Payroll AS ContentOfAccountingRecord
	|FROM
	|	TablePayments AS PayrollPaymentsDeductions
	|WHERE
	|	(PayrollPaymentsDeductions.AccountOfExpenses.AccountType = VALUE(Enum.AccountTypes.OtherNonCurrentAsset)
	|			OR PayrollPaymentsDeductions.AccountOfExpenses.AccountType = VALUE(Enum.AccountTypes.CostOfSales))
	|	AND 
	| PayrollPaymentsDeductions.AmountCur <> 0
	|;
	|
	|
	|SELECT
	|	PayrollPaymentsDeductions.LineNumber AS LineNumber,
	|	PayrollPaymentsDeductions.Period AS Period,
	|	&Company AS Company,
	|	PayrollPaymentsDeductions.AccountOfExpenses AS Account,
	|	PayrollPaymentsDeductions.AccountOfExpenses AS AccountOfExpenses,
	|	CASE
	|		WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Deduction)
	|			THEN -1 * PayrollPaymentsDeductions.Amount
	|		ELSE PayrollPaymentsDeductions.Amount
	|	END AS ExpenseAmount,
	|	CASE
	|		WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Deduction)
	|			THEN -1 * PayrollPaymentsDeductions.Amount
	|		ELSE PayrollPaymentsDeductions.Amount
	|	END AS Amount,
	|	PayrollPaymentsDeductions.CustomerOrder AS CustomerOrder,
	|	VALUE(AccountingRecordType.Debit) AS RecordKindGeneralJournal,
	|	&Payroll AS ContentOfAccountingRecord
	|FROM
	|	TablePayments AS PayrollPaymentsDeductions
	|WHERE
	|	PayrollPaymentsDeductions.AccountOfExpenses.AccountType = VALUE(Enum.AccountTypes.Expense)
	|	AND 
	|   PayrollPaymentsDeductions.AmountCur <> 0
	|;
	|
	|
	|SELECT
	|	PayrollPaymentsDeductions.LineNumber AS LineNumber,
	|	PayrollPaymentsDeductions.Period AS Period,
	|	&Company AS Company,
	|	CASE
	|		WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Payment)
	|			THEN PayrollPaymentsDeductions.AccountOfExpenses
	|		ELSE PayrollPaymentsDeductions.Employee.HumanResourcesAccount
	|	END AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurrencyDr,
	|	CASE
	|		WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Payment)
	|			THEN PayrollPaymentsDeductions.Employee.HumanResourcesAccount
	|		ELSE PayrollPaymentsDeductions.AccountOfExpenses
	|	END AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurrencyCr,
	|	PayrollPaymentsDeductions.Amount AS Amount,
	|	&Payroll AS Content
	|FROM
	|	TablePayments AS PayrollPaymentsDeductions
	|WHERE
	|	PayrollPaymentsDeductions.AmountCur <> 0");
	
	Query.SetParameter("Ref", DocumentRefPayroll);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Payroll", NStr("en = 'Payroll'"));
	    	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentDeductionKinds", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableHumanResourcesAccounting", ResultsArray[2].Unload());
    StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGeneralJournal", ResultsArray[5].Unload());
	
EndProcedure

// Checks for the negative balance.
//
Procedure RunControl(DocumentRefPayroll, AdditionalProperties, Cancellation, PostingDelete = False) Export
	
	If Not _DemoPayrollAndHRServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
EndProcedure
