
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// First of all, checking the access rights
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("en = 'Running the data processor manually requires administrator rights.'");
	EndIf;
	
  // Skipping the initialization to guarantee that the form will be 
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	Object.ExchangeFileName = Parameters.ExchangeFileName;
	Object.ExchangeRuleFileName = Parameters.ExchangeRuleFileName;
	Object.EventHandlerExternalDataProcessorFileName = Parameters.EventHandlerExternalDataProcessorFileName;
	Object.AlgorithmDebugMode = Parameters.AlgorithmDebugMode;
	Object.ReadEventHandlersFromExchangeRuleFile = Parameters.ReadEventHandlersFromExchangeRuleFile;
	
	FormTitle = NStr("en = Debug settings for %Event% handlers'");	
	Event = ?(Parameters.ReadEventHandlersFromExchangeRuleFile, NStr("en = 'data export'"), NStr("en = 'data import'"));
	FormTitle = StrReplace(FormTitle, "%Event%", Event);
	Title = FormTitle;
	
	ButtonTitle = NStr("en = 'Generate debug module for %Event%'");
	Event = ?(Parameters.ReadEventHandlersFromExchangeRuleFile, NStr("en = 'data export'"), NStr("en = 'data import'"));
	ButtonTitle = StrReplace(ButtonTitle, "%Event%", Event);
	Items.ExportHandlerScript.Title = ButtonTitle;
	
	SetVisible();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure AlgorithmDebugOnChange(Item)
	
	AlgorithmDebugOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	
	FileDialog.Filter     = NStr("en = 'Event handler external data processor file (*.epf)|*.epf'");
	FileDialog.DefaultExt = "epf";
	FileDialog.Title = NStr("en = 'Select file'");
	FileDialog.Preview = False;
	FileDialog.FilterIndex = 0;
	FileDialog.FullFileName = Item.EditText;
	FileDialog.CheckFileExist = True;
	
	If FileDialog.Choose() Then
		
		Object.EventHandlerExternalDataProcessorFileName = FileDialog.FullFileName;
		
		EventHandlerExternalDataProcessorFileNameOnChange(Item)
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EventHandlerExternalDataProcessorFileNameOnChange(Item)
	
	SetVisible();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Done(Command)
	
	ClearMessages();
	
	If IsBlankString(Object.EventHandlerExternalDataProcessorFileName) Then
		
		MessageToUser(NStr("en = 'Enter the external data processor file name.'"), "EventHandlerExternalDataProcessorFileName");
		Return;
		
	EndIf;
	
	EventHandlerExternalDataProcessorFile = New File(Object.EventHandlerExternalDataProcessorFileName);
	If Not EventHandlerExternalDataProcessorFile.Exist() Then
		
		MessageToUser(NStr("en = 'The specified external data processor file does not exist.'"), "EventHandlerExternalDataProcessorFileName");
		Return;
		
	EndIf;
	
	CloseParameters = New Structure;
	CloseParameters.Insert("EventHandlerExternalDataProcessorFileName", Object.EventHandlerExternalDataProcessorFileName);
	CloseParameters.Insert("AlgorithmDebugMode", Object.AlgorithmDebugMode);
	CloseParameters.Insert("ExchangeRuleFileName", Object.ExchangeRuleFileName);
	CloseParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	
	Close(CloseParameters);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	ShowEventHandlersInWindow();
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetVisible()
	
	AlgorithmDebugOnChangeAtServer();
	
	//Highlighting wizard steps that require corrections with red color
	SetBorderHighlight("Group_Step_4", IsBlankString(Object.EventHandlerExternalDataProcessorFileName));
	
	Items.OpenFile.Enabled = Not IsBlankString(Object.EventHandlerTempFileName);
	
EndProcedure

&AtServer
Procedure SetBorderHighlight(BorderName, BorderHighlightRequired = False) 
	
	WizardStepBorder = Items[BorderName];
	
	If BorderHighlightRequired Then
		
		WizardStepBorder.TitleTextColor = StyleColors.SpecialTextColor;
		
	Else
		
		WizardStepBorder.TitleTextColor = New Color;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportHandlerScript(Command)
	
	//Data was exported earlier
	If Not IsBlankString(Object.EventHandlerTempFileName) Then
		
		ButtonList = New ValueList;
		ButtonList.Add(DialogReturnCode.Yes, NStr("en = 'Repeat export'"));
		ButtonList.Add(DialogReturnCode.No, NStr("en = 'Open module'"));
		ButtonList.Add(DialogReturnCode.Cancel);
		
		NotifyDescription = New NotifyDescription("ExportHandlerScriptCompletion", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'The debug module with the handler script is already exported.'"), ButtonList,,DialogReturnCode.No);
		
	Else
		
		ExportHandlerScriptCompletion(DialogReturnCode.Yes, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportHandlerScriptCompletion(Result, AdditionalParameters) Export
	
	HasExportErrors = False;
	
	If Result = DialogReturnCode.Yes Then
		
		ExportedWithErrors = False;
		ExportEventHandlersAtServer(ExportedWithErrors);
		
	ElsIf Result = DialogReturnCode.Cancel Then
		
		Return;
		
	EndIf;
	
	If Not HasExportErrors Then
		
		SetVisible();
		
		ShowEventHandlersInWindow();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowEventHandlersInWindow()
	
	HandlerFile = New File(Object.EventHandlerTempFileName);
	If HandlerFile.Exist() And HandlerFile.Size() <> 0 Then
		TextDocument = New TextDocument;
		TextDocument.Read(Object.EventHandlerTempFileName);
		TextDocument.Show(NStr("en = 'Handler debug module'"));
	EndIf;
	
	ErrorLogFile = New File(Object.ExchangeLogTempFileName);
	If ErrorLogFile.Exist() And ErrorLogFile.Size() <> 0 Then
		TextDocument = New TextDocument;
		TextDocument.Read(Object.EventHandlerTempFileName);
		TextDocument.Show(NStr("en = 'Handler debug module export errors'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportEventHandlersAtServer(Cancel)
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.ExportEventHandlers(Cancel);
	ValueToFormAttribute(ObjectForServer, "Object");
	
EndProcedure

&AtServer
Procedure AlgorithmDebugOnChangeAtServer()
	
	ToolTip = Items.AlgorithmDebugTooltip;
	
	ToolTip.CurrentPage = ToolTip.ChildItems["Group_"+Object.AlgorithmDebugMode];
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

#EndRegion
