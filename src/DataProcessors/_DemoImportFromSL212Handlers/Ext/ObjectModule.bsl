#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Conversion import handlers SL 2.1.2 --> SL 2.2.2 {c2de3602-78fd-11e3-900e-005056c00000}                                                                                                   
// 
// This module contains export procedures of conversion event handlers and is intended for debugging exchange rules. It is
// recommended that you copy the module text to clipboard as soon
// as debugging is completed, and then import it to the Data conversion database.
//
// /////////////////////////////////////////////////////////////////////////////
// USED ACRONYMS NAME VARIABLE (ABBREVIATIONS)
//
//  OCR  - object conversion
//  rule PCR  - object property conversion
//  rule. PGCR - object property group conversion
//  rule DER  - data export
//  rule DCR  - data clearing rule

////////////////////////////////////////////////////////////////////////////////
// DATA
// PROCESSOR VARIABLES Please do not modify this section.

Var Parameters;
Var Algorithms;
Var Requests;
Var NodeForExchange;
Var CommonProceduresFunctions;

////////////////////////////////////////////////////////////////////////////////
// CONVERSION
// HANDLERS (GLOBAL) Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// OBJECT CONVERSION
// HANDLERS Procedure logic can be modified in this section.

Procedure OCR__DemoCustomerOrder_OnImportObject(ExchangeFile, ObjectFound, Object, DontReplaceObject, ObjectModified) Export

	// Saving data that will be processed after the import will be completed
	PartnersAndContactsTable = Object.PartnersAndContacts.Unload();
	If PartnersAndContactsTable.Columns.Find("TabularSectionRowID") <> Undefined Then
		// Existing properties - flag shows whether the conversion is required
		
		PartnersAndContactsTable.Indexes.Add("Partner, Contact");
		Object.AdditionalProperties.Insert("PartnersAndContactsTable", PartnersAndContactsTable);
	EndIf;

EndProcedure

Procedure OCR__DemoCustomerOrder_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified,
	ObjectTypeName, ObjectFound) Export

	
	// 1. Order closing synchronization
	OrderStateID = ObjectParameters.Get("OrderStateID");
	
	If Metadata.Documents._DemoCustomerOrder.Attributes.Find("OrderStatus") = Undefined Then
		Object.OrderClosed = OrderStateID = "Closed";
	Else
		Object.OrderStatus = Enums["_DemoCustomerOrderStatuses"][OrderStateID];
	EndIf;
		
	// 2. Contact information synchronization with the tabular section
	InitialPartnersAndContacts = Undefined;
	If Object.AdditionalProperties.Property("PartnersAndContactsTable", InitialPartnersAndContacts) Then
		ProcessedContactInformation = New Map;
		PartnersAndContactsFilter = New Structure("Partner, Contact");
		
		// Looping through new partners and contacts and searching for the matches in initial contact information
		For Each NewParntnerDataRow In Object.PartnersAndContacts Do
			
			// Searching for the contact information ID in the saved table
			FillPropertyValues(PartnersAndContactsFilter, NewParntnerDataRow);
			FoundPartnersAndContacts = InitialPartnersAndContacts.FindRows(PartnersAndContactsFilter);
			If FoundPartnersAndContacts.Count()>0 Then
				
				// Saving data that will be processed after import will be completed
				NewParntnerDataRow.TabularSectionRowID = FoundPartnersAndContacts[0].TabularSectionRowID;
				
				// Setting mark of processing
				ProcessedContactInformation.Insert(NewParntnerDataRow.TabularSectionRowID, 1);
				
				// Clearing data for next search
				For Each OldParntnerDataRow In FoundPartnersAndContacts Do
					InitialPartnersAndContacts.Delete(OldParntnerDataRow);
				EndDo;
			Else
				// Clearing reference to the contact information
				NewParntnerDataRow.TabularSectionRowID = 0;
			EndIf;
			
		EndDo;
		
		// Deleting unused items
		NewContactInformationPosition = Object.ContactInformation.Count();
		While NewContactInformationPosition>0 Do
			NewContactInformationPosition = NewContactInformationPosition - 1;
			NewContactInformationID = Object.ContactInformation[NewContactInformationPosition].TabularSectionRowID;
			If ProcessedContactInformation[NewContactInformationID]=Undefined Then
				Object.ContactInformation.Delete(NewContactInformationPosition);
			EndIf;
		EndDo;
	
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OBJECT PROPERTY CONVERSION
// HANDLERS Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// OBJECT PROPERTY GROUP CONVERSION
// HANDLERS Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// DATA EXPORT
// HANDLERS Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// DATA CLEARING
// HANDLERS Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// PARAMETER
// HANDLERS Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// ALGORITHMS
// This section can be modified at your convenience.
// You can also add procedures with algorithms to any of the above sections.

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES
// AND FUNCTIONS Please do not modify this section.

// Internal. Initializes any variables required for debug purposes
//
// Parameters:
//  Owner - InfobaseObjectConversion data processor
//
Procedure AttachDataProcessorToDebug(Owner) Export

	Parameters            	 = Owner.Parameters;
	CommonProceduresFunctions	 = Owner;
	Queries              	 = Owner.Queries;
	NodeForExchange		 	 = Owner.NodeForExchange;

EndProcedure

#EndIf
