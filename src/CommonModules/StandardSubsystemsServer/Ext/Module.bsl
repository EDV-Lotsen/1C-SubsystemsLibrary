
////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Shows message about field filling error.
//
Procedure ShowErrorMessage(ThisObject, MessageText, TabularSectionName = Undefined, LineNumber = Undefined, Field = Undefined, Cancellation = False) Export
		
	Message 	 = New UserMessage();
	Message.Text = MessageText;

	If TabularSectionName <> Undefined Then
		Message.Field = TabularSectionName + "[" + (LineNumber - 1) + "]." + Field;
	ElsIf ValueIsFilled(Field) Then
		Message.Field = Field;
	EndIf;

	Message.SetData(ThisObject);
	Message.Message();

	Cancellation = True;
	
EndProcedure // ShowErrorMessage()

// Determines if attribute with the passed name is present among
// header attributes.
//
// Parameters:
//  AttributeName 		- String name of attribute sought,
//  DocumentMetadata 	- Document metadata description object, among whose attributes search is performed.
//
// Value returned:
//  True 				- Attribute with such name is found, False - not found.
//
Function IsDocumentAttribute(AttributeName, DocumentMetadata)

	Return NOT (DocumentMetadata.Attributes.Find(AttributeName) = Undefined);

EndFunction // IsDocumentAttribute()

