// The procedure calculates inventory cost, updates inventory balances, and posts a transaction
//
Procedure Posting(Cancel, Mode)
	
	If BegBal Then
		
		Reg = AccountingRegisters.GeneralJournal.CreateRecordSet();
		Reg.Filter.Recorder.Set(Ref);
		Reg.Clear();
		RegLine = Reg.AddDebit();
		RegLine.Account = APAccount;
		RegLine.Period = Date;
		If GetFunctionalOption("MultiCurrency") Then
			RegLine.Amount = DocumentTotal;
		Else
			RegLine.Amount = DocumentTotalRC;
		EndIf;
		RegLine.AmountRC = DocumentTotalRC;
		RegLine.Currency = Currency;
		RegLine.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Counterparty] = Counterparty;
		RegLine.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Document] = Ref;
		Reg.Write();
		
		Return;
		
	EndIf;
	
	RegisterRecords.Inventory.Write = True;
	
	PostingDatasetInvOrExp = New ValueTable();
	PostingDatasetInvOrExp.Columns.Add("InvOrExpAccount");
    PostingDatasetInvOrExp.Columns.Add("AmountRC");
		
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
				Message = New UserMessage();
				Message.Text=NStr("en='Insufficient balance'");
				Message.Message();
				Cancel = True;
				Return;
			EndIf;
			
			// inventory journal update and costing procedure
			
			ItemCost = 0;
			
			If CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.WeightedAverage Then
				
				AverageCost = 0;
				
				Query = New Query("SELECT
				                  |	SUM(InventoryBalance.QtyBalance) AS QtyBalance,
				                  |	SUM(InventoryBalance.AmountBalance) AS AmountBalance
				                  |FROM
				                  |	AccumulationRegister.Inventory.Balance AS InventoryBalance
				                  |WHERE
				                  |	InventoryBalance.Item = &Item");
				Query.SetParameter("Item", CurRowLineItems.Item);
				QueryResult = Query.Execute().Unload();
				AverageCost = QueryResult[0].AmountBalance / QueryResult[0].QtyBalance;
								
				Record = RegisterRecords.Inventory.Add();
				Record.RecordType = AccumulationRecordType.Expense;
				Record.Period = Date;
				Record.Item = CurRowLineItems.Item;
				Record.Location = Location;
				Record.Qty = CurRowLineItems.Quantity;				
				ItemCost = CurRowLineItems.Quantity * AverageCost;
				Record.Amount = ItemCost;
				
			EndIf;
			
			If CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.LIFO OR
				CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.FIFO Then
				
				ItemQty = CurRowLineItems.Quantity;
				
				If CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.LIFO Then
					Sorting = "DESC";
				Else
					Sorting = "ASC";
				EndIf;
				
				Query = New Query("SELECT
				                  |	InventoryBalance.QtyBalance,
				                  |	InventoryBalance.AmountBalance,
				                  |	InventoryBalance.Layer,
				                  |	InventoryBalance.Layer.Date AS LayerDate
				                  |FROM
				                  |	AccumulationRegister.Inventory.Balance AS InventoryBalance
				                  |WHERE
				                  |	InventoryBalance.Item = &Item
				                  |	AND InventoryBalance.Location = &Location
				                  |
				                  |ORDER BY
				                  |	LayerDate " + Sorting + "");
				Query.SetParameter("Item", CurRowLineItems.Item);
				Query.SetParameter("Location", Location);
				Selection = Query.Execute().Select();
				
				While Selection.Next() Do
					If ItemQty > 0 Then
						
						Record = RegisterRecords.Inventory.Add();
						Record.RecordType = AccumulationRecordType.Expense;
						Record.Period = Date;
						Record.Item = CurRowLineItems.Item;
						Record.Location = Location;
						Record.Layer = Selection.Layer;
						If ItemQty >= Selection.QtyBalance Then
							ItemCost = ItemCost + Selection.AmountBalance;
							Record.Qty = Selection.QtyBalance;
							Record.Amount = Selection.AmountBalance;
							ItemQty = ItemQty - Record.Qty;
						Else
							ItemCost = ItemCost + ItemQty * (Selection.AmountBalance / Selection.QtyBalance);
							Record.Qty = ItemQty;
							Record.Amount = ItemQty * (Selection.AmountBalance / Selection.QtyBalance);
							ItemQty = 0;
						EndIf;
					EndIf;
				EndDo;
				
				
			EndIf;
			
			// adding to the posting dataset
			
			PostingLineInvOrExp = PostingDatasetInvOrExp.Add();
			PostingLineInvOrExp.InvOrExpAccount = CurRowLineItems.Item.InventoryOrExpenseAccount;
			PostingLineInvOrExp.AmountRC = ItemCost;
			
		EndIf;	
					
	EndDo;

	// fill in the account posting value table with amounts
	
	PostingDataset = New ValueTable();
	PostingDataset.Columns.Add("Account");
	PostingDataset.Columns.Add("AmountRC");
	
	PostingDatasetVAT = New ValueTable();
	PostingDatasetVAT.Columns.Add("VATAccount");
	PostingDatasetVAT.Columns.Add("AmountRC");
		
	For Each CurRowLineItems in LineItems Do		
		
		If CurRowLineItems.Item.Type = Enums.InventoryTypes.NonInventory Then
			
			PostingLine = PostingDataset.Add();
			
			PostingLine.Account = CurRowLineItems.Item.InventoryOrExpenseAccount;
			LineAmount = 0;
			If PriceIncludesVAT Then
				LineAmount = (CurRowLineItems.LineTotal - CurRowLineItems.VAT) * ExchangeRate;
				PostingLine.AmountRC = LineAmount;
			Else
				LineAmount = CurRowLineItems.LineTotal * ExchangeRate; 
				PostingLine.AmountRC = LineAmount;
			EndIf;
		EndIf;	
			
		If CurRowLineItems.VAT > 0 Then
			
			PostingLineVAT = PostingDatasetVAT.Add();
			PostingLineVAT.VATAccount = _DemoVAT_FL.VATAccount(CurRowLineItems.VATCode, "Purchase");
			PostingLineVAT.AmountRC = CurRowLineItems.VAT * ExchangeRate;
							
		EndIf;
		
    EndDo;
	
	
	// GL posting
	
	RegisterRecords.GeneralJournal.Write = True;	
	
	TotalCredit = 0; 
	
	PostingDatasetInvOrExp.GroupBy("InvOrExpAccount", "AmountRC");
	NoOfPostingRows = PostingDatasetInvOrExp.Count();
	For i = 0 To NoOfPostingRows - 1 Do		
		Record = RegisterRecords.GeneralJournal.AddCredit();
		Record.Account = PostingDatasetInvOrExp[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDatasetInvOrExp[i][1];
		TotalCredit = TotalCredit + PostingDatasetInvOrExp[i][1];
	EndDo;
	
	PostingDataset.GroupBy("Account", "AmountRC");
	NoOfPostingRows = PostingDataset.Count();
	For i = 0 To NoOfPostingRows - 1 Do		
		Record = RegisterRecords.GeneralJournal.AddCredit();
		Record.Account = PostingDataset[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDataset[i][1];
		TotalCredit = TotalCredit + PostingDataset[i][1];
	EndDo;

	PostingDatasetVAT.GroupBy("VATAccount", "AmountRC");
	NoOfPostingRows = PostingDatasetVAT.Count();
	For i = 0 To NoOfPostingRows - 1 Do
		Record = RegisterRecords.GeneralJournal.AddCredit();
		Record.Account = PostingDatasetVAT[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDatasetVAT[i][1];
		TotalCredit = TotalCredit + PostingDatasetVAT[i][1];
	EndDo;
	
	Record = RegisterRecords.GeneralJournal.AddDebit();
	Record.Account = APAccount;
	Record.Period = Date;
	Record.Amount = DocumentTotal;
	Record.Currency = Currency;
	Record.AmountRC = DocumentTotal * ExchangeRate;
	Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Counterparty] = Counterparty;
	Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Document] = Ref;
	
	VarianceAmount = 0;
	VarianceAmount = DocumentTotal * ExchangeRate - TotalCredit;
	
	If VarianceAmount > 0 Then
		Record = RegisterRecords.GeneralJournal.AddCredit();
		Record.Account = Counterparty.ExpenseAccount;
		Record.Period = Date;
		Record.AmountRC = VarianceAmount;
		Record.Memo = "Purchase Return variance";
	ElsIf VarianceAmount < 0 Then
		Record = RegisterRecords.GeneralJournal.AddDebit();
		Record.Account = Counterparty.ExpenseAccount;
		Record.Period = Date;
		Record.AmountRC = VarianceAmount;
		Record.Memo = "Purchase Return variance";
    EndIf;
	
EndProcedure


// The procedure prepopulates a sales invoice when created from a goods receipt,
// vendor invoice, or purchase order.
//
Procedure Filling(FillingData, StandardProcessing)

	If TypeOf(FillingData) = Type("DocumentRef.PurchaseInvoice") Then
		Counterparty = FillingData.Counterparty;
		CounterpartyCode = FillingData.CounterpartyCode;
		DocumentTotal = FillingData.DocumentTotal;
		DocumentTotalRC = FillingData.DocumentTotalRC;
		ParentDocument = FillingData.Ref;
		Currency = FillingData.Currency;
		ExchangeRate = FillingData.ExchangeRate;
		Location = FillingData.Location;
		VATTotal = FillingData.VATTotal;
		APAccount = FillingData.APAccount;
		PriceIncludesVAT = FillingData.PriceIncludesVAT;
		
		For Each CurRowLineItems In FillingData.LineItems Do
			NewRow = LineItems.Add();
			NewRow.LineTotal = CurRowLineItems.LineTotal;
			NewRow.Price = CurRowLineItems.Price;
			NewRow.Item = CurRowLineItems.Item;
			NewRow.ItemDescription = CurRowLineItems.ItemDescription;
			NewRow.Quantity = CurRowLineItems.Quantity;
			NewRow.VAT = CurRowLineItems.VAT;
			NewRow.VATCode = CurRowLineItems.VATCode;	
		EndDo;
		
	EndIf;
	
EndProcedure
