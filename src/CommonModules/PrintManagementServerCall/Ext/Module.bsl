////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Operations with office document templates

// Gets all data required for printing within a single call: object template data, binary template data, and descriptions of template areas.

// The function is intended for the calling print forms based on office document templates from client modules.

//
// Parameters:
//   PrintManagerName   - String - name for accessing the object manager, for example, Document.<Document name>.
//   TemplateNames      - String - names of templates that are used as basis for print form generation.
//   DocumentContent    - Array - references to infobase objects (all references must have the same type).
//
Function TemplatesAndDataOfObjectsToPrint(Val PrintManagerName, Val TemplateNames, Val DocumentContent) Export
	
	Return PrintManagement.TemplatesAndDataOfObjectsToPrint(PrintManagerName, TemplateNames, DocumentContent);
	
EndFunction

// Obsolete. Use TemplatesAndDataOfObjectsToPrint instead.
//
Function GetTemplatesAndObjectData(Val PrintManagerName, Val TemplateNames, Val DocumentContent) Export
	
	Return PrintManagement.TemplatesAndDataOfObjectsToPrint(PrintManagerName, TemplateNames, DocumentContent);
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// Generates print forms for direct output to a printer
//
// For details, see the description of PrintManagement.GeneratePrintFormsForQuickPrint().
//
Procedure GeneratePrintFormsForQuickPrint(PrintManagerName, TemplateNames, ObjectArray,
	PrintParameters, SpreadsheetDocuments, PrintObjects, OutputParameters, Cancel) Export
	
	PrintManagement.GeneratePrintFormsForQuickPrint(
		PrintManagerName,
		TemplateNames,
		ObjectArray,
		PrintParameters,
		SpreadsheetDocuments,
		PrintObjects,
		OutputParameters,
		Cancel);
	
EndProcedure

// Generates print forms for the direct output to a printer in an ordinary application.
//
// For details, see the description of PrintManagement.GeneratePrintFormsForQuickPrintOrdinaryApplication().
//
Procedure GeneratePrintFormsForQuickPrintOrdinaryApplication(PrintManagerName, TemplateNames, ObjectArray,
	PrintParameters, Address, PrintObjects, OutputParameters, Cancel) Export
	
	PrintManagement.GeneratePrintFormsForQuickPrintOrdinaryApplication(
		PrintManagerName,
		TemplateNames,
		ObjectArray,
		PrintParameters,
		Address,
		PrintObjects,
		OutputParameters,
		Cancel);
	
EndProcedure

// Saves the path to the directory that is used for printing to a temporary storage.
//
// For details,see the description of PrintManagement.SaveLocalPrintFileDirectory().
//
Procedure SaveLocalPrintFileDirectory(Directory) Export
	
	PrintManagement.SaveLocalPrintFileDirectory(Directory);
	
EndProcedure

// Returns a command description by form item name.
// 
// See PrintManagement.PrintCommandDescription
//
Function PrintCommandDescription(CommandName, PrintCommandAddressInTemporaryStorage) Export
	
	Return PrintManagement.PrintCommandDescription(CommandName, PrintCommandAddressInTemporaryStorage);
	
EndFunction

// Returns True if the user has the right to post at least one document.
Function HasRightsToPost(DocumentList) Export
	Return PrintManagement.HasRightsToPost(DocumentList);
EndFunction

// See PrintManagement.DocumentBatch.
Function DocumentBatch (SpreadsheetDocuments, PrintObjects, Collate, Copies = 1) Export
	
	Return PrintManagement.DocumentBatch (SpreadsheetDocuments, PrintObjects,
		Collate, Copies);
	
EndFunction

// Displays a message that the print command is unavailable for the selected object.
Function PrintCommandPurposeMessage(PrintObjectTypes) Export
	MessageText = NStr("en = 'The selected print command is available for the following documents:'") + Chars.LF;
	For Each Type In PrintObjectTypes Do
		MessageText = MessageText + Metadata.FindByType(Type).Presentation() + Chars.LF;
	EndDo;
	Return TrimAll(MessageText);
EndFunction

#EndRegion