// Procedure is required for filling documents common attributes,
// is called in handlers "OnCreateAtServer" in form modules of all documents.
//
// Parameters:
//  DocumentObject             - object of the edited document,
//  CopyingObjectParameter 	   - specifies that document was created by cloning
//  BasisParameter 			   - ref to basis document
Procedure FillDocumentHeader(Object,
	ParameterCopyingValue	= Undefined,
	BasisParameter 			= Undefined,
	DocumentStatus,
	PictureDocumentStatus,
	PostingIsAllowed,
	FillingValues 			= Undefined) Export
	
	User 			 = CommonUse.CurrentUser();
	DocumentMetadata = Object.Ref.Metadata();
	PostingIsAllowed = DocumentMetadata.Posting = Metadata.ObjectProperties.Posting.Allow;
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.Author 		  = User;
		DocumentStatus 		  = "New";
		PictureDocumentStatus = 0;
	Else
		If Object.Posted Then
			DocumentStatus = "Posted";
			PictureDocumentStatus = 1;
		ElsIf PostingIsAllowed Then
			DocumentStatus = "Unposted";
			PictureDocumentStatus = 0;
		Else
			DocumentStatus = "Written";
			PictureDocumentStatus = 3;
		EndIf;
		
	EndIf;
	
	If DocumentMetadata.Name = "RetailReceipt"
	 OR DocumentMetadata.Name = "RetailReceiptReturn"
	 OR DocumentMetadata.Name = "RetailReport" Then
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Object.Ref) Then
		
		If (NOT ValueIsFilled(ParameterCopyingValue)) Then
	
			If IsDocumentAttribute("Company", DocumentMetadata) 
				And NOT (FillingValues <> Undefined And FillingValues.Property("Company") And ValueIsFilled(FillingValues.Company))
				And NOT (ValueIsFilled(BasisParameter)
				And ValueIsFilled(Object.Company)) Then
				SettingValue = StandardSubsystemsSecondUse.GetValueByDefaultUser(User, "MainCompany");
				If ValueIsFilled(SettingValue) Then
					If Object.Company <> SettingValue Then
						Object.Company = SettingValue;
					EndIf;
				Else
					Object.Company = Catalogs.Companies.MainCompany;	
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("Responsible", DocumentMetadata)
				And NOT (FillingValues <> Undefined And FillingValues.Property("Responsible") And ValueIsFilled(FillingValues.Responsible))
				And NOT ValueIsFilled(Object.Responsible) Then
				Object.Responsible = StandardSubsystemsSecondUse.GetValueByDefaultUser(User, "MainResponsible");
			EndIf;
			
			If DocumentMetadata.Name = "CustomerOrder" Then
				If IsDocumentAttribute("StatusOfOrder", DocumentMetadata) 
					And NOT (FillingValues <> Undefined And FillingValues.Property("StatusOfOrder") And ValueIsFilled(FillingValues.StatusOfOrder))
					And NOT (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.StatusOfOrder)) Then
					SettingValue = StandardSubsystemsSecondUse.GetValueByDefaultUser(User, "StatusOfNewCustomerOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.StatusOfOrder <> SettingValue Then
							Object.StatusOfOrder = SettingValue;
						EndIf;
					Else
						Object.IsClosed = False;	
					EndIf;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure // FillDocumentHeader()

// Procedure removes attribute that is checked from the array of attributes being checked.
Procedure DeleteAttributeBeingChecked(CheckedAttributes, AttributeBeingChecked) Export
	
	AttributeFound = CheckedAttributes.Find(AttributeBeingChecked);
	If ValueIsFilled(AttributeFound) Then
		CheckedAttributes.Delete(AttributeFound);
	EndIf;
	
EndProcedure // DeleteAttributeBeingChecked()

// Procedure creates new link key for the tables.
//
// Parameters:
//  DocumentForm - ManagedForm, contains document form, whose attributes
//                 are processed by the procedure.
//
Function CreateNewLinkKey(DocumentForm) Export

	ValueList = New ValueList;
	
	TabularSection = DocumentForm.Object[DocumentForm.TabularSectionName];
	For each TSLine In TabularSection Do
        ValueList.Add(TSLine.ConnectionKey);
	EndDo;

    If ValueList.Count() = 0 Then
		ConnectionKey = 1;
	Else
		ValueList.SortByValue();
		ConnectionKey = ValueList.Get(ValueList.Count() - 1).Value + 1;
	EndIf;

	Return ConnectionKey;

EndFunction //  CreateNewLinkKey()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS

// Function gets table from temporary table.
//
Function TableFromTemporaryTable(TempTablesManager, Table) Export
	
	Query = New Query(
	"SELECT *
	|	FROM " + Table + " AS Table");
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction // TableFromTemporaryTable()

// Function depending on the flag of accounting by company
// company-Company or document Company.
//
// Parameters:
//	Company - CatalogRef.Companies.
//
// Value returned:
//  CatalogRef.Company - ref to the Company.
//
Function GetCompany(Company) Export
	
	Return Company;
	
EndFunction // GetCompany()

// Procedure determines situation, when on document date change document
// moves to another documents numeration period, and in this case
// procedure assignes new unique number to the document.
//
// Parameters:
//  DocumentRef 			- ref the document, where the procedure is called from
//  NewDocumentDate 		- new document date
//  DocumentBegginingDate 	- document opening date
//
// Value returned:
//  Number 					- difference between dates.
//
Function CheckDocumentNo(DocumentRef, NewDocumentDate, DocumentBegginingDate) Export
	
	// Determine number change periodicity for the current document type
	NumberChangePeriod = DocumentRef.Metadata().NumberPeriodicity;
	
	//Depending on the configured periodicity of number change,
	//define difference of old and new using document dates.
	If NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year Then
		Datediff = BegOfYear(DocumentBegginingDate) - BegOfYear(NewDocumentDate);
	ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter Then
		Datediff = BegOfQuarter(DocumentBegginingDate) - BegOfQuarter(NewDocumentDate);
	ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month Then
		Datediff = BegOfMonth(DocumentBegginingDate) - BegOfMonth(NewDocumentDate);
	ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day Then
		Datediff = DocumentBegginingDate - NewDocumentDate;
	Else
		Return 0;
	EndIf;
	
	Return Datediff;
	
EndFunction // CheckDocumentNumber()

// PROCEDURES AND FUNCTIONS OF WORK WITH THE DYNAMIC LISTS

// Procedure applies filter of dynamic list for equity.
//
Procedure SetDynamicListFilterToEquality(Filter, LeftValue, RightValue) Export
	
	FilterItem 					= Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue	 	= LeftValue;
	FilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	FilterItem.RightValue 		= RightValue;
	FilterItem.Use  			= True;
	
EndProcedure // ApplyFilterForDynamicList()

// Deletes dynamic list filter item
//
//Parameters:
// List  	 - modified dynamic list,
// FieldName - name of composition field, whose filter has to be deleted
//
Procedure DeleteListFilterItem(List, FieldName) Export
	
	CompositionField = New DataCompositionField(FieldName);
	For Each FilterItem In List.Filter.Items Do
		If TypeOf(FilterItem) = Type("DataCompositionFilterItem")
			And FilterItem.LeftValue = CompositionField Then
			List.Filter.Items.Delete(FilterItem);
		EndIf;
	EndDo;
	
EndProcedure // DeleteListFilterItem()

// Applies dynamic list filter item
//
//Parameters:
// List				- modified dynamic list,
// FieldName		- name of composition field, whose filter needs to be set,
// ComparisonKind	- filter comparison type, by default - Equal to,
// RightValue 		- filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, ComparisonType = Undefined) Export
	
	FilterItem						= List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue    		= New DataCompositionField(FieldName);
	FilterItem.ComparisonType     	= ?(ComparisonType = Undefined, DataCompositionComparisonType.Equal, ComparisonType);
	FilterItem.Use    				= True;
	FilterItem.RightValue  			= RightValue;
	FilterItem.ViewMode 			= DataCompositionSettingsItemViewMode.Inaccessible;
	
EndProcedure // SetListFilterItem()

// Modifies dynamic list filter item
//
//Parameters:
//List         		- modified dynamic list,
//FieldName        	- name of composition field, whose filter needs to be set,
//ComparisonKind   	- filter comparison type, by default - Equal to,
//RightValue 		- filter value,
//Set     			- flag indicating that filter has to be set up
//
Procedure ChangeListFilterElement(List, FieldName, RightValue = Undefined, Set = False, ComparisonType = Undefined, FilterByPeriod = False) Export
	
	DeleteListFilterItem(List, FieldName);
	
	If Set Then
		If FilterByPeriod Then
			SetListFilterItem(List, FieldName, RightValue.StartDate, 	DataCompositionComparisonType.GreaterOrEqual);
			SetListFilterItem(List, FieldName, RightValue.EndDate, 		DataCompositionComparisonType.LessOrEqual);		
		Else
		    SetListFilterItem(List, FieldName, RightValue, ComparisonType);	
		EndIf;		
	EndIf;
	
EndProcedure // ChangeListFilterElement()

////////////////////////////////////////////////////////////////////////////////
// POSTING CONTROL

// Performs initialization of additional properties for document posting.
//
Procedure InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties) Export
	
	// Create properties with keys "TableForRegisterRecords", "ForPosting", "AccountingPolicy" in structure "AdditionalProperties"
	
	// "TableForRegisterRecords" - structure, that will contain value tables for generating register records.
	StructureAdditionalProperties.Insert("TableForRegisterRecords", New Structure);
	
	// "ForPosting" - structure, containing properties and document attributes, required for posting.
	StructureAdditionalProperties.Insert("ForPosting", New Structure);
	
	// Structure, containing key with name "TempTablesManager", whose value stores temporary tables manager.
	// Contains key (temporary table name) and value (flag that there are some records in temporary table) for each temporary table.
	StructureAdditionalProperties.ForPosting.Insert("StructureTemporaryTables", New Structure("TempTablesManager", New TempTablesManager));
	StructureAdditionalProperties.ForPosting.Insert("DocumentMetadata", DocumentRef.Metadata());
	
	// "AccountingPolicy" - structure, containing values all parameters of accounting policy at the moment of document time
	// with applied filter by Company or company (in case when accounting is conducted by company).
	StructureAdditionalProperties.Insert("AccountingPolicy", New Structure);
	
	// Query, getting document data.
	Query = New Query(
	"SELECT
	|	_Document_.Ref AS Ref,
	|	_Document_.Number AS Number,
	|	_Document_.Date AS Date,
	|   " + ?(StructureAdditionalProperties.ForPosting.DocumentMetadata.Attributes.Find("Company") <> Undefined, "_Document_.Company" , "VALUE(Catalog.Companies.EmptyRef)") + " AS Company,
	|	_Document_.PointInTime AS PointInTime,
	|	_Document_.Presentation AS Presentation
	|FROM
	|	Document." + StructureAdditionalProperties.ForPosting.DocumentMetadata.Name + " AS _Document_
	|WHERE
	|	_Document_.Ref = &DocumentRef");
	
	Query.SetParameter("DocumentRef", DocumentRef);
	
	QueryResult = Query.Execute();
	
	// Generate keys, containig document data.
	For each Column In QueryResult.Columns Do
		
		StructureAdditionalProperties.ForPosting.Insert(Column.Name);
		
	EndDo;
	
	QueryResultSelection = QueryResult.Choose();
	QueryResultSelection.Next();
	
	// Fill values of the keys, containig document data.
	FillPropertyValues(StructureAdditionalProperties.ForPosting, QueryResultSelection);
	
	// Determine and assign value of the moment, on which document control should be performed.
	StructureAdditionalProperties.ForPosting.Insert("ControlTime", 		Date('00010101'));
	StructureAdditionalProperties.ForPosting.Insert("ControlPeriod", 	Date("39991231"));
		
	// Assign Company in case of accounting by company.
	StructureAdditionalProperties.ForPosting.Company = StandardSubsystemsServer.GetCompany(StructureAdditionalProperties.ForPosting.Company);
	

	QueryResultSelection = QueryResult.Choose();
	QueryResultSelection.Next();
	
	// Fill values for the keys, containing acounting policy data.
	FillPropertyValues(StructureAdditionalProperties.AccountingPolicy, QueryResultSelection);
	
EndProcedure // InitializeAdditionalPropertiesForPosting()

// Generate array of register names, which have document records.
//
Function GetNamesArrayOfUsedRegisters(Recorder, DocumentMetadata)
	
	RegistersArray 	= New Array;
	QueryText 		= "";
	TablesCounter 	= 0;
	CycleCounter 	= 0;
	TotalRegisters	= DocumentMetadata.RegisterRecords.Count();
	
	For each Record in DocumentMetadata.RegisterRecords Do
		
		If TablesCounter > 0 Then
			
			QueryText = QueryText + "
			|UNION ALL
			|";
			
		EndIf;
		
		TablesCounter = TablesCounter + 1;
		CycleCounter = CycleCounter + 1;
		
		QueryText = QueryText + 
		"SELECT TOP 1
		|""" + Record.Name + """ AS RegisterName
		|
		|FROM " + Record.FullName() + "
		|
		|WHERE Recorder = &Recorder
		|";
		
		If TablesCounter = 256 OR CycleCounter = TotalRegisters Then
			
			Query = New Query(QueryText);
			Query.SetParameter("Recorder", Recorder);
			
			QueryText  		= "";
			TablesCounter 	= 0;
			
			If RegistersArray.Count() = 0 Then
				
				RegistersArray = Query.Execute().Unload().UnloadColumn("RegisterName");
				
			Else
				
				Selection = Query.Execute().Choose();
				
				While Selection.Next() Do
					
					RegistersArray.Add(Selection.RegisterName);
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return RegistersArray;
	
EndFunction // GetNamesArrayOfUsedRegisters()

// Prepare document recordsets.
//
Procedure PrepareRecordSetsForRecording(StructureObject) Export
	
	For each RecordSet in StructureObject.RegisterRecords Do
		
		If TypeOf(RecordSet) = Type("KeyAndValue") Then
			
			RecordSet = RecordSet.Value;
			
		EndIf;
		
		If RecordSet.Count() > 0 Then
			
			RecordSet.Clear();
			
		EndIf;
		
	EndDo;
	
	RegisterNamesArray = GetNamesArrayOfUsedRegisters(StructureObject.Ref, StructureObject.AdditionalProperties.ForPosting.DocumentMetadata);
	
	For each RegisterName in RegisterNamesArray Do
		
		StructureObject.RegisterRecords[RegisterName].Write = True;
		
	EndDo;
	
EndProcedure

// Write document recordsets.
//
Procedure WriteRecordSets(StructureObject) Export
	
	For each RecordSet in StructureObject.RegisterRecords Do
		
		If TypeOf(RecordSet) = Type("KeyAndValue") Then
			
			RecordSet = RecordSet.Value;
			
		EndIf;
		
		If RecordSet.Write Then
			
			If Not RecordSet.AdditionalProperties.Property("ForPosting") Then
				
				RecordSet.AdditionalProperties.Insert("ForPosting", New Structure);
				
			EndIf;
			
			If Not RecordSet.AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
				
				RecordSet.AdditionalProperties.ForPosting.Insert("StructureTemporaryTables", StructureObject.AdditionalProperties.ForPosting.StructureTemporaryTables);
				
			EndIf;
			
			RecordSet.Write();
			RecordSet.Write = False;
			
		Else
				
			If Metadata.AccumulationRegisters.Contains(RecordSet.Metadata()) Then
				
				Try
					AccumulationRegisters[RecordSet.Metadata().Name].CreateEmptyTemporaryTableChange(StructureObject.AdditionalProperties);
				Except
				EndTry;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES GENERATING REGISTER RECORDS

// Create records in accumulation register CashAssets.
//
Procedure ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableCashAssets = AdditionalProperties.TableForRegisterRecords.TableCashAssets;
	
	If Cancellation
	 OR TableCashAssets.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsCashAssets = RegisterRecords.CashAssets;
	RegisterRecordsCashAssets.Write = True;
	RegisterRecordsCashAssets.Load(TableCashAssets);
	
EndProcedure

// Create records in accumulation register PaymentDeductionKinds.
//
Procedure ReflectPaymentDeductionKinds(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TablePaymentDeductionKinds = AdditionalProperties.TableForRegisterRecords.TablePaymentDeductionKinds;
	
	If Cancellation
	 OR TablePaymentDeductionKinds.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPaymentDeductionKinds 		= RegisterRecords.PaymentDeductionKinds;
	RegisterRecordsPaymentDeductionKinds.Write 	= True;
	RegisterRecordsPaymentDeductionKinds.Load(TablePaymentDeductionKinds);
	
EndProcedure

// Create records in accumulation register HumanResourcesAccounting.
//
Procedure ReflectHumanResourcesAccounting(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableHumanResourcesAccounting = AdditionalProperties.TableForRegisterRecords.TableHumanResourcesAccounting;
	
	If Cancellation
	 OR TableHumanResourcesAccounting.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsHumanResourcesAccounting 		= RegisterRecords.HumanResourcesAccounting;
	RegisterRecordsHumanResourcesAccounting.Write 	= True;
	RegisterRecordsHumanResourcesAccounting.Load(TableHumanResourcesAccounting);
	
EndProcedure

// Create records in information register PaymentDeductionKindsPlan.
//
Procedure ReflectPaymentDeductionKindsPlan(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TablePlannedPaymentDeductionKinds = AdditionalProperties.TableForRegisterRecords.TablePlannedPaymentDeductionKinds;
	
	If Cancellation
	 OR TablePlannedPaymentDeductionKinds.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPaymentDeductionKindsPlan 		= RegisterRecords.PaymentDeductionKindsPlan;
	RegisterRecordsPaymentDeductionKindsPlan.Write 	= True;
	RegisterRecordsPaymentDeductionKindsPlan.Load(TablePlannedPaymentDeductionKinds);
	
EndProcedure

// Create records in information register Employees.
//
Procedure ReflectEmployees(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableEmployees = AdditionalProperties.TableForRegisterRecords.TableEmployees;
	
	If Cancellation
	 OR TableEmployees.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsEmployees 		= RegisterRecords.Employees;
	RegisterRecordsEmployees.Write 	= True;
	RegisterRecordsEmployees.Load(TableEmployees);
	
EndProcedure

// Create records in accumulation register Timesheet.
//
Procedure ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableTimesheet = AdditionalProperties.TableForRegisterRecords.TableTimesheet;
	
	If Cancellation
	 OR TableTimesheet.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsTimesheet 		= RegisterRecords.Timesheet;
	RegisterRecordsTimesheet.Write 	= True;
	RegisterRecordsTimesheet.Load(TableTimesheet);
	
EndProcedure

// Create records in accumulation register Inventory.
//
Procedure ReflectInventory(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableInventory = AdditionalProperties.TableForRegisterRecords.TableInventory;
	
	If Cancellation
	 OR TableInventory.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsInventory 		= RegisterRecords.Inventory;
	RegisterRecordsInventory.Write  = True;
	RegisterRecordsInventory.Load(TableInventory);
	
EndProcedure

// Create records in register Customer orders.
//
Procedure ReflectCustomerOrders(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableCustomerOrders = AdditionalProperties.TableForRegisterRecords.TableCustomerOrders;
	
	If Cancellation
	 OR TableCustomerOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsCustomerOrders 		= RegisterRecords.CustomerOrders;
	RegisterRecordsCustomerOrders.Write = True;
	RegisterRecordsCustomerOrders.Load(TableCustomerOrders);
	
EndProcedure // ReflectCustomerOrders()

// Create records in accounting register Managerial.
//
Procedure ReflectManagerial(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableManagerial = AdditionalProperties.TableForRegisterRecords.TableManagerial;
	
	If Cancellation
	   Or TableManagerial.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsManagerial 		= RegisterRecords.Managerial;
	RegisterRecordsManagerial.Write = True;
	
	For Each RowTableManagerial In TableManagerial Do
		RegisterRecordManagerial = RegisterRecordsManagerial.Add();
		FillPropertyValues(RegisterRecordManagerial, RowTableManagerial);
	EndDo;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF THE PRICING SUBSYSTEMS

// Returns currency rates on date.
//
// Parameters:
//  Currency       			- CatalogRef.Currencies - Currency (item of catalog "Currencies")
//  RateDate    			- Date - date, used to get exchange rate.
//
// Value returned:
//  Structure, containing:
//   ExchangeRate       	- Number - currency rate,
//   Multiplicity   			- Number - currency Multiplicity.
//
Function GetCurrencyRates(CurrencyBeg, CurrencyEnd, RateDate) Export
	
	StructureBeg = InformationRegisters.CurrencyRates.GetLast(RateDate, New Structure("Currency", CurrencyBeg));
	StructureEnd = InformationRegisters.CurrencyRates.GetLast(RateDate, New Structure("Currency", CurrencyEnd));
	
	StructureEnd.ExchangeRate = ?(
		StructureEnd.ExchangeRate = 0,
		1,
		StructureEnd.ExchangeRate
	);
	StructureEnd.Multiplicity = ?(
		StructureEnd.Multiplicity = 0,
		1,
		StructureEnd.Multiplicity
	);
	StructureEnd.Insert("RateBeg", ?(StructureBeg.ExchangeRate      = 0, 1, StructureBeg.ExchangeRate));
	StructureEnd.Insert("MultiplicityBeg", ?(StructureBeg.Multiplicity = 0, 1, StructureBeg.Multiplicity));
	
	Return StructureEnd;
	
EndFunction // GetCurrencyRates()

// Function recalculates amount from one currency to another
//
// Parameters:
//	Amount         - Number - amount to recalculate.
// 	RateBeg        - Number - source rate.
// 	RateEnd        - Number - destination rate.
// 	MultiplicityBeg  - Number - source Multiplicity
//                  (by default = 1).
// 	MultiplicityEnd  - Number - destination Multiplicity
//                  (by default = 1).
//
// Value returned:
//  Number		   - amount, recalculated to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, RateBeg, RateEnd,	MultiplicityBeg = 1, MultiplicityEnd = 1) Export
	
	If (RateBeg = RateEnd) And (MultiplicityBeg = MultiplicityEnd) Then
		Return Amount;
	EndIf;
	
	If RateBeg = 0 OR RateEnd = 0 OR MultiplicityBeg = 0 OR MultiplicityEnd = 0 Then
		Message		 = New UserMessage();
		Message.Text = NStr("en = 'Found zero exchange rate. Recalculation failed.'");
		Message.Message();
		Return Amount;
	EndIf;
	
	AmountRecalculated = Round((Amount * RateBeg * MultiplicityEnd) / (RateEnd * MultiplicityBeg), 2);
	
	Return AmountRecalculated;
	
EndFunction // RecalculateFromCurrencyToCurrency()

// Round number using specified round precision.
//
// Parameters:
//  Number        	- Number, to be rounded
//  RoundPrecision  - Enums.RoundingMethods - round precision
//  RoundUp 		- Boolean -rounds up.
//
// Value returned:
//  Number       	- round result.
//
Function RoundPrice(Number, RoundRule, RoundUp) Export
	
	Var Result; // Result to return.
	
	// Convert number round precision.
	// If empty precision was passed, then round to cents.
	If NOT ValueIsFilled(RoundRule) Then
		RoundPrecision = Enums.RoundingMethods.Round0_01; 
	Else
		RoundPrecision = RoundRule;
	EndIf;
	Order = Number(String(RoundPrecision));
	
	// calculate number of intervals, contained in number
	QuantityInterval	= Number / Order;
	
	// calculate whole number of intervals.
	NumberOfEntireIntervals = Int(QuantityInterval);
	
	If QuantityInterval = NumberOfEntireIntervals Then
		
		// Numbers are whole. No need to round.
		Result	= Number;
	Else
		If RoundUp Then
			
			// On round precision "0.05" 0.371 should be rounded to 0.4
			Result = Order * (NumberOfEntireIntervals + 1);
		Else
			
			// On round precision "0.05" 0.371 should be rounded to 0.35
			// and 0.376 to 0.4
			Result = Order * Round(QuantityInterval, 0, RoundMode.Round15as20);
		EndIf; 
	EndIf;
	
	Return Result;
	
EndFunction // RoundPrice()

///////////////////////////////////////////////////////////////////////////////////////////////////
// PRESENTATION OF OBJECTS

/////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS GENERATING MESSAGE TEXTS ABOUT POSTING ERRORS

// Generates cash presentation string.
//
// Parameters:
//  ItemPresentation 		- String - Item presentation.
//  GoodAccountingKindPresentation 	- String - Item kind presentation.
//  StagePresentation 				- String - stage presentation.
//
// Value returned:
//  String 							- String with Item presentation.
//
Function CashBankingAccountPresentation(BankAccountPettyCashPresentation,
										   CashAssetsTypePresentation = "",
										   CurrencyPresentation = "") Export
	
	StrPresentation = """" + TrimAll(BankAccountPettyCashPresentation) + """";
	
	If ValueIsFilled(CashAssetsTypePresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(CashAssetsTypePresentation);
	EndIf;
	
	If ValueIsFilled(CurrencyPresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(CurrencyPresentation);
	EndIf;
	
	Return StrPresentation;
	
EndFunction // PresentationOfItem()

// Generates string of Item presentation.
//
// Parameters:
//  ItemPresentation 	- String - Item presentation.
//
// Value returned:
//  String - string with Item presentation.
//
Function PresentationOfItem(ItemPresentation,
								  CustomerOrderPresentation   = "") Export
	
	StrPresentation = """" + TrimAll(ItemPresentation) + """";
	
	If  ValueIsFilled(CustomerOrderPresentation) Then
		StrPresentation = StrPresentation + " | """ + TrimAll(CustomerOrderPresentation) + """";
	EndIf;
	
	Return StrPresentation;
	
EndFunction // PresentationOfItem()

// Generates contractor presentation string.
//
// Parameters:
//  ItemPresentation 		- String - Item presentation.
//  GoodAccountingKindPresentation 	- String - Item kind presentation.
//  StagePresentation 				- String - stage presentation.
//
// Value returned:
//  String 							- String with Item presentation.
//
Function PresentationOfCounterparty(CounterpartyPresentation,
	                             AgreementPresentation = "",
	                             DocumentPresentation = "",
	                             OrderPresentation 	  = "",
	                             CalculationsKindPresentation = "") Export
	
	StrPresentation = """" + TrimAll(CounterpartyPresentation) + """";
	
	If ValueIsFilled(AgreementPresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(AgreementPresentation);
	EndIf;
	
	If ValueIsFilled(DocumentPresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(DocumentPresentation);
	EndIf;
	
	If ValueIsFilled(OrderPresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(OrderPresentation);
	EndIf;
	
	If ValueIsFilled(CalculationsKindPresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(CalculationsKindPresentation);
	EndIf;
	
	Return StrPresentation;
	
EndFunction // PresentationOfCounterparty()

// Generates cash presentation string.
//
// Parameters:
//  ItemPresentation 		- String - Item presentation.
//  GoodAccountingKindPresentation 	- String - Item kind presentation.
//  SeriesPresentation 				- String - series presentation.
//  StagePresentation 				- String - stage presentation.
//
// Value returned:
//  String 							- String with Item presentation.
//
Function PresentationOfAccountablePerson(PresentationAccountablePerson,
	                       			  CurrencyPresentation = "",
									  DocumentPresentation = "") Export
	
	StrPresentation = """" + TrimAll(PresentationAccountablePerson) + """";
	
	If ValueIsFilled(CurrencyPresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(CurrencyPresentation);
	EndIf;
	
	If ValueIsFilled(DocumentPresentation)Then
		StrPresentation = StrPresentation + ", " + TrimAll(DocumentPresentation);
	EndIf;    
	
	Return StrPresentation;
	
EndFunction // PresentationOfItem()

// Function returns individual passport data used in print forms
// as string.
//
// Parameters
//  DataStructure 	– Structure – ref to Individual and Date
//
// Value returned:
//   String      	– String, containing passport data
//
Function GetPassportDataAsString(DataStructure) Export

	If NOT ValueIsFilled(DataStructure.Individual) Then
		Return NStr("en = 'No identification data.'");
	EndIf; 
	
	Query = New Query("SELECT
	                  |	IndividualDocumentsSliceLast.Period AS IssueDate,
	                  |	IndividualDocumentsSliceLast.DocumentKind,
	                  |	IndividualDocumentsSliceLast.Series,
	                  |	IndividualDocumentsSliceLast.Number,
	                  |	IndividualDocumentsSliceLast.Issuer
	                  |FROM
	                  |	InformationRegister.IndividualDocuments.SliceLast(
	                  |			&ToDate,
	                  |			Individual = &Individual
	                  |				AND IsIdentityDocument) AS IndividualDocumentsSliceLast");
						  
	Query.SetParameter("ToDate", 	DataStructure.Date);					  
	Query.SetParameter("Individual", 		DataStructure.Individual);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return NStr("en = 'No identification data'");	
	Else
		PassportData 	= QueryResult.Unload()[0];
		DocumentKind    = PassportData.DocumentKind;
		Series          = PassportData.Series;
		Number          = PassportData.Number;
		IssueDate       = PassportData.IssueDate;
		Issuer       = PassportData.Issuer;
		
		If NOT (NOT ValueIsFilled(IssueDate)
			   And NOT ValueIsFilled(DocumentKind)
			   And NOT ValueIsFilled(Series + Number + Issuer)) Then

			StringPassportData = NStr("en = '%DocumentKind%  Series: %Series% # %Number% Issued: %IssueDate% y, %Issuer%'");   
			
			StringPassportData = StrReplace(StringPassportData, "%DocumentKind%", ?(DocumentKind.IsEmpty(),"","" + DocumentKind + ", ")); 
			StringPassportData = StrReplace(StringPassportData, "%Series%", 		Series); 
			StringPassportData = StrReplace(StringPassportData, "%Number%", 		Number); 
			StringPassportData = StrReplace(StringPassportData, "%IssueDate%", 		Format(IssueDate,"DF='dd MMMM yyyy'")); 
			StringPassportData = StrReplace(StringPassportData, "%Issuer%", 		Issuer); 
			
			Return StringPassportData;

		Else
			Return NStr("en = 'No identification data'");
		EndIf;
	EndIf; 	

EndFunction // GetPassportDataAsString()

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF THE SALARY AND HR SUBSYSTEM

&AtServer
// Procedure adds formula parameters into structure.
//
Procedure AddParametersToStructure(FormulaString, ParametersStructure, Cancellation = False) Export

	Formula = FormulaString;
	
	OperandBeg = Find(Formula, "[");
	OperandEnd = Find(Formula, "]");
     
	IsOperand = True;
	While IsOperand Do
     
		If OperandBeg <> 0 And OperandEnd <> 0 Then
			
            Id = TrimAll(Mid(Formula, OperandBeg+1, OperandEnd - OperandBeg - 1));
            Formula = Right(Formula, StrLen(Formula) - OperandEnd);   
			
			Try
				If NOT ParametersStructure.Property(Id) Then
					ParametersStructure.Insert(Id);
				EndIf;
			Except
			    Break;
				Cancellation = True;
			EndTry 
			 
		EndIf;     
          
		OperandBeg = Find(Formula, "[");
		OperandEnd = Find(Formula, "]");
          
		If NOT (OperandBeg <> 0 And OperandEnd <> 0) Then
			IsOperand = False;
        EndIf;     
               
	EndDo;	

EndProcedure

// Function returns parameter value
//
Function CalculateParameterValue(ParametersStructure, CalculationParameter, ErrorText = "") Export

	// 1. Create query
	Query = New Query;
	Query.Text = CalculationParameter.Query;

    // 2. Control filling of all query parameters
    For each QueryParameter In CalculationParameter.QueryParameters Do
		If ValueIsFilled(QueryParameter.Value) Then
			Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), QueryParameter.Value);
		Else
			If ParametersStructure.Property(StrReplace(QueryParameter.Name, ".", "")) Then

	            StringPeriod = CalculationParameter.DataFilterPeriods.Find(StrReplace(QueryParameter.Name, ".", ""), "BoundaryDateName");
	            If StringPeriod <> Undefined  Then

					If StringPeriod.PeriodShift <> 0 Then
		            	NewPeriod = AddInterval(ParametersStructure[StrReplace(QueryParameter.Name, ".", "")], StringPeriod.ShiftPeriod, StringPeriod.PeriodShift);
		                Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), NewPeriod);
                    Else
                        Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), ParametersStructure[StrReplace(QueryParameter.Name, ".", "")]);
					EndIf;
		        
				Else
				
					Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), ParametersStructure[StrReplace(QueryParameter.Name, ".", "")]);	
				
				EndIf; 

            ElsIf ValueIsFilled(TypeOf(QueryParameter.Value)) Then

                Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), QueryParameter.Value);

			Else
				Message = New UserMessage();
				Message.Text = NStr("en = 'Query parameter values are not set'") + QueryParameter.Name + ErrorText;
				Message.Message();				
		        Return 0;		
			EndIf;		
		EndIf; 
	EndDo; 

	// 4. Execute query
	QueryResult = Query.Execute().Unload();
	If QueryResult.Count() = 0 Then		
        Return 0;
	Else	
		Return QueryResult[0][0];	
	EndIf;

EndFunction // CalculateParameterValue()

// Function adds interval to a date
//
// Parameters:
//     Periodicity (Enums.Periodicity)     						- periodicity of planning by schedule.
//     DateInPeriod (Date)                                   	- arbitrary date
//     BeforeAfter (number)                                   	- detetmines direction and number of periods, where date being shifted
//
// Value returned:
//     Date, differing from the source date for the specified number of periods
//
Function AddInterval(PeriodDate, Periodicity, Sign) Export

     If Sign = 0 Then
          NewPeriodDate = PeriodDate;
          
     ElsIf Periodicity = Enums.Periodicity.Day Then
          NewPeriodDate = BegOfDay(PeriodDate + Sign * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicity.Week Then
          NewPeriodDate = BegOfWeek(PeriodDate + Sign * 7 * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicity.Month Then
          NewPeriodDate = AddMonth(PeriodDate, Sign);
          
     ElsIf Periodicity = Enums.Periodicity.Quarter Then
          NewPeriodDate = AddMonth(PeriodDate, Sign * 3);
          
     ElsIf Periodicity = Enums.Periodicity.Year Then
          NewPeriodDate = AddMonth(PeriodDate, Sign * 12);
          
     Else
          NewPeriodDate=BegOfDay(PeriodDate) + Sign * 24 * 3600;
          
     EndIf;

     Return NewPeriodDate;

EndFunction // AddInterval()

// Function generates surname, name and patronymic in the same string.
//
// Parameters
//  Surname      			- ind surname
//  Name          			- ind name
//  Patronymic     			- ind patronymic
//  NameAndSurnameBriefly   - Boolean - if True (by default), Individual presentation
//                 includes surname and initials, if False - surname and full
//                 name and patronymic.
//
// Value to return:
//  Surname, name, patronymic in the same string.
//
Function GetSurnameNamePatronymic(Surname = " ", Name = " ", Patronymic = " ", NameAndSurnameBriefly = True) Export
	
	If NameAndSurnameBriefly Then
		Return ?(NOT IsBlankString(Surname), Surname + ?(NOT IsBlankString(Name)," " + Left(Name,1) + "." + 
				?(NOT IsBlankString(Patronymic) , 
				Left(Patronymic,1)+".", ""), ""), "");
	Else
		Return ?(NOT IsBlankString(Surname), Surname + ?(NOT IsBlankString(Name)," " + Name + 
				?(NOT IsBlankString(Patronymic) , " " + Patronymic, ""), ""), "");
	EndIf;

EndFunction // GetSurnameNamePatronymic()

// Function finds sentence first word
Function SelectWord(SourceLine) Export
	
	Buffer	 			= TrimL(SourceLine);
	PositionAfterSpace  = Find(Buffer, " ");

	If PositionAfterSpace = 0 Then
		SourceLine = "";
		Return Buffer;
	EndIf;
	
	SelectedWord 	= TrimAll(Left(Buffer, PositionAfterSpace));
	SourceLine 		= Mid(SourceLine, PositionAfterSpace + 1);
	
	Return SelectedWord;
	
EndFunction

/////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS GENERATING ACCOUNTING RECORDS

// Generates structure of accounting records table.
//
Procedure GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties) Export
	
	TableManagerial = New ValueTable;
	
	TableManagerial.Columns.Add("LineNumber");
	TableManagerial.Columns.Add("Period");
	TableManagerial.Columns.Add("Company");
	TableManagerial.Columns.Add("PlanningPeriod");
	TableManagerial.Columns.Add("AccountDr");
	TableManagerial.Columns.Add("CurrencyDr");
	TableManagerial.Columns.Add("AmountCurrencyDr");
	TableManagerial.Columns.Add("AccountCr");
	TableManagerial.Columns.Add("CurrencyCr");
	TableManagerial.Columns.Add("AmountCurrencyCr");
	TableManagerial.Columns.Add("Amount");
	TableManagerial.Columns.Add("Content");
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManagerial", TableManagerial);
	
EndProcedure // GenerateTransactionsTable()

/////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF PRINT FORMS GENERATION

// Function returns Item presentation for printing.
//
Function GetItemPresentationForPrinting(Item)  Export

	Return TrimAll(Item);

EndFunction // GetItemPresentationForPrinting()

// Function returns data about individual as structure,
// The data includes Name, Surname, Patronymic, position in the specified Company,
// passsport data and other
//
// Parameters:
//  Company  	- CatalogRef.Companies - Company, used
//                 		to determine employee position and division
//  Individual      		- CatalogRef.Individuals - individual,
//                 		for whom data is returned
//  SliceDate    	- Date 	 - date, on which, data being read
//  NameAndSurnameBriefly    - Boolean - if True (by default), Individual presentation
//                 includes surname and initials, if False - surname and full
//                 name and patronymic.
//
// Value returned:
//  Structure    - Structure with data about individual:
//                 "Surname",
//                 "Name"
//                 "Patronymic"
//                 "Presentation (Surname And N.P.)"
//                 "DocumentKind"
//                 "DocumentSerie"
//                 "DocumentNumber"
//                 "DocumentIssueDate"
//                 "DocumentIssuer".
//
Function IndData(Company, Individual, SliceDate, NameAndSurnameBriefly = True) Export
		
	QueryByPersons 		= New Query();
	QueryByPersons.SetParameter("SliceDate",   	SliceDate);
	QueryByPersons.SetParameter("Company", StandardSubsystemsServer.GetCompany(Company));
	QueryByPersons.SetParameter("Individual", 			Individual);
	QueryByPersons.Text =
	"SELECT
	|	IndividualsNameAndSurnameSliceLast.Surname,
	|	IndividualsNameAndSurnameSliceLast.Name,
	|	IndividualsNameAndSurnameSliceLast.Patronymic,
	|	Employees.EmployeeNumber,
	|	Employees.Position,
	|	IndividualDocumentsSliceLast.DocumentKind AS DocumentKind1,
	|	IndividualDocumentsSliceLast.Series AS DocumentSerie,
	|	IndividualDocumentsSliceLast.Number AS DocumentNumber,
	|	IndividualDocumentsSliceLast.Period AS DocumentIssueDate,
	|	IndividualDocumentsSliceLast.Issuer AS DocumentIssuer
	|FROM
	|	(SELECT
	|		Individuals.Ref AS Individual
	|	FROM
	|		Catalog.Individuals AS Individuals
	|	WHERE
	|		Individuals.Ref = &Individual) AS Inds
	|		LEFT JOIN InformationRegister.IndividualsNameAndSurname.SliceLast(&SliceDate, Individual = &Individual) AS IndividualsNameAndSurnameSliceLast
	|		ON Inds.Individual = IndividualsNameAndSurnameSliceLast.Individual
	|		LEFT JOIN InformationRegister.IndividualDocuments.SliceLast(
	|				&SliceDate,
	|				Individual = &Individual
	|					AND IsIdentityDocument) AS IndividualDocumentsSliceLast
	|		ON Inds.Individual = IndividualDocumentsSliceLast.Individual
	|		LEFT JOIN (SELECT TOP 1
	|			Employees.Employee.Code AS EmployeeNumber,
	|			Employees.Employee.Individual AS Individual,
	|			Employees.Position AS Position
	|		FROM
	|			EmployeePositionsAndPayRates.SliceLast(
	|					&SliceDate,
	|					Employee.Individual = &Individual
	|						AND Company = &Company) AS Employees
	|		
	|		) AS Employees
	|		ON Inds.Individual = Employees.Individual";
	
	Data = QueryByPersons.Execute().Choose();
	Data.Next();
	
	Result = New Structure("Surname, Name, Patronymic, Presentation, 
								|EmployeeNumber, Position, 
								|DocumentKind1, DocumentSerie, DocumentNumber,  
								|DocumentIssueDate, DocumentIssuer, 
								|PresentationOfDocument");

	FillPropertyValues(Result, Data);

	Result.Presentation           = GetSurnameNamePatronymic(Data.Surname, Data.Name, Data.Patronymic, NameAndSurnameBriefly);
	Result.PresentationOfDocument = GetNatPersonDocumentPresentation(Data);
	
	Return Result;
	
EndFunction // IndData()

// Get presentation for the ID document.
//
// Parameters
//  IndData 		– Data collection of individual (structure, table row, ...),
//                 		containing values: DocumentKind, DocumentSerie,
//                 		DocumentNumber, DocumentIssueDate, DocumentIssuer.
//
// Value returned:
//   String      	– Presentation of the ID document.
//
Function GetNatPersonDocumentPresentation(IndData) Export

	Return String(IndData.DocumentKind1) 	+ " series " +
			IndData.DocumentSerie       	+ ", number " +
			IndData.DocumentNumber      	+ ", issued " +
			Format(IndData.DocumentIssueDate, "DF=dd.MM.yyyy")  + " " +
			IndData.DocumentIssuer;

EndFunction // GetNatPersonDocumentPresentation()

// Procedure used to convert document number.
//
// Parameters:
//  Document     - (DocumentRef), document, whose number should be obtained
//                 for printing.
//
// Returned value.
//  String       - document number for printing
//
Function GetNumberForPrinting(DocumentNo, Prefix) Export

	If NOT ValueIsFilled(DocumentNo) Then 
		Return 0;
	EndIf;

	Number = TrimAll(DocumentNo);
	
	// delete prefix from document number
	If Find(Number, Prefix)=1 Then 
		Number = Mid(Number, StrLen(Prefix)+1);
	EndIf;
	
	// also, minus in front, may not be removed
	If Left(Number, 1) = "-" Then
		Number = Mid(Number, 2);
	EndIf;
	
	// delete leading zeros
	While Left(Number, 1)="0" Do
		Number = Mid(Number, 2);
	EndDo;

	Return Number;

EndFunction // GetNumberForPrinting()

// Returns data structure with the brief contractor description.
//
// Parameters:
//  ListOfInformation 	- value list with the values of Company parameters
//   ListOfInformation generated by function InfoAboutBusinessIndividual
//  List         		- list of the requested Company parameters
//  WithPrefix     		- Flag output or none Company parameter prefix
//
// Value returned:
//  String 				- describes Company / contractor / individual.
//
Function CompaniesDetails(ListOfInformation, List = "", WithPrefix = True) Export

	If IsBlankString(List) Then
		List = "Details,TIN,License,LegalAddress,PhoneNumbers,AccountNo,Bank,BIN,CorrespondentAccount";
	EndIf; 

	Result = "";

	MapOfParameters = New Map();
	MapOfParameters.Insert("Details",					" ");
	MapOfParameters.Insert("TIN",						" TIN ");
	MapOfParameters.Insert("License",					" ");
	MapOfParameters.Insert("IssueDate",		" from ");
	MapOfParameters.Insert("LegalAddress",				" ");
	MapOfParameters.Insert("PhoneNumbers",				" tel.: ");
	MapOfParameters.Insert("AccountNo",				" b/a ");
	MapOfParameters.Insert("Bank",               		" In bank ");
	MapOfParameters.Insert("BIN",                		" BIN ");
	MapOfParameters.Insert("CorrespondentAccount",           	" c/a ");
	MapOfParameters.Insert("CodeByOKPO",          		" Code on OKPO ");

	List          		= List + ?(Right(List, 1) = ",", "", ",");
	NumberOfParameters1 = StrOccurrenceCount(List, ",");

	For Counter = 1 to NumberOfParameters1 Do

		CommaPos = Find(List, ",");

		If CommaPos > 0  Then
			ParameterName = Left(List, CommaPos - 1);
			List = Mid(List, CommaPos + 1, StrLen(List));

			Try
				StringOfAddition = "";
				ListOfInformation.Property(ParameterName, StringOfAddition);

				If IsBlankString(StringOfAddition) Then
					Continue;
				EndIf;

				Prefix = MapOfParameters[ParameterName];
				If Not IsBlankString(Result)  Then
					Result = Result + ",";
				EndIf; 

				Result = Result + ?(WithPrefix = True, Prefix, "") + StringOfAddition;

			Except

				Message = New UserMessage();
		        Message.Text = NStr("en = 'Failed to define the value of Company parameter'") + ParameterName;
				Message.Message();

			EndTry;

		EndIf; 

	EndDo;

	Return Result;

EndFunction // CompaniesDetails()

// Standard function of the quantity format.
//
// Parameters:
//  Quantity   - Number, to be formatted.
//
// Value returned:
//  Formatted in the proper way quantity string presentation.
//
Function QuantityInWords(Quantity) Export

	WholePortion   	= Int(Quantity);
	Fraction 		= Round(Quantity - WholePortion, 3);

	If Fraction = Round(Fraction,0) Then
		WritingParameters = ", , , , , , , , 0";
   	ElsIf Fraction = Round(Fraction, 1) Then
		WritingParameters = "whole, whole, whole, f, tenth, tenths, tenths, m, 1";
   	ElsIf Fraction = Round(Fraction, 2) Then
		WritingParameters = "whole, whole, whole, f, hundredth, hundredths, hundredths, m, 2";
   	Else
		WritingParameters = "whole, whole, whole, f, thousandth, thousandths, thousandths, m, 3";
    EndIf;

	Return NumberInWords(Quantity, ,WritingParameters);

EndFunction // QuantityInWords()

// Standard for the current configuration function for formatting amount.
//
// Parameters:
//  Amount         	- Number, to be formatted
//  Currency      	- Ref to the item of "Currencies" catalog, if it's specified, then
//                 			currency presentation will be added into the resultant string
//  NZ           	- String, presenting number zero value
//  NGS          	- Char-separator of the number integer part.
//
// Value returned:
//  Properly formatted amount string presentation.
//
Function AmountsFormat(Amount, Currency = Undefined, NZ = "", NGS = "") Export

	FormatString = "ND1=15;NFD=2" +
					?(NOT ValueIsFilled(NZ), "", ";" + "NZ=" + 	NZ) +
					?(NOT ValueIsFilled(NGS),"", ";" + "NGS=" + NGS);

	ResultantString = TrimL(Format(Amount, FormatString));
	
	If ValueIsFilled(Currency) Then
		ResultantString = ResultantString + " " + TrimR(Currency);
	EndIf;

	Return ResultantString;

EndFunction // AmountsFormat()

// Function generates anount presentation in words in specified currency.
//
// Value returned:
//  String - amount in words.
//
Function GenerateAmountInWords(Amount, Currency) Export

	If Currency.WritingParameters = "" Then
		Return AmountsFormat(Amount);
	Else
		Return NumberInWords(Amount, , Currency.WritingParameters);
	EndIf;

EndFunction // GenerateAmountInWords()

// Formats amount of the bank payment document.
//
// Parameters:
//  Amount        				- Number  - attribute, to be formatted
//  OutputAmountWithoutCents 	- Boolean - flag of amount presentation without cents.
//
// Value to return:
//  Formatted string.
//
Function FormatPaymentDocumentAmount(Amount, OutputAmountWithoutCents = False) Export
	
	Result  		= Amount;
	WholePortion 	= Int(Amount);
	
	If Result = WholePortion Then
		If OutputAmountWithoutCents Then
			Result = Format(Result, "NFD=2; NDS='='; NG=0");
			Result = Left(Result, Find(Result, "="));
		Else
			Result = Format(Result, "NFD=2; NDS='-'; NG=0");
		EndIf;
	Else
		Result = Format(Result, "NFD=2; NDS='-'; NG=0");
	EndIf;
	
	Return Result;
	
EndFunction // FormatPaymentDocumentAmount()

// Formats amount of the bank payment document in words.
//
// Parameters:
//  Amount         				- Number  				- attribute, that has to be represented in words
//  Currency       				- CatalogRef.Currencies - currency of the the amount being
//                  				presented
//  OutputAmountWithoutCents 	- Boolean 				- flag of amount presentation without cents.
//
// Value to return:
//  Formatted string.
//
Function FormatPaymentDocumentAmountInWords(Amount, Currency, OutputAmountWithoutCents = False) Export
	
	Result     		= Amount;
	WholePortion    = Int(Amount);
	FormatString1   = "L=en_US; DE=False";
	SubjectParam 	= Currency.WritingParameters;
	
	If Result = WholePortion Then
		If OutputAmountWithoutCents Then
			Result = NumberInWords(Result, FormatString1, SubjectParam);
			Result = Left(Result, Find(Result, "0") - 1);
		Else
			Result = NumberInWords(Result, FormatString1, SubjectParam);
		EndIf;
	Else
		Result = NumberInWords(Result, FormatString1, SubjectParam);
	EndIf;
	
	Return Result;
	
EndFunction // FormatPaymentDocumentAmountInWords()

/////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS FOR WORK WITH INVOICES

// Function returns ref to the subordinate invoice
//
Function GetSubordinateInvoice(Basis, Received1 = False) Export

EndFunction // GetSubordinateInvoice()
 
// Apply hyperlink label on the Invoice
//
Procedure SetTextAboutInvoice(DocumentForm, Received1 = False) Export

	InvoiceFound = StandardSubsystemsServer.GetSubordinateInvoice(DocumentForm.Object.Ref, Received1);
	If ValueIsFilled(InvoiceFound) Then
		TextAboutInvoice 		 = NStr("en = '# %Number% from %Date%'");
		TextAboutInvoice 		 = StrReplace(TextAboutInvoice, "%Number%", InvoiceFound.Number);
		TextAboutInvoice 		 = StrReplace(TextAboutInvoice, "%Date%", 	Format(InvoiceFound.Date, "DF=dd.MM.yyyy"));
		DocumentForm.InvoiceText = TextAboutInvoice;	
	Else
	    DocumentForm.InvoiceText = "Create invoice";
	EndIf;

EndProcedure // FillTextAboutInvoice()
