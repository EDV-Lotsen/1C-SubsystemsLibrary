
////////////////////////////////////////////////////////////////////////////////
// Sales Invoice: Object module
//
////////////////////////////////////////////////////////////////////////////////
// OBJECT EVENTS HANDLERS

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	// Save document parameters before posting the document
	If WriteMode = DocumentWriteMode.Posting
	Or WriteMode = DocumentWriteMode.UndoPosting Then
	
		// Save custom document parameters
		Orders = LineItems.UnloadColumn("Order");
		_DemoGeneralFunctions.NormalizeArray(Orders);
	
		// Common filling of parameters
		DocumentParameters = New Structure("Ref, Date, IsNew,   Posted, ManualAdjustment, Metadata,   Orders",
		                                    Ref, Date, IsNew(), Posted, ManualAdjustment, Metadata(), Orders);
		_DemoDocumentPosting.PrepareDataStructuresBeforeWrite(AdditionalProperties, DocumentParameters, Cancel, WriteMode, PostingMode);
	EndIf;
		
	// Prcheck of register balances to complete filling of document posting
	If WriteMode = DocumentWriteMode.Posting Then
		
		// Precheck of document data, calculation of temporary data, required for document posting
		If (Not ManualAdjustment) And (Orders.Count() > 0) Then
			DocumentParameters = New Structure("Ref, PointInTime,   Counterparty, LineItems",
			                                    Ref, PointInTime(), Counterparty, LineItems.Unload(, "Order, Item, Quantity"));
			Documents.SalesInvoice.PrepareDataBeforeWrite(AdditionalProperties, DocumentParameters, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// 1. Common postings clearing / reactivate manual ajusted postings
	_DemoDocumentPosting.PrepareRecordSetsForPosting(AdditionalProperties, RegisterRecords);
	
	// 2. Skip manually adjusted documents
	If ManualAdjustment Then
		Return;
	EndIf;

	// 3. Create structures with document data to pass it on the server
	_DemoDocumentPosting.PrepareDataStructuresBeforePosting(AdditionalProperties);
	
	// 4. Collect document data, available for posing, and fill created structure 
	Documents.SalesInvoice.PrepareDataStructuresForPosting(Ref, AdditionalProperties, RegisterRecords);

	// 5. Fill register records with document's postings
	_DemoDocumentPosting.FillRecordSets(AdditionalProperties, RegisterRecords, Cancel);

	// 6. Write document postings to register
	_DemoDocumentPosting.WriteRecordSets(AdditionalProperties, RegisterRecords);

	// 7. Check register blanaces according to document's changes
	_DemoDocumentPosting.CheckPostingResults(AdditionalProperties, RegisterRecords, Cancel);

	// 8. Clear used temporary document data
	_DemoDocumentPosting.ClearDataStructuresAfterPosting(AdditionalProperties);
	
	
	// OLD Posting
	
	IncomeBooking = True;
	
	If BegBal Then
		
		Reg = AccountingRegisters.GeneralJournal.CreateRecordSet();
		Reg.Filter.Recorder.Set(Ref);
		Reg.Clear();
		RegLine = Reg.AddDebit();
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
	
	RegisterRecords.Inventory.Write = True;
	
	If IncomeBooking Then
		
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
					Message.Text=NStr("en='Insufficient balance'");
					Message.Message();
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
				
				PostingLineCOGS = PostingDatasetCOGS.Add();
				PostingLineCOGS.COGSAccount = CurRowLineItems.Item.COGSAccount;
				PostingLineCOGS.AmountRC = ItemCost;
				
				PostingLineInvOrExp = PostingDatasetInvOrExp.Add();
				PostingLineInvOrExp.InvOrExpAccount = CurRowLineItems.Item.InventoryOrExpenseAccount;
				PostingLineInvOrExp.AmountRC = ItemCost;
				
			EndIf;				
						
			// fill in the account posting value table with amounts
			
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
		
	EndIf;
	
	
	If IncomeBooking Then
		
		// GL posting
		
		RegisterRecords.GeneralJournal.Write = True;	
					
		Record = RegisterRecords.GeneralJournal.AddDebit();
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
			Record = RegisterRecords.GeneralJournal.AddCredit();
			Record.Account = PostingDatasetIncome[i][0];
			Record.Period = Date;
			Record.AmountRC = PostingDatasetIncome[i][1];				
		EndDo;

		PostingDatasetCOGS.GroupBy("COGSAccount", "AmountRC");
		NoOfPostingRows = PostingDatasetCOGS.Count();
		For i = 0 To NoOfPostingRows - 1 Do			
			Record = RegisterRecords.GeneralJournal.AddDebit();
			Record.Account = PostingDatasetCOGS[i][0];
			Record.Period = Date;
			Record.AmountRC = PostingDatasetCOGS[i][1];				
		EndDo;

		PostingDatasetInvOrExp.GroupBy("InvOrExpAccount", "AmountRC");
		NoOfPostingRows = PostingDatasetInvOrExp.Count();
		For i = 0 To NoOfPostingRows - 1 Do			
			Record = RegisterRecords.GeneralJournal.AddCredit();
			Record.Account = PostingDatasetInvOrExp[i][0];
			Record.Period = Date;
			Record.AmountRC = PostingDatasetInvOrExp[i][1];				
		EndDo;
				
		If SalesTax > 0 Then
			Record = RegisterRecords.GeneralJournal.AddCredit();
			Record.Account = Constants.TaxPayableAccount.Get();
			Record.Period = Date;
			Record.AmountRC = SalesTax * ExchangeRate;
		EndIf;		

		PostingDatasetVAT.GroupBy("VATAccount", "AmountRC");
		NoOfPostingRows = PostingDatasetVAT.Count();
		For i = 0 To NoOfPostingRows - 1 Do
			Record = RegisterRecords.GeneralJournal.AddCredit();
			Record.Account = PostingDatasetVAT[i][0];
			Record.Period = Date;
			Record.AmountRC = PostingDatasetVAT[i][1];	
		EndDo;	
					
	EndIf;
	 	 	
EndProcedure

Procedure UndoPosting(Cancel)

	// 1. Common posting clearing / deactivate manual ajusted postings
	_DemoDocumentPosting.PrepareRecordSetsForPostingClearing(AdditionalProperties, RegisterRecords);
	
	// 2. Skip manually adjusted documents
	If ManualAdjustment Then
		Return;
	EndIf;
	
	// 3. Create structures with document data to pass it on the server
	_DemoDocumentPosting.PrepareDataStructuresBeforePosting(AdditionalProperties);
	
	// 4. Collect document data, required for posing clearing, and fill created structure 
	Documents.SalesInvoice.PrepareDataStructuresForPostingClearing(Ref, AdditionalProperties, RegisterRecords);
	
	// 5. Write document postings to register
	_DemoDocumentPosting.WriteRecordSets(AdditionalProperties, RegisterRecords);

	// 6. Check register blanaces according to document's changes
	_DemoDocumentPosting.CheckPostingResults(AdditionalProperties, RegisterRecords, Cancel);

	// 7. Clear used temporary document data
	_DemoDocumentPosting.ClearDataStructuresAfterPosting(AdditionalProperties);

EndProcedure

Procedure OnCopy(CopiedObject)
	
	// Clear manual ajustment attribute
	ManualAdjustment = False;
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	Var TabularSectionData; Cancel = False;
	
	// Filling on the base of other referenced object
	If FillingData <> Undefined Then
		
		// 0. Custom check of sales order for interactive generate of sales invoice on the base of sales order
		If (TypeOf(FillingData) = Type("DocumentRef.SalesOrder"))
		And Not Documents.SalesInvoice.CheckStatusOfSalesOrder(FillingData) Then
			Cancel = True;
			Return;
		EndIf;		
		
		// 1. Common filling of parameters
		DocumentParameters = New Structure("Ref, Date, Metadata",
		                                    Ref, ?(ValueIsFilled(Date), Date, CurrentSessionDate()), Metadata());
		_DemoDocumentFilling.PrepareDataStructuresBeforeFilling(AdditionalProperties, DocumentParameters, FillingData, Cancel);
		
		// 2. Cancel filling on failed data
		If Cancel Then
			Return;
		EndIf;
			
		// 3. Collect document data, available for filling, and fill created structure 
		Documents.SalesInvoice.PrepareDataStructuresForFilling(Ref, AdditionalProperties);
			
		// 4. Check collected data
		_DemoDocumentFilling.CheckDataStructuresOnFilling(AdditionalProperties, Cancel);
		
		// 5. Fill document fields
		If Not Cancel Then
			// Fill "draft" values to attributes (all including non-critical fields will be filled)
			FillPropertyValues(ThisObject, AdditionalProperties.Filling.FillingTables.Table_Attributes[0]);
			
			// Fill checked unique values to attributes (critical fields will be filled)
			FillPropertyValues(ThisObject, AdditionalProperties.Filling.FillingTables.Table_Check[0]);
			
			// Fill line items
			For Each TabularSection In AdditionalProperties.Metadata.TabularSections Do
				If AdditionalProperties.Filling.FillingTables.Property("Table_" + TabularSection.Name, TabularSectionData) Then
					ThisObject[TabularSection.Name].Load(TabularSectionData);
				EndIf;
			EndDo;
		EndIf;
		
		// 6. Clear used temporary document data
		_DemoDocumentFilling.ClearDataStructuresAfterFilling(AdditionalProperties);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Check doubles in items (to be sure of proper orders placement)
	_DemoGeneralFunctions.CheckDoubleItems(Ref, LineItems, "Order, Item, LineNumber", Cancel);
	
EndProcedure
