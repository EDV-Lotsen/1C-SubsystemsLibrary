#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Conversion export handlers SL 2.1.2 --> SL 2.2.2 
// {c2de3602-78fd-11e3-900e-005056c00000}
// 
// This module contains export procedures of conversion event handlers and is intended 
// for debugging exchange rules. It is recommended that you copy the module text to clipboard 
// as soon as debugging is completed, and then import it to the Data conversion database.
//
// /////////////////////////////////////////////////////////////////////////////
// VARIABLE ACRONYMS (ABBREVIATIONS) USED
//
//  OCR  - object conversion rule
//  PCR  - object property conversion rule
//  PGCR - object property group conversion rule
//  DER  - data export rule
//  DCR  - data clearing rule

////////////////////////////////////////////////////////////////////////////////
// DATA PROCESSOR VARIABLES
// Please do not modify this section.

Var Parameters;
Var Algorithms;
Var Requests;
Var NodeForExchange;
Var CommonProceduresFunctions;

////////////////////////////////////////////////////////////////////////////////
// CONVERSION HANDLERS (GLOBAL)
// Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// OBJECT CONVERSION HANDLERS
// Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// OBJECT PROPERTY CONVERSION HANDLERS
// Procedure logic can be modified in this section.

Procedure PCR__DemoCustomerOrder_Number_OnExportProperty_18_20(ExchangeFile, Source, Target, IncomingData, OutgoingData,
	PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
	ExtDimensions, Empty, OCRName, PropertyOCR,PropertyNode, PropertyCollectionNode,
	ExtDimensionTypeOCRName, ExportObject) Export

	// Type and source may vary between versions, therefore must be passed using a parameter
	If Metadata.Documents._DemoCustomerOrder.Attributes.Find("OrderStatus") = Undefined Then
		// Junior version
		If Source.OrderClosed Then
			Value = "Closed";
		Else
			Value = "NotApproved";
		EndIf;
	Else
		// Senior version
		CurrentOrderStatus = Source.OrderStatus;
		If CurrentOrderStatus.IsEmpty() Then
			Value = "NotApproved";
		Else
			EnumIndex = Enums["_DemoCustomerOrderStatuses"].IndexOf(CurrentOrderStatus);
			Value = CurrentOrderStatus.Metadata().EnumValues.Get(EnumIndex).Name;
		EndIf;
	EndIf;

EndProcedure

Procedure PCR_Companies_ContactInformation_FieldValues_OnExportProperty_10_11(ExchangeFile, Source, Target, IncomingData, OutgoingData,
	PCR, OCR, CollectionObject, Cancel, Value, KeyAndValue, ExtDimensionType,
	ExtDimensions, Empty, OCRName, PropertyOCR,PropertyNode, PropertyCollectionNode,
	ExtDimensionTypeOCRName, ExportObject) Export

	SLVersion = StandardSubsystemsServer.LibVersion();
	If CommonUseClientServer.CompareVersions(SLVersion, "2.1.4.1") >= 0 Then
		
		ContactInformationManagementModule = Eval("ContactInformationManagement");
		Value = ContactInformationManagementModule.PreviousContactInformationXMLFormat(Value, True);
		
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OBJECT PROPERTY GROUP CONVERSION HANDLERS 
// Procedure logic can be modified in this section.

Procedure PGCR_AdditionalDataAndAttributeSets_AdditionalAttributes_BeforeProcessExport_5_39(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR_AdditionalDataAndAttributeSets_AdditionalData_BeforeProcessExport_7_39(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DATA EXPORT HANDLERS 
// Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// DATA CLEARING HANDLERS 
// Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// PARAMETER HANDLERS 
// Procedure logic can be modified in this section.

////////////////////////////////////////////////////////////////////////////////
// ALGORITHMS
// This section can be modified at your convenience.
// You can also add procedures with algorithms to any of the above sections.

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS 
// Please do not modify this section.

// Internal. Initializes any variables required for debug purposes.
//
// Parameters:
//  Owner - InfobaseObjectConversion data processor.
//
Procedure AttachDataProcessorToDebug(Owner) Export

	Parameters                = Owner.Parameters;
	CommonProceduresFunctions = Owner;
	Queries                  = Owner.Queries;
	NodeForExchange		 	     = Owner.NodeForExchange;

EndProcedure

#EndIf
