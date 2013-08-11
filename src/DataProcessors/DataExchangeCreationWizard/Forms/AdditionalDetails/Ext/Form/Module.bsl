////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Template = DataProcessors.DataExchangeCreationWizard.GetTemplate(Parameters.TemplateName);
	
	HTMLDocumentField = Template.GetText();
	
	Title = Parameters.Title;
	
EndProcedure
