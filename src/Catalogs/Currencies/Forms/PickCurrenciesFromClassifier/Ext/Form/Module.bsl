
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	// Filling in the currency list from the currency classifier
	CloseOnChoice = False;
	FillCurrencyTable();
	
EndProcedure

#EndRegion

#Region ItemEventHandlersFormTableCurrencyList

&AtClient
Procedure CurrencyListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	ProcessChoiceInCurrencyList(StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChooseExecute()
	
	ProcessChoiceInCurrencyList();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure FillCurrencyTable()
	
	// Filling in the currency list from the currency classifier template
	
	XMLClassifier = Catalogs.Currencies.GetTemplate("CurrencyClassifier").GetText();
	
	ClassifierTable = CommonUse.ReadXMLToTable(XMLClassifier).Data;
	
	For Each CCRecord In ClassifierTable Do
		NewRow = Currencies.Add();
		NewRow.NumericCurrencyCode            = CCRecord.Code;
		NewRow.AlphabeticCurrencyCode         = CCRecord.CodeSymbol;
		NewRow.Description                    = CCRecord.Name;
		NewRow.CountriesAndTerritories        = CCRecord.Description;
		NewRow.Importing                      = CCRecord.RBCLoading;
		NewRow.InWordParametersInHomeLanguage = CCRecord.NumerationItemOptions;
	EndDo;
	
EndProcedure

&AtServer
Function SaveSelectedRows(Val SelectedRows, ThereAreRates)
	
	ThereAreRates = False;
	CurrentRef = Undefined;
	
	For Each LineNumber In SelectedRows Do
		CurrentData = Currencies[LineNumber];
		
		RowInDatabase = Catalogs.Currencies.FindByCode(CurrentData.NumericCurrencyCode);
		If ValueIsFilled(RowInDatabase) Then
			If LineNumber = Items.CurrencyList.CurrentRow Or CurrentRef = Undefined Then
				CurrentRef = RowInDatabase;
			EndIf;
			Continue;
		EndIf;
		
		NewRow = Catalogs.Currencies.CreateItem();
		NewRow.Code            = CurrentData.NumericCurrencyCode;
		NewRow.Description     = CurrentData.AlphabeticCurrencyCode;
		NewRow.LongDescription = CurrentData.Description;
		If CurrentData.Importing Then
			NewRow.RateSettingMethod = Enums.CurrencyRateSettingMethods.ImportFromInternet;
		Else
			NewRow.RateSettingMethod = Enums.CurrencyRateSettingMethods.ManualInput;
		EndIf;
		NewRow.InWordParametersInHomeLanguage = CurrentData.InWordParametersInHomeLanguage;
		NewRow.Write();
		
		If LineNumber = Items.CurrencyList.CurrentRow Or CurrentRef = Undefined Then
			CurrentRef = NewRow.Ref;
		EndIf;
		
		If CurrentData.Importing Then 
			ThereAreRates = True;
		EndIf;
		
	EndDo;
	
	Return CurrentRef;

EndFunction

&AtClient
Procedure ProcessChoiceInCurrencyList(StandardProcessing = Undefined)
	Var ThereAreRates;
	
	// Adds a catalog item and displays it to the user
	StandardProcessing = False;
	
	CurrentRef = SaveSelectedRows(Items.CurrencyList.SelectedRows, ThereAreRates);
	
	NotifyChoice(CurrentRef);
	
	ShowUserNotification(
		NStr("en = 'Currencies are added.'"), ,
		?(StandardSubsystemsClientCached.ClientParameters().DataSeparationEnabled And ThereAreRates, 
			NStr("en = 'The rates will soon be imported automatically.'"), ""),
		PictureLib.Information32);
	Close();
	
EndProcedure

#EndRegion
