﻿

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	If Parameters.ChoiceMode Then
		
		Items.List.ChoiceMode = True;
		// Filter of items not marked for deletion
		List.Filter.Items[0].Use = True;
		List.Filter.Items[1].Use = Parameters.Property("ParentChoice");
		
		If Parameters.CloseOnChoice = False Then
			// Selection mode
			Title = NStr("en = 'Selection of users group'");
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
		Else
			Title = NStr("en = 'Select users group'");
		EndIf;
	EndIf;
	
EndProcedure
