

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
 If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	Ref = Parameters.Ref;
	
	If ObjectVersioning.LastVersionNumber(Ref) = 0 Then
		Items.MainPage.CurrentPage = Items.NoVersionsToCompare;
		Items.NoVersions.Title = StringFunctionsClientServer.SubstituteParametersInString(
	       NStr("en = 'Earlier versions are not available: %1.'"),
	       String(Ref));
	EndIf;
	
	RefreshVersionList();
	
	GoToVersionAllowed = Users.InfobaseUserWithFullAccess();
	Items.GoToVersion.Visible = GoToVersionAllowed;
	Items.VersionListGoToVersion.Visible = GoToVersionAllowed;
	
	Attributes = NStr("en = 'All'")
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetEnabled();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure AttributesStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("OnAttributeSelection", ThisObject);
	OpenForm("InformationRegister.ObjectVersions.Form.SelectObjectAttributes", New Structure(
		"Ref,Filter", Ref, Filter.UnloadValues()), , , , , NotifyDescription);
EndProcedure

&AtClient
Procedure EventLogClick(Item)
	EventLogOperationsClient.OpenEventLog();
EndProcedure

#EndRegion

#Region FormTableEventItemHandlersVersionList

&AtClient
Procedure VersionListOnActivateRow(Item)
	
	SetEnabled();
	
EndProcedure

&AtClient
Procedure VersionListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	OpenReportOnObjectVersion();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenObjectVersion(Command)
	
	OpenReportOnObjectVersion();
	
EndProcedure

&AtClient
Procedure GoToVersion(Command)
	
	GoToSelectedVersion();
	
EndProcedure

&AtClient
Procedure GenerateReportOnChanges(Command)
	
	SelectedRows = Items.VersionList.SelectedRows;
	ComparedVersions = GenerateSelectedVersionList(SelectedRows);
	
	If ComparedVersions.Count() < 2 Then
		ShowMessageBox(, NStr("en = 'To generate a change report, select at least two versions.'"));
		Return;
	EndIf;
	
	OpenReportForm(ComparedVersions);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Function GenerateVersionTable()
	
	If ObjectVersioning.HasRightToReadObjectVersions() Then
		SetPrivilegedMode(True);
	EndIf;
	
	VersionNumbers = New Array;
	If Filter.Count() > 0 Then
		VersionNumbers = VersionNumbersWithChangesInSelectedAttributes();
	EndIf;
	
	QueryText = 
	"SELECT
	|	ObjectVersions.VersionNumber AS VersionNumber,
	|	ObjectVersions.VersionAuthor AS VersionAuthor,
	|	ObjectVersions.VersionDate AS VersionDate,
	|	ObjectVersions.Comment AS Comment
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.Object = &Ref
	|	AND (&WithoutSelection
	|			OR ObjectVersions.VersionNumber IN (&VersionNumbers))
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("WithoutSelection", Filter.Count() = 0);
	Query.SetParameter("VersionNumbers", VersionNumbers);
	Query.SetParameter("Ref", Ref);
	
	Return Query.Execute().Unload();
	
EndFunction

