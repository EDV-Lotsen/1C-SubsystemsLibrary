////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.ChoiceMode Then
		
		Items.List.ChoiceMode = True;
		// Selecting items that are not marked for deletion
		List.Filter.Items[0].Use = True;
		List.Filter.Items[1].Use = Parameters.Property("ChooseParent");
		
		If Parameters.CloseOnChoice = False Then
			// Multiple choice mode
			Title = NStr("en = 'Choose external user groups'");
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
		Else
			Title = NStr("en = 'Choose external user group'");
		EndIf;
	EndIf;
	
EndProcedure
