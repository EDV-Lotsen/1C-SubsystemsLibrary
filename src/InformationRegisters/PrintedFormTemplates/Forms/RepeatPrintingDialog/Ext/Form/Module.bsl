

&AtClient
Procedure ChangePrintWorkingDirectory(Command)
	
	Result = Undefined;

	
	OpenForm("InformationRegister.PrintedFormTemplates.Form.PrintFilesFolderSettings",,,,,, New NotifyDescription("ChangePrintWorkingDirectoryEnd", ThisObject), FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

&AtClient
Procedure ChangePrintWorkingDirectoryEnd(Result1, AdditionalParameters) Export
	
	Result = Result1;
	
	If TypeOf(Result) = Type("String") Then
		DirrectoryForPrintDataSave = Result;
	EndIf;

EndProcedure

&AtClient
Procedure RetryPrint(Command)
	Close(DirrectoryForPrintDataSave);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	Items.Message.Title = Items.Message.Title + Chars.LF + Parameters.MessageAboutError;
	
EndProcedure
