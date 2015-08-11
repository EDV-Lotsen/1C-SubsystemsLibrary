&AtClient
Procedure LoadRefreshClientParameters(Parameters) Export
	
	Update();
	RestartAtClient();
	AttachIdleHandler("RestartAtClient", 1, True);
	
EndProcedure

&AtServer 
Procedure Update()
	
	If CommonUseCached.DataSeparationEnabled() Then
		If CommonUse.UseSessionSeparator() Then
			InfoBaseUpdateServiceMode.UpdateCurrentDataArea();
		Else
			InfoBaseUpdate.ExecuteInfoBaseUpdate(False);
			InfoBaseUpdateServiceMode.UpdateDataAreas();
		EndIf;
	Else
		InfoBaseUpdate.ExecuteInfoBaseUpdate(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure RestartAtClient()
	
	If Find(LaunchParameter, "InitSeparatedInfobase") <> 0 Then
		Terminate(True, "/CInitSeparatedInfobaseExecute");
	Else
		Terminate(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure Restart(Command)
	
	RestartAtClient();
	
EndProcedure
