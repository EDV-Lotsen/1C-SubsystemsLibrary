////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Determines end points that have the specified message channel in the 
// current infobase.
//
// Parameters:
// MessageChannel – String - message channel ID.
//
// Returns:
// Array of ExchangePlanRef.MessageExchange - array of end point items.
//
Function MessageChannelSubscribers(Val MessageChannel) Export
	
	QueryText =
	"SELECT
	|	SenderSettings.Recipient AS Recipient
	|FROM
	|	InformationRegister.SenderSettings AS SenderSettings
	|WHERE
	|	SenderSettings.MessageChannel = &MessageChannel";
	
	Query = New Query;
	Query.SetParameter("MessageChannel", MessageChannel);
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction
