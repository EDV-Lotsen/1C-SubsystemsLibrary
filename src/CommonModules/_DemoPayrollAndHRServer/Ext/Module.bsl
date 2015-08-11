////////////////////////////////////////////////////////////////////////////////
// Payroll and HR demo subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

// Determines whether header attributes contain the attribute with the passed name.
//
// Parameters:
//  AttributeName 	 - attribute name string.
//  DocumentMetadata - document metadata object where the attribute is searched.
//
// Returns:
//  True if the attribute is found, otherwise is False.
//
Function IsDocumentAttribute(AttributeName, DocumentMetadata)

	Return NOT (DocumentMetadata.Attributes.Find(AttributeName) = Undefined);

EndFunction // IsDocumentAttribute()

// Fills common document attributes.
// Is called from OnCreateAtServer handlers in form modules of all subsystem documents.
//
Procedure FillDocumentHeader(Object,
	ParameterCopyingValue	= Undefined,
	BasisParameter 			= Undefined,
	DocumentStatus,
	PictureDocumentStatus,
	PostingIsAllowed,
	FillingValues 			= Undefined) Export
	
	
	User 			 = Users.CurrentUser();
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
				SettingValue = _DemoPayrollAndHRServerCached.GetValueByDefaultUser(User, "MainCompany");
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
				Object.Responsible = _DemoPayrollAndHRServerCached.GetValueByDefaultUser(User, "MainResponsible");
			EndIf;
			
			If DocumentMetadata.Name = "CustomerOrder" Then
				If IsDocumentAttribute("StatusOfOrder", DocumentMetadata) 
					And NOT (FillingValues <> Undefined And FillingValues.Property("StatusOfOrder") And ValueIsFilled(FillingValues.StatusOfOrder))
					And NOT (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.StatusOfOrder)) Then
					SettingValue = _DemoPayrollAndHRServerCached.GetValueByDefaultUser(User, "StatusOfNewCustomerOrder");
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
	
EndProcedure

// Shows message about field filling error.
//
Procedure ShowErrorMessage(ThisObject, MessageText, TabularSectionName = Undefined, LineNumber = Undefined, Field = Undefined, Cancellation = False)Export
		
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
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// Fill values of the keys, containig document data.
	FillPropertyValues(StructureAdditionalProperties.ForPosting, QueryResultSelection);
	
	// Determine and assign value of the moment, on which document control should be performed.
	StructureAdditionalProperties.ForPosting.Insert("ControlTime", 		Date('00010101'));
	StructureAdditionalProperties.ForPosting.Insert("ControlPeriod", 	Date("39991231"));
		
	// Assign Company in case of accounting by company.
	StructureAdditionalProperties.ForPosting.Company = StructureAdditionalProperties.ForPosting.Company;
	

	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// Fill values for the keys, containing acounting policy data.
	FillPropertyValues(StructureAdditionalProperties.AccountingPolicy, QueryResultSelection);
	
EndProcedure // InitializeAdditionalPropertiesForPosting()

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
				
				Selection = Query.Execute().Select();
				
				While Selection.Next() Do
					
					RegistersArray.Add(Selection.RegisterName);
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return RegistersArray;
	
EndFunction // GetNamesArrayOfUsedRegisters()

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

// Function returns constant ControlBalancesDuringPosting value.
//
Function RunBalanceControl() Export
	
	Return Constants.ControlBalancesDuringPosting.Get();
	
EndFunction

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

// Create records in accounting register GeneralJournal.
//
Procedure ReflectGeneralJournal(AdditionalProperties, RegisterRecords, Cancellation) Export
	
	TableGeneralJournal = AdditionalProperties.TableForRegisterRecords.TableGeneralJournal;
	
	If Cancellation
	   Or TableGeneralJournal.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGeneralJournal 		= RegisterRecords.GeneralJournal;
	RegisterRecordsGeneralJournal.Write = True;
	
	For Each RowTableGeneralJournal In TableGeneralJournal Do
		RegisterRecordGeneralJournal = RegisterRecordsGeneralJournal.Add();
		FillPropertyValues(RegisterRecordGeneralJournal, RowTableGeneralJournal);
	EndDo;
	
