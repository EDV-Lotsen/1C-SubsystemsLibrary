
#Region FormHeaderItemEventHandlers

&AtClient
Procedure DirectionOnChange(Item)
	
	GenerateCondition();
	
EndProcedure

&AtClient
Procedure StateOnChange(Item)
	
	GenerateCondition();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ChoiceResult = New Structure("Direction, State");
	ChoiceResult.Direction = Direction;
	ChoiceResult.State = State;
	
	NotifyChoice(ChoiceResult);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure GenerateCondition()
	
	If Direction > 0 Then
		If Upper(State) = "GOOD" Then
			Limit = 0.93;
		ElsIf Upper(State) = "FAIR" Then
			Limit = 0.84;
		ElsIf Upper(State) = "POOR" Then
			Limit = 0.69;
		EndIf;
		Condition = "apdex > " + Limit;
	ElsIf Direction < 0 Then
		If Upper(State) = "GOOD" Then
			Limit = 0.85;
		ElsIf Upper(State) = "FAIR" Then
			Limit = 0.7;
		ElsIf Upper(State) = "POOR" Then
			Limit = 0.5;
		EndIf;
		Condition = "apdex < " + Limit;
	EndIf;
	
EndProcedure

#EndRegion
