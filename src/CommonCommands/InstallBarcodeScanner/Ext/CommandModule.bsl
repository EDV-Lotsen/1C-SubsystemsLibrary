//////////////////////////////////////////////////////////////////////////////// 
// EVENT HANDLERS
//

// The barcode scanner driver installation command handler
&AtClient
Procedure CommandProcessing(CommandParameter)
	
	SystemInfo = New SystemInfo;
	
	If SystemInfo.PlatformType = PlatformType.Windows_x86 Or SystemInfo.PlatformType = PlatformType.Windows_x86_64 Then
		
		OSType = "Windows";
		
	ElsIf SystemInfo.PlatformType = PlatformType.Linux_x86 Or SystemInfo.PlatformType = PlatformType.Linux_x86_64 Then
		
		OSType = "Linux";
		
	EndIf;

	// Adding external components
	If OSType = "Windows" Then
		BeginInstallAddIn(, "CommonTemplate.BarcodeScannerDriver");
	ElsIf OSType = "Linux" Then
		BeginInstallAddIn(, "CommonTemplate.BarcodeScannerDriverNative");
	EndIf;
	
EndProcedure
