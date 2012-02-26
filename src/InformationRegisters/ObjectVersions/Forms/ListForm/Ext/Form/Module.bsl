

&AtClient
Procedure ListBeforeAddRow(Item, Cancellation, Clone, Parent, Folder)
	Cancellation = True;
EndProcedure

&AtClient
Procedure DeleteRecords(Command)
	
	QuestionText = NStr("en = 'Attention! Not coordinated records delete by object versions might lead to incorrect sequence 
                         |of records and furthermore to incorrect report on changes. Do you want to continue?'");
	If DoQueryBox(QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("en = 'Warning'")) = DialogReturnCode.Yes Then
		DeleteVersionsFromRegister(Items.List.SelectedRows);
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteVersionsFromRegister(Val RecordKeysArray)
	
	For Each RecordKey In RecordKeysArray Do
		RecordSet = InformationRegisters.ObjectVersions.CreateRecordSet();
		
		RecordSet.Filter.Object.Value 				= RecordKey.Object;
		RecordSet.Filter.Object.ComparisonType 		= ComparisonType.Equal;
		RecordSet.Filter.Object.Use 				= True;
		
		RecordSet.Filter.VersionNo.Value			= RecordKey.VersionNo;
		RecordSet.Filter.VersionNo.ComparisonType 	= ComparisonType.Equal;
		RecordSet.Filter.VersionNo.Use 				= True;
		
		RecordSet.Write(True);
	EndDo;
	
	Items.List.Refresh();
	
EndProcedure
