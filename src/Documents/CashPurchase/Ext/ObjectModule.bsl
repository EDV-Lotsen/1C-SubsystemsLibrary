// The procedure performs document posting
//
Procedure Posting(Cancel, Mode)
	
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
	
	RegisterRecords.Inventory.Write = True;
	For Each CurRowLineItems In LineItems Do
		If CurRowLineItems.Item.Type = Enums.InventoryTypes.Inventory Then
			Record = RegisterRecords.Inventory.Add();
			Record.RecordType = AccumulationRecordType.Receipt;
			Record.Period = Date;
			Record.Item = CurRowLineItems.Item;
			Record.Location = Location;
			If CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.WeightedAverage Then
			Else
				Record.Layer = Ref;
			EndIf;
			Record.Qty = CurRowLineItems.Quantity;				
			Record.Amount = CurRowLineItems.Quantity * CurRowLineItems.Price * ExchangeRate;
		EndIf;
	EndDo;
	
	// fill in the account posting value table with amounts
	
	PostingDatasetVAT = New ValueTable();
	PostingDatasetVAT.Columns.Add("VATAccount");
	PostingDatasetVAT.Columns.Add("AmountRC");
	
	PostingDataset = New ValueTable();
	PostingDataset.Columns.Add("Account");
	PostingDataset.Columns.Add("AmountRC");
	
	For Each CurRowLineItems in LineItems Do		
		PostingLine = PostingDataset.Add();       
		PostingLine.Account = CurRowLineItems.Item.InventoryOrExpenseAccount;
		If PriceIncludesVAT Then
			PostingLine.AmountRC = (CurRowLineItems.LineTotal - CurRowLineItems.VAT) * ExchangeRate;
		Else
			PostingLine.AmountRC = CurRowLineItems.LineTotal * ExchangeRate;
		EndIf;
		
		If CurRowLineItems.VAT > 0 Then
			PostingLineVAT = PostingDatasetVAT.Add();
			PostingLineVAT.VATAccount = _DemoVAT_FL.VATAccount(CurRowLineItems.VATCode, "Purchase");
			PostingLineVAT.AmountRC = CurRowLineItems.VAT * ExchangeRate;
		EndIf;
		
    EndDo;
	
	
	PostingDataset.GroupBy("Account", "AmountRC");
	
	NoOfPostingRows = PostingDataset.Count();
	
	// GL posting
	
	RegisterRecords.GeneralJournal.Write = True;	
	
	For i = 0 To NoOfPostingRows - 1 Do
		
		Record = RegisterRecords.GeneralJournal.AddDebit();
		Record.Account = PostingDataset[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDataset[i][1];
			
	EndDo;

	Record = RegisterRecords.GeneralJournal.AddCredit();
	Record.Account = BankAccount;
	Record.Currency = BankAccount.Currency;
	Record.Period = Date;
	If Currency = BankAccount.Currency Then
		Record.Amount = DocumentTotal;
	Else
		Record.Amount = DocumentTotal * ExchangeRate;
	EndIf;
	Record.AmountRC = DocumentTotal * ExchangeRate;
	
	PostingDatasetVAT.GroupBy("VATAccount", "AmountRC");
	NoOfPostingRows = PostingDatasetVAT.Count();
	For i = 0 To NoOfPostingRows - 1 Do
		Record = RegisterRecords.GeneralJournal.AddDebit();
		Record.Account = PostingDatasetVAT[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDatasetVAT[i][1];	
	EndDo;
	
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

	
	For Each CurRowLineItems In LineItems Do
					
		If CurRowLineItems.Item.Type = Enums.InventoryTypes.Inventory Then
											
			// check inventory balances and cancel if not sufficient
			
			CurrentBalance = 0;
								
			Query = New Query("SELECT
			                  |	InventoryBalance.QtyBalance
			                  |FROM
			                  |	AccumulationRegister.Inventory.Balance AS InventoryBalance
			                  |WHERE
			                  |	InventoryBalance.Item = &Item
			                  |	AND InventoryBalance.Location = &Location");
			Query.SetParameter("Item", CurRowLineItems.Item);
			Query.SetParameter("Location", Location);
			QueryResult = Query.Execute();
				
			If QueryResult.IsEmpty() Then
			Else
				Dataset = QueryResult.Unload();
				CurrentBalance = Dataset[0][0];
			EndIf;
							
			If CurRowLineItems.Quantity > CurrentBalance Then
				Cancel = True;
				Message = New UserMessage();
				Message.Text=NStr("en='Insufficient balance';de='Nicht ausreichende Bilanz'");
				Message.Message();
				Return;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	// Deleting bank reconciliation data
	
	Records = InformationRegisters.TransactionReconciliation.CreateRecordManager();
	Records.Document = Ref;
	Records.Account = BankAccount;
	Records.Read();
	Records.Delete();
	
EndProcedure

