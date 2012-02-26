
&AtClient
Procedure OK(Command)
	StructuresArray = New Array;
	
	SystemInfo = New SystemInfo();
	ClientID   = SystemInfo.ClientID;
	
	Item = New Structure;
	Item.Insert("Object",  "ScanSettings/ShowScannerDialog");
	Item.Insert("Options", ClientID);
	Item.Insert("Value",   ShowScannerDialog);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanSettings/DeviceName");
	Item.Insert("Options", ClientID);
	Item.Insert("Value", DeviceName);
	StructuresArray.Add(Item);
	
	Item = New Structure;
	Item.Insert("Object", "ScanSettings/FormatOfScannedImage");
	Item.Insert("Options", ClientID);
	Item.Insert("Value", FormatOfScannedImage);
	StructuresArray.Add(Item);
	
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
	Close();
	
	RefreshReusableValues();
EndProcedure

&AtClient
Procedure OpenScannedFileNumbers(Command)
	OpenForm("InformationRegister.ScannedFileNumbers.ListForm");
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	RefreshStatus1();
EndProcedure

&AtClient
Procedure RefreshStatus1()
	
	Items.DeviceName.Enabled 			= False;
	Items.FormatOfScannedImage.Enabled 	= False;
	Items.Resolution.Enabled 			= False;
	Items.Chromaticity.Enabled 			= False;
	Items.Rotation.Enabled 				= False;
	Items.PaperSize.Enabled 			= False;
	Items.SetStandardSettings.Enabled 	= False;
	
	If WorkWithScannerClient.InitializeComponent() Then
		
		Items.SetScanningComponent.Visible = False;
		ScanComponentVersion = WorkWithScannerClient.ScanComponentVersion();
		
		If WorkWithScannerClient.CommandScanAvailable() Then
			
			Items.DeviceName.Enabled = True;
			
			Items.DeviceName.ChoiceList.Clear();
			ArrayOfDevices = WorkWithScannerClient.GetDevices();
			For Each String In ArrayOfDevices Do
				Items.DeviceName.ChoiceList.Add(String);
			EndDo;
			
			If Not IsBlankString(DeviceName) Then
				
				Items.FormatOfScannedImage.Enabled 	= True;
				Items.Resolution.Enabled 		 	= True;
				Items.Chromaticity.Enabled 			= True;
				Items.SetStandardSettings.Enabled 	= True;
				
				If Resolution.IsEmpty() OR Chromaticity.IsEmpty() Then
					ResolutionNumber 	= WorkWithScannerClient.GetSetting(DeviceName, "XRESOLUTION");
					ChromaticityNumber  = WorkWithScannerClient.GetSetting(DeviceName, "PIXELTYPE");
					RotationNumber  	= WorkWithScannerClient.GetSetting(DeviceName, "ROTATION");
					PaperSizeNumber  	= WorkWithScannerClient.GetSetting(DeviceName, "SUPPORTEDSIZES");
					
					Items.Rotation.Enabled = (RotationNumber <> -1);
					Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
					
					FileOperations.ConvertScannerParametersToEnums(ResolutionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber, 
						Resolution, Chromaticity, Rotation, PaperSize);
					WorkWithScannerClient.SaveScannerParametersInPreferences(Resolution, Chromaticity, Rotation, PaperSize);
				Else
					Items.Rotation.Enabled  = Not Rotation.IsEmpty();
					Items.PaperSize.Enabled = Not PaperSize.IsEmpty();
				EndIf;	
				
			EndIf;		
		Else
			Items.DeviceName.Enabled = False;
		EndIf;
		
	Else
		ScanComponentVersion = NStr("en = 'Scanning component is not installed'");
		Items.DeviceName.Enabled = False;
	EndIf;
EndProcedure

&AtClient
Procedure SetScanningComponent(Command)
	WorkWithScannerClient.SetComponent();
	RefreshStatus1();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.ComponentInstalled Then
		Items.SetScanningComponent.Visible = False;
	EndIf;	
	
	ClientID = Parameters.ClientID;
	
	ShowScannerDialog = 
		CommonSettingsStorage.Load("ScanSettings/ShowScannerDialog", ClientID);
	If ShowScannerDialog = Undefined Then
		ShowScannerDialog = True;
		CommonSettingsStorage.Save("ScanSettings/ShowScannerDialog", ClientID, ShowScannerDialog);
	EndIf;
	
	DeviceName = 
		CommonSettingsStorage.Load("ScanSettings/DeviceName", ClientID);
	If DeviceName = Undefined Then
		DeviceName = "";
		CommonSettingsStorage.Save("ScanSettings/DeviceName", ClientID, DeviceName);
	EndIf;
	
	FormatOfScannedImage = 
		CommonSettingsStorage.Load("ScanSettings/FormatOfScannedImage", ClientID);
	If FormatOfScannedImage.IsEmpty() Then
		FormatOfScannedImage = Enums.ScannedImageFormats.PNG;
		CommonSettingsStorage.Save("ScanSettings/FormatOfScannedImage", ClientID, FormatOfScannedImage);
	EndIf;
	
	Resolution 	 = CommonSettingsStorage.Load("ScanSettings/Resolution", ClientID);
	Chromaticity = CommonSettingsStorage.Load("ScanSettings/Chromaticity", ClientID);
	
	Rotation  = CommonSettingsStorage.Load("ScanSettings/Rotation", ClientID);
	PaperSize =  CommonSettingsStorage.Load("ScanSettings/PaperSize", ClientID);
	
EndProcedure

&AtClient
Procedure DeviceNameOnChange(Item)
	ReadScannerSettings();
EndProcedure

&AtClient
Procedure DeviceNameChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If DeviceName = ValueSelected Then // nothing changed - do nothing
		StandardProcessing = False;
	EndIf;	
EndProcedure

&AtClient
Procedure ReadScannerSettings()
	
	Items.FormatOfScannedImage.Enabled = Not IsBlankString(DeviceName);
	Items.Resolution.Enabled = Not IsBlankString(DeviceName);
	Items.Chromaticity.Enabled = Not IsBlankString(DeviceName);
	Items.SetStandardSettings.Enabled = Not IsBlankString(DeviceName);
	
	If Not IsBlankString(DeviceName) Then
	
	TextOfMessage = StringFunctionsClientServer.SubstitureParametersInString(
					 NStr("en = 'Scaner collecting information ""%1""'"), DeviceName);
	Status(TextOfMessage);
	
	ResolutionNumber 	= WorkWithScannerClient.GetSetting(DeviceName, "XRESOLUTION");
	ChromaticityNumber  = WorkWithScannerClient.GetSetting(DeviceName, "PIXELTYPE");
	RotationNumber  	= WorkWithScannerClient.GetSetting(DeviceName, "ROTATION");
	PaperSizeNumber  	= WorkWithScannerClient.GetSetting(DeviceName, "SUPPORTEDSIZES");
	
	Items.Rotation.Enabled  = (RotationNumber <> -1);
	Items.PaperSize.Enabled = (PaperSizeNumber <> -1);
	
	FileOperations.ConvertScannerParametersToEnums(ResolutionNumber, ChromaticityNumber, RotationNumber, PaperSizeNumber,
		Resolution, Chromaticity, Rotation, PaperSize);
		
	Status();
	
	Else
		Items.Rotation.Enabled  = False;
		Items.PaperSize.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetStandardSettings(Command)
	ReadScannerSettings();
EndProcedure
