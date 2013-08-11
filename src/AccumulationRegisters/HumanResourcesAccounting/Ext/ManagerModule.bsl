
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

// Procedure creates empty temporary table of records modification.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If NOT AdditionalProperties.Property("ForPosting")
	 OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	HumanResourcesAccounting.LineNumber AS LineNumber,
	|	HumanResourcesAccounting.Company AS Company,
	|	HumanResourcesAccounting.Employee AS Employee,
	|	HumanResourcesAccounting.Currency AS Currency,
	|	HumanResourcesAccounting.AccountingPeriod AS AccountingPeriod,
	|	HumanResourcesAccounting.Amount AS AmountBeforeWrite,
	|	HumanResourcesAccounting.Amount AS AmountChange,
	|	HumanResourcesAccounting.Amount AS AmountOnWrite,
	|	HumanResourcesAccounting.AmountCur AS AmountCurBeforeWrite,
	|	HumanResourcesAccounting.AmountCur AS AmountCurChange,
	|	HumanResourcesAccounting.AmountCur AS AmountCurOnWrite
	|INTO RegisterRecordsHumanResourcesAccountingChange
	|FROM
	|	AccumulationRegister.HumanResourcesAccounting AS HumanResourcesAccounting");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsHumanResourcesAccountingChange", False);
	
EndProcedure // CreateEmptyTemporaryTableChange()
