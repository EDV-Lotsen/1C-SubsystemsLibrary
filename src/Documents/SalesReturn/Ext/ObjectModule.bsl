// The procedure performs document posting
//
Procedure Posting(Cancel, Mode)
	
	If BegBal Then
		
		Reg = AccountingRegisters.GeneralJournal.CreateRecordSet();
		Reg.Filter.Recorder.Set(Ref);
		Reg.Clear();
		RegLine = Reg.AddCredit();
		RegLine.Account = ARAccount;
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
	
	// create a value table for posting amounts
	
	PostingDatasetIncome = New ValueTable();
	PostingDatasetIncome.Columns.Add("IncomeAccount");
	PostingDatasetIncome.Columns.Add("AmountRC");
	
	PostingDatasetCOGS = New ValueTable();
	PostingDatasetCOGS.Columns.Add("COGSAccount");
	PostingDatasetCOGS.Columns.Add("AmountRC");	
	
	PostingDatasetInvOrExp = New ValueTable();
	PostingDatasetInvOrExp.Columns.Add("InvOrExpAccount");
    PostingDatasetInvOrExp.Columns.Add("AmountRC");		
	
	PostingDatasetVAT = New ValueTable();
	PostingDatasetVAT.Columns.Add("VATAccount");
	PostingDatasetVAT.Columns.Add("AmountRC");

	RegisterRecords.Inventory.Write = True;
	For Each CurRowLineItems In LineItems Do
		
		If CurRowLineItems.Item.Type = Enums.InventoryTypes.Inventory Then
			
			// last cost calculation
			
			LastCost = 0;
			
			If CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.WeightedAverage Then
				
				Query = New Query("SELECT
				                  |	SUM(InventoryBalance.QtyBalance) AS QtyBalance,
				                  |	SUM(InventoryBalance.AmountBalance) AS AmountBalance
				                  |FROM
				                  |	AccumulationRegister.Inventory.Balance AS InventoryBalance
				                  |WHERE
				                  |	InventoryBalance.Item = &Item");
				Query.SetParameter("Item", CurRowLineItems.Item);
				QueryResult = Query.Execute().Unload();
				LastCost = QueryResult[0].AmountBalance / QueryResult[0].QtyBalance;
				
			EndIf;
			
			If CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.LIFO OR
				CurRowLineItems.Item.CostingMethod = Enums.InventoryCostingMethods.FIFO Then
								
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
				Selection = Query.Execute().Unload();
				
				LastCost = Selection[0].AmountBalance / Selection[0].QtyBalance; 
													
			EndIf;
			
			// creating inventory layers
			
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
			LineAmount = CurRowLineItems.Quantity * LastCost;
			Record.Amount = LineAmount;
			
			// adding to posting datasets
			
			PostingLineCOGS = PostingDatasetCOGS.Add();
			PostingLineCOGS.COGSAccount = CurRowLineItems.Item.COGSAccount;
			PostingLineCOGS.AmountRC = LineAmount;
			
			PostingLineInvOrExp = PostingDatasetInvOrExp.Add();
			PostingLineInvOrExp.InvOrExpAccount = CurRowLineItems.Item.InventoryOrExpenseAccount;
			PostingLineInvOrExp.AmountRC = LineAmount;
			
		EndIf;
				
		PostingLineIncome = PostingDatasetIncome.Add();
		PostingLineIncome.IncomeAccount = CurRowLineItems.Item.IncomeAccount;
		If PriceIncludesVAT Then
			PostingLineIncome.AmountRC = (CurRowLineItems.LineTotal - CurRowLineItems.VAT) * ExchangeRate;
		Else
			PostingLineIncome.AmountRC = CurRowLineItems.LineTotal * ExchangeRate;
		EndIf;

		If CurRowLineItems.VAT > 0 Then
			
			PostingLineVAT = PostingDatasetVAT.Add();
			PostingLineVAT.VATAccount = _DemoVAT_FL.VATAccount(CurRowLineItems.VATCode, "Sales");
			PostingLineVAT.AmountRC = CurRowLineItems.VAT * ExchangeRate;
							
		EndIf;

		
	EndDo;
	
	// GL posting
	
	RegisterRecords.GeneralJournal.Write = True;	
		
	Record = RegisterRecords.GeneralJournal.AddCredit();
	Record.Account = ARAccount;
	Record.Period = Date;
	Record.Currency = Currency;
	Record.Amount = DocumentTotal;
	Record.AmountRC = DocumentTotal * ExchangeRate;
	Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Counterparty] = Counterparty;
	Record.ExtDimensions[ChartsOfCharacteristicTypes.Dimensions.Document] = Ref;
	
	PostingDatasetIncome.GroupBy("IncomeAccount", "AmountRC");
	NoOfPostingRows = PostingDatasetIncome.Count();
	For i = 0 To NoOfPostingRows - 1 Do			
		Record = RegisterRecords.GeneralJournal.AddDebit();
		Record.Account = PostingDatasetIncome[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDatasetIncome[i][1];				
	EndDo;

	PostingDatasetCOGS.GroupBy("COGSAccount", "AmountRC");
	NoOfPostingRows = PostingDatasetCOGS.Count();
	For i = 0 To NoOfPostingRows - 1 Do			
		Record = RegisterRecords.GeneralJournal.AddCredit();
		Record.Account = PostingDatasetCOGS[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDatasetCOGS[i][1];				
	EndDo;

	PostingDatasetInvOrExp.GroupBy("InvOrExpAccount", "AmountRC");
	NoOfPostingRows = PostingDatasetInvOrExp.Count();
	For i = 0 To NoOfPostingRows - 1 Do			
		Record = RegisterRecords.GeneralJournal.AddDebit();
		Record.Account = PostingDatasetInvOrExp[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDatasetInvOrExp[i][1];				
	EndDo;
			
	If SalesTax > 0 Then
		Record = RegisterRecords.GeneralJournal.AddDebit();
		Record.Account = Constants.TaxPayableAccount.Get();
		Record.Period = Date;
		Record.AmountRC = SalesTax * ExchangeRate;
	EndIf;		
	
	PostingDatasetVAT.GroupBy("VATAccount", "AmountRC");
	NoOfPostingRows = PostingDatasetVAT.Count();
	For i = 0 To NoOfPostingRows - 1 Do
		Record = RegisterRecords.GeneralJournal.AddDebit();
		Record.Account = PostingDatasetVAT[i][0];
		Record.Period = Date;
		Record.AmountRC = PostingDatasetVAT[i][1];	
	EndDo;	
	
EndProcedure

// The procedure prepopulates a sales invoice when created from a sales order, or
// sales invoice
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		Counterparty = FillingData.Counterparty;
		CounterpartyCode = FillingData.CounterpartyCode;
		DocumentTotal = FillingData.DocumentTotal;
		DocumentTotalRC = FillingData.DocumentTotalRC;
		ParentDocument = FillingData.Ref;
		SalesTax = FillingData.SalesTax;
		Currency = FillingData.Currency;
		ExchangeRate = FillingData.ExchangeRate;
		ARAccount = FillingData.ARAccount;
		Location = FillingData.Location;
		VATTotal = FillingData.VATTotal;
		ARAccount = FillingData.ARAccount;
		PriceIncludesVAT = FillingData.PriceIncludesVAT;
		
		For Each CurRowLineItems In FillingData.LineItems Do
			NewRow = LineItems.Add();
			NewRow.LineTotal = CurRowLineItems.LineTotal;
			NewRow.Price = CurRowLineItems.Price;
			NewRow.Item = CurRowLineItems.Item;
			NewRow.ItemDescription = CurRowLineItems.ItemDescription;
			NewRow.Quantity = CurRowLineItems.Quantity;
			NewRow.SalesTaxType = CurRowLineItems.SalesTaxType;
			NewRow.TaxableAmount = CurRowLineItems.TaxableAmount;
			NewRow.VAT = CurRowLineItems.VAT;
			NewRow.VATCode = CurRowLineItems.VATCode;
		EndDo;
		
	EndIf;
		
EndProcedure

Procedure UndoPosting(Cancel)
	
	If BegBal Then
		Return;
	EndIf;
	
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

EndProcedure


