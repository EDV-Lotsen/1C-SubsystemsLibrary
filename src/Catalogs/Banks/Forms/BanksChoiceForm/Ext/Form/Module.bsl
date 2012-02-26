

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

&AtServer
// Procedure fills list of banks.
//
Procedure FillBankList()

	QueryResult = Catalogs.Banks.GetQueryResultByClassifier(
		BIN,
		CorrespondentAccount,
		Description,
		City
	);
	
	BankList.Clear();
    
    Selection = QueryResult.Choose();
    While Selection.Next() Do
    
    	NewRow = BankList.Add();
    	FillPropertyValues(NewRow, Selection);
    
    EndDo;
    
EndProcedure // FillBankList()

&AtServer
// Procedure adds selected banks to the catalog "Banks".
//
// Value returned:
//	Array - Array of added banks
//
Function AddBanksToCatalog()

	BanksArray = New Array;

	LineNumbersArray = Items.BankList.SelectedRows;
	For Each TableRow In BankList Do
	
		If TableRow.Selected Then
			
			BankFound = Catalogs.Banks.FindByCode(TableRow.BIN);
			If Not ValueIsFilled(BankFound) Then
				
				BankObject = Catalogs.Banks.CreateItem();
				FillPropertyValues(BankObject, TableRow);
				BankObject.Code = TableRow.BIN;
				BankObject.Write();
				
				BanksArray.Add(BankObject.Ref);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return BanksArray;

EndFunction // AddBanksToCatalog()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES - ACTIONS OF FORM COMMAND BARS

&AtClient
// Procedure is called on click button "Fill banks".
//
Procedure SelectBanksExecute()

	FillBankList();
	
EndProcedure // SelectBanksExecute()

&AtClient
// Procedure is called on click button "Add to catalog".
//
Procedure AddToCatalog(Command)
	
	BanksArray = AddBanksToCatalog();
	
	For Each Bank In BanksArray Do
		Url = GetURL(Bank);
		ShowUserNotification(NStr("en = 'New bank is added'"),Url);
	EndDo;
	
	NotifyChoice("");
	
EndProcedure // AddToCatalog()

&AtClient
// Procedure is called on click on button "Select all".
//
Procedure ChooseBanks(Command)
	
	For Each TableRow In BankList Do
		TableRow.Selected = True;
	EndDo;
	
EndProcedure // ChooseBanks()

&AtClient
// Procedure is called on click on button "Exclude all".
//
Procedure ExcludeBanks(Command)
	
	For Each TableRow In BankList Do
		TableRow.Selected = False;
	EndDo;
	
EndProcedure // ExcludeBanks()

&AtClient
// Procedure is called on click on button "Select highlighted".
//
Procedure ChooseHighlightedBanks(Command)
	
	RowsArray = Items.BankList.SelectedRows;
	For Each LineNumber In RowsArray Do
		BankList.FindByID(LineNumber).Selected = True;
	EndDo;
	
EndProcedure // ChooseHighlightedBanks()

&AtClient
// Procedure is called on click on button "Exclude highlighted".
//
Procedure ExcludeSelectedBanks(Command)
	
	RowsArray = Items.BankList.SelectedRows;
	For Each LineNumber In RowsArray Do
		BankList.FindByID(LineNumber).Selected = False;
	EndDo;
	
EndProcedure // ExcludeSelectedBanks()

///////////////////////////////////////////////////////////////////////////////
// PROCEDURES - EVENT HANDLERS OF FORMS ITEMS

&AtClient
// Procedure - handler of event "Selection" of field ""BankList".
//
Procedure BankListSelection(Item, RowSelected, Field, StandardProcessing)
	
	TableRow = BankList.FindByID(RowSelected);
	TableRow.Selected = NOT TableRow.Selected;
	
EndProcedure // BankListSelection()



