////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	ProxySettingsAtClient = Parameters.ProxySettingsAtClient;
	
	If ProxySettingsAtClient Then
		ProxyServerSettings = CommonUse.CommonSettingsStorageLoad("ProxyServerSettings");
	Else
		ProxyServerSettings = GetFilesFromInternet.GetServerProxySettings();
	EndIf;
	
	If TypeOf(ProxyServerSettings) = Type("Map") Then
		UseProxy = ProxyServerSettings.Get("UseProxy");
		Server = ProxyServerSettings.Get("Server");
		User = ProxyServerSettings.Get("User");
		Password = ProxyServerSettings.Get("Password");
		Port = ProxyServerSettings.Get("Port");
		BypassProxyForLocalURLs = ProxyServerSettings.Get("BypassProxyForLocalURLs");
		UseSystemSettings = ProxyServerSettings.Get("UseSystemSettings");
	EndIf;
	
	ProxyServerUseVariant = ?(UseProxy, ?(UseSystemSettings = True, 1, 2), 0);
	If Not ProxySettingsAtClient Then
		ProxySettings = Undefined;
		// Proxy server settings variants:
		// 0 - Do not use the proxy server (the default value, corresponds to the New InternetProxy(False))
		// 1 - Use proxy server system settings (corresponds to the New InternetProxy(True))
		// 2 - Use custom proxy server settings (corresponds to manual proxy server parameter setup)
		// In the latter case, proxy server parameters can be changed manually.
		If ProxyServerUseVariant = 0 Then
			ProxySettings = EmptyProxyServerSettings();
		ElsIf ProxyServerUseVariant = 1 Then
			ProxySettings = ProxyServerSystemSettingsAtServer();
		EndIf;
		InitFormItems(ThisForm, ProxySettings);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ProxySettingsAtClient Then
#If WebClient Then
		DoMessageBox(NStr("en = 'You have to specify proxy server parameters in your browser when running the application with the web client.'"));
		Cancel = True;
		Return;
#EndIf		
		ProxySettings = Undefined;
		// Proxy server settings variants:
		// 0 - Do not use the proxy server (the default value, corresponds to the New InternetProxy(False))
		// 1 - Use proxy server system settings (corresponds to the New InternetProxy(True))
		// 2 - Use custom proxy server settings (corresponds to manual proxy server parameter setup)
		// In the latter case, proxy server parameters can be changed manually.
		If ProxyServerUseVariant = 0 Then
			ProxySettings = EmptyProxyServerSettings();
		ElsIf ProxyServerUseVariant = 1 Then
			ProxySettings = ProxyServerSystemSettingsAtClient();
		EndIf;
		InitFormItems(ThisForm, ProxySettings);
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure UseSystemProxySettingsOnChange(Item)
	
	UseProxy = ProxyServerUseVariant > 0;
	UseSystemSettings = ProxyServerUseVariant = 1;
	
	ProxySettings = Undefined;
		// Proxy server settings variants:
		// 0 - Do not use the proxy server (the default value, corresponds to the New InternetProxy(False))
		// 1 - Use proxy server system settings (corresponds to the New InternetProxy(True))
		// 2 - Use custom proxy server settings (corresponds to manual proxy server parameter setup)
		// In the latter case, proxy server parameters can be changed manually.
	If ProxyServerUseVariant = 0 Then
		ProxySettings = EmptyProxyServerSettings();
	ElsIf ProxyServerUseVariant = 1 Then
		ProxySettings = ?(ProxySettingsAtClient, ProxyServerSystemSettingsAtClient(), ProxyServerSystemSettingsAtServer());
	EndIf;
	InitFormItems(ThisForm, ProxySettings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

// Closes the form.
//
// Form closure result:
// Map - proxy parameters.
//
&AtClient
Procedure OKButton(Command)
	
	ProxyServerSettings = New Map;
	ProxyServerSettings.Insert("UseProxy", UseProxy);
	ProxyServerSettings.Insert("User", User);
	ProxyServerSettings.Insert("Password", Password);
	ProxyServerSettings.Insert("Port", Port);
	ProxyServerSettings.Insert("Server", Server);
	ProxyServerSettings.Insert("BypassProxyForLocalURLs", BypassProxyForLocalURLs);
	ProxyServerSettings.Insert("UseSystemSettings", UseSystemSettings);
	
	SaveProxyServerSettings(ProxySettingsAtClient, ProxyServerSettings);
	Close(ProxyServerSettings);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServerNoContext
Procedure SaveProxyServerSettings(ProxySettingsAtClient, ProxyServerSettings)
	If ProxySettingsAtClient Then
		CommonUse.CommonSettingsStorageSave("ProxyServerSettings", , ProxyServerSettings);
		RefreshReusableValues();
	Else
		GetFilesFromInternet.SaveServerProxySettings(ProxyServerSettings);
	EndIf;
EndProcedure

&AtClientAtServerNoContext
Procedure InitFormItems(Form, ProxySettings)
	
	If ProxySettings <> Undefined Then	
		Form.Server = ProxySettings.Server;
		Form.Port = ProxySettings.Port;
		Form.User = ProxySettings.User;
		Form.Password = ProxySettings.Password;
		Form.BypassProxyForLocalURLs = ProxySettings.BypassProxyForLocalURLs;
	EndIf;
	
	// Setting up availability of the proxy parameter editing group, based on the proxy server usage variant
	Form.Items.ProxyParameters.Enabled = (Form.ProxyServerUseVariant = 2);
	
EndProcedure

&AtClient
Function ProxyServerSystemSettingsAtClient()
	
	Proxy = New InternetProxy(True);
	
	Result = New Structure();
	Result.Insert("Server", Proxy.Server());
	Result.Insert("Port", Proxy.Port());
	Result.Insert("User", Proxy.User);
	Result.Insert("Password", Proxy.Password);
	Result.Insert("BypassProxyForLocalURLs", Proxy.BypassProxyForLocalURLs);
	Return Result;
	
EndFunction

&AtServerNoContext
Function ProxyServerSystemSettingsAtServer()
	
	Proxy = New InternetProxy(True);
	
	Result = New Structure();
	Result.Insert("Server", Proxy.Server());
	Result.Insert("Port", Proxy.Port());
	Result.Insert("User", Proxy.User);
	Result.Insert("Password", Proxy.Password);
	Result.Insert("BypassProxyForLocalURLs", Proxy.BypassProxyForLocalURLs);
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function EmptyProxyServerSettings()
	
	Result = New Structure();
	Result.Insert("Server", "");
	Result.Insert("Port", 0);
	Result.Insert("User", "");
	Result.Insert("Password", "");
	Result.Insert("BypassProxyForLocalURLs", False);
	Return Result;
	
EndFunction
