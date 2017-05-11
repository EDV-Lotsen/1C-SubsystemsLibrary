﻿
Procedure Filling(FillingData, StandardProcessing)
	
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

	
	If TypeOf(FillingData) = Type("DocumentRef.InvoicePayment") Then
		
		// Check if a Check is already created. If found - cancel.
		
		Query = New Query("SELECT
		                  |	Check.Ref
		                  |FROM
		                  |	Document.Check AS Check
		                  |WHERE
		                  |	Check.ParentDocument = &Ref");
		Query.SetParameter("Ref", FillingData.Ref);
		QueryResult = Query.Execute();
		If NOT QueryResult.IsEmpty() Then
			Message = New UserMessage();
			Message.Text=NStr("en='Check is already created based on this Invoice payment'");
			Message.Message();
			DontCreate = True;
			Return;
		EndIf;
		
		Counterparty = FillingData.Counterparty;
		Memo = FillingData.Memo;
		BankAccount = FillingData.BankAccount;
		ParentDocument = FillingData.Ref;
		DocumentTotal = FillingData.DocumentTotal;
		DocumentTotalRC = FillingData.DocumentTotalRC;
		
		AccountCurrency = CommonUse.GetAttributeValue(BankAccount, "Currency");
		ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(CurrentDate(), AccountCurrency);
		
		Number = _DemoGeneralFunctions.NextCheckNumber(BankAccount);	
		
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.CashPurchase") Then
		
		// Check if a Check is already created. If found - cancel.
		
		Query = New Query("SELECT
		                  |	Check.Ref
		                  |FROM
		                  |	Document.Check AS Check
		                  |WHERE
		                  |	Check.ParentDocument = &Ref");
		Query.SetParameter("Ref", FillingData.Ref);
		QueryResult = Query.Execute();
		If NOT QueryResult.IsEmpty() Then
			Message = New UserMessage();
			Message.Text=NStr("en='Check is already created based on this Cash purchase'");
			Message.Message();
			DontCreate = True;
			Return;
		EndIf;
		
		Counterparty = FillingData.Counterparty;
		Memo = FillingData.Memo;
		BankAccount = FillingData.BankAccount;
		ParentDocument = FillingData.Ref;
		DocumentTotal = FillingData.DocumentTotal;
		DocumentTotalRC = FillingData.DocumentTotalRC;
		
		AccountCurrency = CommonUse.GetAttributeValue(BankAccount, "Currency");
		ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(CurrentDate(), AccountCurrency);
		
		Number = _DemoGeneralFunctions.NextCheckNumber(BankAccount);	
		
	EndIf;
	
	
		  					  
EndProcedure

// Performs document posting
//
Procedure Posting(Cancel, PostingMode)
	
	If ParentDocument = Undefined Then
	
		RegisterRecords.GeneralJournal.Write = True;	
		
		VarDocumentTotal = 0;
		VarDocumentTotalRC = 0;
		For Each CurRowLineItems In LineItems Do			
			
			If CurRowLineItems.Amount >= 0 Then
				Record = RegisterRecords.GeneralJournal.AddDebit();
			Else
				Record = RegisterRecords.GeneralJournal.AddCredit();
			EndIf;
			Record.Account = CurRowLineItems.Account;
			Record.Period = Date;
			Record.Memo = CurRowLineItems.Memo;
			Record.AmountRC = SQRT(POW((CurRowLineItems.Amount * ExchangeRate),2));
			VarDocumentTotal = VarDocumentTotal + CurRowLineItems.Amount;
			VarDocumentTotalRC = VarDocumentTotalRC + CurRowLineItems.Amount * ExchangeRate;
			
		EndDo;
		
		Record = RegisterRecords.GeneralJournal.AddCredit();
		Record.Account = BankAccount;
		Record.Memo = Memo;
		Record.Currency = BankAccount.Currency;
		Record.Period = Date;
		Record.Amount = VarDocumentTotal;
		Record.AmountRC = VarDocumentTotalRC;
		
		// Writing bank reconciliation data
		
		Records = InformationRegisters.TransactionReconciliation.CreateRecordSet();
		Records.Filter.Document.Set(Ref);
		Records.Read();
		If Records.Count() = 0 Then
			Record = Records.Add();
			Record.Document = Ref;
			Record.Account = BankAccount;
			Record.Reconciled = False;
			Record.Amount = -1 * DocumentTotalRC;		
		Else
			Records[0].Account = BankAccount;
			Records[0].Amount = -1 * DocumentTotalRC;
		EndIf;
		Records.Write();
	
	EndIf;
	
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
	Records.Account = BankAccount;
	Records.Read();
	Records.Delete();

EndProcedure


