////////////////////////////////////////////////////////////////////////////////
// Users subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Procedures that are used when exchanging data.

// Overrides the standard mechanism of data export.
// The InfoBaseUserID attribute is not exported.
//
Procedure OnSendData(DataItem, ItemSending) Export
	
	If ItemSending = DataItemSend.Delete
		Or TypeOf(DataItem) = Type("ObjectDeletion") Then
		Return;
	EndIf;
	
	If TypeOf(DataItem) = Type("CatalogObject.Users")
	 Or TypeOf(DataItem) = Type("CatalogObject.ExternalUsers") Then
		DataItem.InfoBaseUserID = New UUID("00000000-0000-0000-0000-000000000000");
	EndIf;
	
EndProcedure

// Overrides the standard mechanism of data importing.
// The InfoBaseUserID attribute is not imported because it is always corresponds to
// a user of the current infobase or does not correspond to any user at all.
//
Procedure OnDataGet(DataItem) Export
	
	If TypeOf(DataItem) = Type("CatalogObject.Users")
	 Or TypeOf(DataItem) = Type("CatalogObject.ExternalUsers") Then
		DataItem.InfoBaseUserID = CommonUse.GetAttributeValue(DataItem.Ref, "InfoBaseUserID");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers. 

// The OnWrite event subscription handler. 
// Updates the external user presentation when a presentation of his or her
// authorization object is changed.
//
// The following authorization object types must be included into the subscription:
// Metadata.Catalogs.ExternalUsers.Attributes.AuthorizationObject.Type;
// For example: Catalog.Individuals, Catalog.Counterparties.
//
Procedure UpdateExternalUserPresentation(Val Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	If TypeOf(Object.Ref) = Type("CatalogRef.ExternalUsers") Then
		Return;
	EndIf;
	
	ExternalUsers.UpdateExternalUserPresentation(Object.Ref);
	
EndProcedure







