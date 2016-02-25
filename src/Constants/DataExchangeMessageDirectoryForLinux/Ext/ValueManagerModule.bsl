#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	DataExchangeServer.ExternalResourcesDataExchangeMessageDirectoryQuery(PermissionRequests, ThisObject);
	
EndProcedure

#EndIf