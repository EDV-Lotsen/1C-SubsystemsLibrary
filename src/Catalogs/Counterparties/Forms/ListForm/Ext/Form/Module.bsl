
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Try
		Items.Customer.Title = _DemoGeneralFunctionsCached.GetCustomerName();
		Items.Vendor.Title = _DemoGeneralFunctionsCached.GetVendorName();
	Except
	EndTry;
	
EndProcedure

&AtClient
Procedure Import(Command)
	
	Mode = FileDialogMode.Open;
	OpeningFileDialogue = New FileDialog(Mode);
	OpeningFileDialogue.FullFileName = "";
	Filter = "Excel(*.xlsx)|*.xlsx|Excel 97(*.xls)|*.xls";
	OpeningFileDialogue.Filter = Filter;
	OpeningFileDialogue.Multiselect = False;
	OpeningFileDialogue.Title = "Select file";
	If OpeningFileDialogue.Choose() Then
	    FilesArray = OpeningFileDialogue.SelectedFiles;
	    For Each FileName In FilesArray Do
	        Selection = New File(FileName);
	        //Message(FileName+"; Size = "+Selection.Size());
		EndDo;
		ImportCounterparties(Selection.FullName);
	Else
	    DoMessageBox("File(s) not selected!");
	EndIf;

EndProcedure

&AtServer
Procedure ImportCounterparties(File)
		
	try
	      ExcelApp    = New  COMObject("Excel.Application");
	except
	      Message(ErrorDescription()); 
	      Message("Can't initialize Excel"); 
	      Return; 
	EndTry; 

	
	try 
	ExcelFile = ExcelApp.Workbooks.Open(File);

	NColumns =1;
	NRows =1; // not taking the header
	
	TotalNRows  = ExcelApp.Sheets(1).UsedRange.row + ExcelApp.Sheets(1).UsedRange.Rows.Count - 1;
		   
	For n= 1 To   TotalNRows Do
		
		NewCounterparty = Catalogs.Counterparties.CreateItem();
		//NewCounterparty.Code = GeneralFunctions.LastCounterpartyNumber() + 1;
		NewCounterparty.Description = ExcelApp.Sheets(1).Cells(NRows,1).Value;
		//NewCounterparty.Name = ExcelApp.Sheets(1).Cells(NRows,1).Value;
		//If ExcelApp.Sheets(1).Cells(NRows,2).Value = "C" Then
		//	NewCounterparty.Customer = True;
		//Else
			NewCounterparty.Vendor = True;
		//EndIf;
		NewCounterparty.DefaultCurrency = Constants.DefaultCurrency.Get();
		NewCounterparty.ExpenseAccount = Constants.ExpenseAccount.Get(); 
        NewCounterparty.IncomeAccount = Constants.IncomeAccount.Get();
		NewCounterparty.Terms = Catalogs.PaymentTerms.Net30;
		
		NewCounterparty.Write();					
		
		AddressLine = Catalogs.Addresses.CreateItem();
		AddressLine.Owner = NewCounterparty.Ref;
		AddressLine.Description = "Primary";
		AddressLine.DefaultShipping = True;
		AddressLine.DefaultBilling = True;
		AddressLine.Write();
		
   		NRows = NRows +1;
		
	EndDo;
	
	except
		Message(ErrorDescription()); 
		ExcelApp.Application.Quit();
	endTry;
	
	ExcelApp.ActiveWorkbook.Close(False);
		
EndProcedure
