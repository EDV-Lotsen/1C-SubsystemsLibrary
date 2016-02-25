
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	// Fill out the form
	Server      = Parameters.Server;
	Port        = Parameters.Port;
	
	HTTPServer  = Parameters.HTTPServer;
	HTTPPort    = Parameters.HTTPPort;
	
	HTTPSServer = Parameters.HTTPSServer;
	HTTPSPort   = Parameters.HTTPSPort;
	
	FTPServer   = Parameters.FTPServer;
	FTPPort     = Parameters.FTPPort;
	
	OneProxyForAllProtocols = Parameters.OneProxyForAllProtocols;
	
	InitFormItems(ThisObject);
	
	For Each ExceptionListItem In Parameters.BypassProxyOnAddresses Do
		ExceptionStr = ExceptionAddresses.Add();
		ExceptionStr.ServerAddress = ExceptionListItem.Value;
	EndDo;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure OneProxyForAllProtocolsOnChange(Item)
	
	InitFormItems(ThisObject);
	
EndProcedure

&AtClient
Procedure HTTPServerOnChange(Item)
	
	// If the server is not specified, then reset the corresponding port
	If IsBlankString(ThisObject[Item.Name]) Then
		ThisObject[StrReplace(Item.Name, "Server", "Port")] = 0;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKButton(Command)
	
	If Not Modified Then
		// If the form data were not changed, they need not be returned
		NotifyChoice(Undefined);
		Return;
	EndIf;
	
	If Not ValidateExceptionServerAddresses() Then
		Return;
	EndIf;
	
	// If the form is successfully validated, then the additional proxy server settings 
	// are returned to the structure
	ReturnValueStructure = New Structure;
	
	ReturnValueStructure.Insert("OneProxyForAllProtocols", OneProxyForAllProtocols);
	
	ReturnValueStructure.Insert("HTTPServer" , HTTPServer);
	ReturnValueStructure.Insert("HTTPPort"   , HTTPPort);
	ReturnValueStructure.Insert("HTTPSServer", HTTPSServer);
	ReturnValueStructure.Insert("HTTPSPort"  , HTTPSPort);
	ReturnValueStructure.Insert("FTPServer"  , FTPServer);
	ReturnValueStructure.Insert("FTPPort"    , FTPPort);
	
	ExceptionList = New ValueList;
	
	For Each AddressStr In ExceptionAddresses Do
		If Not IsBlankString(AddressStr.ServerAddress) Then
			ExceptionList.Add(AddressStr.ServerAddress);
		EndIf;
	EndDo;
	
	ReturnValueStructure.Insert("BypassProxyOnAddresses", ExceptionList);
	
	NotifyChoice(ReturnValueStructure);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

// Generates form items in accordance with
// the proxy server settings
//
&AtClientAtServerNoContext
Procedure InitFormItems(Form)
	
	Form.Items.GroupProxyServers.Enabled = Not Form.OneProxyForAllProtocols;
	If Form.OneProxyForAllProtocols Then
		
		Form.HTTPServer  = Form.Server;
		Form.HTTPPort    = Form.Port;
		
		Form.HTTPSServer = Form.Server;
		Form.HTTPSPort   = Form.Port;
		
		Form.FTPServer   = Form.Server;
		Form.FTPPort     = Form.Port;
		
	EndIf;
	
EndProcedure

// Validates the correctness of exception server addresses.
// It also informs users on incorrectly filled addresses.
//
// Returns: 
//  Boolean - True, if the addresses are correct,
//						  False otherwise
//
&AtClient
Function ValidateExceptionServerAddresses()
	
	AddressesAreCorrect = True;
	For Each StrAddress In ExceptionAddresses Do
		If Not IsBlankString(StrAddress.ServerAddress) Then
			ProhibitedChars = ProhibitedCharsInString(StrAddress.ServerAddress,
				"0123456789aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwWxXyYzZ_-.:*?");
			
			If Not IsBlankString(ProhibitedChars) Then
				
				MessageText = StrReplace(NStr("en = 'The address contains invalid characters: %1'"),
					"%1",
					ProhibitedChars);
				
				IndexString = StrReplace(String(ExceptionAddresses.IndexOf(StrAddress)), Char(160), "");
				
				CommonUseClientServer.MessageToUser(MessageText,
					,
					"ExceptionAddresses[" + IndexString + "].ServerAddress");
				Message = New UserMessage;
				AddressesAreCorrect = False;
				
			EndIf;
		EndIf;
	EndDo;
	
	Return AddressesAreCorrect;
	
EndFunction

// Finds and returns comma-separated strings of prohibited characters.
//
// Parameters:
//  StringToValidate (String) - a string that is checked for the presence of 
//								 prohibited characters.
//  AllowedChars (String) - allowed character string.
//
// Returns: 
//  String - prohibited character string. Empty string, if
//						  the string under validation contains no prohibited characters.
//
&AtClient
Function ProhibitedCharsInString(StringToValidate, AllowedChars)
	
	ProhibitedCharList = New ValueList;
	
	StringLength = StrLen(StringToValidate);
	For Iterator = 1 To StringLength Do
		CurrentChar = Mid(StringToValidate, Iterator, 1);
		If Find(AllowedChars, CurrentChar) = 0 Then
			If ProhibitedCharList.FindByValue(CurrentChar) = Undefined Then
				ProhibitedCharList.Add(CurrentChar);
			EndIf;
		EndIf;
	EndDo;
	
	ProhibitedCharString = "";
	Comma                = False;
	
	For Each ProhibitedCharItem In ProhibitedCharList Do
		
		ProhibitedCharString = ProhibitedCharString
			+ ?(Comma, ",", "")
			+ """"
			+ ProhibitedCharItem.Value
			+ """";
		Comma = True;
		
	EndDo;
	
	Return ProhibitedCharString;
	
EndFunction

#EndRegion
