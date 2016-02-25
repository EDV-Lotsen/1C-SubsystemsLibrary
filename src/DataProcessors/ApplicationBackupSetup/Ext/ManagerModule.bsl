#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	StandardProcessing = False;
	
	SetPrivilegedMode(True);
	
	Versions = GetWebServiceVersions();
	
	If Versions.Find("1.0.2.1") <> Undefined Then
	
		SelectedForm = "SetWithIntervals";
			
		DataArea = CommonUse.SessionSeparatorValue();
		
		AdditionalParameters = DataAreaBackupFormDataInterface.
			GetSettingsFormParameters(DataArea);
		For Each KeyAndValue In AdditionalParameters Do
			Parameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		
	ElsIf DataAreaBackupCached.ServiceManagerSupportsBackup() Then
		
		SelectedForm = "SetWithoutIntervals";
		
	Else
#EndIf
		
		Raise(NStr("en = 'The service manager does not support application backup'"));
		
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	EndIf;
#EndIf
	
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
Function GetWebServiceVersions()
	
	Return CommonUse.GetInterfaceVersions(
		Constants.InternalServiceManagerURL.Get(),
		Constants.AuxiliaryServiceManagerUserName.Get(),
		Constants.AuxiliaryServiceManagerUserPassword.Get(),
		"ZoneBackupControl");

EndFunction
#EndIf

#EndRegion
