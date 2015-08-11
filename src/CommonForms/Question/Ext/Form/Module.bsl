////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the SelfTest parameter is passed.
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	If Not IsBlankString(Parameters.Title) Then
		Title = Parameters.Title;
	EndIf;
	
	Timeout = Parameters.Timeout;
	Items.MessageText.Title = Parameters.MessageText;
	AddCommandsAndButtonsOnForm(Parameters.Buttons);
	SetDefaultButton(Parameters.DefaultButton);
	
	If Not IsBlankString(Parameters.TimeoutButton) Then
		For Each Item In ButtonAndReturnValueMap Do
			If Item.Value = Parameters.TimeoutButton Then
				TimeoutCommand = Item.Key;
				Command = Commands.Find(TimeoutCommand);
				TimeoutCommandTitle = Command.Title;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Items.DontAskAgain.Visible = AccessRight("SaveUserData", Metadata);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Timeout > 0 Then
		If TimeoutCommand <> "" Then
			Items[TimeoutCommand].Title = GetTimeoutButtonTitle(TimeoutCommandTitle, Timeout);
		EndIf;
		AttachIdleHandler("Timer", 1, True);
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// FORM HEADER ITEM EVENT HANDLERS

&AtClient
Procedure Attachable_CommandHandler(Command)
	
	Close(New Structure("DontAskAgain, Value", DontAskAgain,
		  DialogReturnCodeByValue(ButtonAndReturnValueMap.Get(Command.Name))));
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

// Adds commands and corresponding to them buttons on the form.
//
// Parameters:
// Buttons - String / ValueList - button set
// if value type is String it must be an ID string in the following format: "QuestionDialogMode.<One of QuestionDialogMode values>",
// for example "QuestionDialogMode.YesNo"
// if value type is ValueList then for each value list items
// Value - Value that the form returns on a button click
// Presentation - Button title
// 
&AtServer
Procedure AddCommandsAndButtonsOnForm(Buttons)
	
	If TypeOf(Buttons) = Type("String") Then
		ButtonsValueList = StandardSet(Buttons);
	Else
		ButtonsValueList = Buttons;
	EndIf;
	
	ButtonToValueMapping = New Map;
	
	Index = 0;
	
	For Each ButtonInfoItem In ButtonsValueList Do
		Index = Index + 1;
		CommandName = "Command" + String(Index);
		Command = Commands.Add(CommandName);
		Command.Action = "Attachable_CommandHandler";
		Command.Title = ButtonInfoItem.Presentation;
		Command.ModifiesStoredData = False;
		
		Button= Items.Add(CommandName, Type("FormButton"), Items.FormCommandBar);
		Button.OnlyInAllActions = False;
		Button.CommandName = CommandName;
		
		ButtonToValueMapping.Insert(CommandName, ButtonInfoItem.Value);
	EndDo;
	
	ButtonAndReturnValueMap = New FixedMap(ButtonToValueMapping);
	
EndProcedure

&AtClient
Procedure Timer()
	
	If Timeout = 0 Then
		Close(New Structure("DontAskAgain, Value", False, DialogReturnCode.Timeout) );
	Else
		Timeout = Timeout - 1;
		If TimeoutCommand <> "" Then
			Items[TimeoutCommand].Title = GetTimeoutButtonTitle(TimeoutCommandTitle, Timeout);
		EndIf;
		AttachIdleHandler("Timer", 1, True);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function StandardSet(Buttons)
	
	Result = New ValueList;
	
	If Buttons = "QuestionDialogMode.YesNo" Then
		Result.Add("DialogReturnCode.Yes", NStr("en = 'Yes'"));
		Result.Add("DialogReturnCode.No", NStr("en = 'No'"));
	ElsIf Buttons = "QuestionDialogMode.YesNoCancel" Then
		Result.Add("DialogReturnCode.Yes", NStr("en = 'Yes'"));
		Result.Add("DialogReturnCode.No", NStr("en = 'No'"));
		Result.Add("DialogReturnCode.Cancel", NStr("en = 'Cancel'"));
	ElsIf Buttons = "QuestionDialogMode.OK" Then
		Result.Add("DialogReturnCode.OK", NStr("en = 'OK'"));
	ElsIf Buttons = "QuestionDialogMode.OKCancel" Then
		Result.Add("DialogReturnCode.OK", NStr("en = 'OK'"));
		Result.Add("DialogReturnCode.Cancel", NStr("en = 'Cancel'"));
	ElsIf Buttons = "QuestionDialogMode.RetryCancel" Then
		Result.Add("DialogReturnCode.Retry", NStr("en = 'Retry'"));
		Result.Add("DialogReturnCode.Cancel", NStr("en = 'Cancel'"));
	ElsIf Buttons = "QuestionDialogMode.AbortRetryIgnore" Then
		Result.Add("DialogReturnCode.Abort", NStr("en = 'Abort'"));
		Result.Add("DialogReturnCode.Retry", NStr("en = 'Retry'"));
		Result.Add("DialogReturnCode.Ignore", NStr("en = 'Ignore'"));
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetDefaultButton(DefaultButton)
	
	For Each Item In ButtonAndReturnValueMap Do
		If Item.Value = DefaultButton Then
			Items[Item.Key].DefaultButton = True;
			Break;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function DialogReturnCodeByValue(Value)
	
	If TypeOf(Value) <> Type("String") Then
		Return Value;
	EndIf;
	
	If Value = "DialogReturnCode.Yes" Then
		Result = DialogReturnCode.Yes;
	ElsIf Value = "DialogReturnCode.No" Then
		Result = DialogReturnCode.No;
	ElsIf Value = "DialogReturnCode.OK" Then
		Result = DialogReturnCode.OK;
	ElsIf Value = "DialogReturnCode.Cancel" Then
		Result = DialogReturnCode.Cancel;
	ElsIf Value = "DialogReturnCode.Retry" Then
		Result = DialogReturnCode.Retry;
	ElsIf Value = "DialogReturnCode.Abort" Then
		Result = DialogReturnCode.Abort;
	ElsIf Value = "DialogReturnCode.Ignore" Then
		Result = DialogReturnCode.Ignore;
	Else
		Result = Value;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Function GetTimeoutButtonTitle(Title, SecondsCount)
	
	Pattern = NStr("en = '%1 (%2 sec. left)'");
	Return StringFunctionsClientServer.SubstituteParametersInString(Pattern, Title, SecondsCount);
	
EndFunction