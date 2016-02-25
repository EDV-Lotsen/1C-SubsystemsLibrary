
&AtClient
Procedure Select(Command)
	If FileToSaveType = 0 Then 
		Result = "xlsx";
	ElsIf FileToSaveType = 1 Then 
		Result = "csv";
	Else
		Result = "mxl";
	EndIf;
	Close(Result);
EndProcedure

&AtClient
Procedure InstallAddonForFacilitatingWorkWithFiles(Command)
	BeginInstallFileSystemExtension(Undefined);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
EndProcedure







