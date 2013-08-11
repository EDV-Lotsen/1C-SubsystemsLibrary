////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

// Calculates the document amount.
//
Function GetDocumentAmount() Export

	PaymentsTable = New ValueTable;
    Array = New Array;
	ReturnStructure = New Structure("AmountAccrued, AmountWithheld, DocumentAmount", 0, 0, 0);
	
	Array.Add(Type("CatalogRef.PaymentDeductionKinds"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	PaymentsTable.Columns.Add("PaymentDeductionKind", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	PaymentsTable.Columns.Add("Amount", TypeDescription);
	
	For each TSLine In PaymentsDeductions Do
		NewRow = PaymentsTable.Add();
        NewRow.PaymentDeductionKind = TSLine.PaymentDeductionKind;
        NewRow.Amount = TSLine.Amount;
	EndDo;
	
	Query = New Query("SELECT
	                      |	TablePaymentsDeductions.PaymentDeductionKind,
	                      |	TablePaymentsDeductions.Amount
	                      |INTO TablePaymentsDeductions
	                      |FROM
	                      |	&TablePaymentsDeductions AS TablePaymentsDeductions
	                      |;
	                      |
	                      |
	                      |SELECT
	                      |	SUM(CASE
	                      |			WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Payment)
	                      |				THEN PayrollPaymentsDeductions.Amount
	                      |			ELSE 0
	                      |		END) AS AmountAccrued,
	                      |	SUM(CASE
	                      |			WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Payment)
	                      |				THEN 0
	                      |			ELSE PayrollPaymentsDeductions.Amount
	                      |		END) AS AmountWithheld,
	                      |	SUM(CASE
	                      |			WHEN PayrollPaymentsDeductions.PaymentDeductionKind.Type = VALUE(Enum.PaymentDeductionTypes.Payment)
	                      |				THEN PayrollPaymentsDeductions.Amount
	                      |			ELSE -1 * PayrollPaymentsDeductions.Amount
	                      |		END) AS DocumentAmount
	                      |FROM
	                      |	TablePaymentsDeductions AS PayrollPaymentsDeductions");
						  
	Query.SetParameter("TablePaymentsDeductions", PaymentsTable);
	QueryResult = Query.ExecuteBatch();
	
	If QueryResult[1].IsEmpty() Then
		Return ReturnStructure;	
	Else
		FillPropertyValues(ReturnStructure, QueryResult[1].Unload()[0]);
		Return ReturnStructure;	
	EndIf; 

EndFunction

////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

// BeforeWrite event handler.
//
Procedure BeforeWrite(Cancellation, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = GetDocumentAmount().DocumentAmount;
	
EndProcedure

// Posting event handler.
//
Procedure Posting(Cancellation, PostingMode)
	
	// Initializing additional properties for posting the document
	_DemoPayrollAndHRServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initializing the document data
	Documents.PayrollCalculation.DataInitializationDocument(Ref, AdditionalProperties);
	
	// Preparing the record sets
	_DemoPayrollAndHRServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Accounting
	_DemoPayrollAndHRServer.ReflectPaymentDeductionKinds(AdditionalProperties, RegisterRecords, Cancellation);
	_DemoPayrollAndHRServer.ReflectHumanResourcesAccounting(AdditionalProperties, RegisterRecords, Cancellation);
	_DemoPayrollAndHRServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancellation);
	//_DemoPayrollAndHRServer.ReflectGeneralJournal(AdditionalProperties, RegisterRecords, Cancellation);

	// Writing the record sets.
	_DemoPayrollAndHRServer.WriteRecordSets(ThisObject);

	// Controlling
	Documents.PayrollCalculation.RunControl(Ref, AdditionalProperties, Cancellation);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// UndoPosting event handler.
//
Procedure UndoPosting(Cancellation)
	
	// Initializing additional properties for clearing the document posting
	_DemoPayrollAndHRServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparing the record sets
	_DemoPayrollAndHRServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing the record sets
	_DemoPayrollAndHRServer.WriteRecordSets(ThisObject);
	
	// Controlling
	Documents.PayrollCalculation.RunControl(Ref, AdditionalProperties, Cancellation, True);
	
EndProcedure



