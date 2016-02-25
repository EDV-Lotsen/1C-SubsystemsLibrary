
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skip the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ProxySettingsAtClient = Parameters.ProxySettingsAtClient;
	If Not Parameters.ProxySettingsAtClient
		And Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise NStr("en = 'Limited access rights.
			|
			|Proxy server configuration is performed by the administrator.'");
	EndIf;
	
	If ProxySettingsAtClient Then
		ProxyServerSettings = GetFilesFromInternet.ProxySettingsAtClient();
	Else
		ProxyServerSettings = GetFilesFromInternet.ProxySettingsAtServer();
	EndIf;
	
	UseProxy = True;
	UseSystemSettings = True;
	If TypeOf(ProxyServerSettings) = Type("Map") Then
		
		UseProxy = ProxyServerSettings.Get("UseProxy");
		UseSystemSettings = ProxyServerSettings.Get("UseSystemSettings");
		
		If UseProxy And Not UseSystemSettings Then
			
			// Complete the forms with manual settings
			Server             = ProxyServerSettings.Get("Server");
			User               = ProxyServerSettings.Get("User");
			Password           = ProxyServerSettings.Get("Password");
			Port               = ProxyServerSettings.Get("Port");
			BypassProxyOnLocal = ProxyServerSettings.Get("BypassProxyOnLocal");
			
			ExceptionServerAddressesArray = ProxyServerSettings.Get("BypassProxyOnAddresses");
			If TypeOf(ExceptionServerAddressesArray) = Type("Array") Then
				ExceptionServers.LoadValues(ExceptionServerAddressesArray);
			EndIf;
			
			AdditionalProxy = ProxyServerSettings.Get("AdditionalProxySettings");
			
			If TypeOf(AdditionalProxy) <> Type("Map") Then
				OneProxyForAllProtocols = True;
			Else
				
				// If additional proxy servers are specified in the settings,
				// then read them from the settings
				For Each ProtocolServer In AdditionalProxy Do
					Protocol         = ProtocolServer.Key;
					ProtocolSettings = ProtocolServer.Value;
					ThisObject["Server" + Protocol] = ProtocolSettings.Address;
					ThisObject["Port"   + Protocol] = ProtocolSettings.Port;
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Proxy server use variants:
	// 0 - Bypass proxy server (by default, corresponds to New InternetProxy(False)) 
	// 1 - Use proxy server system settings (corresponds to New InternetProxy (True))
	// 2 - Use your proxy server settings (corresponds to manual setting of proxy server parameters)
	// The latter proxy server parameters can be changed manually
	ProxyServerUseVariant = ?(UseProxy, ?(UseSystemSettings = True, 1, 2), 0);
	If ProxyServerUseVariant = 0 Then
		InitFormItems(ThisObject, EmptyProxyServerSettings());
	ElsIf ProxyServerUseVariant = 1 And Not ProxySettingsAtClient Then
		InitFormItems(ThisObject, ProxyServerSystemSettings());
	EndIf;
	
	// Manage the visibility of additional form elements
	FileMode = CommonUseCached.ApplicationRunMode().File;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ProxySettingsAtClient Then
#If WebClient Then
		ShowMessageBox(, NStr("en = 'Proxy server parameters for web client are entered in the browser settings.'"));
		Cancel = True;
		Return;
#EndIf
		
		If ProxyServerUseVariant = 1 Then
			InitFormItems(ThisObject, ProxyServerSystemSettings());
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.AdditionalProxyServerParameters") Then
		
		If TypeOf(SelectedValue) <> Type("Structure") Then
			Return;
		EndIf;
		
		For Each KeyAndValue In SelectedValue Do
			If KeyAndValue.Key <> "BypassProxyOnAddresses" Then
				ThisObject[KeyAndValue.Key] = KeyAndValue.Value;
			EndIf;
		EndDo;
		
		ExceptionServers = SelectedValue.BypassProxyOnAddresses;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, StandardProcessing)
	
	Notification = New NotifyDescription("SelectAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure ProxyServerUseVariantsOnChange(Item)
	
	UseProxy = (ProxyServerUseVariant > 0);
	UseSystemSettings = (ProxyServerUseVariant = 1);
	
	ProxySettings = Undefined;
	// Alternative proxy server settings:
	// 0 - Bypass proxy server (by default, corresponds to New InternetProxy(False))
	// 1 - Use proxy server system settings (corresponds to New InternetProxy (True))
	// 2 - Use your proxy server settings (corresponds to manual setting of proxy server parameters) 
	// The latter proxy server parameters can be changed manually
	If ProxyServerUseVariant = 0 Then
		ProxySettings = EmptyProxyServerSettings();
	ElsIf ProxyServerUseVariant = 1 Then
		ProxySettings = ?(ProxySettingsAtClient,
							ProxyServerSystemSettings(),
							ProxyServerSystemSettingsAtServer());
	EndIf;
	
	InitFormItems(ThisObject, ProxySettings);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AdditionalProxyServerParameters(Command)
	
	// Configure parameters for additional settings
	FormParameters = New Structure;
	FormParameters.Insert("OneProxyForAllProtocols", OneProxyForAllProtocols);
	
	FormParameters.Insert("Server"     , Server);
	FormParameters.Insert("Port"       , Port);
	FormParameters.Insert("HTTPServer" , HTTPServer);
	FormParameters.Insert("HTTPPort"   , HTTPPort);
	FormParameters.Insert("HTTPSServer", HTTPSServer);
	FormParameters.Insert("HTTPSPort"  , HTTPSPort);
	FormParameters.Insert("FTPServer"  , FTPServer);
	FormParameters.Insert("FTPPort"    , FTPPort);
	
	FormParameters.Insert("BypassProxyOnAddresses", ExceptionServers);
	
	OpenForm("CommonForm.AdditionalProxyServerParameters", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure OKButton(Command)
	
	// Saves proxy server settings and closes the form,
	// passing proxy parameters as returned results.
	SaveProxyServerSettings();
	
EndProcedure

&AtClient
Procedure CancelButton(Command)
	
	Modified = False;
	Close();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClientAtServerNoContext
Procedure InitFormItems(Form, ProxySettings)
	
	If ProxySettings <> Undefined Then
		
		Form.Server             = ProxySettings.Server;
		Form.Port               = ProxySettings.Port;
		Form.HTTPServer         = ProxySettings.HTTPServer;
		Form.HTTPPort           = ProxySettings.HTTPPort;
		Form.HTTPSServer        = ProxySettings.HTTPSServer;
		Form.HTTPSPort          = ProxySettings.HTTPSPort;
		Form.FTPServer          = ProxySettings.FTPServer;
		Form.FTPPort            = ProxySettings.FTPPort;
		Form.User               = ProxySettings.User;
		Form.Password           = ProxySettings.Password;
		Form.BypassProxyOnLocal = ProxySettings.BypassProxyOnLocal;
		Form.ExceptionServers.LoadValues(ProxySettings.BypassProxyOnAddresses);
		
		// If the settings for all protocols correspond to the default proxy
		// settings, then a single proxy is used for all protocols
		Form.OneProxyForAllProtocols = (Form.Server = Form.HTTPServer
			And Form.HTTPServer = Form.HTTPSServer
			And Form.HTTPSServer = Form.FTPServer
			And Form.Port = Form.HTTPPort
			And Form.HTTPPort = Form.HTTPSPort
			And Form.HTTPSPort = Form.FTPPort);
		
	EndIf;
	
	// Change the accessibility of the proxy parameter editing group
	// according to the variant of proxy server use
	Form.Items.ProxyParameters.Enabled = (Form.ProxyServerUseVariant = 2);
	
EndProcedure

// Saves proxy server settings interactively as a result of user actions
// and reflects messages for users, then closes the form and returns
// proxy server settings.
//
&AtClient
Procedure SaveProxyServerSettings(CloseForm = True)
	
	ProxyServerSettings = New Map;
	
	ProxyServerSettings.Insert("UseProxy"              , UseProxy);
	ProxyServerSettings.Insert("User"                  , User);
	ProxyServerSettings.Insert("Password"              , Password);
	ProxyServerSettings.Insert("Server"                , NormalizedProxyServerAddress(Server));
	ProxyServerSettings.Insert("Port"                  , Port);
	ProxyServerSettings.Insert("BypassProxyOnLocal"    , BypassProxyOnLocal);
	ProxyServerSettings.Insert("BypassProxyOnAddresses", ExceptionServers.UnloadValues());
	ProxyServerSettings.Insert("UseSystemSettings"     , UseSystemSettings);
	
	// Configure additional proxy server addresses
	
	If Not OneProxyForAllProtocols Then
		
		AdditionalSettings = New Map;
		If Not IsBlankString(HTTPServer) Then
			AdditionalSettings.Insert("http",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPServer), HTTPPort));
		EndIf;
		
		If Not IsBlankString(HTTPSServer) Then
			AdditionalSettings.Insert("https",
				New Structure("Address,Port", NormalizedProxyServerAddress(HTTPSServer), HTTPSPort));
		EndIf;
		
		If Not IsBlankString(FTPServer) Then
			AdditionalSettings.Insert("ftp",
				New Structure("Address,Port", NormalizedProxyServerAddress(FTPServer), FTPPort));
		EndIf;
		
		If AdditionalSettings.Count() > 0 Then
			ProxyServerSettings.Insert("AdditionalProxySettings", AdditionalSettings);
		EndIf;
		
	EndIf;
	
	WriteProxyServerSettingsToInfobase(ProxySettingsAtClient, ProxyServerSettings);
	
	Modified = False;
	
	If CloseForm Then
		
		Close(ProxyServerSettings);
		
	EndIf;
	
