////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions

// Returns the sign of the object company change or object date change.
// 
// Parameters:
//  Ref - a reference to an infobase object.
//  DateAfterChange - object date after change.
//  CompanyAfterChange - object company after change.
// 
//  Returns:
//   True - the object company was changed or a new object date was set in 
//          another interval of periodicity as compared to the previous date value.
//   False - the company and the document date were not changed.
//
Function ObjectDateOrCompanyChanged(Ref, Val DateAfterChange, Val CompanyAfterChange, FullTableName) Export
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Date AS Date,
	|	ISNULL(ObjectHeader.[AttributeNameCompany].Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS ObjectHeader
	|WHERE 
	|  ObjectHeader.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[AttributeNameCompany]", 
ObjectPrefixationEvents.AttributeNameCompany(FullTableName));
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	CompanyPrefixAfterChange = Undefined;
	ObjectReprefixation.OnCompanyPrefixIdentification(CompanyAfterChange, 
CompanyPrefixAfterChange);
	
	// if an empty reference to the company is passed
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", 
CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange
		Or Not ObjectDatesInSamePeriod(Selection.Date, DateAfterChange, Ref);
	
EndFunction

// Returns the sign of the object company change.
//
// Parameters:
//  Ref - a reference to an infobase object.
//  CompanyAfterChange - object company after change.
//
//  Returns:
//   True - object company was changed. False - company was not changed.
//
Function ObjectCompanyChanged(Ref, Val CompanyAfterChange, FullTableName) Export
	
	QueryText = "
	|SELECT
	|	ISNULL(ObjectHeader.[AttributeNameCompany].Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS ObjectHeader
	|WHERE 
	| ObjectHeader.Ref = &Ref
	|";
	
	QueryText = StrReplace(QueryText, "[AttributeNameCompany]", 
ObjectPrefixationEvents.AttributeNameCompany(FullTableName));
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	CompanyPrefixAfterChange = Undefined;
	ObjectReprefixation.OnCompanyPrefixIdentification(CompanyAfterChange, CompanyPrefixAfterChange);
	
	// if an empty reference to the company is passed
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", 
CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange;
	
EndFunction

// Identifies the equality of metadata object dates.
// Dates are considered to be equal, if they belong to the same period of time: 
// Year, Month, Day, and etc.
// 
// Parameters:
// Date1 - the first date to compare with;
// Date2 - the second date to compare with;
// ObjectMetadata - object metadata for which function value must be acquired.
// 
//  Returns:
//   True - object dates of the same period; False - object dates of different periods.
//
Function ObjectDatesInSamePeriod(Val Date1, Val Date2, Ref) Export
	
	ObjectMetadata = Ref.Metadata();
	
	If DocumentNumberPeriodicityYear(ObjectMetadata) Then
		
		DateDiff = BegOfYear(Date1) - BegOfYear(Date2);
		
	ElsIf DocumentNumberPeriodicityQuarter(ObjectMetadata) Then
		
		DateDiff = BegOfQuarter(Date1) - BegOfQuarter(Date2);
		
	ElsIf DocumentNumberPeriodicityMonth(ObjectMetadata) Then
		
		DateDiff = BegOfMonth(Date1) - BegOfMonth(Date2);
		
	ElsIf DocumentNumberPeriodicityDay(ObjectMetadata) Then
		
		DateDiff = BegOfDay(Date1) - BegOfDay(Date2);
		
	Else // DocumentNumberPeriodicityUndefined
		
		DateDiff = 0;
		
	EndIf;
	
	Return DateDiff = 0;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions

Function DocumentNumberPeriodicityYear(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year;
	
EndFunction

Function DocumentNumberPeriodicityQuarter(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter;
	
EndFunction

Function DocumentNumberPeriodicityMonth(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = 
Metadata.ObjectProperties.DocumentNumberPeriodicity.Month;
	
EndFunction

Function DocumentNumberPeriodicityDay(ObjectMetadata)
	
	Return ObjectMetadata.NumberPeriodicity = 
Metadata.ObjectProperties.DocumentNumberPeriodicity.Day;
	
EndFunction

#EndRegion
