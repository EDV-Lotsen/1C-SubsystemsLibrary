
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	VerifyAccessRights("Administration", Metadata);
	
  // Skipping the initialization to guarantee that the form will be  
  // received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	QueryConsoleID = "QueryConsole";
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	CurrentObject.ReadSLSupportFlags();
	
	String = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting);
	If Lower(Right(String, 4)) = ".epf" Then
		QueryConsoleUseVariant = 2;
	ElsIf Metadata.DataProcessors.Find(String) <> Undefined Then
		QueryConsoleUseVariant = 1;
		String = "";	
	Else 
		QueryConsoleUseVariant = 0;
		String = "";
	EndIf;
	CurrentObject.QueryExternalDataProcessorAddressSetting = String;
	
	ThisObject(CurrentObject);
	
	ChoiceList = Items.ExternalQueryDataProcessor.ChoiceList;
	
  // The data processor is included in the metadata if it is a predefined 
  // part of the configuration
	If Metadata.DataProcessors.Find(QueryConsoleID) = Undefined Then
		CurItem = ChoiceList.FindByValue(1);
		If CurItem <> Undefined Then
			ChoiceList.Delete(CurItem);
		EndIf;
	EndIf;
	
	// Option string from the file
	If CurrentObject.IsFileInfobase() Then
		CurItem = ChoiceList.FindByValue(2);
		If CurItem <> Undefined Then
			CurItem.Presentation = NStr("en = 'In directory:'");
		EndIf;
	EndIf;

	// SLGroup form item is visible if this SL version is supported
	Items.SLGroup.Visible = CurrentObject.ConfigurationSupportsSL
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure QueryDataProcessorPathOnChange(Item)
	QueryConsoleUseVariant = 2;
EndProcedure

&AtClient
Procedure QueryDataProcessorPathStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	Dialog = New FileDialog(FileDialogMode.Open);
	Dialog.CheckFileExist = True;
	Dialog.Filter = NStr("en = 'External data processors (*.epf)|*.epf'");
	If Dialog.Choose() Then
		QueryConsoleUseVariant = 2;
		SetQueryExternalDataProcessorAddressSetting(Dialog.FullFileName);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConfirmSelection(Command)
	
	Checking = CheckSettings();
	If Checking.HasErrors Then
		// Reporting errors
		If Checking.QueryExternalDataProcessorAddressSetting <> Undefined Then
			ReportError(Checking.QueryExternalDataProcessorAddressSetting, "Object.QueryExternalDataProcessorAddressSetting");
			Return;
		EndIf;
	EndIf;
	
	// No errors
	SaveSettings();
	Close();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure ReportError(Text, AttributeName = Undefined)
	
	If AttributeName = Undefined Then
		ErrorTitle = NStr("en = 'Error'");
		ShowMessageBox(, Text, , ErrorTitle);
		Return;
	EndIf;
	
	Message = New UserMessage();
	Message.Text  = Text;
	Message.Field = AttributeName;
	Message.SetData(ThisObject);
	Message.Message();
EndProcedure	

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function CheckSettings()
	CurrentObject = ThisObject();
	
	If QueryConsoleUseVariant = 2 Then
		
		CurrentObject.QueryExternalDataProcessorAddressSetting = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting);
		If Left(CurrentObject.QueryExternalDataProcessorAddressSetting, 1) = """" 
			And Right(CurrentObject.QueryExternalDataProcessorAddressSetting, 1) = """"
		Then
			CurrentObject.QueryExternalDataProcessorAddressSetting = Mid(CurrentObject.QueryExternalDataProcessorAddressSetting, 
				2, StrLen(CurrentObject.QueryExternalDataProcessorAddressSetting) - 2);
		EndIf;
		
		If Lower(Right(TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting), 4)) <> ".epf" Then
			CurrentObject.QueryExternalDataProcessorAddressSetting = TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting) + ".epf";
		EndIf;
		
	ElsIf QueryConsoleUseVariant = 0 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = "";
		
	EndIf;
	
	Result = CurrentObject.CheckSettingCorrectness();
	ThisObject(CurrentObject);
	
	Return Result;
EndFunction

&AtServer
Procedure SaveSettings()
	CurrentObject = ThisObject();
	If QueryConsoleUseVariant = 0 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = "";
	ElsIf QueryConsoleUseVariant = 1 Then
		CurrentObject.QueryExternalDataProcessorAddressSetting = QueryConsoleID		;
	EndIf;
	CurrentObject.SaveSettings();
	ThisObject(CurrentObject);
EndProcedure

&AtServer
Procedure SetQueryExternalDataProcessorAddressSetting(PathToFile)
	CurrentObject = ThisObject();
	CurrentObject.QueryExternalDataProcessorAddressSetting = PathToFile;
	ThisObject(CurrentObject);
EndProcedure

#EndRegion
