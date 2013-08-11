////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Determines end points (subscribers) for the broadcast channel of the 
// Publication/Subscription type.
//
// Parameters:
// MessageChannel – String. ID of the broadcast message channel.
//
// Returns:
// Array of ExchangePlanRef.MessageExchange - array of end point items.
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
