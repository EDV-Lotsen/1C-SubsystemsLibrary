
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	TemplateMetadataObjectName = Parameters.TemplateMetadataObjectName;
	
	NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(TemplateMetadataObjectName, ".");
	TemplateName = NameParts[NameParts.UBound()];
	
	OwnerName = "";
	For PartNumber = 0 To NameParts.UBound()-1 Do
		If Not IsBlankString(OwnerName) Then
			OwnerName = OwnerName + ".";
		EndIf;
		OwnerName = OwnerName + NameParts[PartNumber];
	EndDo;
	
	TemplateType = Parameters.TemplateType;
	
	TemplatePresentation = TemplatePresentation();
	TemplateFileName = CommonUseClientServer.ReplaceProhibitedCharsInFileName(TemplatePresentation) + "." + Lower(TemplateType);
	
	If Parameters.OpenOnly Then
		Title = NStr("en = 'Open print form template'");
	EndIf;
	
	ClientType = ?(Parameters.IsWebClient, "", "Not") + "WebClient";
	WindowOptionsKey = ClientType + Upper(TemplateType);
	
	If Not Parameters.IsWebClient And TemplateType = "MXL" Then
		Items.ApplyChangesLabelNotWebClient.Title = NStr(
			"en = 'Once you finish editing the template, click ""Apply changes"" '");
	EndIf;
	
	SetApplicationNameForTemplateOpening();
	
	Items.Dialog.CurrentPage = Items["ImportToComputerPage" + ClientType];
	Items.CommandBar.CurrentPage = Items.ImportPanel;
	Items.ChangeButton.DefaultButton = True;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	#If Not WebClient Then
		If Parameters.OpenOnly Then
			Cancel = True;
		EndIf;
		If Parameters.OpenOnly Or TemplateType = "MXL" Then
			OpenTemplate();
		EndIf;
	#EndIf
EndProcedure

&AtClient
Procedure OnClose()
	
	If Not IsBlankString(TemporaryFolder) Then
		DeleteFiles(TemporaryFolder);
	EndIf;
	
	EventName = "CancelTemplateChange";
	If TemplateImported Then
		EventName = "Write_UserPrintTemplates";
	EndIf;
	
	Notify(EventName, New Structure("TemplateMetadataObjectName", TemplateMetadataObjectName), ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure LinkToApplicationPageClick(Item)
	GotoURL(ApplicationAddressForTemplateOpening);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)
	OpenTemplate();
	If Parameters.OpenOnly Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure ApplyChanges(Command)
	
	#If WebClient Then
		NotifyDescription = New NotifyDescription("PutFileCompletion", ThisObject);
		BeginPutFile(NotifyDescription, TemplateFileAddressInTemporaryStorage, TemplateFileName);
	#Else
		If Lower(TemplateType) = "mxl" Then
			TemplateToChange.Hide();
			TemplateFileAddressInTemporaryStorage = PutToTempStorage(TemplateToChange);
			TemplateImported = True;
		Else
			File = New File(PathToTemplateFile);
			If File.Exist() Then
				BinaryData = New BinaryData(PathToTemplateFile);
				TemplateFileAddressInTemporaryStorage = PutToTempStorage(BinaryData);
				TemplateImported = True;
			EndIf;
		EndIf;
	
		If TemplateImported Then
			SaveTemplate();
		EndIf;

		Close();
		
	#EndIf
	
EndProcedure

&AtClient
Procedure PutFileCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	TemplateImported = Result;
	TemplateFileAddressInTemporaryStorage = Address;
	TemplateFileName = SelectedFileName;

	If TemplateImported Then
		SaveTemplate();
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetApplicationNameForTemplateOpening()
	
	ApplicationNameForTemplateOpening = "";
	
	FileType = Lower(TemplateType);
	If FileType = "mxl" Then
		ApplicationNameForTemplateOpening = NStr("en = '1C:Enterprise - File Workshop'");
		ApplicationAddressForTemplateOpening = "http://1c-dn.com/developer_tools/fileworkshop/";
	ElsIf FileType = "doc" Then
		ApplicationNameForTemplateOpening = NStr("en = 'Microsoft Word'");
		ApplicationAddressForTemplateOpening = "http://office.microsoft.com/ru-ru/word";
	ElsIf FileType = "odt" Then
		ApplicationNameForTemplateOpening = NStr("en = 'OpenOffice Writer'");
		ApplicationAddressForTemplateOpening = "http://www.openoffice.org/product/writer.html";
	EndIf;
	
	AdditionalDataForFilling = New Structure;
	AdditionalDataForFilling.Insert("TemplateName", TemplatePresentation);
	AdditionalDataForFilling.Insert("ApplicationName", ApplicationNameForTemplateOpening);
	AdditionalDataForFilling.Insert("ActionDetails", ?(Parameters.OpenOnly, NStr("en = 'view'"), NStr("en = 'edit'")));
	
	ItemsForFilling = New Array;
	ItemsForFilling.Add(Items.LinkToApplicationPageBeforeImportWebClient);
	ItemsForFilling.Add(Items.LinkToApplicationPageBeforeImportNotWebClient);
	ItemsForFilling.Add(Items.LinkToApplyChangesApplicationPageWebClient);
	ItemsForFilling.Add(Items.LinkToApplyChangesApplicationPageNotWebClient);
	ItemsForFilling.Add(Items.LabelBeforeApplicationTemplateImportWebClient);
	ItemsForFilling.Add(Items.LabelBeforeApplicationTemplateImportNotWebClient);
	ItemsForFilling.Add(Items.ApplyChangesLabelWebClient);
	ItemsForFilling.Add(Items.ApplyChangesLabelNotWebClient);
	
	For Each Item In ItemsForFilling Do
		Item.Title = StringFunctionsClientServer.SubstituteParametersInString(Item.Title, AdditionalDataForFilling);
	EndDo;
	
	LinkToAplicationPageVisibility = Parameters.IsWebClient Or FileType <> "mxl";
	Items.LinkToApplicationPageBeforeImportWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplicationPageBeforeImportNotWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplyChangesApplicationPageWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplyChangesApplicationPageNotWebClient.Visible = LinkToAplicationPageVisibility;
	
	Items.LabelBeforeApplicationTemplateImportNotWebClient.Visible = FileType <> "mxl";
	
	Items.ImportToComputerPageWebClient.Visible = Parameters.IsWebClient;
	Items.ImportToInfobasePageWebClient.Visible = Parameters.IsWebClient;
	Items.ImportToComputerPageNotWebClient.Visible = Not Parameters.IsWebClient;
	Items.ImportToInfobasePageNotWebClient.Visible = Not Parameters.IsWebClient;
	
