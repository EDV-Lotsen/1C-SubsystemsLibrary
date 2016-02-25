
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
  // Skipping the initialization to guarantee that the form 
  // will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then
		Return;
	EndIf;
	
	List.Parameters.Items[0].Value = Parameters.InfobaseNode;
	List.Parameters.Items[0].Use = True;
	
	Title = NStr("en = 'Synchronization scenario setup for: [InfobaseNode]'");
	Title = StrReplace(Title, "[InfobaseNode]", String(Parameters.InfobaseNode));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_DataExchangeScenarios" Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemEventHandlers

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.List.RowData(SelectedRow);
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Field = Items.UseImportFlag Then
		
		EnableDisableImportAtServer(CurrentData.UseImportFlag, CurrentData.Ref);
		
	ElsIf Field = Items.UseExportFlag Then
		
		EnableDisableExportAtServer(CurrentData.UseExportFlag, CurrentData.Ref);
		
	ElsIf Field = Items.Description Then
		
		EditDataExchangeScenario(Undefined);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Create(Command)
	
	FormParameters = New Structure("InfobaseNode", Parameters.InfobaseNode);
	
	OpenForm("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EditDataExchangeScenario(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", CurrentData.Ref);
	
	OpenForm("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure EnableDisableScheduledJob(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableScheduledJobAtServer(CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EnableDisableExport(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableExportAtServer(CurrentData.UseExportFlag, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EnableDisableImport(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableImportAtServer(CurrentData.UseImportFlag, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure EnableDisableImportExport(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	EnableDisableImportExportAtServer(CurrentData.UseImportFlag Or CurrentData.UseExportFlag, CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure ExecuteScenario(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Message = NStr("en = 'Synchronizing data according to %1 scenario...'");
	Message = StringFunctionsClientServer.SubstituteParametersInString(Message, String(CurrentData.Ref));
	
	Status(Message);
	
	Cancel = False;
	
	// Starting synchronization
	DataExchangeServerCall.ExecuteDataExchangeUsingDataExchangeScenario(Cancel, CurrentData.Ref);
	
	If Cancel Then
		Message = NStr("en = 'Synchronization scenario completed with errors.'");
		Picture = PictureLib.Error32;
	Else
		Message = NStr("en = 'Synchronization scenario completed (no errors).'");
		Picture = Undefined;
	EndIf;
	
	Status(Message,,, Picture);
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure EnableDisableScheduledJobAtServer(Ref)
	
	SettingsObject = Ref.GetObject();
	SettingsObject.UseScheduledJob = Not SettingsObject.UseScheduledJob;
	SettingsObject.Write();
	
	// Updating list data
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableExportAtServer(Val UseExportFlag, Val DataExchangeScenario)
	
	If UseExportFlag Then
		
		Catalogs.DataExchangeScenarios.DeleteExportFromDataExchangeScenario(DataExchangeScenario, Parameters.InfobaseNode);
		
	Else
		
		Catalogs.DataExchangeScenarios.AddExportToDataExchangeScenarios(DataExchangeScenario, Parameters.InfobaseNode);
		
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableImportAtServer(Val UseImportFlag, Val DataExchangeScenario)
	
	If UseImportFlag Then
		
		Catalogs.DataExchangeScenarios.DeleteImportFromDataExchangeScenario(DataExchangeScenario, Parameters.InfobaseNode);
		
	Else
		
		Catalogs.DataExchangeScenarios.AddImportToDataExchangeScenarios(DataExchangeScenario, Parameters.InfobaseNode);
		
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableImportExportAtServer(Val UsageFlag, Val DataExchangeScenario)
	
	EnableDisableImportAtServer(UsageFlag, DataExchangeScenario);
	
	EnableDisableExportAtServer(UsageFlag, DataExchangeScenario);
	
EndProcedure

#EndRegion
