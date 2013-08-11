////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Sets the subscription source prefix according to the company prefix. 
// The subscription source must contains Company header attribute of the
// CatalogRef.Companies type.
//
// Parameters:
//  Source             - any of the following objects: Catalog, Document, Chart of 
//                       characteristic types, Business process, Task - subscription
//                       event source. 
//  StandardProcessing - Boolean - standard subscription processing flag.
//  Prefix             - String - object prefix to be changed.
//
Procedure SetCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, False, True);
	
EndProcedure

// Sets the subscription source prefix according to the infobase prefix. 
// Source attributes have no extra restrictions.
//
// Parameters:
// Source             - any of the following objects: Catalog, Document, Chart of 
//                      characteristic types, Business process, Task - subscription
//                      event source. 
// StandardProcessing - Boolean - standard subscription processing flag.
// Prefix             - String - object prefix to be changed.
//
Procedure SetInfoBasePrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, False);
	
EndProcedure

// Sets the subscription source prefix according to the company and infobase prefixes. 
// The subscription source must contains Company header attribute of the
// CatalogRef.Companies type.
//
// Parameters:
// Source             - any of the following objects: Catalog, Document, Chart of 
//                      characteristic types, Business process, Task - subscription
//                      event source. 
// StandardProcessing - Boolean - standard subscription processing flag.
// Prefix             - String - object prefix to be changed.
//
Procedure SetInfoBaseAndCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with catalogs.

// Checks whether the Company catalog item attribute was changed.
// It the attribute was changed, the item code is reset to be specified again.
//
// Parameters:
//  Source - CatalogObject - subscription event source.
//  Cancel - Boolean - cancel flag.
// 
Procedure CheckCatalogCodeByCompany(Source, Cancel) Export
	
	CheckObjectCodeByCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with business processes.

// Checks whether Date of the business process was changed.
// If the date is not included in the previous period, the business process number is
// reset to be specified again.
//
// Parameters:
//  Source - BusinessProcessObject - subscription event source.
//  Cancel - Boolean - cancel flag.
// 
Procedure CheckBusinessProcessNumberByDate(Source, Cancel) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure


// Checks whether Date and Company of the business process were changed.
// If the date is not included in the previous period or the Company attribute was 
// changed, the business process number is reset to be specified again.
//
// Parameters:
//  Source - BusinessProcessObject - subscription event source.
//  Cancel - Boolean - cancel flag.
//  
Procedure CheckBusinessProcessNumberByDateAndCompany(Source, Cancel) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with documents.


// Checks whether Date of the document was changed.
// If the date is not included in the previous period, the document number is reset to 
// be specified again.
//
// Parameters:
// Source - BusinessProcessObject - subscription event source.
// Cancel - Boolean - cancel flag.
// 
Procedure CheckDocumentNumberByDate(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks whether Date and Company of the document were changed.
// If the date is not included in the previous period or the Company attribute was 
// changed, the document number is reset to be specified again.
//
// Parameters:
// Source - BusinessProcessObject - subscription event source.
// Cancel - Boolean - cancel flag.
// 
Procedure CheckDocumentNumberByDateAndCompany(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure SetPrefix(Source, Prefix, SetInfoBasePrefix, SetCompanyPrefix)
	
	InfoBasePrefix = "";
	CompanyPrefix  = "";
	
	If SetInfoBasePrefix
		And ObjectPrefixationCached.HasInfoBasePrefixFunctionalOption() Then
		
		InfoBasePrefix = GetFunctionalOption("InfoBasePrefix");
		
		SupplementStringWithZerosFromLeft(InfoBasePrefix, 2);
		
	EndIf;
	
	If SetCompanyPrefix
		And ObjectPrefixationCached.HasFunctionalOptionCompanyPrefixes() Then
		
		If CompanyAttributeAvailable(Source) Then
			
			CompanyPrefix = GetFunctionalOption("CompanyPrefixes", New Structure("Company", Source.Company));
			
			// If the company reference is empty
			If CompanyPrefix = False Then
				
				CompanyPrefix = "";
				
			EndIf;
			
		EndIf;
		
		SupplementStringWithZerosFromLeft(CompanyPrefix, 2);
		
	EndIf;
	
	MainPrefix = CompanyPrefix + InfoBasePrefix;
	
	Separator = "-";
	
	Prefix = MainPrefix + Separator + Prefix;
	
EndProcedure

Procedure SupplementStringWithZerosFromLeft(String, StringLength)
	
	String = StringFunctionsClientServer.SupplementString(String, StringLength, "0", "Left");
	
EndProcedure

Procedure CheckObjectNumberByDate(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	EndIf;
	
	ObjectMetadata = Object.Metadata();
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Date AS Date
	|FROM
	|	" + ObjectMetadata.FullName() + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	If Not ObjectPrefixation.IsObjectDatesOfSamePeriod(Selection.Date, Object.Date, Object.Ref) Then
		
		Object.Number = "";
		
	EndIf;
	
EndProcedure

Procedure CheckObjectNumberByDateAndCompany(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	EndIf;
	
	If ObjectPrefixation.ObjectDateOrCompanyChanged(Object.Ref, Object.Date, Object.Company, Object.Metadata().FullName()) Then
		
		Object.Number = "";
		
	EndIf;
	
EndProcedure

Procedure CheckObjectCodeByCompany(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	ElsIf Not CompanyAttributeAvailable(Object) Then
		Return;
	EndIf;
	
	If ObjectPrefixation.ObjectCompanyChanged(Object.Ref, Object.Company, Object.Metadata().FullName()) Then
		
		Object.Code = "";
		
	EndIf;
	
EndProcedure

Function CompanyAttributeAvailable(Object)
	
	// Return value
	Result = True;
	
	ObjectMetadata = Object.Metadata();
	
	If   (CommonUse.IsCatalog(ObjectMetadata)
		Or CommonUse.IsChartOfCharacteristicTypes(ObjectMetadata))
		And ObjectMetadata.Hierarchical Then
		
		CompanyAttribute = ObjectMetadata.Attributes.Find("Company");
		
		If CompanyAttribute.Use = Metadata.ObjectProperties.AttributeUse.ForFolder And Not Object.IsFolder Then
			
			Result = False;
			
		ElsIf CompanyAttribute.Use = Metadata.ObjectProperties.AttributeUse.ForItem And Object.IsFolder Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction







