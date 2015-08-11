
////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// Procedure - handler of event BeforeWrite of recordset.
//
Procedure BeforeWrite(Cancellation, Replacing)
	
	If DataExchange.Load
      OR NOT AdditionalProperties.Property("ForPosting")
      OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Apply exclusive lock to the recorder current recordset.
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.HumanResourcesAccounting.RecordSet");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.SetValue("Recorder", Filter.Recorder.Value);
	Block.Lock();
	
	If NOT StructureTemporaryTables.Property("RegisterRecordsHumanResourcesAccountingChange") OR
		StructureTemporaryTables.Property("RegisterRecordsHumanResourcesAccountingChange") And NOT StructureTemporaryTables.RegisterRecordsHumanResourcesAccountingChange Then
		
		// If temporary table "RegisterRecordsHumanResourcesAccountingChange" does not exist or does not contain any records
		// about recorset change, then recordset is being written first time or balance control has been performed for this recordset.
		// Recordset current state is placed to the temporary table "RegisterRecordsHumanResourcesAccountingBeforeWrite",
		// to get, on write, new recordset change relatively to the current one.
		
		Query = New Query(
		"SELECT
		|	HumanResourcesAccounting.LineNumber AS LineNumber,
		|	HumanResourcesAccounting.Company AS Company,
		|	HumanResourcesAccounting.Employee AS Employee,
		|	HumanResourcesAccounting.Currency AS Currency,
		|	HumanResourcesAccounting.AccountingPeriod AS AccountingPeriod,
		|	CASE
		|		WHEN HumanResourcesAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN HumanResourcesAccounting.Amount
		|		ELSE -HumanResourcesAccounting.Amount
		|	END AS AmountBeforeWrite,
		|	CASE
		|		WHEN HumanResourcesAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN HumanResourcesAccounting.AmountCur
		|		ELSE -HumanResourcesAccounting.AmountCur
		|	END AS AmountCurBeforeWrite
		|INTO RegisterRecordsHumanResourcesAccountingBeforeWrite
		|FROM
		|	AccumulationRegister.HumanResourcesAccounting AS HumanResourcesAccounting
		|WHERE
		|	HumanResourcesAccounting.Recorder = &Recorder
		|	And &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	Else
		
		// If temporary table "RegisterRecordsHumanResourcesAccountingChange" exists and contains records
		// about recorset change, then recordset is being written not the first time and balance control has not been performed for this recordset.
		// Recordset current state and changes current state are placed to the temporary table "RegisterRecordsHumanResourcesAccountingBeforeWrite",
		// to get, on write, new recordset change relatively to the original one.
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsHumanResourcesAccountingChange.LineNumber AS LineNumber,
		|	RegisterRecordsHumanResourcesAccountingChange.Company AS Company,
		|	RegisterRecordsHumanResourcesAccountingChange.Employee AS Employee,
		|	RegisterRecordsHumanResourcesAccountingChange.Currency AS Currency,
		|	RegisterRecordsHumanResourcesAccountingChange.AccountingPeriod AS AccountingPeriod,
		|	RegisterRecordsHumanResourcesAccountingChange.AmountBeforeWrite AS AmountBeforeWrite,
		|	RegisterRecordsHumanResourcesAccountingChange.AmountCurBeforeWrite AS AmountCurBeforeWrite
		|INTO RegisterRecordsHumanResourcesAccountingBeforeWrite
		|FROM
		|	RegisterRecordsHumanResourcesAccountingChange AS RegisterRecordsHumanResourcesAccountingChange
		|
		|UNION ALL
		|
		|SELECT
		|	HumanResourcesAccounting.LineNumber,
		|	HumanResourcesAccounting.Company,
		|	HumanResourcesAccounting.Employee,
		|	HumanResourcesAccounting.Currency,
		|	HumanResourcesAccounting.AccountingPeriod,
		|	CASE
		|		WHEN HumanResourcesAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN HumanResourcesAccounting.Amount
		|		ELSE -HumanResourcesAccounting.Amount
		|	END,
		|	CASE
		|		WHEN HumanResourcesAccounting.RecordType = VALUE(AccumulationRecordType.Receipt)
		|			THEN HumanResourcesAccounting.AmountCur
		|		ELSE -HumanResourcesAccounting.AmountCur
		|	END
		|FROM
		|	AccumulationRegister.HumanResourcesAccounting AS HumanResourcesAccounting
		|WHERE
		|	HumanResourcesAccounting.Recorder = &Recorder
		|	And &Replacing");
		
		Query.SetParameter("Recorder", Filter.Recorder.Value);
		Query.SetParameter("Replacing", Replacing);
				
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		
	EndIf;
	
	// Temporary table "RegisterRecordsHumanResourcesAccountingChange" is being deleted
	// Information about existence of this table is being deleted as well.
	
	If StructureTemporaryTables.Property("RegisterRecordsHumanResourcesAccountingChange") Then
		
		Query = New Query("DROP RegisterRecordsHumanResourcesAccountingChange");
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.Execute();
		StructureTemporaryTables.Delete("RegisterRecordsHumanResourcesAccountingChange");
	
	EndIf;
	
EndProcedure // BeforeWrite() 

// Procedure - handler of event OnWrite of recordset.
//
Procedure OnWrite(Cancellation, Replacing)
	
	If DataExchange.Load
  OR NOT AdditionalProperties.Property("ForPosting")
  OR NOT AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// Calculate change of the new recorset relatively to the current one including accumulated changes
	// and is being placed to the temporary table "RegisterRecordsHumanResourcesAccountingChange".
	
	Query = New Query(
	"SELECT
	|	MIN(RegisterRecordsHumanResourcesAccountingChange.LineNumber) AS LineNumber,
	|	RegisterRecordsHumanResourcesAccountingChange.Company AS Company,
	|	RegisterRecordsHumanResourcesAccountingChange.Employee AS Employee,
	|	RegisterRecordsHumanResourcesAccountingChange.Currency AS Currency,
	|	RegisterRecordsHumanResourcesAccountingChange.AccountingPeriod AS AccountingPeriod,
	|	SUM(RegisterRecordsHumanResourcesAccountingChange.AmountBeforeWrite) AS AmountBeforeWrite,
	|	SUM(RegisterRecordsHumanResourcesAccountingChange.AmountChange) AS AmountChange,
	|	SUM(RegisterRecordsHumanResourcesAccountingChange.AmountOnWrite) AS AmountOnWrite,
	|	SUM(RegisterRecordsHumanResourcesAccountingChange.AmountCurBeforeWrite) AS AmountCurBeforeWrite,
	|	SUM(RegisterRecordsHumanResourcesAccountingChange.AmountCurChange) AS AmountCurChange,
	|	SUM(RegisterRecordsHumanResourcesAccountingChange.AmountCurOnWrite) AS AmountCurOnWrite
	|INTO RegisterRecordsHumanResourcesAccountingChange
	|FROM
	|	(SELECT
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.LineNumber AS LineNumber,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.Company AS Company,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.Employee AS Employee,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.Currency AS Currency,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.AccountingPeriod AS AccountingPeriod,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.AmountBeforeWrite AS AmountBeforeWrite,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.AmountBeforeWrite AS AmountChange,
	|		0 AS AmountOnWrite,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.AmountCurBeforeWrite AS AmountCurBeforeWrite,
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite.AmountCurBeforeWrite AS AmountCurChange,
	|		0 AS AmountCurOnWrite
	|	FROM
	|		RegisterRecordsHumanResourcesAccountingBeforeWrite AS RegisterRecordsHumanResourcesAccountingBeforeWrite
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		RegisterRecordsHumanResourcesAccountingOnWrite.LineNumber,
	|		RegisterRecordsHumanResourcesAccountingOnWrite.Company,
	|		RegisterRecordsHumanResourcesAccountingOnWrite.Employee,
	|		RegisterRecordsHumanResourcesAccountingOnWrite.Currency,
	|		RegisterRecordsHumanResourcesAccountingOnWrite.AccountingPeriod,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsHumanResourcesAccountingOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsHumanResourcesAccountingOnWrite.Amount
	|			ELSE RegisterRecordsHumanResourcesAccountingOnWrite.Amount
	|		END,
	|		RegisterRecordsHumanResourcesAccountingOnWrite.Amount,
	|		0,
	|		CASE
	|			WHEN RegisterRecordsHumanResourcesAccountingOnWrite.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -RegisterRecordsHumanResourcesAccountingOnWrite.AmountCur
	|			ELSE RegisterRecordsHumanResourcesAccountingOnWrite.AmountCur
	|		END,
	|		RegisterRecordsHumanResourcesAccountingOnWrite.AmountCur
	|	FROM
	|		AccumulationRegister.HumanResourcesAccounting AS RegisterRecordsHumanResourcesAccountingOnWrite
	|	WHERE
	|		RegisterRecordsHumanResourcesAccountingOnWrite.Recorder = &Recorder) AS RegisterRecordsHumanResourcesAccountingChange
	|
	|GROUP BY
	|	RegisterRecordsHumanResourcesAccountingChange.Company,
	|	RegisterRecordsHumanResourcesAccountingChange.Employee,
	|	RegisterRecordsHumanResourcesAccountingChange.Currency,
	|	RegisterRecordsHumanResourcesAccountingChange.AccountingPeriod
	|
	|HAVING
	|	(SUM(RegisterRecordsHumanResourcesAccountingChange.AmountChange) <> 0
	|		OR SUM(RegisterRecordsHumanResourcesAccountingChange.AmountCurChange) <> 0)
	|
	|INDEX BY
	|	Company,
	|	Employee,
	|	Currency,
	|	AccountingPeriod");
	
	Query.SetParameter("Recorder", Filter.Recorder.Value);
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	
	QueryResult = Query.Execute();
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// New changes have been placed to the temporary table "RegisterRecordsHumanResourcesAccountingChange".
	// Add information about existence of this table and that it contains records about changes.
	StructureTemporaryTables.Insert("RegisterRecordsHumanResourcesAccountingChange", QueryResultSelection.Count > 0);
	
	// Temporary table "RegisterRecordsHumanResourcesAccountingBeforeWrite" is being deleted
	Query = New Query("DROP RegisterRecordsHumanResourcesAccountingBeforeWrite");
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	Query.Execute();
	
EndProcedure // OnWrite()
