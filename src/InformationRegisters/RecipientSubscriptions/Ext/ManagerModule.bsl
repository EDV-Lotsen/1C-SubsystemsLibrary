#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

// Defines the endpoints (subscribers) for
// broadcast channel of the "Publication/Subscription" type.
//
// Parameters:
//  MessageChannel - String - Message broadcast channel ID.
//
// Returns:
//  Array - Endpoints items array, that contains items of ExchangePlanRef.MessageExchange type.
//
Function MessageChannelSubscribers(Val MessageChannel) Export
	
	QueryText =
	"SELECT
	|	RecipientSubscriptions.Recipient AS Recipient
	|FROM
	|	InformationRegister.RecipientSubscriptions AS RecipientSubscriptions
	|WHERE
	|	RecipientSubscriptions.MessageChannel = &MessageChannel";
	
	Query = New Query;
	Query.SetParameter("MessageChannel", MessageChannel);
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction

#EndRegion

#EndIf