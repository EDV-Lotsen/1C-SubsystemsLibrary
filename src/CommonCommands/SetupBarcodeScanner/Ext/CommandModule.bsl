//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 
// 

// The driver attaching parameters filling and saving into the settings storage.
// 
// Parameters: 
//  OSType - String - The operating system type.  (IN)
//  SelectedParameters - Structure - Reference Data For connections. (IN)
//  ScannerDriverAddress - String - The scanner add-in address
// 
// Returns: 
//  No.
&AtServer
Procedure SaveScannerAttachingParameters(OSType, SelectedParameters)

	Parameters = New Structure();
	Parameters.Insert("DataBits", SelectedParameters.DataBits);
	Parameters.Insert("Speed", SelectedParameters.Speed);
	Parameters.Insert("Port", SelectedParameters.Port);
	
	If OSType = "Windows" Then
		
		CommonSettingsStorage.Save("CurrentScannerSettingsWindows",,Parameters);
		
	ElsIf OSType = "Linux" Then
	
		CommonSettingsStorage.Save("CurrentScannerSettingsLinux",,Parameters);
		
	EndIf;

EndProcedure

//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

// Barcode scanner setup command handler
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	// Updating current scanner settings 
	
	// Getting the shop equipment settings form
	Notification  = New  NotifyDescription("CommandProcessingCompletion",  ThisObject);

	OpenForm("Catalog.ShopEquipmentSettings.ChoiceForm",
		New Structure("ChoiceMode", True),,,,,
		Notification, FormWindowOpeningMode.LockWholeInterface);
		
EndProcedure

&AtClient
Procedure  CommandProcessingCompletion(SelectedSettings,  Parameters)  Export
	// If settings are selected - performing an attempt to connect the scanner
	If SelectedSettings <> Undefined Then
		
		SystemInfo = New SystemInfo;
		
		If SystemInfo.PlatformType = PlatformType.Windows_x86 Or SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
			
			OSType = "Windows";
			
		ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86 Or SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
			
			OSType = "Linux";
			
		EndIf;
		
		SaveScannerAttachingParameters(OSType, SelectedSettings);
		// Applying new barcode scanner attaching settings
		HandlingShopEquipment.DisableBarcodeScanner();
		HandlingShopEquipment.AttachBarcodeScanner();
	EndIf;
	
EndProcedure
