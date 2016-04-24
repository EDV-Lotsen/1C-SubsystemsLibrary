#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Var RecordLevelSecurityEnabled; // Flag showing whether the constant value changed from False to True.

//                                 Used in OnWrite event handler.

Var RecordLevelSecurityChanged; // Flag showing whether the constant value changed.
//                                 Used in OnWrite event handler.

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	RecordLevelSecurityEnabled = Value And Not Constants.UseRecordLevelSecurity.Get();
	
	RecordLevelSecurityChanged = Value <> Constants.UseRecordLevelSecurity.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If RecordLevelSecurityChanged 
Then
		
		AccessManagementInternal.OnChangeRecordLevelSecurity(
			RecordLevelSecurityEnabled);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf