#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Batch object modification

// Returns a list of attributes that are not editable
// with the help of the batch object modification data processor
//
Function AttributesToSkipOnGroupProcessing() Export
	
	Result = New Array;
	
	Result.Add("Prefix");
	Result.Add("ContactInformation.*");
	
	Return Result
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Use several companies

// Returns the company by default.
// If the infobase contains only one commpany that is not marked to be deleted
// and is not predefined, there will be returned a reference to the company, or 
// an empty reference.
//
// Returns:
//     CatalogRef.Companies - reference to the company.
//
Function DefaultCompany() Export
	
	Company = Catalogs.Companies.EmptyRef();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 2
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	NOT Companies.DeletionMark
	|	AND NOT Companies.Predefined";
	
	Selection = Query.Execute().Select();
	If Selection.Next() And Selection.Count() = 1 Then
		Company = Selection.Company;
	EndIf;
	
	Return Company;

EndFunction

// Returns the number of items in the Company catalog.
// Disregards items that are predefined or marked for deletion.
//
// Returns:
//     Number - the number of companies 
//
Function CompaniesCount() Export
	
	SetPrivilegedMode(True);
	
	Count = 0;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(*) AS Count
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	NOT Companies.Predefined";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Count = Selection.Count;
	EndIf;
	
	SetPrivilegedMode(False);
	
	Return Count;
	
EndFunction

#EndRegion

#Region InternalInterface

// Is called after update to SL version 2.2.1.12
//
Procedure FillConstantUseSeveralCompanies() Export
	
	If GetFunctionalOption("UseSeveralCompanies") =
			GetFunctionalOption("DontUseSeveralCompanies") Then
		// The options need opposite values.
		// If not, then the infobase did not have such options - we initialise their values.
		Constants.UseSeveralCompanies.Set(CompaniesCount() > 1);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
