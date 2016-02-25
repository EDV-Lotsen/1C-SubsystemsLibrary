////////////////////////////////////////////////////////////////////////////////
// GENERAL IMPLEMENTATION OF INFORMATION CENTER MESSAGE HANDLING
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Generates the CommonInformationCenterData catalog item by message.
//
// Parameters:
//  Body - XDTODataObject - message body.
//
Procedure AddSuggestionNotification(Body) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		AddSuggestionNotificationToCatalog(Body);
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds the notification by suggestion. 
//
// Parameters:
// Body - XDTODataObject - message body.
//
Procedure AddSuggestionNotificationToCatalog(Body)
	
	SuggestionNotification                 = Catalogs.CommonInformationCenterData.CreateItem();
	SuggestionNotification.ID            = Body.id;
	SuggestionNotification.Description     = Body.name;
	SuggestionNotification.StartDate       = Body.startDate;
	SuggestionNotification.EndDate         = Body.endDate;
	SuggestionNotification.InformationType = InformationCenterServer.DetermineInformationTypeRef("SuggestionNotification");
	SuggestionNotification.Criticality     = Body.criticality;
	SuggestionNotification.Write();
	
EndProcedure























