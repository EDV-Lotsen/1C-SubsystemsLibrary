Procedure Filling(FillingData, StandardProcessing)
    
    If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
        
		PriceKind = FillingData.PriceKind;
		Customer = FillingData.Ref;
        
    ElsIf TypeOf(FillingData) = Type("CatalogRef.Products") Then
        
        NewRow = Products.Add();
        NewRow.Product = FillingData.Ref;
        NewRow.Quantity = 1;
        
    EndIf;
    
	If IsNew() Then
		Author = Users.CurrentUser();
    EndIf;
    
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
    
    If DataExchange.Load Then
		Return;
    EndIf;
    
	If IsNew() Then
        Author = Users.CurrentUser();
    EndIf;
    
EndProcedure

Procedure FillCheckProcessing(Cancel, AttributesToCheck)
    
	// Removing the currency from the list of the attributes to be checked if the company
	// does not use multicurrency.
	If Not GetFunctionalOption("Multicurrency", New Structure("Company", Company)) Then
		AttributesToCheck.Delete(AttributesToCheck.Find("Currency"));
    EndIf;	
    
EndProcedure