&AtClient
Procedure GoToSelectedVersion(UndoPosting = False)
	
	If Items.VersionList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	Result = GoToVersionServer(Ref, Items.VersionList.CurrentData.VersionNumber, UndoPosting);
	
	If Result = "RecoveryError" Then
		CommonUseClientServer.MessageToUser(ErrorMessageText);
	ElsIf Result = "PostingError" Then
		QuestionText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Migration to the selected version is not performed
				|due to the following reason:
				|%1 
       |Do you want to cancell the posting and switch to the selected version?'"),
			ErrorMessageText);
			
		NotifyDescription = New NotifyDescription("GoToSelectedVersionQuestionSet", ThisObject);
		Buttons = New ValueList;
		Buttons.Add("GoTo", NStr("en = 'Go to'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NotifyDescription, QuestionText, Buttons);
	Else //Result = RestorationCompleted		
   NotifyChanged(Ref);
		If FormOwner <> Undefined Then
			Try
				FormOwner.Read();
			Except
				// Do nothing if the form has no Read() method
			EndTry;
		EndIf;
		ShowMessageBox(, NStr("en = 'Migration to an earlier version is completed.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToSelectedVersionQuestionSet(QuestionResult, AdditionalParameters) Export
	If QuestionResult <> "GoTo" Then
		Return;
	EndIf;
	
	GoToSelectedVersion(True);
EndProcedure

&AtServer
Function GoToVersionServer(Ref, VersionNumber, UndoPosting = False)
	
	Information = ObjectVersioning.ObjectVersionDetails(Ref, VersionNumber);
	AddressInTempStorage = PutToTempStorage(Information.ObjectVersion);
	
	ErrorMessageText = "";
	Object = ObjectVersioning.RestoreObjectByXML(AddressInTempStorage, ErrorMessageText);
	
	If Not IsBlankString(ErrorMessageText) Then
		Return "RecoveryError";
	EndIf;
	
	Object.AdditionalProperties.Insert("ObjectVersioningVersionComment",
		StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Migration from version %1 from %2 is completed'"),
			String(VersionNumber),
			Format(Information.VersionDate, "DLF=DT")) );
			
	WriteMode = DocumentWriteMode.Write;
	If CommonUse.IsDocument(Object.Metadata()) Then
		If Object.Posted And Not UndoPosting Then
			WriteMode = DocumentWriteMode.Posting;
		Else
			WriteMode = DocumentWriteMode.UndoPosting;
		EndIf;
		
		Try
			Object.Write(WriteMode);
		Except
			ErrorMessageText = BriefErrorDescription(ErrorInfo());
			Return "PostingError"
		EndTry;
	Else
		Try
			Object.Write();
		Except
			ErrorMessageText = BriefErrorDescription(ErrorInfo());
			Return "RecoveryError"
		EndTry;
	EndIf;
	
	
	RefreshVersionList();
	
	Return "RestorationCompleted";
	
EndFunction

&AtClient
Procedure OpenReportOnObjectVersion()
	
	ComparedVersions = New Array;
	ComparedVersions.Add(Items.VersionList.CurrentData.VersionNumber);
	OpenReportForm(ComparedVersions);
	
EndProcedure

&AtClient
Procedure OpenReportForm(ComparedVersions)
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("ComparedVersions", ComparedVersions);
	
	OpenForm("InformationRegister.ObjectVersions.Form.ReportOnObjectVersions",
		ReportParameters,
		ThisObject,
		UUID);
	
EndProcedure

&AtClient
Function GenerateSelectedVersionList(SelectedRows)
	
	ComparedVersions = New ValueList;
	
	For Each SelectedRowNumber In SelectedRows Do
		ComparedVersions.Add(Items.VersionList.RowData(SelectedRowNumber).VersionNumber);
	EndDo;
	
	ComparedVersions.SortByValue(SortDirection.Asc);
	
	Return ComparedVersions.UnloadValues();
	
EndFunction

&AtClient
Procedure SetEnabled()
	Items.OpenObjectVersion.Enabled = Items.VersionList.SelectedRows.Count() > 0;
	Items.ReportOnChanges.Enabled = Items.VersionList.SelectedRows.Count() > 1;
	Items.GoToVersion.Enabled = Items.VersionList.SelectedRows.Count() = 1;
	Items.VersionListGoToVersion.Enabled = Items.GoToVersion.Enabled;
EndProcedure

&AtClient
Procedure OnAttributeSelection(ChoiceResult, AdditionalParameters) Export
	If ChoiceResult = Undefined Then
		Return;
	EndIf;
	
	Attributes = ChoiceResult.SelectedItemPresentation;
	Filter.LoadValues(ChoiceResult.SelectedAttributes);
	RefreshVersionList();
EndProcedure

&AtServer
Procedure RefreshVersionList()
	ValueToFormAttribute(GenerateVersionTable(), "VersionList");
EndProcedure

&AtClient
Procedure AttributesClearing(Item, StandardProcessing)
	StandardProcessing = False;
	Attributes = NStr("en = 'All'");
	Filter.Clear();
	RefreshVersionList();
EndProcedure

&AtServer
Function VersionNumbersWithChangesInSelectedAttributes()
	
	QueryText =
	"SELECT
	|	ObjectVersions.VersionNumber AS VersionNumber,
	|	ObjectVersions.ObjectVersion AS Data
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ChangedByUser)
	|	AND ObjectVersions.Object = &Ref
	|	AND ObjectVersions.HasVersionData
	|
	|ORDER BY
	|	VersionNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	StoredVersions = Query.Execute().Unload();
	
	CurrentVersion = StoredVersions.Add();
	CurrentVersion.Data = New ValueStorage(ObjectVersioning.SerializeObject(Ref.GetObject()), New Deflation(9));
	CurrentVersion.VersionNumber = ObjectVersioning.LastVersionNumber(Ref);
	
	PreviousVersion = ObjectVersioning.XMLObjectPresentationParsing(StoredVersions[0].Data.Get(), Ref);
	
	Result = New Array;
	Result.Add(StoredVersions[0].VersionNumber);
	
	For VersionNumber = 1 To StoredVersions.Count() - 1 Do
		Version = StoredVersions[VersionNumber];
		CurrentVersion = ObjectVersioning.XMLObjectPresentationParsing(Version.Data.Get(), Ref);
		If AttributesChanged(CurrentVersion, PreviousVersion, Filter.UnloadValues()) Then
			Result.Add(Version.VersionNumber);
		EndIf;
		PreviousVersion = CurrentVersion;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function AttributesChanged(CurrentVersion, PreviousVersion, AttributeList)
	For Each Attribute In AttributeList Do
		TabularSectionName = Undefined;
		AttributeName = Attribute;
		If Find(AttributeName, ".") > 0 Then
			NameParts = StringFunctionsClientServer.SplitStringIntoSubstringArray(AttributeName, ".", True);
			If NameParts.Count() > 1 Then
				TabularSectionName = NameParts[0];
				AttributeName = NameParts[1];
			EndIf;
		EndIf;
		
		// Tabular section attribute change check
		If TabularSectionName <> Undefined Then
			CurrentTabularSection = CurrentVersion.TabularSections[TabularSectionName];
			PreviousTabularSection = PreviousVersion.TabularSections[TabularSectionName];
			
			// Tabular section is missing
			If CurrentTabularSection = Undefined Or PreviousTabularSection = Undefined Then
				Return Not CurrentTabularSection = Undefined And PreviousTabularSection = Undefined;
			EndIf;
			
			// If the number of tabular section rows is changed,
			If CurrentTabularSection.Count() <> PreviousTabularSection.Count() Then
				Return True;
			EndIf;
			
			// Attribute is missing
			CurrentAttributeExists = CurrentTabularSection.Columns.Find(AttributeName) <> Undefined;
			PreviousAttributeExists = PreviousTabularSection.Columns.Find(AttributeName) <> Undefined;
			If CurrentAttributeExists <> PreviousAttributeExists Then
				Return True;
			EndIf;
			If Not CurrentAttributeExists Then
				Return False;
			EndIf;
			
			// Comparison by rows
			For LineNumber = 0 To CurrentTabularSection.Count() - 1 Do
				If CurrentTabularSection[LineNumber][AttributeName] <> PreviousTabularSection[LineNumber][AttributeName] Then
					Return True;
				EndIf;
			EndDo;
			
			Return False;
		EndIf;
		
		// Header attribute check
		
		CurrentAttribute = CurrentVersion.Attributes.Find(AttributeName, "AttributeDescription");
		CurrentAttributeExists = CurrentAttribute <> Undefined;
		CurrentAttributeValue = Undefined;
		If CurrentAttributeExists Then
			CurrentAttributeValue = CurrentAttribute.AttributeValue;
		EndIf;
		
		PreviousAttribute = PreviousVersion.Attributes.Find(AttributeName, "AttributeDescription");
		PreviousAttributeExists = PreviousAttribute <> Undefined;
		PreviousAttributeValue = Undefined;
		If PreviousAttributeExists Then
			PreviousAttributeValue = PreviousAttribute.AttributeValue;
		EndIf;
		
		If CurrentAttributeExists <> PreviousAttributeExists
			Or CurrentAttributeValue <> PreviousAttributeValue Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

&AtClient
Procedure VersionListCommentOnChange(Item)
	CurrentData = Items.VersionList.CurrentData;
	If CurrentData <> Undefined Then
		AddCommentToVersion(Ref, CurrentData.VersionNumber, CurrentData.Comment);
	EndIf;
EndProcedure

&AtServerNoContext
Procedure AddCommentToVersion(ObjectRef, VersionNumber, Comment);
	ObjectVersioning.AddCommentToVersion(ObjectRef, VersionNumber, Comment);
EndProcedure

&AtClient
Procedure VersionListBeforeRowChange(Item, Cancel)
	If Not CanEditComments(Item.CurrentData.VersionAuthor) Then
		Cancel = True;
	EndIf;
EndProcedure
////

&AtServer
Function CanEditComments(VersionAuthor)
	Return Users.InfobaseUserWithFullAccess()
		Or VersionAuthor = Users.CurrentUser();
EndFunction

#EndRegion