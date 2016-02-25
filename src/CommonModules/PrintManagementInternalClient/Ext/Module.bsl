////////////////////////////////////////////////////////////////////////////////
// Print subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Continues the execution of PrintManagementClient.RunAttachablePrintCommand procedure.
Procedure RunAttachablePrintCommandConfirmWriting(QuestionResult, AdditionalParameters) Export
	
	CommandDescription = AdditionalParameters.CommandDescription;
	Form = AdditionalParameters.Form;
	Source = AdditionalParameters.Source;
	
	If QuestionResult = DialogReturnCode.OK Then
		Form.Write();
		If Source.Ref.IsEmpty() Or Form.Modified Then
			Return; // Writing failed, the reasons are displayed by the platform
		EndIf;
	ElsIf QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	RunAttachablePrintCommandPreparePrintObjects(AdditionalParameters);
	
EndProcedure

// Continues the execution of PrintManagementClient.RunAttachablePrintCommand procedure.
Procedure RunAttachablePrintCommandPreparePrintObjects(AdditionalParameters)
	
	PrintObjects = AdditionalParameters.Source;
	If TypeOf(PrintObjects) <> Type("Array") Then
		PrintObjects = PrintObjects(PrintObjects);
	EndIf;
	
	If PrintObjects.Count() = 0 Then
		Raise NStr("en = 'The command cannot be executed for the specified object.'")
	EndIf;
	
	If AdditionalParameters.CommandDescription.PrintObjectTypes.Count() <> 0 Then // Type check required
		HasObjectsToPrint = False;
		For Each PrintObject In PrintObjects Do
			If AdditionalParameters.CommandDescription.PrintObjectTypes.Find(TypeOf(PrintObject)) <> Undefined Then
				HasObjectsToPrint = True;
				Break;
			EndIf;
		EndDo;
		
		If Not HasObjectsToPrint Then
			MessageText = PrintManagementServerCall.PrintCommandPurposeMessage(AdditionalParameters.CommandDescription.PrintObjectTypes);
			ShowMessageBox(, MessageText);
			Return;
		EndIf;
	EndIf;
	
	If AdditionalParameters.CommandDescription.CheckPostingBeforePrint Then
		NotifyDescription = New NotifyDescription("RunAttachablePrintCommandAttachFileSystemExtension", ThisObject, AdditionalParameters);
		PrintManagementClient.CheckDocumentsPosted(NotifyDescription, PrintObjects, AdditionalParameters.Form);
		Return;
	EndIf;
	
	RunAttachablePrintCommandAttachFileSystemExtension(PrintObjects, AdditionalParameters);
	
EndProcedure

// Continues the execution of PrintManagementClient.RunAttachablePrintCommand procedure.
Procedure RunAttachablePrintCommandAttachFileSystemExtension(PrintObjects, AdditionalParameters) Export
	
	If PrintObjects.Count() = 0 Then
		Return;
	EndIf;
	
	AdditionalParameters.Insert("PrintObjects", PrintObjects);
	
	If AdditionalParameters.CommandDescription.FileSystemExtensionRequired Then
		NotifyDescription = New NotifyDescription("RunAttachablePrintCommandCompletion", ThisObject, AdditionalParameters);
		ShowFileSystemExtensionInstallationQuestion(NotifyDescription);
		Return;
	EndIf;
	
	RunAttachablePrintCommandCompletion(True, AdditionalParameters);
	
EndProcedure
	
// Continues the execution of PrintManagementClient.RunAttachablePrintCommand procedure.
Procedure RunAttachablePrintCommandCompletion(FileSystemExtensionAttached, AdditionalParameters) Export
	
	If Not FileSystemExtensionAttached Then
		Return;
	EndIf;
	
	CommandDescription = AdditionalParameters.CommandDescription;
	Form = AdditionalParameters.Form;
	PrintObjects = AdditionalParameters.PrintObjects;
	
	CommandDescription = CommonUseClientServer.CopyStructure(CommandDescription);
	CommandDescription.Insert("PrintObjects", PrintObjects);
	
	If CommandDescription.PrintManager = "StandardSubsystems.AdditionalReportsAndDataProcessors" 
		And CommonUseClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
			AdditionalReportsAndDataProcessorsClientModule = CommonUseClient.CommonModule("AdditionalReportsAndDataProcessorsClient");
			AdditionalReportsAndDataProcessorsClientModule.ExecuteAssignedPrintCommand(CommandDescription, Form);
			Return;
	EndIf;
	
	If Not IsBlankString(CommandDescription.Handler) Then
		CommandDescription.Insert("Form", Form);
		HandlerName = CommandDescription.Handler;
		Handler = HandlerName + "(CommandDescription)";
		Result = Eval(Handler);
		Return;
	EndIf;
	
	If CommandDescription.SkipPreview Then
		PrintManagementClient.ExecutePrintToPrinterCommand(CommandDescription.PrintManager, CommandDescription.ID,
			PrintObjects, CommandDescription.AdditionalParameters);
	Else
		PrintManagementClient.ExecutePrintCommand(CommandDescription.PrintManager, CommandDescription.ID,
			PrintObjects, Form, CommandDescription);
	EndIf;
	
EndProcedure

