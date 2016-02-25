
////////////////////////////////////////////////////////////////////////////////
// DataAreaBackupCached.
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Returns the mapping between the fields of application system settings and the 
// fields from ZoneBackupControl XDTO package of the service manager
// (type:{http:www.1c.ru/SaaS/1.0/XMLSchema/ZoneBackupControl}Settings).
//
// Returns:
// FixedMap.
//
Function MapBetweenSMSettingsAndAppSettings() Export
	
	Result = New Map;
	
	Result.Insert("CreateDailyBackup", "CreateDailyBackups");
	Result.Insert("CreateMonthlyBackup", "CreateMonthlyBackups");
	Result.Insert("CreateYearlyBackup", "CreateYearlyBackups");
	Result.Insert("BackupCreationTime", "BackupCreationTime");
	Result.Insert("MonthlyBackupCreationDay", "MonthlyBackupCreationDate");
	Result.Insert("YearlyBackupCreationMonth", "YearlyBackupCreationMonth");
	Result.Insert("YearlyBackupCreationDay", "YearlyBackupCreationDate");
	Result.Insert("KeepDailyBackups", "DailyBackupCount");
	Result.Insert("KeepMonthlyBackups", "MonthlyBackupCount");
	Result.Insert("KeepYearlyBackups", "YearlyBackupCount");
	Result.Insert("CreateDailyBackupOnUserWorkDaysOnly", "CreateDailyBackupsOnlyOnUserWorkdays");
	
	Return New FixedMap(Result);

EndFunction	

// Determines whether the application supports backup creation.
//
// Returns:
// Boolean - True if the application supports backup creation.
//
Function ServiceManagerSupportsBackup() Export
	
	SetPrivilegedMode(True);
	
	SupportedVersions = CommonUse.GetInterfaceVersions(
		Constants.InternalServiceManagerURL.Get(),
		Constants.AuxiliaryServiceManagerUserName.Get(),
		Constants.AuxiliaryServiceManagerUserPassword.Get(),
		"DataAreaBackup");
		
	Return SupportedVersions.Find("1.0.1.1") <> Undefined;
	
EndFunction

// Returns backup control web service proxy.
// 
// Returns: 
// WSProxy.
// Service manager proxy. 
// 
Function BackupControlProxy() Export
	
	ServiceManagerURL = Constants.InternalServiceManagerURL.Get();
	If Not ValueIsFilled(ServiceManagerURL) Then
		Raise(NStr("en = 'Service manager connection parameters are not specified.'"));
	EndIf;
	
	ServiceURL = ServiceManagerURL + "/ws/ZoneBackupControl?wsdl";
	UserName = Constants.AuxiliaryServiceManagerUserName.Get();
	UserPassword = Constants.AuxiliaryServiceManagerUserPassword.Get();
	
	Proxy = CommonUse.WSProxy(ServiceURL, "http://www.1c.ru/SaaS/1.0/WS",
		"ZoneBackupControl", , UserName, UserPassword, 10);
		
	Return Proxy;
	
EndFunction

// Returns the subsystem name to be used in the names of log events.
//
// Returns: String.
//
Function SubsystemNameForEventLogEvents() Export
	
	Return Metadata.Subsystems.StandardSubsystems.Subsystems.SaaSOperations.Subsystems.DataAreaBackup.Name;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Background jobs

// Returns the method name of the background job that exports areas to files.
//
// Returns:
// String.
//
Function BackgroundBackupMethodName() Export
	
	Return "DataAreaBackup.ExportAreaToSMStorage";
	
EndFunction

// Returns the description of the background job that exports areas to files.
//
// Returns:
// String.
//
Function BackgroundBackupDescription() Export
	
	Return NStr("en = 'Data area backup'", CommonUseClientServer.DefaultLanguageCode());
	
EndFunction

#EndRegion
