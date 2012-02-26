
////////////////////////////////////////////////////////////////////////////////
// EXPORT EXTERNAL PROCEDURES

// Sets prefix of the source of subscription according to the Company prefix.
// Subscription source should contain
// Required header attribute "Company", type: "CatalogRef.Companies"
//
// Parameters:
//  Source - Source of the subscription event.
//             Any object from the list [Catalog, Document, Plan of characteristic types, Business process, Task]
// StandardProcessing - Boolean - flag of subscription standard processing
// Prefix  - String - object prefix, that has to be changed
//
Procedure SetCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	If CurrentDate() < Date('20110101') Then
		SetPrefixUntil20110101(Source, Prefix, False, True);
	Else	
		SetPrefix(Source, Prefix, False, True);
	EndIf;

EndProcedure

// Sets prefix of the subscription source according to the infobase prefix.
// There are no restrictions for the source attributes
//
// Parameters:
//  Source - Source of the subscription event.
//             Any object from the list [Catalog, Document, Plan of characteristic types, Business process, Task]
// StandardProcessing - Boolean - flag of subscription standard processing
// Prefix  - String - object prefix, that has to be changed
//
Procedure SetIBPrefix(Source, StandardProcessing, Prefix) Export
	
	If CurrentDate() < Date('20110101') Then
		SetPrefixUntil20110101(Source, Prefix, True, False);
	Else	
		SetPrefix(Source, Prefix, True, False);
	EndIf;
	
EndProcedure

// Sets prefix of the subscription source according to the infobase prefix and the Company prefix.
// Subscription source should contain
// Required header attribute "Company", type: "CatalogRef.Companies"
//
// Parameters:
//  Source - Source of the subscription event.
//             Any object from the list [Catalog, Document, Plan of characteristic types, Business process, Task]
// StandardProcessing - Boolean - flag of subscription standard processing
// Prefix  - String - object prefix, that has to be changed
//
Procedure SetIBAndCompanyPrefix(Source, StandardProcessing, Prefix) Export
	
	If Source.Date < Date('20110101') Then
		SetPrefixUntil20110101(Source, Prefix, True, True);
	Else	
		SetPrefix(Source, Prefix, True, True);
	EndIf;	
		
EndProcedure

// for catalogs

// Checks if attribute Company of catalog item has been modified
// If attribute Company was changed, then item Code is being nullified.
// This is required to assign item new code
//
// Parameters:
//  Source 			- CatalogObject - source of the subscription event
//  Cancellation    - Boolean 		- cancellation flag
//
Procedure CheckCatalogCodeByCompany(Source, Cancellation) Export
	
	CheckObjecCodetByCompany(Source);
	
EndProcedure

// for business processes

// Checks if business process Date has been modified
// If date is not inside the previous period, then business process number is being nullified.
// This is required to assign new number to a business process
//
// Parameters:
//  Source 			- BusinessProcessObject - source of the subscription event
//  Cancellation    - Boolean - cancellation flag
//
Procedure CheckBusinessProcessNumberByDate(Source, Cancellation) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks if business process Date and Company have been modified
// If date is not inside the previous period or attribute Company has been modified, then business process number is being nullified.
// This is required to assign new number to a business process
//
// Parameters:
//  Source	 		- BusinessProcessObject - source of the subscription event
//  Cancellation    - Boolean 				- cancellation flag
//
Procedure CheckBusinessProcessNumberByDateAndCompany(Source, Cancellation) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

// for documents

