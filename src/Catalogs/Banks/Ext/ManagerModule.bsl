
// Function generates query result by the banks classifier
// with the filter by BIN, correspondent account, description or city.
//
// Parameters:
//	BIN 			 - String (9) - bank BIN
//	BalancedAccount  - String (20) - Bank corerspondent account
//	Description 	 - String - Bank description
//	City 			 - String - Bank city
//
// Value returned:
//	QueryResult - Query result by the classifier.
//
Function GetQueryResultByClassifier(BIN, CorrespondentAccount, Description, City) Export
	
	TemporaryFileName = GetTempFileName();
	Template = Catalogs.Banks.GetTemplate("BanksClassifier");
	Template.Write(TemporaryFileName);  
	ClassifierTable = ValueFromFile(TemporaryFileName);
	
	QueryBuilder = New QueryBuilder;
	QueryBuilder.DataSource = New DataSourceDescription(ClassifierTable);
	
	Filter = QueryBuilder.Filter;
	
	If ValueIsFilled(BIN) Then
		Filter.Add("BIN");
		Filter.BIN.Value = TrimAll(BIN);
		Filter.BIN.ComparisonType = ComparisonType.Contains;
		Filter.BIN.Use = True;
	EndIf;
	
	If ValueIsFilled(CorrespondentAccount) Then
		Filter.Add("CorrespondentAccount");
		Filter.CorrespondentAccount.Value = TrimAll(CorrespondentAccount);
		Filter.CorrespondentAccount.ComparisonType = ComparisonType.Contains;
		Filter.CorrespondentAccount.Use = ValueIsFilled(CorrespondentAccount);
	EndIf;
	
	If ValueIsFilled(Description) Then
		Filter.Add("Description");
		Filter.Description.Value = TrimAll(Description);
		Filter.Description.ComparisonType = ComparisonType.Contains;
		Filter.Description.Use = ValueIsFilled(Description);
	EndIf;
	
	If ValueIsFilled(City) Then
		Filter.Add("City");
		Filter.City.Value = TrimAll(City);
		Filter.City.ComparisonType = ComparisonType.Contains;
		Filter.City.Use = ValueIsFilled(City);
	EndIf;
	
    QueryBuilder.Execute();
    QueryResult = QueryBuilder.Result;

	Return QueryResult;

EndFunction // GetQueryResultByClassifier()

// Procedure adds new bank from the classifier
// using BIN or correspondent account value.
//
// Parameters:
//	BIN 		- String (9) - bank BIN
//	CorrespondentAccount - String (20) - Bank correspondent account
//	BanksTable  - ValueTable - Table of the banks
//
Procedure AddBanksFromClassifier(BIN, CorrespondentAccount, BanksTable)

	QueryResult = Catalogs.Banks.GetQueryResultByClassifier(
		BIN,
		CorrespondentAccount,
		, // Description
		  // City
		);
	
	BanksArray = New Array;
	
	Selection = QueryResult.Choose();
    While Selection.Next() Do
    
    	BankObject = Catalogs.Banks.CreateItem();
		FillPropertyValues(BankObject, Selection);
		BankObject.Code = Selection.BIN;
		BankObject.Write();
		
		NewRow = BanksTable.Add();
		FillPropertyValues(NewRow, BankObject);
    
    EndDo;
    
EndProcedure // AddBanksFromClassifier()

// Function gets table of bank refs using BIN or corr. account.
//
// Parameters:
//	Field - String - Name of field (BIN or CorrespondentAccount)
//	Value - String - Value of BIN or Correspondent account
//
// Value returned:
//	ValueTable - banks found
//
Function GetBanksTableByAttributes(Field, Value) Export
	
	BanksTable = New ValueTable;
	Columns = BanksTable.Columns;
	Columns.Add("Ref");
	Columns.Add("Code");
	Columns.Add("CorrespondentAccount");
	
	ThisIsBIK = False;
	ThisIsCorrAccount = False;
	If Find(Field, "BIN") <> 0 Then
		ThisIsBIK = True;
	ElsIf Find(Field, "CorrespondentAccount") <> 0 Then
		ThisIsCorrAccount = True;
	EndIf;
	
	If (ThisIsBIK And StrLen(Value) = 9)
	 OR (ThisIsCorrAccount And StrLen(Value) = 20)
	Then
		
		If ThisIsBIK Then
			FilterStructure = New Structure("Code", Value);
			
		ElsIf ThisIsCorrAccount Then
			FilterStructure = New Structure("CorrespondentAccount", Value);
			
		EndIf;
		
		Selection = Catalogs.Banks.Select(,, FilterStructure, "Code Asc");
		While Selection.Next() Do
			NewRow = BanksTable.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
		
		If BanksTable.Count() = 0 Then
			AddBanksFromClassifier(
				?(ThisIsBIK, Value, ""), // BIN
				?(ThisIsCorrAccount, Value, ""), // CorrespondentAccount
				BanksTable
			);
		EndIf;
		
	EndIf;
	
	Return BanksTable;
	
EndFunction // GetBanksTableByAttributes()
