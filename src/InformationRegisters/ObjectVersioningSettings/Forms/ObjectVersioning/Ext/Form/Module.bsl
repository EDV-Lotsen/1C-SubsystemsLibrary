#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	FillObjectTypesInValueTree();
	
	ChoiceListFull = New ValueList;
	ChoiceListFull.Add(Enums.ObjectVersioningModes.VersionizeOnWrite);
	ChoiceListFull.Add(Enums.ObjectVersioningModes.VersionizeOnPost);
	ChoiceListFull.Add(Enums.ObjectVersioningModes.DontVersionize);
	
	ChoiceListWithoutPosting = New ValueList;
	ChoiceListWithoutPosting.Add(Enums.ObjectVersioningModes.VersionizeOnWrite);
	ChoiceListWithoutPosting.Add(Enums.ObjectVersioningModes.DontVersionize);
	
	Items.Schedule.Title = CurrentSchedule();
	AutomaticallyDeleteObsoleteVersions = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearingObsoleteObjectVersions).Use;

	UpdateObsoleteVersionsInfo();
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure VersioningModeChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	TreeRow = Items.MetadataObjectTree.CurrentData;
	TreeRow.VersioningMode = SelectedValue;
	
	ObjectType     = TreeRow.ObjectType;
	VersioningMode = TreeRow.VersioningMode;
	
	SaveVersioningConfiguration(ObjectType, VersioningMode);
	
EndProcedure

#EndRegion

#Region MetadataObjectTreeFormTableItemEventHandlers

&AtClient
Procedure MetadataObjectTreeBeforeRowChange(Item, Cancel)
	
	If Item.CurrentData.GetParent() = Undefined Then
		Cancel = True;
	EndIf;
	
	If Item.CurrentItem = Items.VersioningMode Then
		FillChoiceList(Items.MetadataObjectTree.CurrentItem);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetVersioningModeDontVersionize(Command)
	
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectVersioningModes.DontVersionize"));	
	
EndProcedure

&AtClient
Procedure SetVersioningModeOnWrite(Command)
	
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectVersioningModes.VersionizeOnWrite"));	
	
EndProcedure

&AtClient
Procedure SetVersioningModeOnPost(Command)
	
	If DocumentsThatCannotBePostedSelected() Then
		ShowMessageBox(, NStr("en = 'The versioning mode (Versionize on write) is set for documents that cannot be posted.'"));
	EndIf;
	
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectVersioningModes.VersionizeOnPost"));	
	
EndProcedure

