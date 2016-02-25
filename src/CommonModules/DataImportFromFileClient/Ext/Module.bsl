
#Region Interface

// Creates a new structure of parameters for importing data from a file to a tabular section.
//
// Returns:
//   Structure - parameters for opening the form for importing data to a tabular section:
//    * FullTabularSectionName   - String - full path to the document tabular section 
//                                          in format: "DocumentName.TabularSectionName".
//    * Presentation             - String - window title in the data import form.
//    * DataStructureTemplateName - String - data input template name.
//
Function DataImportParameters() Export
	ImportParameters = New Structure();
	ImportParameters.Insert("FullTabularSectionName");
	ImportParameters.Insert("Title");
	ImportParameters.Insert("DataStructureTemplateName");
	
	Return ImportParameters;
EndFunction

// Opens the data import form for filling the tabular section.
//
// Parameters: 
//   ImportParameters   - Structure         - see DataImportFromFileClient.DataImportParameters.
//   ImportNotification - NotifyDescription - notification that is called for adding the 
//                                            imported data to the tabular section.
//
Procedure ShowImportForm(ImportParameters, ImportNotification) Export
	
	OpenForm("DataProcessor.DataImportFromFile.Form", ImportParameters, 
		ImportNotification.Module, , , , ImportNotification);
		
EndProcedure

#EndRegion

#Region InternalInterface

// Opens the data import form for filling the reference mapping tabular section in 
// the Report options subsystem.
//
// Parameters: 
//   ImportParameters   - Structure         - see DataImportFromFileClient.DataImportParameters.
//   ImportNotification - NotifyDescription - notification that is called for adding the 
//                                            imported data to the tabular section.
//
Procedure ShowRefFillingForm(ImportParameters, ImportNotification) Export
	
	OpenForm("DataProcessor.DataImportFromFile.Form", ImportParameters,
		ImportNotification.Module,,,, ImportNotification);
		
EndProcedure

#EndRegion