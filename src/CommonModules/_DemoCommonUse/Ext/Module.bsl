
////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS

// Check if documents are posted
// Parameters
//  Documents - array - documents, to be checked if they are posted
// Value to return:
//  Array 	  - unposted documents from the array Documents
//
Function DocumentsArePosted(Val Documents) Export
	
	QueryText = "SELECT
		|	Document.Ref AS Ref
		|FROM
		|	Document.[DocumentName] AS Document
		|WHERE
		|	Document.Ref In (&DocumentsArray)
		|	And Not Document.Posted";
	
	DocumentName = StringFunctionsClientServer.SplitStringIntoSubstringArray(
		Documents[0].Metadata().FullName(), ".")[1];
	
	QueryText = StrReplace(QueryText, "[DocumentName]", DocumentName);
	
	Query 		= New Query;
	Query.Text  = QueryText;
	Query.SetParameter("DocumentsArray", Documents);
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Function returns name of kind of metadata objects by object type.
//
// Route points of business-processes are not processed.
//
// Parameters:
//  Type         - Type of applied object, defined in configuration
//
// Value returned:
//  String       - name of the kind of metadata objects, for example, "Catalog", "Document" ...
//
Function ObjectClassByType(Type) Export
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enum";
	
	Else
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Incorrect parameter value type (%1)'"), String(Type));
	
	EndIf;
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions for installation of extension of work with files in web-client.

// Returns value of session parameter SuggestWorkWithFilesExtensionInstallationByDefault.
// Value returned:
//  Boolean - value of session parameter SuggestWorkWithFilesExtensionInstallationByDefault.
//
Function SessionParametersSuggestWorkWithFilesExtensionInstallationByDefault() Export
	SetPrivilegedMode(True);   
	Return SessionParameters.SuggestWorkWithFilesExtensionInstallationByDefault;
EndFunction

// Sets value of session parameter SuggestWorkWithFilesExtensionInstallationByDefault.
// Parameters:
//  Suggest  - Boolean - new value of session parameter SuggestWorkWithFilesExtensionInstallationByDefault.
//
Procedure SetSessionParameterSuggestWorkWithFilesExtensionInstallationByDefault(Suggest) Export
	SetPrivilegedMode(True);   
	SessionParameters.SuggestWorkWithFilesExtensionInstallationByDefault = Suggest;
EndProcedure	

// Saves SuggestWorkWithFilesExtensionInstallationByDefault in settings and session parameter
Procedure SaveSuggestWorkWithFilesExtensionInstallation(Suggest) Export
	
	CommonSettingsStorage.Save("ApplicationSettings", "SuggestWorkWithFilesExtensionInstallationByDefault", 
		Suggest);	
	
	// here always assign False, to avoid disturbing in this session.
	//  but to CommonSettingsStorage True can be written
	//   - and on next start we will suggest installation again
	SetSessionParameterSuggestWorkWithFilesExtensionInstallationByDefault(False);
EndProcedure	

