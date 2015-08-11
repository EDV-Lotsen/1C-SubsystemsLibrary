// Internal use only.
Procedure SetInitialSettings(Val UserName) Export
	
	SystemInfo = New SystemInfo;
	
	CurrentMode = Metadata.InterfaceCompatibilityMode;
	Taxi = (CurrentMode = Metadata.ObjectProperties.InterfaceCompatibilityMode.Taxi
		Or CurrentMode = Metadata.ObjectProperties.InterfaceCompatibilityMode.TaxiEnableVersion8_2);
	
	ClientSettings = New ClientSettings;
	ClientSettings.ShowNavigationAndActionsPanels = False;
	ClientSettings.ShowSectionsPanel = True;
	ClientSettings.ApplicationFormsOpenningMode = ApplicationFormsOpenningMode.Tabs;
	
	TaxiSettings = Undefined;
	InterfaceSettings = New CommandInterfaceSettings;
	
	If Taxi Then
		
		InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.PictureAndText;
		
		TaxiSettings = New ClientApplicationInterfaceSettings;
  		ContentSettings = New ClientApplicationInterfaceContentSettings;
		LeftGroup = New ClientApplicationInterfaceContentSettingsGroup;
		LeftGroup.Add(New ClientApplicationInterfaceContentSettingsItem("ToolsPanel"));
		LeftGroup.Add(New ClientApplicationInterfaceContentSettingsItem("SectionsPanel"));
  		ContentSettings.Left.Add(LeftGroup);
  		TaxiSettings.SetContent(ContentSettings);
		
	Else
		InterfaceSettings.SectionsPanelRepresentation = SectionsPanelRepresentation.Text;
	EndIf;
	
	DefaultSettings = New Structure("ClientSettings,InterfaceSettings,TaxiSettings", 
		ClientSettings, InterfaceSettings, TaxiSettings);
	UsersOverridable.OnSetInitialSettings(DefaultSettings);
	
	If DefaultSettings.ClientSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/ClientSettings", "",
			DefaultSettings.ClientSettings, , UserName);
	EndIf;
	
	If DefaultSettings.InterfaceSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/SectionsPanel/CommandInterfaceSettings", "",
			DefaultSettings.InterfaceSettings, , UserName);
	EndIf;
		
	If DefaultSettings.TaxiSettings <> Undefined Then
		SystemSettingsStorage.Save("Common/ClientApplicationInterfaceSettings", "",
			DefaultSettings.TaxiSettings, , UserName);
	EndIf;
		
EndProcedure

// Internal use only.
Procedure InternalEventOnAdd(ClientEvents, ServerEvents) Export
	
	// SERVER EVENTS.
	
	ServerEvents.Add("StandardSubsystems.Users\RoleEditOnDefineDenial");
	
	ServerEvents.Add("StandardSubsystems.Users\FormActionsOnDefine");

	ServerEvents.Add(
		"StandardSubsystems.Users\BeforeWriteFirstAdministratorOnDefineQuestionText");
	
	ServerEvents.Add("StandardSubsystems.Users\AdministratorOnWrite");
	
	ServerEvents.Add("StandardSubsystems.Users\DuringLogOnOnCreateUser");
	
	ServerEvents.Add("StandardSubsystems.Users\NewInfoBaseUserOnAuthorize");
	
	ServerEvents.Add("StandardSubsystems.Users\InfoBaseUserProcessingOnStart");
	
	ServerEvents.Add("StandardSubsystems.Users\BeforeWriteInfoBaseUser");
	
EndProcedure

// Internal use only.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS.
	
	ServerHandlers["StandardSubsystems.InfoBaseVersionUpdate\UpdateHandlersOnAdd"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\SessionParameterSettingHandlersOnAdd"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ClientParametersOnAdd"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ReferenceSearchExceptionOnAdd"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnSendDataToSlave"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnSendDataToMaster"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromSlave"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\OnReceiveDataFromMaster"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\AfterReceiveDataFromSubordinate"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\AfterReceiveDataFromMaster"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\RequiredExchangePlanObjectOnReceive"].Add(
		"UsersInternal");
	
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExceptionExchangePlanObjectOnReceive"].Add(
		"UsersInternal");
		
	ServerHandlers["StandardSubsystems.BaseFunctionality\ExchangePlanInitialImageObjectsOnGet"].Add(
		"UsersInternal");
	
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ServerHandlers["StandardSubsystems.AccessManagement\MetadataObjectAccessResctrictionTypesOnFill"].Add(
			"UsersInternal");
	EndIf;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		ServerHandlers["StandardSubsystems.ReportOptions\ReportOptionsOnSetup"].Add(
			"UsersInternal");
	EndIf;
	
EndProcedure

// Internal use only.
Procedure SessionParameterSettingHandlersOnAdd(Handlers) Export
	
	Handlers.Insert("CurrentUser",         "Users.SetSessionParameters");
	Handlers.Insert("CurrentExternalUser", "Users.SetSessionParameters");
	
EndProcedure

// Internal use only.
Procedure ClientParametersOnAdd(Parameters) Export
	
	Parameters.Insert("InfoBaseUserWithFullAccess", Users.InfoBaseUserWithFullAccess());
	
EndProcedure
