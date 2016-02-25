#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Data conversion export handlers DemoDataSynchronizationWithSL 
// {4ce80052-9871-11e3-b918-005056c00000}                                                                   
// 
// This module contains export procedures of conversion event handlers and is intended 
// for debugging exchange rules. It is recommended that you copy the module text to clipboard 
// as soon as debugging is completed, and then import it to the Data conversion database.
//
// /////////////////////////////////////////////////////////////////////////////
//  VARIABLE ACRONYMS (ABBREVIATIONS) USED
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

////////////////////////////////////////////////////////////////////////////////
// OBJECT PROPERTY GROUP CONVERSION HANDLERS 
// Procedure logic can be modified in this section.

Procedure PGCR__DemoCounterparties_AdditionalAttributes_BeforeProcessExport_12_16(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR__DemoCounterparties_ContactInformation_BeforeProcessExport_16_16(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR__DemoProductsAndServices_Similar_BeforeProcessExport_13_17(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR__DemoProductsAndServices_AdditionalAttributes_BeforeProcessExport_15_17(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR__DemoPartners_AdditionalAttributes_BeforeProcessExport_11_13(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR__DemoPartners_ContactInformation_BeforeProcessExport_15_13(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR__DemoDepartments_Employees_BeforeProcessExport_5_18(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

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

Procedure PGCR_Companies_ContactInformation_BeforeProcessExport_5_11(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
	PGCR, Cancel, ObjectCollection, DontReplace, PropertyCollectionNode, DontClear) Export

	If Source.IsFolder Then
		Cancel = True;
	EndIf;

EndProcedure

Procedure PGCR_Users_ContactInformation_BeforeProcessExport_4_12(ExchangeFile, Source, Target, IncomingData, OutgoingData, OCR,
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

// Internal procedure. Initializes any variables required for debug purposes.
//
// Parameters:
//  Owner - InfobaseObjectConversion data processor.
//
Procedure AttachDataProcessorToDebug(Owner) Export

	Parameters            	   = Owner.Parameters;
	CommonProceduresFunctions	= Owner;
	Requests              	   = Owner.Requests;
	NodeForExchange		 	      = Owner.NodeForExchange;

EndProcedure

#EndIf
