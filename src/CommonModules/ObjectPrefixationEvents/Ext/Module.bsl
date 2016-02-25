////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Sets the subscription source prefix in accordance with the company prefix. 
// The subscription source should contain 
// the mandatory Company header attribute with the CatalogRef.Company type
//
// Parameters:
// Source             - Subscription event source.
//                      Any object from the set [Catalog, Document, 
//                      Chart of characteristic types, Business process, Task]
// StandardProcessing - Boolean - subscription standard processing flag
// Prefix             - String  - object prefix that requires changing
//
Procedure SetCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, False, True);
	
EndProcedure

// Sets the subscription source prefix in accordance with the infobase prefix.
// The source attributes are not restricted
//
// Parameters:
// Source             - Subscription event source.
//                      Any object from the set [Catalog, Document, 
//                      Chart of characteristic types, Business process, Task]
// StandardProcessing - Boolean - subscription standard processing flag
// Prefix             - String  - object prefix that requires changing
//
Procedure SetInfobasePrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, False);
	
EndProcedure

// Sets the subscription source prefix in accordance with the infobase prefix and 
// the company prefix.
// The subscription source should contain
// the mandatory Company header attribute with the CatalogRef.Company type
//
// Parameters:
//  Source            - Subscription event source.
//                      Any object from the set [Catalog, Document, 
//                      Chart of characteristic types, Business process, Task]
// StandardProcessing - Boolean - subscription standard processing flag
// Prefix             - String  - object prefix that requires changing
//
Procedure SetInfobaseAndCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	SetPrefix(Source, Prefix, True, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For catalogs

// Ckecks whether the Catalog item company attribute is changed
// If the Company attribute is changed, then the item code is reset to zero.
// It eanbles item code resetting
//
// Parameters:
//  Source - CatalogObject - subscription event source
//  Cancel - Boolean       - cancellation flag
// 
Procedure CheckCatalogCodeByCompany(Source, Cancel) Export
	
	CheckObjectCodeByCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For business processes

// Ckecks whether the Business process date is changed
// If the date is not included in the previous period, then the business process number 
// is reset to zero.
// It enables business process number resetting
//
// Parameters:
//  Source - BusinessProcessObject - subscription event source
//  Cancel - Boolean               - cancellation flag
// 
Procedure CheckBusinessProcessNumberByDate(Source, Cancel) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Ckecks whether the Document date or Business process company are changed
// If the date is not included in the previous period or the Company attribute is changed, 
// then the business process number is reset to zero.
// It enables business process number resetting
//
// Parameters:
//  Source - BusinessProcessObject - subscription event source
//  Cancel - Boolean               - cancellation flag
// 
Procedure CheckBusinessProcessNumberByDateAndCompany(Source, Cancel) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For documents

// Ckecks whether the Document date is changed
// If the date is not included in the previous period, then the document number 
// is reset to zero.
// It eanbles document number resetting
//
// Parameters:
//  Source - DocumentObject - subscription event source
//  Cancel - Boolean        - cancellation flag
// 
Procedure CheckDocumentNumberByDate(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Ckecks whether the Document date or company are changed 
// If the date is not included in the previous period or the Company attribute is changed, 
// then the document number is reset to zero.
// It enables document number resetting
//
// Parameters:
//  Source - DocumentObject - subscription event source
//  Cancel - Boolean        - cancellation flag
// 
Procedure CheckDocumentNumberByDateAndCompany(Source, Cancel, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Procedure SetPrefix(Source, Prefix, SetInfobasePrefix, SetCompanyPrefix)
	
	InfobasePrefix = "";
	CompanyPrefix  = "";
	
	If SetInfobasePrefix Then
		
		ObjectReprefixation.OnInfobasePrefixDefinition(InfobasePrefix);
		
		SupplementStringWithZerosFromLeft(InfobasePrefix, 2);
	EndIf;
	
	If SetCompanyPrefix Then
		
		If CompanyAttributeAvailable(Source) Then
			
			ObjectReprefixation.OnCompanyPrefixIdentification(
				Source[AttributeNameCompany(Source.Metadata())], CompanyPrefix);
			// if an empty ref to the company is passed
			If CompanyPrefix = False Then
				
				CompanyPrefix = "";
				
			EndIf;
			
		EndIf;
		
		SupplementStringWithZerosFromLeft(CompanyPrefix, 2);
	EndIf;
	
	PrefixTemplate = "[OR][Infobase]-[Prefix]";
	PrefixTemplate = StrReplace(PrefixTemplate, "[OR]", CompanyPrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[Infobase]", InfobasePrefix);
	PrefixTemplate = StrReplace(PrefixTemplate, "[Prefix]", Prefix);
	
	Prefix = PrefixTemplate;
	
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
	|	" + ObjectMetadata.FullName() + " AS
	|ObjectHeader
	|WHERE ObjectHeader.Ref = &Ref
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	If Not ObjectPrefixationInternal.ObjectDatesInSamePeriod(Selection.Date, Object.Date, Object.Ref) Then
		Object.Number = "";
	EndIf;
	
EndProcedure

Procedure CheckObjectNumberByDateAndCompany(Object)
	
	If Object.DataExchange.Load Then
		Return;
	ElsIf Object.IsNew() Then
		Return;
	EndIf;
	
	If ObjectPrefixationInternal.ObjectDateOrCompanyChanged(Object.Ref, Object.Date,
		Object[AttributeNameCompany(Object.Metadata())], Object.Metadata().FullName()) Then
		
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
	
	If ObjectPrefixationInternal.ObjectCompanyChanged(Object.Ref,	
		Object[AttributeNameCompany(Object.Metadata())], Object.Metadata().FullName()) Then
		
		Object.Code = "";
		
	EndIf;
	
EndProcedure

Function CompanyAttributeAvailable(Object)
	
	// return value
	Result = True;
	
	ObjectMetadata = Object.Metadata();
	
	If (CommonUse.IsCatalog(ObjectMetadata)
		Or CommonUse.IsChartOfCharacteristicTypes(ObjectMetadata))
		And ObjectMetadata.Hierarchical Then
		
		AttributeNameCompany = AttributeNameCompany(ObjectMetadata);
		
		CompanyAttribute = ObjectMetadata.Attributes.Find(AttributeNameCompany);
		
		If CompanyAttribute = Undefined Then
			
			If CommonUse.IsStandardAttribute(ObjectMetadata.StandardAttributes, AttributeNameCompany) Then
				
				// The standard attribute is always available both for the item and for the group.
				Return True;
				
			EndIf;
			
			MessageString = NStr("en = 'The %2 attribute is not defined for the %1 metadata object.'");
			MessageString = StringFunctionsClientServer.SubstituteParametersInString(MessageString, ObjectMetadata.FullName(), AttributeNameCompany);
			Raise MessageString;
		EndIf;
			
		If CompanyAttribute.Use = Metadata.ObjectProperties.AttributeUse.ForFolder And Not Object.IsFolder Then
			
			Result = False;
			
		ElsIf CompanyAttribute.Use = Metadata.ObjectProperties.AttributeUse.ForItem And Object.IsFolder Then
			
			Result = False;
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// For internal use
Function AttributeNameCompany(Object) Export
	
	If TypeOf(Object) = Type("MetadataObject") Then
		FullName = Object.FullName();
	Else
		FullName = Object;
	EndIf;
	
	Attribute = ObjectPrefixationCached.PrefixFormingAttributes().Get(FullName);
	
	If Attribute <> Undefined Then
		Return Attribute;
	EndIf;
	
	Return "Company";
	
EndFunction

#EndRegion
