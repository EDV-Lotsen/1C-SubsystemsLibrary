﻿// The procedure posts a cash receipt document. Different transactions are creating depending whether the deposit type is
// 1 for an undeposited funds account, and 2 for a bank account, also an FX gain or loss is calculated and posted.
//
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

	
	// Query for a credit memos of a document
	Query = New Query;
	Query.Text = "SELECT
				 |	CashReceiptCreditMemos.Document,
				 |	CashReceiptCreditMemos.Payment,
				 |	CashReceiptCreditMemos.Currency,
				 |	ISNULL(-GeneralJournalBalance.AmountBalance, 0) AS BalanceFCY,
				 |	ISNULL(-GeneralJournalBalance.AmountRCBalance, 0) AS Balance
				 |FROM
				 |	Document.CashReceipt.CreditMemos AS CashReceiptCreditMemos
				 |LEFT JOIN
				 |	AccountingRegister.GeneralJournal.Balance(&Period,
				 |			Account IN (SELECT ARAccount FROM Document.SalesReturn WHERE Ref IN (SELECT DISTINCT Document FROM Document.CashReceipt.CreditMemos WHERE Ref = &Ref)),
				 |			,
				 |			ExtDimension2 IN (SELECT DISTINCT Document FROM Document.CashReceipt.CreditMemos WHERE Ref = &Ref)) AS GeneralJournalBalance
				 |			ON (CashReceiptCreditMemos.Document = ExtDimension2)
				 |WHERE
				 |	CashReceiptCreditMemos.Ref = &Ref
				 |	AND CashReceiptCreditMemos.Payment > 0
				 |ORDER BY
				 |	CashReceiptCreditMemos.LineNumber";
				 
	Query.SetParameter("Period", New Boundary(PointInTime(), BoundaryType.Excluding));
	Query.SetParameter("Ref",  Ref);
	CreditMemosVt = Query.Execute().Unload();
	
	// Define global flag of nettings (credit memo) using
	UseNettings = CreditMemosVt.Total("Payment") > 0;
	
	// Exchange Gain/Loss (here must be reusable values used)
	ExchangeGainAccount = Constants.ExchangeGain.Get();
	ExchangeLossAccount = Constants.ExchangeLoss.Get();
	
	// Write records to General Journal
	RegisterRecords.GeneralJournal.Write = True;
	
	CashPayment = 0;
	
	// Old part - cycle through document lines 
	For Each DocumentLine In LineItems Do
		
		// Get object of booking document, calculate exchange rate to default currency
		DocumentObject = DocumentLine.Document.GetObject();
		ExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Date, DocumentObject.Currency);
		 
		// Select proper attribute for booking an account
		If TypeOf(DocumentObject.Ref) = Type("DocumentRef.SalesInvoice") Then
			DocumentObjectAccount = DocumentObject.ARAccount;
			
		ElsIf TypeOf(DocumentObject.Ref) = Type("DocumentRef.PurchaseReturn") Then
			DocumentObjectAccount = DocumentObject.APAccount;
			
		EndIf;
			
		// Book value
		DocumentObjectAmount =   DocumentLine.Payment;
		DocumentObjectAmountRC = DocumentLine.Payment * DocumentObject.ExchangeRate;
		
		// Book credit amount
		Record = RegisterRecords.GeneralJournal.AddCredit();
		Record.Period =   Date;
		Record.Account =  DocumentObjectAccount;
		Record.Currency = DocumentObject.Currency;
		Record.Amount =   DocumentObjectAmount;
		Record.AmountRC = DocumentObjectAmountRC;
		Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Counterparty] =  Counterparty;
		Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Document] = DocumentObject.Ref;
		
		// Book debit amount
		// 1. Book available credit memos
		If UseNettings Then
			For Each CreditMemo In CreditMemosVt Do
				// Calculate credit value in RC
				CreditExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Date, CreditMemo.Currency);
				CreditAvailable =    CreditMemo.Payment;
				CreditAvailableRC =  CreditMemo.Payment * CreditExchangeRate; // AmountRC for a credit memo
				
				// Compare credit value with due amount
				If ?(DocumentObject.Currency = CreditMemo.Currency,
						CreditAvailable > DocumentObjectAmount,
						CreditAvailableRC > DocumentObjectAmountRC)
				Then
					// Book debit operation
					Record = RegisterRecords.GeneralJournal.AddDebit();
					Record.Period =   Date;
					Record.Account =  CreditMemo.Document.ARAccount;
					Record.Currency = CreditMemo.Currency;
					
					If DocumentObject.Currency = CreditMemo.Currency Then
						WriteOffAmount =  DocumentObjectAmount;
						Record.Amount =   DocumentObjectAmount;
						Record.AmountRC = DocumentObjectAmountRC;
						// Write-off part of the credit payment amount
						CreditMemo.Payment = CreditMemo.Payment - DocumentObjectAmount;
					Else
						WriteOffAmount =  Round(DocumentObjectAmountRC / CreditExchangeRate, 15.2);
						Record.Amount =   WriteOffAmount;
						Record.AmountRC = DocumentObjectAmountRC;
						// Write-off part of the credit payment amount
						CreditMemo.Payment = CreditMemo.Payment - WriteOffAmount;
					EndIf;
					Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Counterparty] = Counterparty;
					Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Document] = CreditMemo.Document;
					
					// Write-off current document line
					DocumentObjectAmount = 0;
					DocumentObjectAmountRC = 0;
					
					// Currency gain/loss for credit memo (later: use only in case of last write-off)
					If ExchangeRate <> CreditExchangeRate Then
						FXGainLoss = (ExchangeRate - CreditExchangeRate) * WriteOffAmount;
						If FXGainLoss < 0 Then
							Record = RegisterRecords.GeneralJournal.AddCredit();
							Record.Account = ExchangeGainAccount;
							Record.Period = Date;
							Record.AmountRC = -FXGainLoss;
							
						ElsIf FXGainLoss > 0 Then
							Record = RegisterRecords.GeneralJournal.AddDebit();
							Record.Account = ExchangeLossAccount;
							Record.Period = Date;
							Record.AmountRC = FXGainLoss;
						EndIf;
					EndIf;
					
					// No more write-off by nettings required
					Break;						
					
				Else // Credit is lower than document sum
					// Book debit operation
					Record = RegisterRecords.GeneralJournal.AddDebit();
					Record.Period =   Date;
					Record.Account =  CreditMemo.Document.ARAccount;
					Record.Currency = CreditMemo.Currency;
					Record.Amount =   CreditAvailable;
					Record.AmountRC = CreditAvailableRC;
					Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Counterparty] = Counterparty;
					Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Document] = CreditMemo.Document;
					
					// Clear used memo
					CreditMemo.Payment = 0;
					
					// Write-off part of the closed sum of document
					If DocumentObject.Currency = CreditMemo.Currency Then
						DocumentObjectAmount =   DocumentObjectAmount - CreditAvailable;
						DocumentObjectAmountRC = DocumentObjectAmountRC - CreditAvailableRC;
					Else
						WriteOffAmount =  Round(CreditAvailableRC / ExchangeRate, 15.2);
						DocumentObjectAmount =   DocumentObjectAmount - WriteOffAmount;
						DocumentObjectAmountRC = DocumentObjectAmountRC - CreditAvailableRC;
					EndIf;
					
					// Currency gain/loss for credit memo
					If ExchangeRate <> CreditExchangeRate Then
						FXGainLoss = (ExchangeRate - CreditExchangeRate) * CreditAvailable;
						If FXGainLoss < 0 Then
							Record = RegisterRecords.GeneralJournal.AddCredit();
							Record.Account = ExchangeGainAccount;
							Record.Period = Date;
							Record.AmountRC = -FXGainLoss;
							
						ElsIf FXGainLoss > 0 Then
							Record = RegisterRecords.GeneralJournal.AddDebit();
							Record.Account = ExchangeLossAccount;
							Record.Period = Date;
							Record.AmountRC = FXGainLoss;
						EndIf;
					EndIf;
				EndIf;
			EndDo;
			
			// Delete used lines from credit memos
			While CreditMemosVt.Count() > 0 AND CreditMemosVt.Get(0).Payment = 0 Do
				CreditMemosVt.Delete(0);
			EndDo;
		EndIf;	
		
		// 2. Book rest of the sum with cash
		If DocumentObjectAmount > 0 Then
			
			If DepositType = "1" Then 
				Record = RegisterRecords.GeneralJournal.AddDebit();
				Record.Period = Date;
				Record.Account = Constants.UndepositedFundsAccount.Get();
				Record.Currency = DocumentObject.Currency;
				Record.Amount =   DocumentObjectAmount;
				Record.AmountRC = DocumentObjectAmount * ExchangeRate;
			
			ElsIf DepositType = "2" Then 
				Record = RegisterRecords.GeneralJournal.AddDebit();
				Record.Period = Date;
				Record.Account = BankAccount;
				Record.Currency = BankAccount.Currency;
				If DocumentObject.Currency = BankAccount.Currency Then
					Record.Amount = DocumentObjectAmount;
				Else
					Record.Amount = DocumentObjectAmount * ExchangeRate;
				EndIf;
				Record.AmountRC = DocumentObjectAmount * ExchangeRate;
				CashPayment = CashPayment + DocumentObjectAmount * ExchangeRate; // kzuzik
			EndIf;
		EndIf;
		
		// 3. Book currency gain/loss for paid document
		FXGainLoss = (ExchangeRate - DocumentObject.ExchangeRate) * DocumentLine.Payment;
		If FXGainLoss > 0 Then
			Record = RegisterRecords.GeneralJournal.AddCredit();
			Record.Account = ExchangeGainAccount;
			Record.Period = Date;
			Record.AmountRC = FXGainLoss;
						
		ElsIf FXGainLoss < 0 Then
			Record = RegisterRecords.GeneralJournal.AddDebit();
			Record.Account = ExchangeLossAccount;
			Record.Period = Date;
			Record.AmountRC = -FXGainLoss;
		EndIf;
		
	EndDo;
	
	// Writing bank reconciliation data 
	
	If DepositType = "2" Then
		
		Records = InformationRegisters.TransactionReconciliation.CreateRecordSet();
		Records.Filter.Document.Set(Ref);
		Records.Read();
		If Records.Count() = 0 Then
			Record = Records.Add();
			Record.Document = Ref;
			Record.Account = BankAccount;
			Record.Reconciled = False;
			Record.Amount = CashPayment;		
		Else
			Records[0].Account = BankAccount;
			Records[0].Amount = CashPayment;
		EndIf;
		Records.Write();
	
	EndIf;

	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	// Query for a credit memos of a document
	Query = New Query;
	Query.Text = "SELECT
				 |	Payment,
				 |  0 AS PaymentRC,
				 |	Currency
				 |FROM
				 |	Document.CashReceipt.CreditMemos
				 |WHERE
				 |	Ref = &Ref
				 |	AND Payment > 0
				 |ORDER BY
				 |	LineNumber";
	Query.SetParameter("Ref",  Ref);
	CreditMemosVt = Query.Execute().Unload();
	For Each CreditMemo In CreditMemosVt Do
		CreditExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Date, CreditMemo.Currency);
		CreditMemo.PaymentRC = Round(CreditMemo.Payment * CreditExchangeRate, 2);
	EndDo;
	
	// Query for invoices of document	
	Query.Text = "SELECT
				 |	Payment,
				 |  0 AS PaymentRC,
				 |	Currency
				 |FROM
				 |	Document.CashReceipt.LineItems
				 |WHERE
				 |	Ref = &Ref
				 |	AND Payment > 0
				 |ORDER BY
				 |	LineNumber";
	InvoicesVt = Query.Execute().Unload();
	For Each Invoice In InvoicesVt Do
		InvoiceExchangeRate = _DemoGeneralFunctions.GetExchangeRate(Date, Invoice.Currency);
		Invoice.PaymentRC = Round(Invoice.Payment * InvoiceExchangeRate, 2);
	EndDo;
	
	// Compare both totals
	If CreditMemosVt.Total("PaymentRC") > InvoicesVt.Total("PaymentRC") Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The total credit memo payment amount can''t be greater then the total invoice payment amount'");
		Message.Message();
		Cancel = True;
		Return;
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


