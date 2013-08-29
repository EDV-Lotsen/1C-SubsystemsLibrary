
////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	DataExchangeClient.SetupFormBeforeClose(Cancel, ThisForm);
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DataExchangeServer.CorrespondentInfoBaseNodeSetupFormOnCreateAtServer(ThisForm, Metadata.ExchangePlans._DemoExchangeWithSubsystemsLibrary.Name);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisibility();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure OKCommand(Command)
	
	DataExchangeClient.NodeSettingsFormCloseFormCommand(ThisForm);
	
EndProcedure

&AtClient
Procedure UseFilterByCompaniesOnChange(Item)
	
	SetVisibility();
	
EndProcedure

&AtClient
Procedure SetVisibility()
	
	Items.Companies.Visible = UseFilterByCompanies;
	
EndProcedure

&AtClient
Procedure CompaniesCompanyStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfoBaseItemChoiceHandlerStartChoice("Company", "Catalog.Companies", Items.Companies,StandardProcessing, ExternalConnectionParameters);
	
EndProcedure

&AtClient
Procedure CompaniesChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	DataExchangeClient.CorrespondentInfoBaseItemChoiceProcessingHandler(Item, SelectedValue);
	
EndProcedure
