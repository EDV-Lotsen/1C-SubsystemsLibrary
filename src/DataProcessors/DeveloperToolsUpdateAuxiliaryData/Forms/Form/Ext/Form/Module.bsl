
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
 // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed
	If Parameters.Property("Autotest") Then 		Return;
	EndIf;
	
	// Simple settings
	BaseFunctionalitySubsystemData = True;
	UsersSubsystemData = True;
	AccessManagementSubsystemData = True;
	ReportOptionsSubsystemData = True;
	
	// Complex settings
	
	// StandardSubsystems BaseFunctionality
	InternalEventParameters = True;
	MetadataObjectIDs = True;
	ProgramInterfaceCache = True;
	
	// StandardSubsystems Users
	UserSessionParameters = True;
	UserGroupContent = True;
	
	// StandardSubsystems AccessManagement
	RoleRights = True;
	RightDependencies = True;
	AccessKindsProperties = True;
	SuppliedAccessGroupProfilesDescription = True;
	AvailableRightsForObjectRightSetupDescription = True;
	SuppliedAccessGroupProfiles = True;
	InfobaseUserRoles = True;
	AccessGroupTables = True;
	AccessGroupValues = True;
	ObjectRightsSettingsInheritance = True;
	ObjectRightsSettings = True;
	AccessValueGroups = True;
	AccessValueSets = True;
	
	// StandardSubsystems ReportOptions
	ReportOptionParameters = True;
	ReportOptionsCatalog = True;
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If CommonUseCached.SessionWithoutSeparators() Then
			UpdateSharedData = True;
		EndIf;
	Else
		UpdateSharedData = True;
		UpdateSeparatedData   = True;
	EndIf;
	
	If Not CommonUseCached.DataSeparationEnabled()
	 Or Not UpdateSharedData Then
		
		Items.DataArea.Visible                  = False;
		Items.LogOnToSpecifiedDataArea.Visible  = False;
		Items.CurrentDataArea.Visible           = False;
		Items.LogOffFromCurrentDataArea.Visible = False;
	EndIf;
	
	UpdateCurrentDataArea();
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Items.AccessManagementSubsystem.Visible     = False;
		Items.AccessManagementSubsystemData.Visible = False;
	EndIf;
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		Items.ReportOptionsSubsystem.Visible     = False;
		Items.ReportOptionsSubsystemData.Visible = False;
	EndIf;
	
	UpdateVisibilityBySetupMode();
	
	UpdateItemsEnabled(ThisObject);
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	UpdateVisibilityBySetupMode();
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure SetupModeOnChange(Item)
	
	UpdateVisibilityBySetupMode();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure LogOnToSpecifiedDataArea(Command)
	
	UpdateCurrentDataArea();
	
	If DataArea = CurrentDataArea Then
		ShowMessageBox(, NStr("en = 'You are already logged on to the specified data area.'"));
		Return;
	EndIf;
	
	If CurrentDataArea <> Undefined Then
		Cancel = False;
		LogOffFromDataArea(Cancel);
		If Cancel Then
			ShowMessageBox(, NStr("en = 'Cannot log off from the data area.'"));
			Return;
		EndIf;
	EndIf;
	
	LogOnToDataArea();
	
	UpdateCurrentDataArea();
	
EndProcedure