EndProcedure

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
//     Periodicity (Enums.Periodicities)     						- periodicity of planning by schedule.
//     DateInPeriod (Date)                                   	- arbitrary date
//     BeforeAfter (number)                                   	- detetmines direction and number of periods, where date being shifted
//
// Value returned:
//     Date, differing from the source date for the specified number of periods
//
Function AddInterval(PeriodDate, Periodicity, Sign) Export

     If Sign = 0 Then
          NewPeriodDate = PeriodDate;
          
     ElsIf Periodicity = Enums.Periodicities.Day Then
          NewPeriodDate = BegOfDay(PeriodDate + Sign * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicities.Week Then
          NewPeriodDate = BegOfWeek(PeriodDate + Sign * 7 * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicities.Month Then
          NewPeriodDate = AddMonth(PeriodDate, Sign);
          
     ElsIf Periodicity = Enums.Periodicities.Quarter Then
          NewPeriodDate = AddMonth(PeriodDate, Sign * 3);
          
     ElsIf Periodicity = Enums.Periodicities.Year Then
          NewPeriodDate = AddMonth(PeriodDate, Sign * 12);
          
     Else
          NewPeriodDate=BegOfDay(PeriodDate) + Sign * 24 * 3600;
          
     EndIf;

     Return NewPeriodDate;

EndFunction // AddInterval()

// Gets accrual kind expenses account by default.
//
// Parameters:
//  DataStructure - Structure, containing object attributes, that have to be received
//                 		and filled with the attributes, that are required
//                 		for the receiving.
//
Procedure GetPaymentKindAccountOfExpenses(DataStructure) Export
	
	AccountOfExpenses = DataStructure.PaymentDeductionKind.AccountOfExpenses;
	AccountKind = AccountOfExpenses.AccountType;
	If NOT (AccountKind = Enums.AccountTypes.CostOfSales
		   OR AccountKind = Enums.AccountTypes.Expense
		   OR AccountKind = Enums.AccountTypes.OtherCurrentAsset
		   OR AccountKind = Enums.AccountTypes.OtherNonCurrentAsset) Then
	
		AccountOfExpenses = ChartsOfAccounts.ChartOfAccounts.EmptyRef();
	
	EndIf; 	
	
	DataStructure.AccountOfExpenses = AccountOfExpenses;

EndProcedure

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
	
EndProcedure

/////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS OF PRINT FORMS GENERATION

// Function returns Item presentation for printing.
//
Function GetItemPresentationForPrinting(Item)  Export

	Return TrimAll(Item);

EndFunction // GetItemPresentationForPrinting()

// Function returns information Entity responsible persons and their
// positions.
//
// Parameters:
//  OrganizationalUnit - Composite type: CatalogRef.Entities,
//                 CatalogRef.Cashes, CatalogRef.StoragePlaces,
//                 organizational unit for which we need to get
//                 information about responsible persons
//  SliceDate    - Date - date, on which data being read.
//
// Value returned:
//  Structure    - Structure with data about individuals
//                 of the base unit.
//
Function CompanyResponsiblePersons(Company, SliceDate) Export
	
	Result = New Structure("CompanyHeadFullName, CompanyHeadPosition, ChiefAccountantFullName, CashierFullName, WarehouseManNameAndSurname, WarehouseMan_Position");

	If Company <> Undefined Then

		Query = New Query;
		Query.SetParameter("SliceDate", SliceDate);
		Query.SetParameter("Company", Company);

		Query.Text = 
		"SELECT
		|	ResponsiblePersonsSliceLast.Company AS Company,
		|	ResponsiblePersonsSliceLast.Position AS Position,
		|	ResponsiblePersonsSliceLast.Position.Description AS PositionTitle
		|FROM
		|	InformationRegister.ResponsiblePersons.SliceLast(&SliceDate, Company = &Company) AS ResponsiblePersonsSliceLast";
		
		Selection = Query.Execute().Select();

		While Selection.Next() Do
			If Selection.Position = Catalogs.Positions.Director Then
				Result.CompanyHeadPosition 	= Selection.Position;
			EndIf;
			
		EndDo;
	EndIf;

	Return Result

EndFunction // CompanyResponsiblePersons()

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

// Function finds actual address value in the contact information.
//
// Parameters:
//  Object          - CatalogRef, contact information object
//  AddressType     - Contact information type.
//
// Value to return:
//  String 			- Presentation of the found address.
//
Function GetContactInformation(ContactInformationObject, InformationKind) Export
	
	If TypeOf(ContactInformationObject) = Type("CatalogRef.Companies") Then 		
		TableSource = "Companies";		
	Else 
		Return "";	
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Object",  ContactInformationObject);
	Query.SetParameter("Kind"   , InformationKind);
	
	Query.Text = "SELECT 
	|	ContactInformation.Presentation
	|FROM
	|	Catalog." + TableSource + ".ContactInformation AS ContactInformation
	|WHERE
	|	ContactInformation.Kind = &Kind
	|	And ContactInformation.Ref = &Object";

	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return "";
	Else
		Return QueryResult.Unload()[0].Presentation;
	EndIf;

EndFunction // GetAddressFromContactInformation()

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
		Return NumberInWords(Amount, "L=en_US", Currency.WritingParameters);
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

