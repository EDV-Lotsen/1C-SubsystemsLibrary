
//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS 
// 

Procedure Posting(Cancel, Mode)
	// Generating the MutualSettlements accumulation RegisterRecords
	RegisterRecords.MutualSettlements.Write = True;
	Record = RegisterRecords.MutualSettlements.Add();
	Record.RecordType = AccumulationRecordType.Receipt;
	Record.Period = Date;
	Record.Counterparty = Customer;
	Record.Currency = Currency;
	Record.Amount = Amount;
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	If TypeOf(FillingData) = Type("DocumentRef.ProductExpense") Then
		Currency = FillingData.Currency;
		Customer = FillingData.Customer;
		Company = FillingData.Company;
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
		
		Customer = FillingData.Ref;
	EndIf;
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	//Removing the currency from the checking attributes if the accounting in currency
	//is not performed for this company
	If Not GetFunctionalOption("Multicurrency", New Structure("Company", Company)) Then
		CheckedAttributes.Delete(CheckedAttributes.Find("Currency"));
	EndIf;	
	
EndProcedure
