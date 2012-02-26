
////////////////////////////////////////////////////////////////////////////////
// EXPORT PROCEDURES AND FUNCTIONS

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

// COMMON PROCEDURES AND FUNCTIONS

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
//  Number 		   - amount, recalculated to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, RateBeg, RateEnd,	MultiplicityBeg = 1, MultiplicityEnd = 1) Export
	
	If (RateBeg = RateEnd) And (MultiplicityBeg = MultiplicityEnd) Then
		Return Amount;
	EndIf;
	
	If RateBeg = 0 OR RateEnd = 0 OR MultiplicityBeg = 0 OR MultiplicityEnd = 0 Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Found zero exchange rate. Recalculation failed.'");
		Message.Message();
		Return Amount;
	EndIf;
	
	AmountRecalculated = Round((Amount * RateBeg * MultiplicityEnd) / (RateEnd * MultiplicityBeg), 2);
	
	Return AmountRecalculated;
	
EndFunction // RecalculateFromCurrencyToCurrency()

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

// PROCEDURES FOR WORK WITH SUBORDINATE TABULAR SECTIONS

// Procedure adds link key into tabular section.
//
// Parameters:
//  DocumentForm - ManagedForm, contains document form, whose attributes
//                 are processed by the procedure
//
Procedure AddConnectionKeyToTabularSectionRow(DocumentForm) Export

	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
    
	TabularSectionRow.ConnectionKey = CreateNewLinkKey(DocumentForm);		
        
EndProcedure // AddConnectionKeyToTabularSectionRow()

// Procedure adds link key into subordinate tabular section.
//
// Parameters:
//  DocumentForm 					- ManagedForm, contains document form, whose attributes
//                 							are processed by the procedure
//	SubordinateTabularSectionName 	- String, containing name of the subordinate tabular
//                 							section.
//
Procedure AddConnectionKeyToSubordinateTabularSectionRow(DocumentForm, SubordinateTabularSectionName) Export
	
	SubordinateTabularSection = DocumentForm.Items[SubordinateTabularSectionName];
	
	SubordinateTabularSectionRow = SubordinateTabularSection.CurrentData;
	SubordinateTabularSectionRow.ConnectionKey = SubordinateTabularSection.RowFilter["ConnectionKey"];
	
	FilterStr = New FixedStructure("ConnectionKey", SubordinateTabularSection.RowFilter["ConnectionKey"]);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;

EndProcedure // AddConnectionKeyToSubordinateTabularSectionRow()

// Procedure prohibits to insert new line, if main tabular section line is not selected.
//
// Parameters:
//  DocumentForm 					- ManagedForm, contains document form, whose attributes
//                							 	are processed by the procedure
//	SubordinateTabularSectionName 	- String, containing name of the subordinate tabular
//                 								section.
//
Function BeforeAddToSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	If DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData = Undefined Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The row in the tabular section has not been selected'");
		Message.Message();
		Return True;
	Else
		Return False;
	EndIf;
		
EndFunction // BeforeAddToSubordinateTabularSection()

// Procedure deletes lines from the subordinate tabular section.
//
// Parameters:
//  DocumentForm 					- ManagedForm, contains document form, whose attributes
//                 								are processed by the procedure
//	SubordinateTabularSectionName 	- String, containing name of the subordinate tabular
//              							    section.
//
Procedure DeleteRowsOfSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export

	TabularSectionRow 		  = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	SubordinateTabularSection = DocumentForm.Object[SubordinateTabularSectionName];
   	
    SearchResult = SubordinateTabularSection.FindRows(New Structure("ConnectionKey", TabularSectionRow.ConnectionKey));
	For each SearchString In  SearchResult Do
		DeleteIndex = SubordinateTabularSection.IndexOf(SearchString);
		SubordinateTabularSection.Delete(DeleteIndex);
	EndDo;
	
EndProcedure // DeleteRowsOfSubordinateTabularSection()

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

// Procedure applies filter to the subordinate tabular section.
//
Procedure SetFilterOnSubordinateTabularSection(DocumentForm, SubordinateTabularSectionName) Export
	
	TabularSectionRow = DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData;
	If TabularSectionRow = Undefined Then
		Return;
	EndIf; 
	
	FilterStr = New FixedStructure("ConnectionKey", DocumentForm.Items[DocumentForm.TabularSectionName].CurrentData.ConnectionKey);
	DocumentForm.Items[SubordinateTabularSectionName].RowFilter = FilterStr;
	
EndProcedure //SetFilterOnSubordinateTabularSection()

// PROCEDURES AND FUNCTIONS OF THE SALARY AND HR SUBSYSTEM

// Procedure assignes registration period on the beginning of the month.
//
Procedure OnChangeAccountingPeriod(DocumentForm) Export
    	
	DocumentForm.Object.AccountingPeriod = BegOfMonth(DocumentForm.Object.AccountingPeriod);
	
EndProcedure // PutExpensesAccountByDefault()

// PROCEDURES AND FUNCTIONS OF THE PRICING SUBSYSTEMS

// Procedure calculates tabular section line amount on filling by "Prices and currency".
//
Procedure CalculateTabularSectionRowAmount(DocumentForm, TabSectionLine)
	
	If TabSectionLine.Property("Quantity") And TabSectionLine.Property("Price") Then
		TabSectionLine.Amount = TabSectionLine.Quantity * TabSectionLine.Price;
	EndIf;
	
	If TabSectionLine.Property("DiscountRate") Then
		If TabSectionLine.DiscountRate = 100 Then
			TabSectionLine.Amount = 0;
		ElsIf TabSectionLine.DiscountRate <> 0 And TabSectionLine.Quantity <> 0 Then
			TabSectionLine.Amount = TabSectionLine.Amount * (1 - TabSectionLine.DiscountRate / 100);
		EndIf;
	EndIf;	
	
