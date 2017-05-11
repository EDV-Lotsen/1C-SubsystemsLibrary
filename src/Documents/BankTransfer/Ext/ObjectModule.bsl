﻿
Procedure Posting(Cancel, PostingMode)
	
	// preventing posting if already included in a bank rec
	
	Query = New Query("SELECT
					  |	TransactionReconciliation.Document
					  |FROM
					  |	InformationRegister.TransactionReconciliation AS TransactionReconciliation
					  |WHERE
					  |	TransactionReconciliation.Document = &Ref
					  |	AND TransactionReconciliation.Reconciled = TRUE");
	Query.SetParameter("Ref", Ref);
	Selection = Query.Execute();
	
	If NOT Selection.IsEmpty() Then
		
		Message = New UserMessage();
		Message.Text=NStr("en='This document is already included in a bank reconciliation. Please remove it from the bank rec first.'");
		Message.Message();
		Cancel = True;
		Return;
		
	EndIf;

	// end preventing posting if already included in a bank rec
	
	RegisterRecords.GeneralJournal.Write = True;
	    
	Record = RegisterRecords.GeneralJournal.AddDebit();
	Record.Account = AccountTo;
	Record.Period = Date;
	Record.Currency = _DemoGeneralFunctionsCached.DefaultCurrency();
	Record.Amount = Amount;
	Record.AmountRC = Amount;
	
	Record = RegisterRecords.GeneralJournal.AddCredit();
	Record.Account = AccountFrom;
	Record.Period = Date;
	Record.Currency = _DemoGeneralFunctionsCached.DefaultCurrency();
	Record.Amount = Amount;
	Record.AmountRC = Amount;
	
	// Writing bank reconciliation data
		
	Records = InformationRegisters.TransactionReconciliation.CreateRecordSet();
	Records.Filter.Document.Set(Ref);
	Records.Read();
	If Records.Count() = 0 Then		
		Record = Records.Add();
		Record.Document = Ref;
		Record.Account = AccountFrom;
		Record.Reconciled = False;
		Record.Amount = -1 * Amount;
		
		Record = Records.Add();
		Record.Document = Ref;
		Record.Account = AccountTo;
		Record.Reconciled = False;
		Record.Amount = Amount;		
	Else
		Records[0].Account = AccountFrom;
		Records[0].Amount = -1 * Amount;
		Records[1].Account = AccountTo;
		Records[1].Amount = Amount;
	EndIf;
	Records.Write();

EndProcedure

Procedure UndoPosting(Cancel)
	
	// preventing posting if already included in a bank rec
	
	Query = New Query("SELECT
	                  |	TransactionReconciliation.Document
	                  |FROM
	                  |	InformationRegister.TransactionReconciliation AS TransactionReconciliation
	                  |WHERE
	                  |	TransactionReconciliation.Document = &Ref
	                  |	AND TransactionReconciliation.Reconciled = TRUE");
	Query.SetParameter("Ref", Ref);
	Selection = Query.Execute();
	
	If NOT Selection.IsEmpty() Then
		
		Message = New UserMessage();
		Message.Text=NStr("en='This document is already included in a bank reconciliation. Please remove it from the bank rec first.'");
		Message.Message();
		Cancel = True;
		Return;
		
	EndIf;

	// end preventing posting if already included in a bank rec
	
	// Deleting bank reconciliation data
	
	Records = InformationRegisters.TransactionReconciliation.CreateRecordManager();
	Records.Document = Ref;
	Records.Account = AccountFrom;
	Records.Read();
	Records.Delete();
	
	Records = InformationRegisters.TransactionReconciliation.CreateRecordManager();
	Records.Document = Ref;
	Records.Account = AccountTo;
	Records.Read();
	Records.Delete();

EndProcedure

