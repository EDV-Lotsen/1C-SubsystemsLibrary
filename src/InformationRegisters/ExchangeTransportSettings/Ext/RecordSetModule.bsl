////////////////////////////////////////////////////////////////////////////////
// EVENT HANDLERS

Procedure OnWrite(Cancel, Replacing)
	
	// Updating the platform cache for reading actual exchange message transport 
	// settings with the DataExchangeCached.GetExchangeSettingsStructure procedure.
	RefreshReusableValues();
	
EndProcedure