// Checks if document Date has been modified
// If date is not inside the previous period, then document number is being nullified.
// This is required to assign new document number
//
// Parameters:
//  Source 			- DocumentObject 	- source of the subscription event
//  Cancellation    - Boolean 			- cancellation flag
//
Procedure CheckDocumentNoByDate(Source, Cancellation, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDate(Source);
	
EndProcedure

// Checks if document Date and Company have been modified
// If date is not inside the previous period or attribute Company has been modified, then document number is being nullified.
// This is required to assign new document number
//
// Parameters:
//  Source 			- DocumentObject - source of the subscription event
//  Cancellation    - Boolean 		 - cancellation flag
//
Procedure CheckDocumentNoByDateAndCompany(Source, Cancellation, WriteMode, PostingMode) Export
	
	CheckObjectNumberByDateAndCompany(Source);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS

Procedure SetPrefixUntil20110101(Source, Prefix, SetIBPrefix, SetCompanyPrefix)
	
	InfobasePrefix = "";
	CompanyPrefix        = "";
	
	// set privileged mode
	SetPrivilegedMode(True);
	
	If SetCompanyPrefix Then
		
		If ObjectPrefixationSecondUse.IsFunctionalOption("CompanyPrefixes") Then
			
			CompanyPrefix = GetFunctionalOption("CompanyPrefixes", New Structure("Company", Source.Company));
			
			// if empty ref to the Company is assigned
			If CompanyPrefix = False Then
				
				CompanyPrefix = "";
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// disable privileged mode
	SetPrivilegedMode(False);
	
	MainPrefix = CompanyPrefix;
	
	Separator = ?(IsBlankString(MainPrefix), "", "-");
	
	Prefix = MainPrefix + Separator + Prefix;
	
	// if prefix is empty, then assign default value
	If IsBlankString(Prefix) Then
		
		Prefix = "0";
		
	EndIf;
	
EndProcedure

Procedure SetPrefix(Source, Prefix, SetIBPrefix, SetCompanyPrefix)
	
	InfobasePrefix = "";
	CompanyPrefix        = "";
	
	// set privileged mode
	SetPrivilegedMode(True);
	
	If SetCompanyPrefix
		And ObjectPrefixationSecondUse.IsFunctionalOptionCompanyPrefixes() Then
		
		CompanyPrefix = GetFunctionalOption("CompanyPrefixes", New Structure("Company", Source.Company));
		
		// if empty ref to the Company is assigned
		If CompanyPrefix = False Then
			
			CompanyPrefix = "";
			
		EndIf;
		
		SupplementStringWithZerosOnTheLeft(CompanyPrefix, 2);
		
	EndIf;
	
	MainPrefix = CompanyPrefix + InfobasePrefix;
	
	Separator = ?(IsBlankString(MainPrefix), "", "-");
	
	Prefix = MainPrefix + Separator + Prefix;
	
	// if prefix is empty, then assign default value
	If IsBlankString(Prefix) Then
		
		Prefix = "0";
		
	EndIf;
	
EndProcedure

Procedure CheckObjectNumberByDate(Object)
	
	If Object.IsNew() Then
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
	
	If Selection.Next() Then
		
		If Not OnePeriodObjectDate(Selection.Date, Object.Date, ObjectMetadata) Then
			
			Object.Number = "";
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CheckObjectNumberByDateAndCompany(Object)
	
	If Object.IsNew() Then
		Return;
	EndIf;
	
	ObjectMetadata = Object.Metadata();
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Date                                AS Date,
	|	ISNULL(ObjectHeader.Company.Prefix, """") AS CompanyBeforeChangePrefix
	|FROM
	|	" + ObjectMetadata.FullName() + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Choose();
	
	If Selection.Next() Then
		
		CompanyAfterChangePrefix = GetFunctionalOption("CompanyPrefixes", New Structure("Company", Object.Company));
		
		// if empty ref to the Company is assigned
		CompanyAfterChangePrefix = ?(CompanyAfterChangePrefix = False, "", CompanyAfterChangePrefix);
		
		If Selection.CompanyBeforeChangePrefix <> CompanyAfterChangePrefix Then
			
			Object.Number = "";
			
		ElsIf Not OnePeriodObjectDate(Selection.Date, Object.Date, ObjectMetadata) Then
			
			Object.Number = "";
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CheckObjecCodetByCompany(Object)
	
	If Object.IsNew() Then
		Return;
	EndIf;
	
	ObjectMetadata = Object.Metadata();
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Company AS Company
	|FROM
	|	" + ObjectMetadata.FullName() + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Choose();
	
	If Selection.Next() Then
		
		If Selection.Company <> Object.Company Then
			
			Object.Code = "";
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SupplementStringWithZerosOnTheLeft(String, StringLength)
	
	String = StringFunctionsClientServer.SupplementString(String, StringLength, "0", "OnTheLeft");
	
EndProcedure

Function OnePeriodObjectDate(Val Date1, Val Date2, ObjectMetadata)
	
	If DocumentNumberPeriodicityYear(ObjectMetadata) Then
		
		Datediff = BegOfYear(Date1) - BegOfYear(Date2);
		
	ElsIf DocumentNumberPeriodicityQuarter(ObjectMetadata) Then
		
		Datediff = BegOfQuarter(Date1) - BegOfQuarter(Date2);
		
	ElsIf DocumentNumberPeriodicityMonth(ObjectMetadata) Then
		
		Datediff = BegOfMonth(Date1) - BegOfMonth(Date2);
		
	ElsIf DocumentNumberPeriodicityDay(ObjectMetadata) Then
		
		Datediff = BegOfDay(Date1) - BegOfDay(Date2);
		
	Else // PeriodicityOfDocumentNumberUndefined
		
		Datediff = 0;
		
	EndIf;
	
	Return Datediff = 0;
	
EndFunction

Function DocumentNumberPeriodicityYear(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year;
	
EndFunction

Function DocumentNumberPeriodicityQuarter(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter;
	
EndFunction

Function DocumentNumberPeriodicityMonth(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month;
	
EndFunction

Function DocumentNumberPeriodicityDay(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day;
	
EndFunction