EndProcedure

// Saves proxy server settings.
&AtServerNoContext
Procedure WriteProxyServerSettingsToInfobase(ProxySettingsAtClient, ProxyServerSettings)
	
	If ProxySettingsAtClient
		Or CommonUseCached.ApplicationRunMode().File Then
		
		CommonUse.CommonSettingsStorageSave("ProxyServerSettings", , ProxyServerSettings);
		RefreshReusableValues();
	Else
		GetFilesFromInternetInternal.SaveServerProxySettings(ProxyServerSettings);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function EmptyProxyServerSettings()
	
	Result = New Structure;
	Result.Insert("Server"      , "");
	Result.Insert("Port"        , 0);
	Result.Insert("HTTPServer"  , "");
	Result.Insert("HTTPPort"    , 0);
	Result.Insert("HTTPSServer" , "");
	Result.Insert("HTTPSPort"   , 0);
	Result.Insert("FTPServer"   , "");
	Result.Insert("FTPPort"     , 0);
	Result.Insert("User"        , "");
	Result.Insert("Password"    , "");
	
	Result.Insert("BypassProxyOnLocal", False);
	Result.Insert("BypassProxyOnAddresses", New Array);
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function ProxyServerSystemSettings()
	
	Proxy = New InternetProxy(True);
	
	Result = New Structure;
	Result.Insert("Server", Proxy.Server());
	Result.Insert("Port"  , Proxy.Port());
	
	Result.Insert("HTTPServer" , Proxy.Server("http"));
	Result.Insert("HTTPPort"   , Proxy.Port("http"));
	Result.Insert("HTTPSServer", Proxy.Server("https"));
	Result.Insert("HTTPSPort"  , Proxy.Port("https"));
	Result.Insert("FTPServer"  , Proxy.Server("ftp"));
	Result.Insert("FTPPort"    , Proxy.Port("ftp"));
	
	Result.Insert("User"    , Proxy.User);
	Result.Insert("Password", Proxy.Password);
	
	Result.Insert("BypassProxyOnLocal",
		Proxy.BypassProxyOnLocal);
	
	BypassProxyOnAddresses = New Array;
	For Each ServerAddress In Proxy.BypassProxyOnAddresses Do
		BypassProxyOnAddresses.Add(ServerAddress);
	EndDo;
	Result.Insert("BypassProxyOnAddresses", BypassProxyOnAddresses);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function ProxyServerSystemSettingsAtServer()
	
	Return ProxyServerSystemSettings();
	
EndFunction

// Returns standardized proxy server address - without spaces.
// If there are spaces between meaningful characters, then ignore
// everything after the first space.
//
// Parameters:
// ProxyServerAddress (String) - source proxy server address.
//
// Return value: String - standardized proxy server address.
//
&AtClientAtServerNoContext
Function NormalizedProxyServerAddress(Val ProxyServerAddress)
	
	ProxyServerAddress = TrimAll(ProxyServerAddress);
	SpacePosition = Find(ProxyServerAddress, " ");
	If SpacePosition > 0 Then
		// If there are spaces in the server address then skip everything after 
		// the first space

		ProxyServerAddress = Left(ProxyServerAddress, SpacePosition - 1);
	EndIf;
	
	Return ProxyServerAddress;
	
EndFunction

&AtClient
Procedure SelectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	SaveProxyServerSettings();
	
EndProcedure

#EndRegion
