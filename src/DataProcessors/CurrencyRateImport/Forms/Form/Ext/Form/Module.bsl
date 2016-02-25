
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpenFromList") Then
		If CurrencyRateOperations.RatesRelevant() Then
			MessageRatesRelevant = True;
			Return;
		EndIf;
	EndIf;
	
	FillCurrencies();
	
	// Rate import period beginning and end.
	Object.ImportPeriodEnd = BegOfDay(CurrentSessionDate());
	Object.ImportPeriodBegin = Object.ImportPeriodEnd;
	MinimumDate = BegOfYear(Object.ImportPeriodEnd);
	For Each Currency In Object.CurrencyList Do
		If ValueIsFilled(Currency.RateDate) And Currency.RateDate < Object.ImportPeriodBegin Then
			If Currency.RateDate < MinimumDate Then
				Object.ImportPeriodBegin = MinimumDate;
				Break;
			EndIf;
			Object.ImportPeriodBegin = Currency.RateDate;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If MessageRatesRelevant Then
		CurrencyRateOperationsClient.NotifyRatesRelevant();
		Cancel = True;
		Return;
	EndIf;
	
	AttachIdleHandler("ValidateCurrenciesToBeImportedList", 0.1, True);
EndProcedure

#EndRegion

#Region ItemEventHandlersFormTableCurrencyList

&AtClient
Procedure CurrencyListChoice(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	SwitchImport();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportCurrencyRates()
	
	ClearMessages();
	
	If Not ValueIsFilled(Object.ImportPeriodBegin) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Import period start date is not set.'"),
			,
			"Object.ImportPeriodBegin");
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.ImportPeriodEnd) Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Import period end date is not set.'"),
			,
			"Object.ImportPeriodEnd");
		Return;
	EndIf;
	
	ImportRates();
	AttachIdleHandler("Attachable_CheckRateImport", 1, True);
	Items.Pages.CurrentPage = Items.PageRateImportBeingExecuted;
	Items.CommandBar.Enabled = False;
	
EndProcedure

&AtClient
Procedure ChooseAllCurrencies(Command)
	ConnectSelection(True);
	SetItemsEnabled();
EndProcedure

&AtClient
Procedure RemoveSelection(Command)
	ConnectSelection(False);
	SetItemsEnabled();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RateDate.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.CurrencyList.RateDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New StandardBeginningDate(Date('19800101000000'));

	Item.Appearance.SetParameterValue("Text", "");

EndProcedure

&AtClient
Procedure ConnectSelection(Selection)
	For Each Currency In Object.CurrencyList Do
		Currency.Import = Selection;
	EndDo;
EndProcedure

&AtServer
Procedure FillCurrencies()
	
	// Fill the table with a list of currencies whose rate is independent of other currency rates
	ImportPeriodEnd = Object.ImportPeriodEnd;
	CurrencyList = Object.CurrencyList;
	CurrencyList.Clear();
	
	CurrenciesToBeImported = CurrencyRateOperations.GetCurrenciesToBeImportedArray();
	
	For Each CurrencyItem In CurrenciesToBeImported Do
		AddCurrencyToList(CurrencyItem);
	EndDo;
	
EndProcedure

&AtServer
Procedure AddCurrencyToList(Currency)
	
	// Create entries in the currency list
	NewRow = Object.CurrencyList.Add();
	
	// Fill the rate information on the basis of a currency ref
	FillTableRowDataBasedByCurrency(NewRow, Currency);
	
	NewRow.Import = True;
	
EndProcedure

&AtServer
Procedure RefreshAdditionalDataInCurrencyList()
	
	// Refresh currency rate entries in the list.
	
	For Each DataRow In Object.CurrencyList Do
		CurrencyRef = DataRow.Currency;
		FillTableRowDataBasedByCurrency(DataRow, CurrencyRef);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillTableRowDataBasedByCurrency(TableRow, Currency);
	
	AdditionalDataOnCurrency = CommonUse.ObjectAttributeValues(Currency, "LongDescription,Code,Description");
	
	TableRow.Currency = Currency;
	TableRow.NumericCode = AdditionalDataOnCurrency.Code;
	TableRow.CurrencyCode = AdditionalDataOnCurrency.Code;
	TableRow.AlphabeticCode = AdditionalDataOnCurrency.Description;
	TableRow.Presentation = AdditionalDataOnCurrency.LongDescription;
	
	RateData = CurrencyRateOperations.FillCurrencyRateData(Currency);
	
	If TypeOf(RateData) = Type ("Structure") Then
		TableRow.RateDate             = RateData.RateDate;
		TableRow.Rate                 = RateData.Rate;
		TableRow.UnitConversionFactor = RateData.UnitConversionFactor;
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidateCurrenciesToBeImportedList()
	If Object.CurrencyList.Count() = 0 Then
		NotifyDescription = New NotifyDescription("ValidateCurrenciesToBeImportedListEnd", ThisObject);
		WarningText = NStr("en = 'The currency catalog contains no currencies whose rates are to be imported from the Internet.'");
		ShowMessageBox(NotifyDescription, WarningText);
	EndIf;