&AtClient
Procedure LogOffFromCurrentDataArea(Command)
	
	UpdateCurrentDataArea();
	
	If CurrentDataArea = Undefined Then
		ShowMessageBox(, NStr("en = 'You are not logged on to a data area .'"));
		Return;
	EndIf;
	
	Cancel = False;
	LogOffFromDataArea(Cancel);
	If Cancel Then
		ShowMessageBox(, NStr("en = 'Cannot log off from the data area.'"));
		Return;
	EndIf;
	
	If Not UpdateCurrentDataArea() Then
		ShowMessageBox(, NStr("en = 'The data area is not changed.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure Update(Command)
	
	DataMarked = False;
	
	If Not ValueIsFilled(SetupMode) Then
		DataMarked = True;
	EndIf;
	
	// StandardSubsystems BaseFunctionality
	If SetupMode = "SimpleSetup" And BaseFunctionalitySubsystemData  
	 Or SetupMode = "ComplexSetup"
	     And (    InternalEventParameters        And Items.InternalEventParameters.Enabled
	        Or MetadataObjectIDs And Items.MetadataObjectIDs.Enabled
	        Or ProgramInterfaceCache        And Items.ProgramInterfaceCache.Enabled) Then
		
		DataMarked = True;
	EndIf;
	
	// StandardSubsystems Users
	If SetupMode = "SimpleSetup" And UsersSubsystemData
	 Or SetupMode = "ComplexSetup"
	     And (    UserSessionParameters And Items.UserSessionParameters.Enabled
	        Or UserGroupContent    And Items.UserGroupContent.Enabled) Then
		
		DataMarked = True;
	EndIf;
	
	// StandardSubsystems AccessManagement
	If CommonUseClient.SubsystemExists("StandardSubsystems.AccessManagement") Then
		If SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup"
		   And (    RoleRights                                 And Items.RoleRights.Enabled
		      Or RightDependencies                             And Items.RightDependencies.Enabled
		      Or AccessKindsProperties                          And Items.AccessKindsProperties.Enabled
		      Or SuppliedAccessGroupProfilesDescription        And Items.SuppliedAccessGroupProfilesDescription.Enabled
		      Or AvailableRightsForObjectRightSetupDescription And Items.AvailableRightsForObjectRightSetupDescription.Enabled
		      
		      Or SuppliedAccessGroupProfiles        And Items.SuppliedAccessGroupProfiles.Enabled
		      Or InfobaseUserRoles And Items.InfobaseUserRoles.Enabled
		      Or AccessGroupTables                  And Items.AccessGroupTables.Enabled
		      Or AccessGroupValues                  And Items.AccessGroupValues.Enabled
		      Or ObjectRightsSettingsInheritance    And Items.ObjectRightsSettingsInheritance.Enabled
		      Or ObjectRightsSettings               And Items.ObjectRightsSettings.Enabled
		      Or AccessValueGroups                  And Items.AccessValueGroups.Enabled
		      Or AccessValueSets                    And Items.AccessValueSets.Enabled) Then
			
			DataMarked = True;
		EndIf;
	EndIf;
	
	// StandardSubsystems ReportOptions
	If CommonUseClient.SubsystemExists("StandardSubsystems.ReportOptions") Then
		If SetupMode = "SimpleSetup" And ReportOptionsSubsystemData
		 Or SetupMode = "ComplexSetup"
		   And (    ReportOptionParameters And Items.ReportOptionParameters.Enabled
		      Or ReportOptionsCatalog And Items.ReportOptionsCatalog.Enabled) Then
		
			DataMarked = True;
		EndIf;
	EndIf;
	
	If Not DataMarked Then
		ShowMessageBox(, NStr("en = 'Mark the data that you want to update.'"));
		Return;
	EndIf;
	
	// Setting the normal color for all items
	HighlightChanges(
		"BaseFunctionalitySubsystemData,
		|InternalEventParameters,
		|MetadataObjectIDs,
		|ProgramInterfaceCache, 
		| 
		|UsersSubsystemData,
		|UserSessionParameters,
		|UserGroupContent,
		| 
		|ReportOptionsSubsystemData,
		|ReportOptionParameters,
		|ReportOptionsCatalog,
		| 
		|AccessManagementSubsystemData,
		|RoleRights,
		|RightDependencies,
		|AccessKindsProperties,
		|SuppliedAccessGroupProfilesDescription,
		|AvailableRightsForObjectRightSetupDescription,
		|SuppliedAccessGroupProfiles,
		|InfobaseUserRoles,
		|AccessGroupTables,
		|AccessGroupValues,
		|ObjectRightsSettingsInheritance,
		|ObjectRightsSettings,
		|AccessValueGroups,
		|AccessValueSets",
		False);
	
	HasChanges = False;
	UpdateAtServer(HasChanges);
	
	If HasChanges = Undefined Then
		ShowMessageBox(,
			NStr("en = 'The current data area was changed after opening the data processor.
			           |Check the settings and repeat the command if necessary.'"));
		Return;
	EndIf;
	
	If UpdateSharedData And UpdateSeparatedData Then
		
		If HasChanges Then
			Text = NStr("en = 'The update is completed.'");
		Else
			Text = NStr("en = 'The update is not required.'");
		EndIf;
		
	ElsIf UpdateSharedData Then
		
		If HasChanges Then
			Text = NStr("en = 'Shared data update is completed.'");
		Else
			Text = NStr("en = 'Shared data update is not required.'");
		EndIf;
	Else
		If HasChanges Then
			Text = NStr("en = 'Separated data update is completed.'");
		Else
			Text = NStr("en = 'Separated data update is not required.'");
		EndIf;
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateAtServer(HasChanges)
	
	If UpdateCurrentDataArea() Then
		HasChanges = Undefined;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		PerformSharedDataUpdate(HasChanges);
		UpdateSeparatedData(HasChanges);
	Else
		If UpdateSharedData Then
			BackToCurrentDataArea = False;
			
			If CommonUseCached.CanUseSeparatedData() Then
				// Temporary logout from the data area
				BackToCurrentDataArea = True;
				CommonUse.SetSessionSeparation(False);
				RefreshReusableValues();
			EndIf;
			
			Try
				// Updating shared data.
				PerformSharedDataUpdate(HasChanges);
			Except
				If BackToCurrentDataArea Then
					CommonUse.SetSessionSeparation(True, CurrentDataArea);
				EndIf;
				RefreshReusableValues();
				Raise;
			EndTry;
			
			If BackToCurrentDataArea Then
				CommonUse.SetSessionSeparation(True, CurrentDataArea);
				RefreshReusableValues();
			EndIf;
		EndIf;
		
		If UpdateSeparatedData Then
			// Updating data belonging to the data area
			UpdateSeparatedData(HasChanges);
		EndIf;
	EndIf;
	
	UpdateCurrentDataArea();
	
EndProcedure

&AtServer
Procedure PerformSharedDataUpdate(HasOverallChanges)
	
	SetPrivilegedMode(True);
	
	// StandardSubsystems BaseFunctionality
	If SetupMode = ""
	 Or SetupMode = "SimpleSetup" And BaseFunctionalitySubsystemData  
	 Or SetupMode = "ComplexSetup" And InternalEventParameters Then
		
		HasChanges = False;
		Constants.InternalEventParameters.CreateValueManager().Update(HasChanges);
		
		If HasChanges Then
			HasOverallChanges = True;
			HighlightChanges("BaseFunctionalitySubsystemData, InternalEventParameters");
		EndIf;
	EndIf;
	
	If SetupMode = ""
	 Or SetupMode = "SimpleSetup" And BaseFunctionalitySubsystemData  
	 Or SetupMode = "ComplexSetup" And MetadataObjectIDs Then
		
		HasChanges = False;
		Catalogs.MetadataObjectIDs.UpdateCatalogData(HasChanges);
		
		If HasChanges Then
			HasOverallChanges = True;
			HighlightChanges("BaseFunctionalitySubsystemData, MetadataObjectIDs");
		EndIf;
	EndIf;
	
	If SetupMode = ""
	 Or SetupMode = "SimpleSetup" And BaseFunctionalitySubsystemData  
	 Or SetupMode = "ComplexSetup" And ProgramInterfaceCache Then
		
		HasChanges = False;
		ClearProgramInterfaceCache(HasChanges);
		
		If HasChanges Then
			HasOverallChanges = True;
			HighlightChanges("BaseFunctionalitySubsystemData, ProgramInterfaceCache");
		EndIf;
	EndIf;
	
	// StandardSubsystems Users
	If SetupMode = ""
	 Or SetupMode = "SimpleSetup" And UsersSubsystemData
	 Or SetupMode = "ComplexSetup" And UserSessionParameters Then
		
		HasChanges = False;
		Constants.UserSessionParameters.CreateValueManager().UpdateCommonParameters(HasChanges);
		
		If HasChanges Then
			HasOverallChanges = True;
			HighlightChanges("UsersSubsystemData, UserSessionParameters");
		EndIf;
	EndIf;
	
	// StandardSubsystems AccessManagement
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
	
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And RoleRights Then
			
			HasChanges = False;
			InformationRegisters["RoleRights"].UpdateRegisterData(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, RoleRights");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And RightDependencies Then
			
			HasChanges = False;
			InformationRegisters["AccessRightDependencies"].UpdateRegisterData(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, RightDependencies");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And AccessKindsProperties Then
			
			HasChanges = False;
			Constants["AccessRestrictionParameters"].CreateValueManager(
				).UpdateAccessKindPropertyDescription(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, AccessKindsProperties");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And SuppliedAccessGroupProfilesDescription Then
			
			HasChanges = False;
			Catalogs["AccessGroupProfiles"].UpdatePredefinedProfileContent(HasChanges);
			Catalogs["AccessGroupProfiles"].UpdateSuppliedProfilesDescription(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, SuppliedAccessGroupProfilesDescription");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And AvailableRightsForObjectRightSetupDescription Then
			
			HasChanges = False;
			InformationRegisters["ObjectRightsSettings"].UpdateAvailableRightsForObjectRightSetup(
				HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, AvailableRightsForObjectRightSetupDescription");
			EndIf;
		EndIf;
	
	EndIf;
	
	// StandardSubsystems ReportOptions
	If CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		ReportOptionsModule = CommonUse.CommonModule("ReportOptions");
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And ReportOptionsSubsystemData
		 Or SetupMode = "ComplexSetup" And ReportOptionParameters Then
			
			UpdateParameters = New Structure;
			UpdateParameters.Insert("ExclusiveMode", True);
			UpdateParameters.Insert("SeparatedHandlers",
				InfobaseUpdate.NewUpdateHandlerTable());
			
			HasChanges = False;
			ReportOptionsModule.PerformSharedDataUpdate(UpdateParameters);
			ReportOptionsModule.DeferredFullSharedDataUpdate();
			HasChanges = True; // The change availability check is not supported
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("ReportOptionsSubsystemData, ReportOptionParameters");
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSeparatedData(HasOverallChanges)
	
	SetPrivilegedMode(True);
	
	// StandardSubsystems Users
	If SetupMode = ""
	 Or SetupMode = "SimpleSetup" And UsersSubsystemData
	 Or SetupMode = "ComplexSetup" And UserGroupContent Then
		
		HasChanges = False;
		InformationRegisters["UserGroupContent"].UpdateRegisterData(HasChanges);
		
		If HasChanges Then
			HasOverallChanges = True;
			HighlightChanges("UsersSubsystemData, UserGroupContent");
		EndIf;
	EndIf;
	
	// StandardSubsystems AccessManagement
	If CommonUse.SubsystemExists("StandardSubsystems.AccessManagement") Then
		AccessManagementInternalModule = CommonUse.CommonModule("AccessManagementInternal");
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And SuppliedAccessGroupProfiles Then
			
			HasChanges = False;
			Catalogs["AccessGroups"].MarkForDeletionSelectedProfilesAccessGroups(HasChanges);
			Catalogs["AccessGroupProfiles"].UpdateSuppliedProfiles(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, SuppliedAccessGroupProfiles");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And InfobaseUserRoles Then
			
			HasChanges = False;
			AccessManagementInternalModule.UpdateUserRoles(, , HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("InfobaseUserRoles");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And AccessGroupTables Then
			
			HasChanges = False;
			InformationRegisters["AccessGroupTables"].UpdateRegisterData( , , HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, AccessGroupTables");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And AccessGroupValues Then
			
			HasChanges = False;
			InformationRegisters["AccessGroupValues"].UpdateRegisterData( , HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, AccessGroupValues");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And ObjectRightsSettingsInheritance Then
			
			HasChanges = False;
			InformationRegisters["ObjectRightsSettingsInheritance"].UpdateRegisterData(, HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, ObjectRightsSettingsInheritance");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And ObjectRightsSettings Then
			
			HasChanges = False;
			InformationRegisters["ObjectRightsSettings"].UpdateAuxiliaryRegisterData(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, ObjectRightsSettings");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And AccessValueGroups Then
			
			HasChanges = False;
			InformationRegisters["AccessValueGroups"].UpdateRegisterData(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, AccessValueGroups");
			EndIf;
		EndIf;
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And AccessManagementSubsystemData
		 Or SetupMode = "ComplexSetup" And AccessValueSets Then
			
			HasChanges = False;
			InformationRegisters["AccessValueSets"].UpdateRegisterData(HasChanges);
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("AccessManagementSubsystemData, AccessValueSets");
			EndIf;
		EndIf;
		
	EndIf;
	
	// StandardSubsystems ReportOptions
	If CommonUse.SubsystemExists("StandardSubsystems.ReportOptions") Then
		ReportOptionsModule = CommonUse.CommonModule("ReportOptions");
		
		If SetupMode = ""
		 Or SetupMode = "SimpleSetup" And ReportOptionsSubsystemData
		 Or SetupMode = "ComplexSetup" And ReportOptionsCatalog Then
			
			HasChanges = False;
			ReportOptionsModule.UpdateSeparatedData();
			ReportOptionsModule.DeferredFullSeparatedDataUpdate();
			HasChanges = True; // The change availability check is not supported
			
			If HasChanges Then
				HasOverallChanges = True;
				HighlightChanges("ReportOptionsSubsystemData, ReportOptionsCatalog");
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateItemsEnabled(Form)
	
	Items = Form.Items;
	
	// StandardSubsystems BaseFunctionality
	Items.InternalEventParameters.Enabled                       = Form.UpdateSharedData;
	Items.MetadataObjectIDs.Enabled                             = Form.UpdateSharedData;
	Items.ProgramInterfaceCache.Enabled                         = Form.UpdateSharedData;
	
	// StandardSubsystems Users
	Items.UserSessionParameters.Enabled                         = Form.UpdateSharedData;
	Items.UserGroupContent.Enabled                              = Form.UpdateSeparatedData;
	
	// StandardSubsystems AccessManagement
	Items.RoleRights.Enabled                                    = Form.UpdateSharedData;
	Items.RightDependencies.Enabled                             = Form.UpdateSharedData;
	Items.AccessKindsProperties.Enabled                          = Form.UpdateSharedData;
	Items.SuppliedAccessGroupProfilesDescription.Enabled        = Form.UpdateSharedData;
	Items.AvailableRightsForObjectRightSetupDescription.Enabled = Form.UpdateSharedData;
	Items.SuppliedAccessGroupProfiles.Enabled                   = Form.UpdateSeparatedData;
	Items.InfobaseUserRoles.Enabled                             = Form.UpdateSeparatedData;
	Items.AccessGroupTables.Enabled                             = Form.UpdateSeparatedData;
	Items.AccessGroupValues.Enabled                             = Form.UpdateSeparatedData;
	Items.ObjectRightsSettingsInheritance.Enabled               = Form.UpdateSeparatedData;
	Items.ObjectRightsSettings.Enabled                          = Form.UpdateSeparatedData;
	Items.AccessValueGroups.Enabled                             = Form.UpdateSeparatedData;
	Items.AccessValueSets.Enabled                               = Form.UpdateSeparatedData;
	
	// StandardSubsystems ReportOptions
	Items.ReportOptionParameters.Enabled                        = Form.UpdateSharedData;
	Items.ReportOptionsCatalog.Enabled                          = Form.UpdateSeparatedData;
	
EndProcedure

&AtServer
Procedure UpdateVisibilityBySetupMode()
	
	UpdateCurrentDataArea();
	
	If SetupMode = "SimpleSetup" Then
		Items.SimpleSetup.Visible = True;
		Items.ComplexSetup.Visible = False;
		
	ElsIf SetupMode = "ComplexSetup" Then
		Items.SimpleSetup.Visible = False;
		Items.ComplexSetup.Visible = True;
		
	Else // No settings
		Items.SimpleSetup.Visible = False;
		Items.ComplexSetup.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure HighlightChanges(ItemNames, HasChanges = True)
	
	If ClientApplicationInterfaceCurrentVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		ChangeHighlightColor = New Color(0, 128, 0); // Green (web color)
	Else
		ChangeHighlightColor = New Color(0, 0, 255); // Blue (web color)
	EndIf;
	NormalColor   = Items.DataArea.TitleTextColor; // Auto
	
	MultipleItemDescription= New Structure(ItemNames);
	For Each SingleItemDescription In MultipleItemDescription Do
		Items[SingleItemDescription.Key].TitleTextColor = ?(HasChanges, ChangeHighlightColor, NormalColor);
	EndDo;
	
EndProcedure

&AtServer
Function UpdateCurrentDataArea()
	
	If Not CommonUseCached.DataSeparationEnabled()
	 Or Not UpdateSharedData Then
		
		Return False;
	EndIf;
	
	SessionSeparatorValue = Undefined;
	
	If CommonUseCached.CanUseSeparatedData() Then
		SessionSeparatorValue = CommonUse.SessionSeparatorValue();
	EndIf;
	
	CurrentDataAreaChanged = CurrentDataArea <> SessionSeparatorValue;
	
	If CurrentDataAreaChanged Then
		CurrentDataArea = SessionSeparatorValue;
	EndIf;
	
	If CurrentDataArea = Undefined Then
		UpdateSeparatedData = False;
	Else
		UpdateSeparatedData = True;
	EndIf;
	
	UpdateItemsEnabled(ThisObject);
	
	Return CurrentDataAreaChanged;
	
EndFunction

&AtServer
Procedure ClearProgramInterfaceCache(HasChanges)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.ProgramInterfaceCache AS ProgramInterfaceCache";
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	HasChanges = True;
	
	RecordSet = InformationRegisters.ProgramInterfaceCache.CreateRecordSet();
	RecordSet.Write();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Copied from CommonForm.LogOnToDataArea

&AtClient
Procedure LogOnToDataArea()
	
	If Not IsFilledDataArea(DataArea) Then
		ShowQueryBox(
			New NotifyDescription("LogOnToDataAreaCompletion", ThisObject),
			NStr("en = 'The selected data area is empty. Do you want to log on to the data area?'"),
			QuestionDialogMode.YesNo,
			,
			DialogReturnCode.No);
	Else
		LogOnToDataAreaCompletion(Undefined, Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure LogOnToDataAreaCompletion(Answer, NotDefined) Export
	
	If Answer = DialogReturnCode.No Then
		Return;
	EndIf;
	
	LogOnToDataAreaAtServer(DataArea);
	
	RefreshInterface();
	
	CompletionHandler = New NotifyDescription(
		"ContinueLogOnToDataAreaAfterBeforeStartActions", ThisObject);
	
	StandardSubsystemsClient.BeforeStart(CompletionHandler);
	
EndProcedure

&AtClient
Procedure ContinueLogOnToDataAreaAfterBeforeStartActions(Result, NotDefined) Export
	
	If Result.Cancel Then
		LogOffFromDataAreaAtServer();
		RefreshInterface();
		Return;
	EndIf;
	
	CompletionHandler = New NotifyDescription(
		"ContinueLogOnToDataAreaAfterOnStartActions", ThisObject);
	
	StandardSubsystemsClient.OnStart(CompletionHandler);
	
EndProcedure

&AtClient
Procedure ContinueLogOnToDataAreaAfterOnStartActions(Result, NotDefined) Export
	
	If Result.Cancel Then
		LogOffFromDataAreaAtServer();
		RefreshInterface();
	EndIf;
	
	Activate();
	
EndProcedure

&AtClient
Procedure LogOffFromDataArea(Cancel)
	
	CompletionHandler = New NotifyDescription(
		"ContinueLogOffFromDataAreaAfterBeforeExitActions", ThisObject);
	
	StandardSubsystemsClient.BeforeExit(, CompletionHandler);
	
EndProcedure

&AtClient
Procedure ContinueLogOffFromDataAreaAfterBeforeExitActions(Result, NotDefined) Export
	
	If Result.Cancel Then
		Return;
	EndIf;
	
	LogOffFromDataAreaAtServer();
	
	RefreshInterface();
	
	StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	
EndProcedure

&AtServerNoContext
Function IsFilledDataArea(Val DataArea)
	
	SetPrivilegedMode(True);
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.DataAreas");
	LockItem.SetValue("DataAreaAuxiliaryData", DataArea);
	LockItem.Mode = DataLockMode.Shared;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.Status AS Status
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataAreaAuxiliaryData = &DataArea";
	Query.SetParameter("DataArea", DataArea);
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		Return False;
	Else
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Status = Enums["DataAreaStatuses"].Used;
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure LogOnToDataAreaAtServer(Val DataArea)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
	BeginTransaction();
	
	Try
		AreaKey = InformationRegisters["DataAreas"].CreateRecordKey(
			New Structure("DataAreaAuxiliaryData", DataArea));
		
		LockDataForEdit(AreaKey);
		
		DataLock = New DataLock;
		Item = DataLock.Add("InformationRegister.DataAreas");
		Item.SetValue("DataAreaAuxiliaryData", DataArea);
		Item.Mode = DataLockMode.Shared;
		DataLock.Lock();
		
		RecordManager = InformationRegisters["DataAreas"].CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			RecordManager.DataAreaAuxiliaryData = DataArea;
			RecordManager.Status = Enums.DataAreaStatuses.Used;
			RecordManager.Write();
		EndIf;
		UnlockDataForEdit(AreaKey);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServerNoContext
Procedure LogOffFromDataAreaAtServer()
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

#EndRegion
