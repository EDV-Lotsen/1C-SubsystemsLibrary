// COMMON PROCEDURES AND FUNCTIONS

// Procedure updates document status.
//
Procedure RefreshDocumentStatus(Object, DocumentStatus, PictureDocumentStatus, PostingIsAllowed) Export
	
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
	
EndProcedure // RefreshDocumentStatus()

// PROCEDURES AND FUNCTIONS OF THE SALARY AND HR SUBSYSTEM

// Procedure assignes default expenses account on the accrual choice
// in document tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm, contains document form, whose attributes
//                 are processed by the procedure.
//
Procedure PutExpensesAccountByDefault(DocumentForm) Export
    		
	TabularSectionRow = DocumentForm.Items.PaymentsDeductions.CurrentData;
	
    If ValueIsFilled(TabularSectionRow.PaymentDeductionKind) Then

		Structure = New Structure("PaymentDeductionKind, AccountOfExpenses", TabularSectionRow.PaymentDeductionKind);
		_DemoPayrollAndHRServer.GetPaymentKindAccountOfExpenses(Structure);
    	TabularSectionRow.AccountOfExpenses = Structure.AccountOfExpenses;
	
	EndIf;
	
EndProcedure // PutExpensesAccountByDefault()

// Procedure assignes registration period on the beginning of the month.
//
Procedure OnChangeAccountingPeriod(DocumentForm) Export
    	
	DocumentForm.Object.AccountingPeriod = BegOfMonth(DocumentForm.Object.AccountingPeriod);
	
EndProcedure // PutExpensesAccountByDefault()

// PROCEDURES AND FUNCTIONS OF WORK WITH THE DYNAMIC LISTS

// Deletes dynamic list filter item
//
//Parameters:
//List  	- modified dynamic list,
//FieldName - name of composition field, whose filter has to be deleted
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
//List				- Modified dynamic list,
//FieldName			- Name of composition field, whose filter needs to be set,
//ComparisonKind	- Filter comparison type, by default - Equal to,
//RightValue 		- Filter value
//
Procedure SetListFilterItem(List, FieldName, RightValue, ComparisonType = Undefined) Export
	
	FilterItem 					= List.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue    	= New DataCompositionField(FieldName);
	FilterItem.ComparisonType   = ?(ComparisonType = Undefined, DataCompositionComparisonType.Equal, ComparisonType);
	FilterItem.Use    			= True;
	FilterItem.RightValue   	= RightValue;
	FilterItem.ViewMode 		= DataCompositionSettingsItemViewMode.Inaccessible;
	
EndProcedure // SetListFilterItem()

// Modifies dynamic list filter item
//
//Parameters:
//List         		- Modified dynamic list,
//FieldName        	- Name of composition field, whose filter needs to be set,
//ComparisonKind   	- Filter comparison type, by default - Equal to,
//RightValue		- Filter value,
//Set     			- Flag indicating that filter has to be set up
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

