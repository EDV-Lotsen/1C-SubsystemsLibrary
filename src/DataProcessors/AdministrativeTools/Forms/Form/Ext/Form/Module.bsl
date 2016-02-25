
&AtClient
Procedure ClearHistoryExecute()
	UserWorkHistory.ClearAll();
	ShowUserNotification(NStr("en = 'History cleared.'"));
EndProcedure


