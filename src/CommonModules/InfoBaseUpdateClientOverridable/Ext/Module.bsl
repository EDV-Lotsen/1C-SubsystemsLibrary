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
	
	//// _Demo Start Example
	//If Area.Name = "_DemoHyperlinkSample" Then
	//	ShowMessageBox(,NStr("en = 'The hyperlink was clicked.'"));
	//EndIf;
	//
	//
	//// StandardSubsystems.AccessManagement
	//If Area.Name = "_DemoUpdateDataAccessRestrictions" Then
	//	If AccessManagement.RestrictAccessOnRecordLevel() Then
	//		OpenFormModal("Catalog.AccessGroups.Form.RefreshEnabledAccessRestrictions");
	//	Else
	//		ShowMessageBox(,NStr("en = 'Access restriction on record level is not used.'"));
	//	EndIf;
	//EndIf;
	//// End StandardSubsystems.AccessManagement
	//
	//// _Demo End Example
	
EndProcedure
