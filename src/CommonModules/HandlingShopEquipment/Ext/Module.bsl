//////////////////////////////////////////////////////////////////////////////// 
// PROCEDURES AND FUNCTIONS 
//
// This module contains procedures and functions, designed to work with the shop equipment

// Attaches a barcode scanner.

//
// Returns:
//  Boolean - True if the connection is successful, False otherwise.
Function AttachBarcodeScanner() Export
	
	BarcodeScannerDriver = Undefined;
	
	OSType = OSType();
	
	ScannerParameters =  HandlingCommonSettingsStorage.LoadScannerAttachingParameters(OSType);
	If ScannerParameters = Undefined Then
		Return False;
	EndIf;

	BarcodeComponentTemplateName = "";
	BarcodeComponentAddInName = "";
	BarcodeComponentAddInObjectName = "";
		
	If OSType = "Windows" Then
		
		BarcodeComponentTemplateName = "CommonTemplate.BarcodeScannerDriver";
		BarcodeComponentAddInObjectName = "AddIn.Scanner.Scanner";
		BarcodeComponentAddInName = "Scanner";
		
	ElsIf OSType = "Linux" Then
		
		BarcodeComponentTemplateName = "CommonTemplate.BarcodeScannerDriverNative";
		BarcodeComponentAddInObjectName = "AddIn.InputDevice.InputDevice";
		BarcodeComponentAddInName = "InputDevice";
		
	Else
		
		ShowMessageBox( ,NStr("en = 'The OS type is not supported'"));
		Return False;
		
	EndIf;
	
	If BarcodeScannerDriver = Undefined Then
		
		// Import external components
		If Not AttachAddIn(BarcodeComponentTemplateName, BarcodeComponentAddInName) Then
			Return False;
		EndIf;
		
		BarcodeScannerDriver = New(BarcodeComponentAddInObjectName);
		
	EndIf;
	
	StopChar = 13;
	If OSType = "Windows" Then
		
		BarcodeScannerDriverSource = "Scanner";
		
		BarcodeScannerDriver.Open(BarcodeScannerDriverSource);
	 	BarcodeScannerDriver.DataBits = ScannerParameters.DataBits;
		BarcodeScannerDriver.Port = ScannerParameters.Port;
		BarcodeScannerDriver.Speed = ScannerParameters.Speed;
		BarcodeScannerDriver.StopChar = StopChar;
		BarcodeScannerDriver.SuffixString = Char(StopChar);
		BarcodeScannerDriver.EventName = "BarcodeScanner";
		
		Try
			// Connecting the scanner
			BarcodeScannerDriver.Claim(1);
		Except
			ShowMessageBox( ,NStr("en = 'Error attempting to claim the device'"));
			Return False;
		EndTry;
			
		BarcodeScannerDriver.DeviceEnabled = 1;
		BarcodeScannerDriver.DataEventEnabled = 1;
		BarcodeScannerDriver.ClearInput();
		BarcodeScannerDriver.ClearOutput();
		
	ElsIf OSType = "Linux" Then
		
		BarcodeScannerDriverSource = Undefined;
		
		BarcodeScannerDriver.SetParameter("EquipmentType", "BarcodeScanner");
		BarcodeScannerDriver.SetParameter("Port", Int(ScannerParameters.Port));
		BarcodeScannerDriver.SetParameter("DataBits", Int(ScannerParameters.DataBits));
		BarcodeScannerDriver.SetParameter("StopBit", 0);
		BarcodeScannerDriver.SetParameter("Speed", ScannerParameters.Speed);
		BarcodeScannerDriver.SetParameter("Prefix", -1);
		BarcodeScannerDriver.SetParameter("Suffix", StopChar);
		BarcodeScannerDriver.SetParameter("Timeout", 75);
		BarcodeScannerDriver.SetParameter("EventName", "BarcodeScanner");
		
		// Connecting the scanner
		If Not BarcodeScannerDriver.Open(BarcodeScannerDriverSource) Then
			ShowMessageBox( ,NStr("en = 'Error attempting to claim the device'"));
			Return False;
		EndIf;
		
	EndIf;
		
	Return True;

EndFunction

// Detaches a barcode scanner.
//
Procedure DisableBarcodeScanner() Export

	BarcodeScannerDriver = Undefined;
	BarcodeScannerDriverSource = Undefined;
	
	If BarcodeScannerDriver <> Undefined Then

		OSType = OSType();
		If OSType = "Windows" Then
			BarcodeScannerDriver.Close();
		Else
			BarcodeScannerDriver.Close(BarcodeScannerDriverSource);
		EndIf;

	EndIf

EndProcedure

Function OSType()

	SystemInfo = New SystemInfo;
	
	OSType = "";
	
	If SystemInfo.PlatformType = PlatformType.Windows_x86 
	   Or SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then

		OSType = "Windows";
		
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86 
		  Or SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		
		OSType = "Linux";
		
	EndIf;
	
	Return OSType;
	
EndFunction	