&AtClient
Procedure SetDefaultSettings(Command)
	
	SetSelectedRowsVersioningMode(Undefined);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	FillObjectTypesInValueTree();
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Procedure FillChoiceList(Item)
	
	TreeRow = Items.MetadataObjectTree.CurrentData;
	
	Item.ChoiceList.Clear();
	
	If TreeRow.ObjectClass = "DocumentsClass" And TreeRow.Posting Then
		ChoiceList = ChoiceListFull;
	Else
		ChoiceList = ChoiceListWithoutPosting;
	EndIf;
	
	For Each ListItem In ChoiceList Do
		Item.ChoiceList.Add(ListItem.Value);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillObjectTypesInValueTree()
	
	VersioningSettings = CurrentVersioningSettings();
	
	MOTree = FormAttributeToValue("MetadataObjectTree");
	MOTree.Rows.Clear();
	
	// Command parameter type ChangeHistory contains objects that are versionized
	TypeArray = Metadata.CommonCommands.ChangeHistory.CommandParameterType.Types();
	HasCatalogs = False;
	HasDocuments = False;
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();
	CatalogsNode = Undefined;
	DocumentsNode = Undefined;
	BusinessProcessesNode = Undefined;
	
	For Each Type In TypeArray Do
		If AllCatalogs.ContainsType(Type) Then
			If CatalogsNode = Undefined Then
				CatalogsNode = MOTree.Rows.Add();
				CatalogsNode.ObjectDescriptionSynonym = NStr("en = 'Catalogs'");
				CatalogsNode.ObjectClass = "01CatalogsClassRoot";
				CatalogsNode.PictureCode = 2;
			EndIf;
			NewTableRow = CatalogsNode.Rows.Add();
			NewTableRow.PictureCode = 19;
			NewTableRow.ObjectClass = "CatalogsClass";
		ElsIf AllDocuments.ContainsType(Type) Then
			If DocumentsNode = Undefined Then
				DocumentsNode = MOTree.Rows.Add();
				DocumentsNode.ObjectDescriptionSynonym = NStr("en = 'Documents'");
				DocumentsNode.ObjectClass = "02DocumentsClassRoot";
				DocumentsNode.PictureCode = 3;
			EndIf;
			NewTableRow = DocumentsNode.Rows.Add();
			NewTableRow.PictureCode = 20;
			NewTableRow.ObjectClass = "DocumentsClass";
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			If BusinessProcessesNode = Undefined Then
				BusinessProcessesNode = MOTree.Rows.Add();
				BusinessProcessesNode.ObjectDescriptionSynonym = NStr("en = 'Business processes'");
				DocumentsNode.ObjectClass = "03BusinessProcessesRoot";
				BusinessProcessesNode.ObjectType = "BusinessProcesses";
			EndIf;
			NewTableRow = BusinessProcessesNode.Rows.Add();
			NewTableRow.ObjectClass = "BusinessProcessesClass";
		EndIf;
		ObjectMetadata = Metadata.FindByType(Type);
		NewTableRow.ObjectType = ObjectMetadata.FullName();
		NewTableRow.ObjectDescriptionSynonym = ObjectMetadata.Synonym;
		
		FoundSettings = VersioningSettings.FindRows(New Structure("ObjectType", NewTableRow.ObjectType));
		If FoundSettings.Count() > 0 Then
			NewTableRow.VersioningMode = FoundSettings[0].VersioningMode;
			NewTableRow.VersionLifetime = FoundSettings[0].VersionLifetime;
			If Not ValueIsFilled(FoundSettings[0].VersionLifetime) Then
				NewTableRow.VersionLifetime = Enums.VersionLifetimes.Infinite;
			EndIf;
		Else
			NewTableRow.VersioningMode = Enums.ObjectVersioningModes.DontVersionize;
			NewTableRow.VersionLifetime = Enums.VersionLifetimes.Infinite;
		EndIf;
		
		If NewTableRow.ObjectClass = "DocumentsClass" Then
			NewTableRow.Posting = ? (ObjectMetadata.Posting = Metadata.ObjectProperties.Posting.Allow, True, False);
		EndIf;
	EndDo;
	MOTree.Rows.Sort("ObjectClass");
	For Each TopLevelNode In MOTree.Rows Do
		TopLevelNode.Rows.Sort("ObjectDescriptionSynonym");
	EndDo;
	ValueToFormAttribute(MOTree, "MetadataObjectTree");
	
EndProcedure

&AtServerNoContext
Procedure SaveVersioningConfiguration(Val ObjectType, Val VersioningMode)
	
	ObjectVersioning.SaveObjectVersioningConfiguration(ObjectType, VersioningMode);
	
EndProcedure

