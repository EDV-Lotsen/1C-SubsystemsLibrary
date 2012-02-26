

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	StringAttention = NStr("en = 'Attention!'");
	
	ReminderText = 
	NStr("en = 'The browser will now offer you to open or save the file. Select the ""Save"" option and specify the folder for saving the file. 
          |
          |Then you can go to this folder and edit the saved file.'");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancellation)
	
	SysInfo = New SystemInfo;
	
	If Find(SysInfo.UserAgentInformation, "Firefox") <> 0 Then
		ReminderText = ReminderText + Chars.LF + Chars.LF
		       + NStr("en = '(By default Mozilla Firefox saves files in the ""My Documents"" folder)'");
	EndIf;
	
EndProcedure
