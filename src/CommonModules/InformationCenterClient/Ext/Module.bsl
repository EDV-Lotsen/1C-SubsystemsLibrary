////////////////////////////////////////////////////////////////////////////////
// Information center subsystem
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Opens form with a news item.
//
// Parameters:
// ID - UUID - News item ID.
//
Procedure ShowNewsItem(ID) Export
	
	FormParameters = New Structure;
	FormParameters.Insert("OpenNewsItem");
	FormParameters.Insert("ID", ID);
	OpenForm("DataProcessor.InformationCenter.Form.DisplayMessages", FormParameters);
	
EndProcedure

// Opens form with all news.
//
Procedure ShowAllNews() Export
	
	FormParameters = New Structure("OpenAllNews");
	OpenForm("DataProcessor.InformationCenter.Form.DisplayMessages", FormParameters);
	
EndProcedure

// Retrieves the maximum allowed size (in megabytes) of attachments in outgoing 
// messages. Maximum allowed size is 20 megabytes.
//
// Returns:
// Number - maximum allowed size of attachments.
//
Function MaxAttachmentSizeForOutgoingMessagesToServiceSupport() Export
	
	Return 20;
	
EndFunction

// Opens form for sending a message.
//
Procedure OpenFormForSendingMessageToSupport(MessageParameters = Undefined) Export
	
	OpenForm("DataProcessor.InformationCenter.Form.SendMessageToSupport", MessageParameters);
	
EndProcedure

// Information link clicking handler.
//
// Parameters:
// Form  - ManagedForm - managed form context.
// Item - FormItem - form group.
//
Procedure InformationLinkClick(Form, Item) Export
	
	Hyperlink = Form.InformationLinks.FindByValue(Item.Name);
	
	If Hyperlink <> Undefined Then
		
		GotoURL(Hyperlink.Presentation);
		
	EndIf;
	
EndProcedure

// The All messages clicking handler.
//
// Parameters:
// PathToForm - String - full path to the form.
//
Procedure AllInformationLinksClick(PathToForm) Export
	
	FormParameters = New Structure("PathToForm", PathToForm);
	OpenForm("DataProcessor.InformationCenter.Form.InformativeLinksInContext", FormParameters);
	
EndProcedure

// Opens the form with the suggestion content.
//
// SuggestionID - String - suggestion UUID.
//
Procedure ShowSuggestion(SuggestionID) Export
	
	FormParameters = New Structure("SuggestionID", SuggestionID);
	OpenForm("DataProcessor.InformationCenter.Form.Suggestion", FormParameters);
	
EndProcedure