// Continues the execution of PrintManagementClient.CheckDocumentsPosted procedure.
Procedure CheckDocumentsPostedPostingDialog(Parameters) Export
	
	If PrintManagementServerCall.HasRightsToPost(Parameters.UnpostedDocuments) Then
		If Parameters.UnpostedDocuments.Count() = 1 Then
			QuestionText = NStr("en = 'Only posted documents can be printed. Post the document and continue?'");
		Else
			QuestionText = NStr("en = 'Only posted documents can be printed. Post the documents and continue?'");
		EndIf;
	Else
		If Parameters.UnpostedDocuments.Count() = 1 Then
			WarningText = NStr("en = 'Only posted documents can be printed. You do not have the right to post the document, therefore printing is not available.'");
		Else
			WarningText = NStr("en = 'Only posted documents can be printed. You do not have the right to post the documents, therefore printing is not available.'");
		EndIf;
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	NotifyDescription = New NotifyDescription("CheckDocumentsPostedDocumentPosting", ThisObject, Parameters);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo);
	
EndProcedure

// Continues the execution of PrintManagementClient.CheckDocumentsPosted procedure.
Procedure CheckDocumentsPostedDocumentPosting(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	NotPostedDocumentInformation = CommonUseServerCall.PostDocuments(AdditionalParameters.UnpostedDocuments);
	MessagePattern = NStr("en = 'Document %1 is not posted: %2'");
	UnpostedDocuments = New Array;
	For Each DocumentInformation In NotPostedDocumentInformation Do
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, String(DocumentInformation.Ref), 
				DocumentInformation.ErrorDescription), DocumentInformation.Ref);
		UnpostedDocuments.Add(DocumentInformation.Ref);
	EndDo;
	AdditionalParameters.Insert("UnpostedDocuments", UnpostedDocuments);
	
	PostedDocuments = CommonUseClientServer.ReduceArray(AdditionalParameters.DocumentList, UnpostedDocuments);
	AdditionalParameters.Insert("PostedDocuments", PostedDocuments);
	
	// Notifying open forms that documents are posted
	PostedDocumentTypes = New Map;
	For Each PostedDocument In PostedDocuments Do
		PostedDocumentTypes.Insert(TypeOf(PostedDocument));
	EndDo;
	For Each Type In PostedDocumentTypes Do
		NotifyChanged(Type.Key);
	EndDo;
		
	// If the command is called from a form, reading the up-to-date (posted) document from the infobase
	If TypeOf(AdditionalParameters.Form) = Type("ManagedForm") Then
		Try
			AdditionalParameters.Form.Read();
		Except
			// If the Read method is not available, printing was executed from a location other than the object form
		EndTry;
	EndIf;
		
	If UnpostedDocuments.Count() > 0 Then
		// Asking user whether they want to continue printing while they have unposted documents
		DialogText = NStr("en = 'Cannot post one or several documents.'");
		
		DialogButtons = New ValueList;
		If PostedDocuments.Count() > 0 Then
			DialogText = DialogText + " " + NStr("en = 'Continue?'");
			DialogButtons.Add(DialogReturnCode.Ignore, NStr("en = 'Continue'"));
			DialogButtons.Add(DialogReturnCode.Cancel);
		Else
			DialogButtons.Add(DialogReturnCode.OK);
		EndIf;
		
		NotifyDescription = New NotifyDescription("CheckDocumentsPostedCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(NotifyDescription, DialogText, DialogButtons);
		Return;
	EndIf;
	
	CheckDocumentsPostedCompletion(Undefined, AdditionalParameters);
	
EndProcedure

// Continues the execution of PrintManagementClient.CheckDocumentsPosted procedure.
Procedure CheckDocumentsPostedCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> Undefined And QuestionResult <> DialogReturnCode.Ignore Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.CompletionProcedureDescription, AdditionalParameters.PostedDocuments);
	
EndProcedure

// Returns references to the objects selected on the form.
Function PrintObjects(Source)
	
	Result = New Array;
	
	If TypeOf(Source) = Type("FormTable") Then
		SelectedRows = Source.SelectedRows;
		For Each SelectedRow In SelectedRows Do
			If TypeOf(SelectedRow) = Type("DynamicalListGroupRow") Then
				Continue;
			EndIf;
			CurrentRow = Source.RowData(SelectedRow);
			If CurrentRow <> Undefined Then
				Result.Add(CurrentRow.Ref);
			EndIf;
		EndDo;
	Else
		Result.Add(Source.Ref);
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether the file system extension for the web client is installed and offers installation if it is not installed.
//
// Parameters:
//  NotifyDescription - NotifyDescription - description of the procedure that is called after the check.
//                                            The procedure must have the following parameters:
//                                             Result - (not used).
//                                             AdditionalParameters - (not used).
//
Procedure ShowFileSystemExtensionInstallationQuestion(NotifyDescription) Export
	#If WebClient Then
		MessageText = NStr("en = 'To continue printing, install the file system extension for the 1 C: Enterprise web client.'");
		CommonUseClient.ShowFileSystemExtensionInstallationQuestion(NotifyDescription, MessageText, False);
		Return;
	#EndIf
	ExecuteNotifyProcessing(NotifyDescription, True);
EndProcedure

#EndRegion
