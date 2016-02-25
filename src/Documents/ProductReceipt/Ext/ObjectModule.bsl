////////////////////////////////////////////////////////////////////////////////
// OBJECT EVENT HANDLERS

Procedure Posting(Cancel, Mode)

	// Creating RegisterRecords in the Inventory accumulation register
	RegisterRecords.Inventory.Write = True;
	For Each CurRowProducts In Products Do

		Record = RegisterRecords.Inventory.Add();
		Record.RecordType = AccumulationRecordType.Receipt;
		Record.Period = Date;
		Record.Product = CurRowProducts.Product;
		Record.Warehouse = Warehouse;
		Record.Quantity = CurRowProducts.Quantity;

	EndDo;

	// Creating a record in the MutualSettlements accumulation register
	RegisterRecords.MutualSettlements.Write = True;
	Record = RegisterRecords.MutualSettlements.Add();
	Record.RecordType = AccumulationRecordType.Receipt;
	Record.Period = Date;
	Record.Counterparty = Vendor;
	Record.Currency = Currency;

	If Currency.IsEmpty() Then

		Record.Amount = Products.Total("Amount");

	Else

		Rate = InformationRegisters.CurrencyRates.GetLast(Date, New Structure("Currency", Currency)).Rate;

		If Rate = 0 Then
			Record.Amount = Products.Total("Amount");
		Else
			Record.Amount = Products.Total("Amount") / Rate;
		EndIf;

	EndIf;

EndProcedure

Procedure Filling(FillingData, StandardProcessing)

	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then

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

