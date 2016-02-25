////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Overrides the table of available formats for saving a spreadsheet document.
// This procedure is called from CommonUse.SpeadsheetDocumentFileFormatSettings()
//
// Parameters
// FormatTable - ValueTable:
//                   *  SpreadsheetDocumentFileType - SpreadsheetDocumentFileType - platform format that is mapped to the SL format;
//                   *  Ref                         - EnumRef.ReportSaveFormats - reference to the metadata that stores the format presentation.
//                   *  Presentation                - String - file type presentation (filled from an enumeration).
//                   *  Extension                   - String - file type for the operating system.
//                   *  Picture                     - Picture - format icon.
//
Procedure OnFillSpeadsheetDocumentFileFormatSettings(FormatTable) Export
	
EndProcedure

// Overrides the print command list retrieved by the PrintManagement.FormPrintCommands function.
Procedure BeforeAddPrintCommands(FormName, PrintCommands, StandardProcessing) Export
	
EndProcedure

#EndRegion