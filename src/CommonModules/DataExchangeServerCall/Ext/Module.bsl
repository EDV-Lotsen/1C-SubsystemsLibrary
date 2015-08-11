// Specifies the data exchange subsystem session parameters.
//
// Parameters:
//  ParameterName       - String - name of the session parameter whose value is
//                        specified.
//  SpecifiedParameters - Array - set session parameter information.
// 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	// Updating reusable values and session parameters
	DataExchangeServer.RefreshORMCachedValues();
	
	// Registering names of parameters to be set up during the RefreshORMCachedValues
	// procedure execution.
	SpecifiedParameters.Add("DataExchangeEnabled");
	SpecifiedParameters.Add("UsedExchangePlans");
	SpecifiedParameters.Add("SelectiveObjectChangeRecordRules");
	SpecifiedParameters.Add("ObjectChangeRecordRules");
	SpecifiedParameters.Add("ORMCachedValueRefreshDate");
	
EndProcedure

