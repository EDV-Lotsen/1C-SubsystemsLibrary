////////////////////////////////////////////////////////////////////////////////
// Object prefixation subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Export internal procedures and functions.

// Returns a flag that shows whether the company or the object date were changed.
// 
// Parameters:
//  Ref                – infobase object reference.
//  DateAfterChange    – object date that is set after changes.
//  CompanyAfterChange – object company that is set after changes.
// 
//  Return:
//   Boolean           - True if the company was changed or the new and old object
//                       dates are set in different intervals, otherwise is False.
//
Function ObjectDateOrCompanyChanged(Ref, Val DateAfterChange, Val CompanyAfterChange, FullTableName) Export
	
	QueryText = "
	|SELECT
	|	ObjectHeader.Date AS Date,
	|	ISNULL(ObjectHeader.Company.Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	CompanyPrefixAfterChange = GetFunctionalOption("CompanyPrefixes", New Structure("Company", CompanyAfterChange));
	
	// If the company reference is empty
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange
		Or Not IsObjectDatesOfSamePeriod(Selection.Date, DateAfterChange, Ref);
	//
EndFunction

// Returns a flag that shows whether the company was changed.
//
// Parameters:
// Ref                – infobase object reference.
// CompanyAfterChange – object company that is set after changes.
//
//  Returns:
//   Boolean          - True if the company was changed, otherwise is False.
//
Function ObjectCompanyChanged(Ref, Val CompanyAfterChange, FullTableName) Export
	
	QueryText = "
	|SELECT
	|	ISNULL(ObjectHeader.Company.Prefix, """") AS CompanyPrefixBeforeChange
	|FROM
	|	" + FullTableName + " AS ObjectHeader
	|WHERE
	|	ObjectHeader.Ref = &Ref
	|";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	
	SetPrivilegedMode(True);
	
	Selection = Query.Execute().Choose();
	Selection.Next();
	
	CompanyPrefixAfterChange = GetFunctionalOption("CompanyPrefixes", New Structure("Company", CompanyAfterChange));
	
	// If the company reference is empty
	CompanyPrefixAfterChange = ?(CompanyPrefixAfterChange = False, "", CompanyPrefixAfterChange);
	
	Return Selection.CompanyPrefixBeforeChange <> CompanyPrefixAfterChange;
		
	//
EndFunction

// Returns a flag that shows whether two dates of the metadata object are equal.
// Dates are considered as equal if their values are in the same period (like year, month, day, and so on).
// 
// Parameters:
//  Date1          – first date to be compared;
//  Date2          – second date to be compared;
//  ObjectMetadata – object metadata that is used to determine a compare period.
// 
//  Returns:
//  Boolean. True if the object dates are in the same period, otherwise is False.
//
Function IsObjectDatesOfSamePeriod(Val Date1, Val Date2, Ref) Export
	
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
// Local internal procedures and functions.

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
