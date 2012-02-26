
// Installs scanning component
Procedure SetComponent() Export

	If TwainComponent = Undefined Then
		ReturnCode = AttachAddIn("CommonTemplate.TwainComponent", "twain", AddInType.Native);
		
		If ReturnCode Then
			Status(NStr("en = 'Scanning component is already installed!'"));
		Else
			InstallAddIn("CommonTemplate.TwainComponent");
			ReturnCode = AttachAddIn("CommonTemplate.TwainComponent", "twain", AddInType.Native);
			
			If ReturnCode Then
				FileOperations.DeleteNewFileFormSettings();
				RefreshReusableValues();
				Notify("ScanningComponentInstalled");
			EndIf;
		EndIf;

		TwainComponent = New("AddIn.twain.AddInNativeExtension");	
	Else
		Status(NStr("en = 'Scanning component is already installed!'"));
	EndIf;
	
EndProcedure

// Initialize scanning component
Function InitializeComponent() Export
	If TwainComponent = Undefined Then
		ReturnCode = AttachAddIn("CommonTemplate.TwainComponent", "twain", AddInType.Native);
		
		If Not ReturnCode Then
			Return False;
		EndIf;

		TwainComponent = New("AddIn.twain.AddInNativeExtension");	
	EndIf;
	
	Return True;
EndFunction

// Returns version of the scanning component
Function ScanComponentVersion() Export

	If Not InitializeComponent() Then
		Return NStr("en = 'Scanning component is not installed'");
	EndIf;
	
	Return TwainComponent.Version();
EndFunction // ScanComponentVersion()

// Return array of lines - of TWAIN device
Function GetDevices() Export
	Array = New Array;
	
	If Not InitializeComponent() Then
		Return Array;
	EndIf;
	
	DevicesString = TwainComponent.GetDevices();
	
	For IndexOf = 1 To StrLineCount(DevicesString) Do
		String = StrGetLine(DevicesString, IndexOf); 		
		Array.Add(String);
	EndDo;	
	
	Return Array;
EndFunction // GetDevices()

// Call scan dialog and dispay picture preview dialog
Procedure ScanAndShowViewDialog(FileOwner, UUID, ThisForm,
	DoNotOpenCardAfterCreateFromFile = Undefined) Export
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	OpenParameters = New Structure("FileOwner, DoNotOpenCardAfterCreateFromFile, ClientID", 
							FileOwner, DoNotOpenCardAfterCreateFromFile, ClientID);
	OpenFormModal("Catalog.Files.Form.ScanningResult", OpenParameters);
	
EndProcedure

// Return True, if command Scan is available - scan component is installed and at least one scanner is present
Function CommandScanAvailable() Export

	If Not InitializeComponent() Then
		Return False;
	EndIf;
	
	If TwainComponent.IsDevicePresent() then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction // CommandScanAvailable()


// Gets scanner setting by name
//
// Parameters
//  DeviceName  	- String - Scanner name
//
//  SettingsName  	- String - setting name, for example "XRESOLUTION" or "PIXELTYPE" or "ROTATION" or "SUPPORTEDSIZES"
//
//
// Value returned:
//   Number   		- Scanner setting value
//
Function GetSetting(DeviceName, SettingsName) Export
	
	Try
		Return TwainComponent.GetSetting(DeviceName, SettingsName);
	Except
		Return -1;
	EndTry;
	
EndFunction // GetSetting()

// Saves chromaticity and resolution in settings
Procedure SaveScannerParametersInPreferences(Resolution, Chromaticity, Rotation, PaperSize) Export
	
	StructuresArray = New Array;
	
	SystemInfo 	= New SystemInfo();
	ClientID 	= SystemInfo.ClientID;
	
	Item = New Structure;
	Item.Insert("Object", "ScanSettings/Resolution");
	Item.Insert("Options", ClientID);
	Item.Insert("Value", Resolution);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanSettings/Chromaticity");
	Item.Insert("Options", ClientID);
	Item.Insert("Value", Chromaticity);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanSettings/Rotation");
	Item.Insert("Options", ClientID);
	Item.Insert("Value", Rotation);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanSettings/PaperSize");
	Item.Insert("Options", ClientID);
	Item.Insert("Value", PaperSize);
	StructuresArray.Add(Item);
	
	CommonUse.CommonSettingsStorageSaveArray(StructuresArray);
	
EndProcedure	
