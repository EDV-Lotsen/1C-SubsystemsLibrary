

// Handler UpdateExternalUserPresentation of event OnWrite of event subscription
// "UpdateExternalUserPresentation" calls write method of external user presentation.
// Type CatalogRef.ExternalUsers is used for providing not empty list of types in
// the event subscription.
//  In subscription content authorization object types should be included,
// for example, Catalog.Individuals, Catalog.Counterparties
//
Procedure UpdateExternalUserPresentation(Val Object, Cancellation) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	If TypeOf(Object.Ref) = Type("CatalogRef.ExternalUsers") Then
		Return;
	EndIf;
	
	ExternalUsers.UpdateExternalUserPresentation(Object.Ref);
	
EndProcedure

