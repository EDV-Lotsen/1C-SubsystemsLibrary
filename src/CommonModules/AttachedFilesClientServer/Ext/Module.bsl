////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers

// See the procedure of the same name in the AttachedFiles module.
// Intended for thick client (client/server) mode.
//
Procedure OverrideAttachedFileForm(Source,
                                                      FormType,
                                                      Parameters,
                                                      SelectedForm,
                                                      AdditionalInfo,
                                                      StandardProcessing) Export
	
	AttachedFilesInternalServerCall.OverrideAttachedFileForm(
		Source,
		FormType,
		Parameters,
		SelectedForm,
		AdditionalInfo,
		StandardProcessing);
		
EndProcedure

#EndRegion
