﻿// The procedure posts interest earned and bank service charge transactions.
//
Procedure Posting(Cancel, Mode)
	
	RegisterRecords.GeneralJournal.Write = True;
	    
	Record = RegisterRecords.GeneralJournal.AddDebit();
	Record.Account = BankAccount;
	Record.Period = InterestEarnedDate;
	Record.AmountRC = InterestEarned;

	Record = RegisterRecords.GeneralJournal.AddCredit();
	Record.Account = Constants.BankInterestEarnedAccount.Get();
	Record.Period = InterestEarnedDate;
	Record.AmountRC = InterestEarned;
	
	Record = RegisterRecords.GeneralJournal.AddCredit();
	Record.Account = BankAccount;
	Record.Period = ServiceChargeDate;
	Record.AmountRC = ServiceCharge;

	Record = RegisterRecords.GeneralJournal.AddDebit();
	Record.Account = Constants.BankServiceChargeAccount.Get();
	Record.Period = ServiceChargeDate;
	Record.AmountRC = ServiceCharge;
	
	For Each CurRowLineItems In LineItems Do
		
		If CurRowLineItems.Cleared = True Then
		
			Records = InformationRegisters.TransactionReconciliation.CreateRecordSet();
			Records.Filter.Document.Set(CurRowLineItems.Transaction);
			Records.Filter.Account.Set(BankAccount);
			Records.Read();
			Records[0].Reconciled = True;
			Records.Write();			
			
		EndIf;
		
		If CurRowLineItems.Cleared = False Then
		
			Records = InformationRegisters.TransactionReconciliation.CreateRecordSet();
			Records.Filter.Document.Set(CurRowLineItems.Transaction);
			Records.Filter.Account.Set(BankAccount);
			Records.Read();
			Records[0].Reconciled = False;
			Records.Write();			
			
		EndIf;


	EndDo;


EndProcedure


Procedure UndoPosting(Cancel)
	
	For Each CurRowLineItems In LineItems Do
		
		If CurRowLineItems.Cleared = True Then
		
			Records = InformationRegisters.TransactionReconciliation.CreateRecordSet();
			Records.Filter.Document.Set(CurRowLineItems.Transaction);
			Records.Filter.Account.Set(BankAccount);
			Records.Read();
			Records[0].Reconciled = False;
			Records.Write();
			
		EndIf;

	EndDo;

EndProcedure

