
#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Group)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DeleteRecords(Command)
	
	QuestionText = NStr("en = 'Deleting object versions might leave you without any tools for analyzing the entire object change sequence. Do you want to continue?'");
		
	NotifyDescription = New NotifyDescription("DeleteRecordsCompletion", ThisObject, Items.List.SelectedRows);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Warning'"));
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure DeleteRecordsCompletion(QuestionResult, RecordList) Export
	If QuestionResult = DialogReturnCode.Yes Then
		DeleteVersionsFromRegister(RecordList);
	EndIf;
EndProcedure

&AtServer
Procedure DeleteVersionsFromRegister(Val RecordList)
	
	For Each RecordKey In RecordList Do
		RecordSet = InformationRegisters.ObjectVersions.CreateRecordSet();
		
		RecordSet.Filter.Object.Value = RecordKey.Object;
		RecordSet.Filter.Object.ComparisonType = ComparisonType.Equal;
		RecordSet.Filter.Object.Use = True;
		
		RecordSet.Filter.VersionNumber.Value = RecordKey.VersionNumber;
		RecordSet.Filter.VersionNumber.ComparisonType = ComparisonType.Equal;
		RecordSet.Filter.VersionNumber.Use = True;
		
		RecordSet.Write(True);
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