EndProcedure

&AtServer
Function TemplatePresentation()
	
	Result = TemplateName;
	
	Owner = Metadata.FindByFullName(OwnerName);
	If Owner <> Undefined Then
		Template = Owner.Templates.Find(TemplateName);
		If Template <> Undefined Then
			Result = Template.Synonym;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure OpenTemplate()
	#If WebClient Then
		OpenWebClientTemplate();
	#Else
		OpenThinClientTemplate();
	#EndIf
EndProcedure

&AtClient
Procedure OpenThinClientTemplate()
	
#If Not WebClient Then
	Template = PrintFormTemplate(TemplateMetadataObjectName);
	TemporaryFolder = GetTempFileName();
	CreateDirectory(TemporaryFolder);
	PathToTemplateFile = CommonUseClientServer.AddFinalPathSeparator(TemporaryFolder) + TemplateFileName;
	
	If TemplateType = "MXL" Then
		If Parameters.OpenOnly Then
			Template.ReadOnly = True;
			Template.Show(TemplatePresentation,,True);
		Else
			Template.Write(PathToTemplateFile);
			Template.Show(TemplatePresentation, PathToTemplateFile, True);
			
			TemplateToChange = Template;
		EndIf;
	Else
		Template.Write(PathToTemplateFile);
		If Parameters.OpenOnly Then
			TemplateFile = New File(PathToTemplateFile);
			TemplateFile.SetReadOnly(True);
		EndIf;
		RunApp(PathToTemplateFile);
	EndIf;
	
	GoToApplyChangesPage();
#EndIf
	
EndProcedure

&AtClient
Procedure OpenWebClientTemplate()
	If GetFile(PutTemplateToTempStorage(), TemplateFileName) <> False Then
		GoToApplyChangesPage();
	EndIf;
EndProcedure

&AtServer
Function PutTemplateToTempStorage()
	
	Return PutToTempStorage(TemplateBinaryData());
	
EndFunction

&AtServer
Function TemplateBinaryData()
	
	TemplateData = PrintManagement.PrintFormTemplate(TemplateMetadataObjectName);
	If TypeOf(TemplateData) = Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		TemplateData.Write(TempFileName);
		TemplateData = New BinaryData(TempFileName);
		DeleteFiles(TempFileName);
	EndIf;
	
	Return TemplateData;
	
EndFunction

&AtClient
Procedure GoToApplyChangesPage()
	Items.Dialog.CurrentPage = Items["ImportToInfobasePage" + ClientType];
	Items.CommandBar.CurrentPage = Items.ApplyChangesPanel;
	Items.ApplyChangesButton.DefaultButton = True;
EndProcedure

&AtServer
Procedure SaveTemplate()
	Template = GetFromTempStorage(TemplateFileAddressInTemporaryStorage);
	If Lower(TemplateType) = "mxl" And TypeOf(Template) <> Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		Template.Write(TempFileName);
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFileName);
		Template = SpreadsheetDocument;
	EndIf;
	
	Write = InformationRegisters.UserPrintTemplates.CreateRecordManager();
	Write.Object = OwnerName;
	Write.TemplateName = TemplateName;
	Write.Use = True;
	Write.Template = New ValueStorage(Template, New Deflation(9));
	Write.Write();
EndProcedure

&AtServerNoContext
Function PrintFormTemplate(TemplateMetadataObjectName)
	Return PrintManagement.PrintFormTemplate(TemplateMetadataObjectName);
EndFunction

#EndRegion