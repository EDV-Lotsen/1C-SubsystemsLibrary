#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

////////////////////////////////////////////////////////////////////////////////
// Conversion import handlers {DemoDataSynchronizationWithSL 4ce80052987111e3b918005056c00000}                                                                   
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

Procedure Conversion_AfterReceiveExchangeNodeDetails(ExchangeNodeDataImport) Export

	Parameters.Insert("DefaultValues");
	Parameters.DefaultValues = CommonUse.ObjectAttributeValues(ExchangeNodeDataImport, "DefaultVATRate");

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// OBJECT CONVERSION
// HANDLERS Procedure logic can be modified in this section.

Procedure OCR__DemoProductReceipt_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified,
	ObjectTypeName, ObjectFound) Export

	Object.VATRate = Parameters.DefaultValues.DefaultVATRate;

EndProcedure

Procedure OCR__DemoProductSales_AfterImportObject(ExchangeFile, Cancel, Ref, Object, ObjectParameters, ObjectModified,
	ObjectTypeName, ObjectFound) Export

	Object.VATRate = Parameters.DefaultValues.DefaultVATRate;

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
