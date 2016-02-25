////////////////////////////////////////////////////////////////////////////////
// "Data exchange" subsystem.
// The module is intended for working with an external connection.
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Exports data for the infobase node to a temporary file.
// (For internal use only)
//
Procedure ExportForInfobaseNode(Cancel,
												ExchangePlanName,
												InfobaseNodeCode,
												ExchangeMessageFullFileName,
												ErrorMessageString = ""
	) Export
	
	DataExchangeServer.CheckUseDataExchange();
	
	If CommonUse.FileInfobase() Then
		
		Try
			DataExchangeServer.ExportForInfobaseNodeViaFile(ExchangePlanName, InfobaseNodeCode, ExchangeMessageFullFileName);
		Except
			Cancel = True;
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
		EndTry;
		
	Else
		
		Address = "";
		
		Try
			
			DataExchangeServer.ExportToTempStorageForInfobaseNode(ExchangePlanName, InfobaseNodeCode, Address);
			
			GetFromTempStorage(Address).Write(ExchangeMessageFullFileName);
			
			DeleteFromTempStorage(Address);
			
		Except
			Cancel = True;
			ErrorMessageString = DetailErrorDescription(ErrorInfo());
		EndTry;
		
	EndIf;
	
EndProcedure

// Writes a message about the exchange start to the event log.
// (For internal use only)
//
Procedure WriteLogEventDataExchangeStart(ExchangeSettingsStructure) Export
	
	DataExchangeServer.WriteLogEventDataExchangeStart(ExchangeSettingsStructure);
	
EndProcedure

// Writes a message about completing the exchange through the external connection.
// (For internal use only)
//
Procedure AddExchangeFinishEventLogMessage(ExchangeSettingsStructureExternalConnection) Export
	
	ExchangeSettingsStructureExternalConnection.ExchangeExecutionResult = Enums.ExchangeExecutionResults[ExchangeSettingsStructureExternalConnection.ExchangeExecutionResultString];
	
	DataExchangeServer.AddExchangeOverExternalConnectionFinishEventLogMessage(ExchangeSettingsStructureExternalConnection);
	
EndProcedure

// Gets read object conversion rules by exchange plan name.
// (For internal use only)
//
//  Returns:
//  Read object conversion rules.
//
Function GetObjectConversionRules(ExchangePlanName) Export
	
	Return DataExchangeServer.GetObjectConversionRulesViaExternalConnection(ExchangePlanName);
	
EndFunction

// Retrieves exchange settings structure.
// (For internal use only)
//
Function ExchangeSettingsStructure(Structure) Export
	
	Return DataExchangeServer.ExchangeOverExternalConnectionSettingsStructure(DataExchangeEvents.CopyStructure(Structure));
	
EndFunction

// Checks whether the exchange plan with the specified name exists.
// (For internal use only)
//
Function ExchangePlanExists(ExchangePlanName) Export
	
	Return Metadata.ExchangePlans.Find(ExchangePlanName) <> Undefined;
	
EndFunction

// Retrieves the default infobase prefix through external connection.
// Calls the function with the same name from the overridable module.
// (For internal use only)
//
Function DefaultInfobasePrefix() Export
	
	InfobasePrefix = Undefined;
	//InfobasePrefix = DataExchangeOverridable.DefaultInfobasePrefix();
	DataExchangeOverridable.OnDefineDefaultInfobasePrefix(InfobasePrefix);
	
	Return InfobasePrefix;
	
EndFunction

// Checks whether the check for the conversion rule version mismatch is required.
//
Function WarnAboutExchangeRuleVersionMismatch(ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	Return DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch");
	
EndFunction

// Returns a flag that shows whether the FullAccess role is available.
// (For internal use only)
//
Function IsInRoleFullAccess() Export
	
	Return Users.InfobaseUserWithFullAccess(, True);
	
EndFunction

// Returns the object list table of the specified metadata object.
// (For internal use only)
// 
Function GetTableObjects(FullTableName) Export
	
	Return ValueToStringInternal(CommonUse.ValueFromXMLString(DataExchangeServer.GetTableObjects(FullTableName)));
	
EndFunction

// Returns the object list table of the specified metadata object. 
// (For internal use only)
// 
Function GetTableObjects_2_0_1_6(FullTableName) Export
	
	Return DataExchangeServer.GetTableObjects(FullTableName);
	
EndFunction

// Retrieves the specified metadata object properties (Synonym, Hierarchical).
// (For internal use only)
//
Function MetadataObjectProperties(FullTableName) Export
	
	Return DataExchangeServer.MetadataObjectProperties(FullTableName);
	
EndFunction

// Returns a description of the predefined exchange plan node.
// (For internal use only)
//
Function PredefinedExchangePlanNodeDescription(ExchangePlanName) Export
	
	Return DataExchangeServer.PredefinedExchangePlanNodeDescription(ExchangePlanName);
	
EndFunction

// For internal use
//
Function GetCommonNodeData(Val ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return ValueToStringInternal(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// For internal use
//
Function GetCommonNodeData_2_0_1_6(Val ExchangePlanName) Export
	
	SetPrivilegedMode(True);
	
	Return CommonUse.ValueToXMLString(DataExchangeServer.DataForThisInfobaseNodeTabularSections(ExchangePlanName));
	
EndFunction

// For internal use
//
Function GetInfobaseParameters(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return DataExchangeServer.GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage);
	
EndFunction

// For internal use
//
Function GetInfobaseParameters_2_0_1_6(Val ExchangePlanName, Val NodeCode, ErrorMessage) Export
	
	Return DataExchangeServer.GetInfobaseParameters_2_0_1_6(ExchangePlanName, NodeCode, ErrorMessage);
	
EndFunction

#EndRegion
