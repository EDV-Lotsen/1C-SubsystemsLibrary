

&AtClient
Procedure OnOpen(Cancellation)
	If WorkWithScannerClient.InitializeComponent() Then
		
		ArrayOfDevices = WorkWithScannerClient.GetDevices();
		For Each String In ArrayOfDevices Do
			Items.DeviceName.ChoiceList.Add(String);
		EndDo;
		
	EndIf;
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	StructuresArray = New Array;
	
	SystemInfo = New SystemInfo();
	ClientID = SystemInfo.ClientID;
	
	Item = New Structure;
	Item.Insert("Object", 	"ScanSettings/DeviceName");
	Item.Insert("Options", 	ClientID);
	Item.Insert("Value", 	DeviceName);
	StructuresArray.Add(Item);
	
	CommonUse.CommonSettingsStorageSaveArray(StructuresArray);
	Close(Item);
	
	RefreshReusableValues();
EndProcedure