&AtClient
Function DocumentsThatCannotBePostedSelected()
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.ObjectClass = "DocumentsClass" And Not TreeItem.Posting Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Procedure SetSelectedRowsVersioningMode(Val VersioningMode)
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then 
			For Each TreeChildItem In TreeItem.GetItems() Do
				SetTreeItemVersioningMode(TreeChildItem, VersioningMode);
			EndDo;
		Else
			SetTreeItemVersioningMode(TreeItem, VersioningMode);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetTreeItemVersioningMode(TreeItem, Val VersioningMode)
	
	If VersioningMode = Undefined Then
		If TreeItem.ObjectClass = "DocumentsClass" Then
			VersioningMode = Enums.ObjectVersioningModes.VersionizeOnPost;
		ElsIf TreeItem.GetParent().ObjectType = "BusinessProcesses" Then
			VersioningMode = Enums.ObjectVersioningModes.VersionizeOnStart;
		Else
			VersioningMode = Enums.ObjectVersioningModes.DontVersionize;
		EndIf;
	EndIf;
	
	If VersioningMode = Enums.ObjectVersioningModes.VersionizeOnPost
		And Not TreeItem.Posting 
		Or VersioningMode = Enums.ObjectVersioningModes.VersionizeOnStart
		And TreeItem.ObjectClass <> "BusinessProcessesClass" Then
			VersioningMode = Enums.ObjectVersioningModes.VersionizeOnWrite;
	EndIf;
	
	TreeItem.VersioningMode = VersioningMode;
	ObjectVersioning.SaveObjectVersioningConfiguration(TreeItem.ObjectType, VersioningMode);
	
EndProcedure

&AtServer
Procedure SetSelectedObjectsVersionStoringDuration(VersionLifetime)
	
	For Each RowID In Items.MetadataObjectTree.SelectedRows Do
		TreeItem = MetadataObjectTree.FindByID(RowID);
		If TreeItem.GetParent() = Undefined Then
			For Each TreeChildItem In TreeItem.GetItems() Do
				SetSelectedObjectVersionStoringDuration(TreeChildItem, VersionLifetime);
			EndDo;
		Else
			SetSelectedObjectVersionStoringDuration(TreeItem, VersionLifetime);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetSelectedObjectVersionStoringDuration(SelectedObject, VersionLifetime)
	
	SelectedObject.VersionLifetime = VersionLifetime;
	SaveCurrentObjectSettings(SelectedObject.ObjectType, SelectedObject.VersioningMode, VersionLifetime);
	
EndProcedure

&AtClient
Procedure VersionLifetimeOnChange(Item)
	CurrentData = Items.MetadataObjectTree.CurrentData;
	SaveCurrentObjectSettings(CurrentData.ObjectType, CurrentData.VersioningMode, CurrentData.VersionLifetime);
	UpdateObsoleteVersionsInfo();
EndProcedure

&AtServer
Procedure SaveCurrentObjectSettings(ObjectType, VersioningMode, VersionLifetime)
	Settings = InformationRegisters.ObjectVersioningSettings.CreateRecordManager();
	Settings.ObjectType = ObjectType;
	Settings.Mode = VersioningMode;
	Settings.VersionLifetime = VersionLifetime;
	Settings.Write();
EndProcedure

&AtServer
Function CurrentVersioningSettings()
	SetPrivilegedMode(True);
	QueryText =
	"SELECT
	|	ObjectVersioningSettings.ObjectType AS ObjectType,
	|	ObjectVersioningSettings.Mode AS VersioningMode,
	|	ObjectVersioningSettings.VersionLifetime AS VersionLifetime
	|FROM
	|	InformationRegister.ObjectVersioningSettings AS ObjectVersioningSettings";
	Query = New Query(QueryText);
	Return Query.Execute().Unload();
EndFunction


