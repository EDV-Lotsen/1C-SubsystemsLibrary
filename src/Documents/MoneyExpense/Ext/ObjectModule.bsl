
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

Procedure Posting(Cancel, Mode)
	// Generating the MutualSettlements accumulation RegisterRecords
	RegisterRecords.MutualSettlements.Write = True;
	Record = RegisterRecords.MutualSettlements.Add();
	Record.RecordType = AccumulationRecordType.Expense;
	Record.Period = Date;
	Record.Counterparty = Vendor;
	Record.Amount = Amount;
	Record.Currency = Currency;
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	If TypeOf(FillingData) = Type("DocumentRef.ProductReceipt") Then
		Currency = FillingData.Currency;
		Vendor   = FillingData.Vendor;
		Company  = FillingData.Company;
		Total    = FillingData.Products.Total("Amount");
	ElsIf TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		QueryByCounterparty = New Query("SELECT
		                                   |	Counterparties.IsFolder
		                                   |FROM
		                                   |	Catalog.Counterparties AS Counterparties
		                                   |WHERE
		                                   |	Counterparties.Ref = &CounterpartyRef");
		QueryByCounterparty.SetParameter("CounterpartyRef", FillingData);
		Selection = QueryByCounterparty.Execute().Select();
		If Selection.Next() And Selection.IsFolder Then
			Return;
		EndIf;
		
		Vendor = FillingData.Ref;
	EndIf;
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	//Removing the currency from the checking attributes if the accounting in currency
	//is not performed for this company
	If Not GetFunctionalOption("Multicurrency", New Structure("Company", Company)) Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Currency"));
	EndIf;	
	
EndProcedure
