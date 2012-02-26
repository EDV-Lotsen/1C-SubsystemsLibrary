

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.Property("FileOwner") Then
		FileOwner = Parameters.FileOwner;
	EndIf;
	
	ClientID = Parameters.ClientID;
	
	If Parameters.Property("DoNotOpenCardAfterCreateFromFile") Then
		DoNotOpenCardAfterCreateFromFile = Parameters.DoNotOpenCardAfterCreateFromFile;
	EndIf;
	
	Number = FileOperations.GetNewScanNumber(FileOwner);
	FileName = Format(Number, "ND1=9; NLZ=; NG=0");

	FormatOfScannedImage = 
		CommonSettingsStorage.Load("ScanSettings/FormatOfScannedImage", ClientID);
	If FormatOfScannedImage = Undefined Then
		FormatOfScannedImage = Enums.ScannedImageFormats.PNG;
		CommonSettingsStorage.Save("ScanSettings/FormatOfScannedImage", ClientID, FormatOfScannedImage);
	EndIf;
	PictureFormat = String(FormatOfScannedImage);
	
	ResolutionEnum = CommonSettingsStorage.Load("ScanSettings/Resolution", ClientID);
	ChromaticityEnum =  CommonSettingsStorage.Load("ScanSettings/Chromaticity", ClientID);
	
	RotationEnum = CommonSettingsStorage.Load("ScanSettings/Rotation", ClientID);
	PaperSizeEnum =  CommonSettingsStorage.Load("ScanSettings/PaperSize", ClientID);
	
	ShowScannerDialogLoad = 
		CommonSettingsStorage.Load("ScanSettings/ShowScannerDialog", ClientID);
	If ShowScannerDialogLoad = Undefined Then
		ShowScannerDialogLoad = True;
		CommonSettingsStorage.Save("ScanSettings/ShowScannerDialog", ClientID, ShowScannerDialogLoad);
	EndIf;
	ShowScannerDialog = ShowScannerDialogLoad;
	
	DeviceName = 
		CommonSettingsStorage.Load("ScanSettings/DeviceName", ClientID);
	If DeviceName = Undefined Then
		DeviceName = "";
		CommonSettingsStorage.Save("ScanSettings/DeviceName", ClientID, DeviceName);
	EndIf;
	ScanningDeviceName = DeviceName;

	Resolution = -1;
	If ResolutionEnum = Enums.ScannedImageResolutions.dpi200 Then
		Resolution = 200; 
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi300 Then
		Resolution = 300;
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi600 Then
		Resolution = 600;
	ElsIf ResolutionEnum = Enums.ScannedImageResolutions.dpi1200 Then
		Resolution = 1200;
	EndIf;
	
	Chromaticity = -1;
	If ChromaticityEnum = Enums.ImageChromaticities.Monochrome Then
		Chromaticity = 0;
	ElsIf ChromaticityEnum = Enums.ImageChromaticities.GrayGradations Then
		Chromaticity = 1;
	ElsIf ChromaticityEnum = Enums.ImageChromaticities.Coloured Then
		Chromaticity = 2;
	EndIf;
	
	Rotation = 0;
	If RotationEnum = Enums.ImageRotation.NoRotation Then
		Rotation = 0;
	ElsIf RotationEnum = Enums.ImageRotation.ToTheRightAt90 Then
		Rotation = 90;
	ElsIf RotationEnum = Enums.ImageRotation.ToTheRightAt180 Then
		Rotation = 180;
	ElsIf RotationEnum = Enums.ImageRotation.ToTheLeftAt90 Then
		Rotation = 270;
	EndIf;
	
	PaperSize = 0;
	If PaperSizeEnum = Enums.PaperSizes.NotDefined Then
		PaperSize = 0;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A3 Then
		PaperSize = 11;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A4 Then
		PaperSize = 1;
	ElsIf PaperSizeEnum = Enums.PaperSizes.A5 Then
		PaperSize = 5;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B4 Then
		PaperSize = 6;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B5 Then
		PaperSize = 2;
	ElsIf PaperSizeEnum = Enums.PaperSizes.B6 Then
		PaperSize = 7;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C4 Then
		PaperSize = 14;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C5 Then
		PaperSize = 15;
	ElsIf PaperSizeEnum = Enums.PaperSizes.C6 Then
		PaperSize = 16;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USLetter Then
		PaperSize = 3;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USLegal Then
		PaperSize = 4;
	ElsIf PaperSizeEnum = Enums.PaperSizes.USExecutive Then
		PaperSize = 10;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	If Not WorkWithScannerClient.InitializeComponent() Then
		Cancellation = True;
		Return;
	EndIf;
	
	ShowDialog = ShowScannerDialog;
	SelectedDevice = ScanningDeviceName;
	
	If SelectedDevice = "" Then
		OptionName = OpenFormModal("Catalog.Files.Form.ChoiceOfScanningDevice");
		If TypeOf(OptionName) = Type("Structure") Then
			SelectedDevice = OptionName.Value;
		EndIf;
		
		If SelectedDevice = "" Then 
			Cancellation = True;
			Return;
		EndIf;	
	EndIf;	
	
	If Resolution = -1 OR Chromaticity = -1 OR Rotation = -1 OR PaperSize = -1 Then
		
		Resolution  	= WorkWithScannerClient.GetSetting(SelectedDevice, "XRESOLUTION");
		Chromaticity   	= WorkWithScannerClient.GetSetting(SelectedDevice, "PIXELTYPE");
		Rotation  		= WorkWithScannerClient.GetSetting(SelectedDevice, "ROTATION");
		PaperSize 		= WorkWithScannerClient.GetSetting(SelectedDevice, "SUPPORTEDSIZES");
		
		SystemInfo = New SystemInfo();
		ClientID = SystemInfo.ClientID;
		
		FileOperations.ConvertAndSaveScannerParameters(Resolution, Chromaticity, 
			Rotation, PaperSize, ClientID);
	EndIf;	
	
	PictureFileName = "";
	Items.Accept.Enabled = False;
	
	TwainComponent.StartScanning(ShowDialog, SelectedDevice, PictureFormat, Resolution, Chromaticity, Rotation, PaperSize);
	
EndProcedure
                        
&AtClient
Procedure OnClose()
	If PictureAddress <> "" Then
		DeleteFromTempStorage(PictureAddress);
	EndIf;	
EndProcedure

&AtClient
Procedure Cancel(Command)
	DeleteFiles(PathToFile);
	Close();
EndProcedure

&AtClient
Procedure Rescan(Command)
	DeleteFiles(PathToFile);
	If PictureAddress <> "" Then
		DeleteFromTempStorage(PictureAddress);
	EndIf;	
	PictureAddress = "";
	
	ShowDialog = ShowScannerDialog;
	SelectedDevice = ScanningDeviceName;
	
	TwainComponent.StartScanning(ShowDialog, SelectedDevice, PictureFormat, Resolution, Chromaticity, Rotation, PaperSize);
EndProcedure

&AtClient
Procedure Accept(Command)
	Close();
	FileOperationsClient.CreateDocumentBasedOnFile(PathToFile, FileOwner, ThisForm, DoNotOpenCardAfterCreateFromFile, FileName);
	DeleteFiles(PathToFile);
EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	If Source = "TWAIN" And Event = "ImageAcquired" Then
		
		PictureFileName = Data;
		Items.Accept.Enabled = True;
		
		PathToFile = PictureFileName;
		
		BinaryData 		= New BinaryData(PathToFile);
		PictureAddress 	= PutToTempStorage(BinaryData, Uuid);
		
	EndIf;	
EndProcedure
