

// Handler of event "on create at server"
// Calls code filling currency list from ACC
//
&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	CloseOnChoice = False;
	FillCurrenciesTable();
	
EndProcedure

// Handler of event "selection" of form item CurrencyList
// Notifies calling form abour the choice. Form closes.
//
&AtClient
Procedure CurrencyListSelection(Item, RowSelected, Field, StandardProcessing)
	
	ProcessChoiceInCurrencyList(Item.CurrentData);
	
EndProcedure

// Fills currency list from ACC template
//
&AtServer
Procedure FillCurrenciesTable()
	
	ClassifierXML = Catalogs.Currencies.GetTemplate("CurrencyClassifier").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(ClassifierXML).Data;
	
	For Each WriteOKV In ClassifierTable Do
		NewRow	 						= Currencies.Add();
		NewRow.CurrencyCodeNumeric  	= WriteOKV.Code;
		NewRow.CurrencyCodeAlphabetic 	= WriteOKV.CodeSymbol;
		NewRow.Description       		= WriteOKV.Name;
		NewRow.CountriesAndTerritories  = WriteOKV.Description;
		NewRow.IsLoading        		= WriteOKV.DownloadFromInternet;
	EndDo;
	
EndProcedure

// Click handler of command bar button "Select"
// of form item CurrencyList.
//
&AtClient
Procedure ChooseRun()
	
	ProcessChoiceInCurrencyList(Items.CurrencyList.CurrentData);
	
EndProcedure

// Handler of event "selection" of form item CurrencyList
// Notifies calling form abour the choice. Form closes.
//
&AtClient
Procedure ProcessChoiceInCurrencyList(CurrentData)
	
	ParametersSelection 					= New Structure("CurrencyCode, BriefDescription, Details, IsLoading");
	ParametersSelection.CurrencyCode        = CurrentData.CurrencyCodeNumeric;
	ParametersSelection.BriefDescription	= CurrentData.CurrencyCodeAlphabetic;
	ParametersSelection.Details  	= CurrentData.Description;
	ParametersSelection.IsLoading         	= CurrentData.IsLoading;
	
	NotifyChoice(ParametersSelection);
	
EndProcedure

