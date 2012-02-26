
////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM EVENTS HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	SettingProxyAtClient = Parameters.SettingProxyAtClient;
	
	If SettingProxyAtClient Then
		ProxyServerConfiguration = CommonSettingsStorage.Load("ProxyServerConfiguration");
	Else
		ProxyServerConfiguration = GetFilesFromInternet.GetProxySettingsAt1CEnterpriseServer();
	EndIf;
	
	If TypeOf(ProxyServerConfiguration) = Type("Map") Then
		UseProxy 						= ProxyServerConfiguration["UseProxy"];
		Server       					= ProxyServerConfiguration["Server"];
		User 							= ProxyServerConfiguration["User"];
		Password       					= ProxyServerConfiguration["Password"];
		Port         					= ProxyServerConfiguration["Port"];
		BypassProxyOnLocal 				=
		           ProxyServerConfiguration["BypassProxyOnLocal"];
	EndIf;
	
	Items.ParametersProxy.Enabled = ?(UseProxy, True, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES - FORM ITEMS EVENT HANDLERS

// Handler of click event of button "OK" of command bar of form
// Closes form, passing proxy parameters
// as returning result.
//
&AtClient
Procedure OKExecute()
	
	ProxyServerConfiguration 		= New Map;
	ProxyServerConfiguration.Insert("UseProxy", UseProxy);
	ProxyServerConfiguration.Insert("User", 	User);
	ProxyServerConfiguration.Insert("Password", Password);
	ProxyServerConfiguration.Insert("Port", 	Port);
	ProxyServerConfiguration.Insert("Server", 	Server);
	ProxyServerConfiguration.Insert("BypassProxyOnLocal",
	                              BypassProxyOnLocal);
	
	SaveProxyServerSettings(SettingProxyAtClient, ProxyServerConfiguration);
	
	Close(ProxyServerConfiguration);
	
EndProcedure

// Change proxy parameters edit group accessibility if parameters are not used
//
&AtClient
Procedure UseProxyOnChange(Item)
	
	Items.ParametersProxy.Enabled = ?(UseProxy, True, False);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// AUXILIARY PROCEDURES AND FUNCTIONS

// Save proxy settings
//
&AtServerNoContext
Procedure SaveProxyServerSettings(SettingProxyAtClient, ProxyServerConfiguration)
	
	If SettingProxyAtClient Then
		CommonSettingsStorage.Save("ProxyServerConfiguration", , ProxyServerConfiguration);
		RefreshReusableValues();
	Else
		GetFilesFromInternet.SaveProxySettingsAt1CEnterpriseServer(ProxyServerConfiguration);
	EndIf;
	
EndProcedure

