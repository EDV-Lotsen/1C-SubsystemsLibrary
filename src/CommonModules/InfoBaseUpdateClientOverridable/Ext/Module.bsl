////////////////////////////////////////////////////////////////////////////////
// Infobase version update subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Is called on a hyperlink click or on a double-click of spreadsheet document cell 
// that contains infobase change description.
//
// Parameters:
// Area - SpreadsheetDocumentRange - Document area that was 
// clicked.
//
// See also the UpdateDetails common template.
//
Procedure OnUpdateDetailDocumentHyperlinkClick(Val Area) Export
	
	// _Demo Start Example
	If Area.Name = "_DemoHyperlinkSample" Then
		DoMessageBox(NStr("en = 'The hyperlink was clicked.'"));
	EndIf;
		
	// _Demo End Example
	
EndProcedure