EndProcedure

&AtClient
Procedure ValidateCurrenciesToBeImportedListEnd(AdditionalParameters) Export
	Close();
EndProcedure

&AtClient
Procedure SetItemsEnabled()
	
	HaveSelectedCurrencies = Object.CurrencyList.FindRows(New Structure("Import", True)).Count() > 0;
	Items.ImportCurrencyRatesForm.Enabled = HaveSelectedCurrencies;
	
EndProcedure

&AtClient
Procedure DisableImportSelectedCurrencyRateFromInternet(Command)
	CurrentData = Items.CurrencyList.CurrentData;
	RemoveImportFromInternetFlag(CurrentData.Currency);
	Object.CurrencyList.Delete(CurrentData);
EndProcedure

&AtServer
Procedure RemoveImportFromInternetFlag(CurrencyRef)
	CurrencyObject = CurrencyRef.GetObject();
	CurrencyObject.RateSettingMethod = Enums.CurrencyRateSettingMethods.ManualInput;
	CurrencyObject.Write();
EndProcedure

&AtClient
Procedure SwitchImport()
	Items.CurrencyList.CurrentData.Import = Not Items.CurrencyList.CurrentData.Import;
	SetItemsEnabled();
EndProcedure

&AtServer
Procedure ImportRates()
	
	SetPrivilegedMode(True);
	
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.CurrencyRateImport);
	
	Filter = New Structure;
	Filter.Insert("ScheduledJob", ScheduledJob);
	Filter.Insert("State", BackgroundJobState.Active);
	BackgroundCleanupJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	If BackgroundCleanupJobs.Count() > 0 Then
		BackgroundJobID = BackgroundCleanupJobs[0].UUID;
	Else
		ResultAddress = PutToTempStorage(Undefined, UUID);
		BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 started manually'"), ScheduledJob.Metadata.Synonym);
		
		ImportParameters = New Structure;
		ImportParameters.Insert("BeginOfPeriod", Object.ImportPeriodBegin);
		ImportParameters.Insert("EndOfPeriod", Object.ImportPeriodEnd);
		ImportParameters.Insert("CurrencyList", CommonUse.ValueTableToArray(Object.CurrencyList.Unload(
			Object.CurrencyList.FindRows(New Structure("Import", True)), "CurrencyCode,Currency")));
		
		JobParameters = New Array;
		JobParameters.Add(ImportParameters);
		JobParameters.Add(ResultAddress);
		
		BackgroundJob = BackgroundJobs.Execute(
			ScheduledJob.Metadata.MethodName,
			JobParameters,
			String(ScheduledJob.UUID),
			BackgroundJobDescription);
			
		BackgroundJobID = BackgroundJob.UUID;
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckRateImport()
	
	Try
		JobCompleted = JobCompleted(BackgroundJobID);
	Except
		Items.Pages.CurrentPage = Items.PageCurrencyList;
		Items.CommandBar.Enabled = True;
		Raise;
	EndTry;
	
	If JobCompleted(BackgroundJobID) Then
		Items.Pages.CurrentPage = Items.PageCurrencyList;
		Items.CommandBar.Enabled = True;
		ProcessImportResult();
	Else
		AttachIdleHandler("Attachable_CheckRateImport", 2, True);
	EndIf;
EndProcedure

&AtClient
Procedure ProcessImportResult()
	
	ImportResult = GetFromTempStorage(ResultAddress);
	
	HaveImportedRates = False;
	WithoutErrors = True;
	
	For Each ImportState In ImportResult Do
		If ImportState.OperationStatus Then
			HaveImportedRates = True;
		Else
			WithoutErrors = False;
			Index = Object.CurrencyList.IndexOf(Object.CurrencyList.FindRows(New Structure("Currency", ImportState.Currency))[0]);
			FieldName = StrReplace("CurrencyList[x].Presentation", "x", String(Index));
			CommonUseClientServer.MessageToUser(ImportState.Message,, FieldName, "Object");
		EndIf;
	EndDo;
	
	If HaveImportedRates Then
		RefreshAdditionalDataInCurrencyList();
		WriteParameters = Undefined;
		CurrenciesToRefreshArray = New Array;
		For Each TableRow In Object.CurrencyList Do
			CurrenciesToRefreshArray.Add(TableRow.Currency);
		EndDo;
		Notify("Write_CurrencyRateImport", WriteParameters, CurrenciesToRefreshArray);
		
		CurrencyRateOperationsClient.NotifyRatesAreRefreshed();
		
		If WithoutErrors Then
			Close();
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(BackgroundJobID)
	Return LongActions.JobCompleted(BackgroundJobID);
EndFunction

&AtClient
Procedure ImportOnChange(Item)
	SetItemsEnabled();
EndProcedure

#EndRegion
