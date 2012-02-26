

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Owner = Undefined;
	
	If Parameters.Filter.Property("_Owner", Owner) And ValueIsFilled(Owner) Then
		Parameters.Filter.Delete("_Owner");
		Parameters.Filter.Insert("Owner", Owner);
	EndIf;
	
	If Parameters.Filter.Property("Owner", Owner) And ValueIsFilled(Owner) Then
		Items.Description.Title = Owner.Description;
	EndIf;
	
	TitleString = StrGetLine(Owner.SubjectDeclension, 2);
	
	If IsBlankString(TitleString) Then
		Title = NStr("en = 'Select Value'");
	Else
		Title = TitleString;
	EndIf;
	
EndProcedure

&AtClient
Procedure ListSelection(Item, RowSelected, Field, StandardProcessing)
	
	CheckChoicePossibility(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ValueChoiceList(Item, Value, StandardProcessing)
	
	CheckChoicePossibility(Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CheckChoicePossibility(Item, StandardProcessing)
	
	If Item.CurrentData <> Undefined  And Item.CurrentData.IsFolder Then
		StandardProcessing = False;
		DoMessageBox(NStr("en = 'Selection of groups values is not supported'"));
	EndIf;
	
EndProcedure