&AtClient
Procedure LastWeek(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionLifetimes.LastWeek"));
EndProcedure

&AtClient
Procedure LastMonth(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionLifetimes.LastMonth"));
EndProcedure

&AtClient
Procedure LastThreeMonths(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionLifetimes.LastThreeMonths"));
EndProcedure

&AtClient
Procedure LastSixMonths(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionLifetimes.LastSixMonths"));
EndProcedure

&AtClient
Procedure LastYear(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionLifetimes.LastYear"));
EndProcedure

&AtClient
Procedure Infinite(Command)
	SetSelectedObjectsVersionStoringDuration(
		PredefinedValue("Enum.VersionLifetimes.Infinite"));
EndProcedure

&AtClient
Procedure VersionizeOnStart(Command)
	SetSelectedRowsVersioningMode(
		PredefinedValue("Enum.ObjectVersioningModes.VersionizeOnStart"));
EndProcedure

&AtClient
Procedure SetSchedule(Command)
	ScheduleDialog = New ScheduledJobDialog(CurrentSchedule());
	NotifyDescription = New NotifyDescription("SetScheduleCompletion", ThisObject);
	ScheduleDialog.Show(NotifyDescription);
EndProcedure

&AtClient
Procedure SetScheduleCompletion(Schedule, AdditionalParameters) Export
	If Schedule = Undefined Then
		Return;
	EndIf;
	
	SetJobSchedule(Schedule);
	Items.Schedule.Title = Schedule;
	
EndProcedure

&AtServer
Procedure SetJobSchedule(Schedule);
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
	ScheduledJob.Schedule = Schedule;
	ScheduledJob.Write();
EndProcedure

&AtServer
Function CurrentSchedule()
	Return ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearingObsoleteObjectVersions).Schedule;
EndFunction

&AtClient
Procedure AutomaticallyDeleteObsoleteVersionsOnChange(Item)
	EnableDisableScheduledJob();
EndProcedure

&AtServer
Procedure EnableDisableScheduledJob()
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
	ScheduledJob.Use = Not ScheduledJob.Use;
	ScheduledJob.Write();
EndProcedure

&AtClient
Procedure Clear(Command)
	RunScheduledJob();
	AttachIdleHandler("CheckBackgroundJobExecution", 2, True);
EndProcedure

&AtClient
Procedure CheckBackgroundJobExecution()
	If Not JobCompleted(BackgroundJobID) Then
		AttachIdleHandler("CheckBackgroundJobExecution", 5, True);
	Else
		BackgroundJobID = "";
		UpdateObsoleteVersionsInfo();
	EndIf;
EndProcedure

&AtServerNoContext
Function JobCompleted(BackgroundJobID)
	Return LongActions.JobCompleted(BackgroundJobID);
EndFunction

&AtServer
Procedure RunScheduledJob()
	
	ScheduledJob = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.ClearingObsoleteObjectVersions);
	
	Filter = New Structure;
	Filter.Insert("ScheduledJob", ScheduledJob);
	Filter.Insert("State", BackgroundJobState.Active);
	CleanupBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	If CleanupBackgroundJobs.Count() > 0 Then
		BackgroundJobID = CleanupBackgroundJobs[0].UUID;
	Else
		BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 started manually'"), ScheduledJob.Metadata.Synonym);
		
		BackgroundJob = BackgroundJobs.Execute(
			ScheduledJob.Metadata.MethodName,
			ScheduledJob.Parameters,
			String(ScheduledJob.UUID),
			BackgroundJobDescription);
			
		BackgroundJobID = BackgroundJob.UUID;
	EndIf;
	
	UpdateObsoleteVersionsInfo();
	
EndProcedure

&AtServer
Procedure UpdateObsoleteVersionsInfo()
	
	Items.Clear.Enabled = Not ValueIsFilled(BackgroundJobID);
	If ValueIsFilled(BackgroundJobID) Then
		Items.ObsoleteVersionsInfo.Title = NStr("en = 'Clearing obsolete versions...'");
		Return;
	EndIf;
	
	ObsoleteVersionsInfo = ObjectVersioning.ObsoleteVersionsInfo();
	
	If ObsoleteVersionsInfo.DataSize > 0 Then
		Items.ObsoleteVersionsInfo.Title = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Obsolete versions: %1 (%2)'"),
			ObsoleteVersionsInfo.VersionCount,
			ObjectVersioning.DataSizeString(ObsoleteVersionsInfo.DataSize));
	Else
		Items.ObsoleteVersionsInfo.Title = NStr("en = 'Obsolete versions: none'");
	EndIf;
	
EndProcedure

&AtClient
Procedure StoredObjectVersionsCountAndSize(Command)
	OpenForm("Report.ObjectVersionAnalysis.ObjectForm");
EndProcedure

#EndRegion
