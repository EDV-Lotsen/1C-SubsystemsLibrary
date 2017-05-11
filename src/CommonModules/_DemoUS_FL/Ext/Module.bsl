﻿//////////////////////////////////////////////////////////////////////////////// 
// THIS MODULE CONTAINS FUNCTIONS AND PROCEDURES USED BY
// THE US FINANCIAL LOCALIZATION FUNCTIONALITY
// 


// Returns the taxable sales tax type.
//
// Returned value:
// Enumerations.SalesTaxType - for the taxable type tax is calculated on the applicable amounts.
//
Function Taxable() Export
				
	Return Enums.SalesTaxTypes.Taxable;		
		
EndFunction


// Returns an item's sales tax type. If an item is of inventory type, by default it's taxable,
// if a item is non-inventory, then by default, it's non-taxable. The default taxable property can
// be changed in individual document lines.
//
// Parameter:
// Catalog.Items.
//
// Returned value:
// Enumerations.SalesTaxType - taxable - for inventory items, non-taxable for non-inventory items.
//
Function GetSalesTaxType(Item) Export
		
	If Item.Type = Enums.InventoryTypes.Inventory Then
		Return Enums.SalesTaxTypes.Taxable;
	Else
		Return Enums.SalesTaxTypes.NonTaxable;
	EndIf;
	
EndFunction

// Returns a customer's sales tax rate.
//
// Parameter:
// Catalog.Counterparties.
//
// Returned value:
// Number - a customer's tax rate (for example, 10.5%), or 0 if not defined.
//
Function GetTaxRate(Counterparty) Export
	
	Query = New Query("SELECT
	                  |	STC.TaxRate AS TR
	                  |FROM
	                  |	Catalog.SalesTaxCodes AS STC
	                  |		INNER JOIN Catalog.Counterparties AS C
	                  |		ON (C.SalesTaxCode = STC.Ref)
	                  |WHERE
	                  |	C.Ref = &Counterparty");
	
	Query.SetParameter("Counterparty", Counterparty);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return 0;
	Else
		Dataset = QueryResult.Unload();
		Return Dataset[0][0];
	EndIf;
	
EndFunction

// Returns a dataset used in 1099 reporting.
//
// Parameter:
// String - date filter for selecting GL transactions.
//
// Returned value:
// ValueTable.
//
Function Data1099(WhereCase) Export
	
	// Selecting all 1099 Accounts
	
	Query = New Query("SELECT
	                  |	ChartOfAccounts.Ref,
	                  |	USTaxCategories1099.Threshold,
	                  |	USTaxCategories1099.Description
	                  |FROM
	                  |	Catalog.USTaxCategories1099 AS USTaxCategories1099
	                  |		INNER JOIN ChartOfAccounts.ChartOfAccounts AS ChartOfAccounts
	                  |		ON ChartOfAccounts.Category1099 = USTaxCategories1099.Ref");
					  
					  
					  
	Accounts = Query.Execute().Unload();
	
	// Selecting all 1099 Vendors
	
	Query = New Query("SELECT
	                  |	Counterparties.Ref,
	                  |	Counterparties.Description
	                  |FROM
	                  |	Catalog.Counterparties AS Counterparties
	                  |WHERE
	                  |	Counterparties.Vendor1099 = TRUE");
					  
	Vendors = Query.Execute().Unload();
	
	// For each 1099 account select all GL transactions within the time period.
	// Then for each vendor filter the dataset selecting only transactions where the vendor is the
	// counterparty. Add the result to the value table, group by vendor and 1099 category.
		
	Data1099 = New ValueTable();
	Data1099.Columns.Add("Category1099");
	Data1099.Columns.Add("AmountRC");
	Data1099.Columns.Add("Vendor");	
	
	For i = 0 to Accounts.Count() - 1 Do
				
		Query = New Query("SELECT
		                  |	GeneralJournal.RecordType,
		                  |	GeneralJournal.AmountRC,
		                  |	GeneralJournal.Account,
		                  |	GeneralJournal.Recorder,
		                  |	GeneralJournal.Account.Category1099 AS Category1099
		                  |FROM
		                  |	AccountingRegister.GeneralJournal AS GeneralJournal
		                  |WHERE
		                  |	GeneralJournal.Account = &Account
						  | " + WhereCase + "");
		Query.Parameters.Insert("Account", Accounts[i].Ref);				  
		Dataset = Query.Execute().Unload();
		
		For y = 0 to Vendors.Count() - 1 Do
			
			For z = 0 To Dataset.Count() - 1 Do
				
				If Dataset[z].Recorder.Counterparty = Vendors[y].Ref Then
					
					Data1099Row = Data1099.Add();
					Data1099Row.Category1099 = Dataset[z].Category1099;
					Data1099Row.AmountRC = Dataset[z].AmountRC;
					Data1099Row.Vendor = Vendors[y].Ref;
					
				EndIf;
				
			EndDo;
			
		EndDo;
	
	EndDo;
	
	Data1099.GroupBy("Category1099, Vendor", "AmountRC");
	Data1099.Sort("Vendor");
	
	Return Data1099;
	
EndFunction
