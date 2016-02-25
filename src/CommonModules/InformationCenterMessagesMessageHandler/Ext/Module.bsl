////////////////////////////////////////////////////////////////////////////////
// Information center message handling
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

// Retrieves the list of message handlers that the subsystem handles.
// 
// Parameters:
//  Handlers - ValueTable - see field content in MessageExchange.NewMessageHandlerTable.
// 
Procedure GetMessageChannelHandlers(Val Handlers) Export
	
	AddMessageChannelHandler("InformationCenter\Unavailability\Create",        InformationCenterMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("InformationCenter\Unavailability\Delete",          InformationCenterMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("InformationCenter\NewsItem\Create",              InformationCenterMessagesMessageHandler, Handlers);
	AddMessageChannelHandler("InformationCenter\NewsItem\Delete",                InformationCenterMessagesMessageHandler, Handlers);
	
EndProcedure

// Handles a body of the message from the channel according to the message channel algorithm.
//
// Parameters:
//  MessageChannel - (mandatory) String - ID of the message channel from which the
//                    message is received.
//  Body           - (mandatory) Arbitrary - Body of the message received from the
//                    channel to be handled.
//  <From>         - (mandatory) ExchangePlanRef.MessageExchange - end point that is
//                    the sender of the messages.
//
Procedure ProcessMessage(Val MessageChannel, Val Body, Val From) Export
	
	If MessageChannel = "InformationCenter\Unavailability\Create" Then
		HandleUnavailability(Body);
	ElsIf MessageChannel = "InformationCenter\Unavailability\Delete" Then
		If Body.Property("ID") Then 
			DeleteInformationCenterData(Body.ID);
		EndIf;
	ElsIf MessageChannel = "InformationCenter\NewsItem\Create" Then
		HandleNewsItem(Body);
	ElsIf MessageChannel = "InformationCenter\NewsItem\Delete" Then
		If Body.Property("ID") Then 
			DeleteInformationCenterData(Body.ID);
		EndIf;
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds the channel handler.
//
Procedure AddMessageChannelHandler(Channel, ChannelHandler, Handlers)
	
	Handler = Handlers.Add();
	Handler.Channel = Channel;
	Handler.Handler = ChannelHandler;
	
EndProcedure

// Handles the unavailability.
//
// Parameters:
//  Body - Structure - message body.
//
Procedure HandleUnavailability(Body)
	
	Object = GetDataByID(Body.ID);
	If Object = Undefined Then
		CreateUnavailability(Body);
	Else
		UpdateUnavailability(Object, Body);
	EndIf;
	
EndProcedure

// Creates the unavailability in the catalog of common information center data.
//
// Parameters:
//  Body - Structure - message body.
//
Procedure CreateUnavailability(Body)
	
	Unavailability = Catalogs.CommonInformationCenterData.CreateItem();
	Unavailability.SetNewCode();
	
	Unavailability.ID          = Body.ID;
	Unavailability.Description = GenerateUnavailabilityTitle(Body.Description, Body.StartDate, Body.EndDate);
	Unavailability.Date        = Body.Date;
	Unavailability.StartDate   = Body.StartDate - (60 * 60 * 24);
	Unavailability.EndDate     = Body.EndDate;
	Unavailability.Criticality = Body.Criticality;
	If Body.Property("HTMLText") Then 
		Unavailability.HTMLText = Body.HTMLText;
	EndIf;
	If Body.Property("Attachments") Then 
		Unavailability.Attachments = New ValueStorage(Body.Attachments);
	EndIf;
	If Body.Property("ExternalLink") Then 
		Unavailability.ExternalLink	= Body.ExternalLink;
	EndIf;
	If Body.Property("InformationType") Then 
		Unavailability.InformationType = InformationCenterServer.DetermineInformationTypeRef(Body.InformationType);
	Else
		Unavailability.InformationType = InformationCenterServer.DetermineInformationTypeRef("Unavailability");
	EndIf;
	
	Unavailability.Write();
	
EndProcedure	

// Updates list unavailability.
//
// Parameters:
// Unavailability - CatalogRef.CommonInformationCenterData - reference to unavailability.
// Body           - Structure - message body.
//
Procedure UpdateUnavailability(Unavailability, Body)
	
	Unavailability.InformationType = InformationCenterServer.DetermineInformationTypeRef("Unavailability");
	Unavailability.ID              = Body.ID;
	Unavailability.Description     = GenerateUnavailabilityTitle(Body.Description, Body.StartDate, Body.EndDate);
	Unavailability.Date            = Body.Date;
	Unavailability.StartDate       = Body.StartDate - (60 * 60 * 24);
	Unavailability.EndDate         = Body.EndDate;
	Unavailability.Criticality     = Body.Criticality;
	Unavailability.DeletionMark    = False;
	If Body.Property("HTMLText") Then 
		Unavailability.HTMLText = Body.HTMLText;
	EndIf;
	If Body.Property("Attachments") Then 
		Unavailability.Attachments = New ValueStorage(Body.Attachments);
	EndIf;
	If Body.Property("ExternalLink") Then 
		Unavailability.ExternalLink = Body.ExternalLink;
	EndIf;
	Unavailability.Write();
	
EndProcedure	

// Handles the news item.
//
// Parameters:
// Body - Structure - message body.
//
Procedure HandleNewsItem(Body)
	
	Object = GetDataByID(Body.ID);
	If Object = Undefined Then
		CreateNewsItem(Body);
	Else
		UpdateNewsItem(Object, Body);
	EndIf;
	
EndProcedure

// Creates a news item in the catalog of common information center data.
//
// Parameters:
// Body - Structure - message body.
//
Procedure CreateNewsItem(Body)
	
	NewsItem = Catalogs.CommonInformationCenterData.CreateItem();
	NewsItem.SetNewCode();
	
	NewsItem.ID          = Body.ID;
	NewsItem.Description = TrimAll(Body.Description);
	NewsItem.Date        = Body.Date;
	NewsItem.StartDate   = Body.StartDate;
	NewsItem.EndDate     = Body.EndDate;
	NewsItem.Criticality = Body.Criticality;
	If Body.Property("HTMLText") Then 
		NewsItem.HTMLText = Body.HTMLText;
	EndIf;
	If Body.Property("Attachments") Then 
		NewsItem.Attachments = New ValueStorage(Body.Attachments);
	EndIf;
	If Body.Property("ExternalLink") Then 
		NewsItem.ExternalLink	= Body.ExternalLink;
	EndIf;
	If Body.Property("InformationType") Then 
		NewsItem.InformationType = InformationCenterServer.DetermineInformationTypeRef(Body.InformationType);
	Else
		NewsItem.InformationType = InformationCenterServer.DetermineInformationTypeRef("NewsItem");
	EndIf;
	
	NewsItem.Write();
	
EndProcedure

// Updates the news item.
//
// Parameters:
//  NewsItem - CatalogRef.CommonInformationCenterData - reference to the news item.
//  Body     - Structure - message body.
//
Procedure UpdateNewsItem(NewsItem, Body)
	
	NewsItem.InformationType = InformationCenterServer.DetermineInformationTypeRef("NewsItem");
	NewsItem.ID              = Body.ID;
	NewsItem.Description     = TrimAll(Body.Description);
	NewsItem.Date            = Body.Date;
	NewsItem.StartDate       = Body.StartDate;
	NewsItem.EndDate         = Body.EndDate;
	NewsItem.Criticality     = Body.Criticality;
	NewsItem.DeletionMark    = False;
	If Body.Property("HTMLText") Then 
		NewsItem.HTMLText = Body.HTMLText;
	EndIf;
	If Body.Property("Attachments") Then 
		NewsItem.Attachments = New ValueStorage(Body.Attachments);
	EndIf;
	If Body.Property("ExternalLink") Then 
		NewsItem.ExternalLink	= Body.ExternalLink;
	EndIf;
	NewsItem.Write();
	
EndProcedure

// Deletes information center data item by ID.
//
// Parameters:
//  ID - UUID - news item UUID.
//
Procedure DeleteInformationCenterData(ID)
	
	SetPrivilegedMode(True);
	Object = GetDataByID(ID);
	If Object = Undefined Then 
		Return;
	EndIf;
	
	Object.SetDeletionMark(True);
	
EndProcedure

// Retrieves the CommonInformationCenterData catalog object by ID.
//
// Parameters:
//  ID - UUID - Data item UUID.
//
// Returns:
//  CatalogObject.CommonInformationCenterData, Undefined.
//
Function GetDataByID(ID)
	
	Query = New Query;
	Query.SetParameter("ID", ID);
	Query.Text =
	"SELECT
	|	CommonInformationCenterData.Reference AS Reference
	|FROM
	|	Catalog.CommonInformationCenterData AS CommonInformationCenterData
	|WHERE
	|	CommonInformationCenterData.ID = &ID";
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then 
		Return Undefined;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Return Selection.Reference.GetObject();
	EndDo;
	
EndFunction

// Retrieves the unavailability title.
//
// Parameters:
//  Title     - String - message title.
//  ValidFrom - Date - unavailability start date.
//  ValidTo   - Date - unavailability end date.
//
// Returns:
//  String - unavailability title.
//
Function GenerateUnavailabilityTitle(Title, ValidFrom, ValidTo)
	
	UnavailableFrom	= Format(ValidFrom, "DF=dd.MM.yyyy HH:mm'");
	UpdateDuration	= DateDiffInMinutes(ValidFrom, ValidTo);
	Template = NStr("en = '%1 %2 (%3 min.)'");
	Template = StringFunctionsClientServer.SubstituteParametersInString(Template, String(UnavailableFrom), TrimAll(Title), UpdateDuration);
	Return Template;
	
EndFunction

// Returns difference dates in minutes.
//
// Parameters:
//  ValidFrom - Date - Start date.
//  ValidTo   - Date - End date.
//
// Returns:
//  Number - number of minutes.
//
Function DateDiffInMinutes(ValidFrom, ValidTo)
	
	DateDiffInSeconds = ValidTo - ValidFrom;
	
	Return Round(DateDiffInSeconds / 60);
	
EndFunction