EndProcedure // CalculateTabularSectionRowAmount()

// Perform recalculation of price of tabular section based on currency  after changes done in from
// "Prices and currency".
//
// Parameters:
//  PreviousCurrency - CatalogRef.Currencies, contains link to previous
//                 currency.
//
Procedure RecalculateTabularSectionPricesByCurrency(DocumentForm, PreviousCurrency, TabularSectionName) Export
	
	StructureRates = StandardSubsystemsServer.GetCurrencyRates(PreviousCurrency, DocumentForm.Object.DocumentCurrency, DocumentForm.Object.Date);
																   
	For each TabularSectionRow In DocumentForm.Object[TabularSectionName] Do
		
		// Price.
		If TabularSectionRow.Property("Price") Then
			
			TabularSectionRow.Price = RecalculateFromCurrencyToCurrency(TabularSectionRow.Price, 
																	StructureRates.RateBeg, 
																	StructureRates.ExchangeRate, 
																	StructureRates.MultiplicityBeg, 
																	StructureRates.Multiplicity);
																	
			CalculateTabularSectionRowAmount(DocumentForm, TabularSectionRow);
			
		// Amount.
		ElsIf TabularSectionRow.Property("Amount") Then
			
			TabularSectionRow.Amount = RecalculateFromCurrencyToCurrency(TabularSectionRow.Amount, 
																	StructureRates.RateBeg, 
																	StructureRates.ExchangeRate, 
																	StructureRates.MultiplicityBeg, 
																	StructureRates.Multiplicity);														
					
			If TabularSectionRow.Property("DiscountRate") Then
				
				// Discounts.
				If TabularSectionRow.DiscountRate = 100 Then
					TabularSectionRow.Amount = 0;
				ElsIf TabularSectionRow.DiscountRate <> 0 And TabularSectionRow.Quantity <> 0 Then
					TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountRate / 100);
				EndIf;
								
			EndIf;														
			
			TabularSectionRow.Amount = TabularSectionRow.Amount;
			
		EndIf;
        		        
	EndDo; 

EndProcedure // RecalculateTabularSectionPricesByCurrency()

// PROCEDURES AND FUNCTIONS FOR WORK WITH INVOICES

// Apply hyperlink label on the Invoice
//
Procedure SetTextAboutInvoice(DocumentForm, Received1 = False) Export

	InvoiceFound = StandardSubsystemsServer.GetSubordinateInvoice(DocumentForm.Object.Ref, Received1);
	If ValueIsFilled(InvoiceFound) Then
		DocumentForm.InvoiceText = InvoicePresentation(InvoiceFound.Number, InvoiceFound.Date);	
	Else
	    DocumentForm.InvoiceText = "Create invoice";
	EndIf;

EndProcedure // FillTextAboutInvoice()

// Generates hyperlink label for the Invoice
//
Function InvoicePresentation(Date, Number) Export

	TextAboutInvoice = NStr("en = '# %Number% from  %Date%'");
	TextAboutInvoice = StrReplace(TextAboutInvoice, "%Number%", Number);
	TextAboutInvoice = StrReplace(TextAboutInvoice, "%Date%", Format(Date, "DF=dd.MM.yyyy"));	
	Return TextAboutInvoice;

EndFunction // GetInvoicePresentation()

// Apply hyperlink label on the Invoice
//
Procedure OpenInvoice(DocumentForm, Received1 = False) Export

	If DocumentForm.Object.DeletionMark Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The invoice cannot be entered on the base of the document with deletion mark'");	
		Message.Message();
		Return;	
	EndIf;
	
	If DocumentForm.Modified Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The document has been modified! First you need to record the document!'");	
		Message.Message();
		Return;	
	EndIf;
	
	If NOT ValueIsFilled(DocumentForm.Object.Ref) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'The document has not been recorded. First you need to record the document!'");	
		Message.Message();
		Return;	
	EndIf;
	
	If Received1 Then
		FormName = "Document.PurchaseInvoiceReceived.ObjectForm";
	Else
		FormName = "Document.Invoice.ObjectForm";
	EndIf;	
	
	InvoiceFound = StandardSubsystemsServer.GetSubordinateInvoice(DocumentForm.Object.Ref, Received1);	
	If ValueIsFilled(InvoiceFound) Then
		OpenForm(FormName, New Structure("Key", InvoiceFound.Ref), DocumentForm);	
	Else
	    OpenForm(FormName, New Structure("Basis", DocumentForm.Object.Ref), DocumentForm);
	EndIf;
	
EndProcedure // FillTextAboutInvoice()

// PROCEDURES AND FUNCTIONS OF THE SUBSYSTEM ADDITIONAL ATTRIBUTES

// Procedure expands value tree on the form.
//
Procedure ExpandPropertiesValuesTree(FormItem, Tree) Export
	
	For each Item In Tree.GetItems() Do
		Id = Item.GetID();
		FormItem.Expand(Id, True);
	EndDo;
	
EndProcedure // ExpandPropertiesValuesTree()

// Procedure handler of event BeforeDelete.
//
Procedure PropertyValueTreeBeforeDelete(Item, Cancellation, Modified) Export
	
	Cancellation 			= True;
	Item.CurrentData.Value 	= Item.CurrentData.PropertyValueType.AdjustValue(Undefined);
	Modified 	  			= True;
	
EndProcedure // PropertyValueTreeBeforeDelete()

// Procedure handler of event OnStartEdit.
//
Procedure PropertyValueTreeOnStartEdit(Item) Export
	
	Item.ChildItems.Value.TypeRestriction = Item.CurrentData.PropertyValueType;
	
EndProcedure // PropertyValueTreeOnStartEdit()

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
