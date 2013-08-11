////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure EnableDisableScheduledJob(Command)
	
	SelectedRows = Items.List.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentData = Items.List.CurrentData;
	
	EnableDisableScheduledJobAtServer(SelectedRows, Not CurrentData.UseScheduledJob);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

&AtServer
Procedure EnableDisableScheduledJobAtServer(SelectedRows, UseScheduledJob)
	
	For Each RowData In SelectedRows Do
		
		If RowData.DeletionMark Then
			Continue;
		EndIf;
		
		SettingsObject = RowData.Ref.GetObject();
		SettingsObject.UseScheduledJob = UseScheduledJob;
		SettingsObject.Write();
		
	EndDo;
	
	// Updating list data
	Items.List.Refresh();
	
EndProcedure



