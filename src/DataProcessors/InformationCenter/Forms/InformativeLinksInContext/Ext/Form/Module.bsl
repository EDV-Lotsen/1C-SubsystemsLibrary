////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("PathToForm") Then 
		Cancel = True;
		Return;
	EndIf;
	
	InformationCenterServer.DisplayContextLinks(ThisForm,
														Items.InformationLinks,
														1,
														20,
														False,
														Parameters.PathToForm);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure Attachable_InformationLinkClick(Index)
	
	InformationCenterClient.InformationLinkClick(ThisForm, Index);
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS






