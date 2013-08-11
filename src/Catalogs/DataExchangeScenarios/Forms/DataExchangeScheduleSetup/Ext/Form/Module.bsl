////////////////////////////////////////////////////////////////////////////////
// FORM EVENT HANDLERS

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	List.Parameters.Items[0].Value = Parameters.InfoBaseNode;
	List.Parameters.Items[0].Use = True;
	
	Title = NStr("en = 'Data exchange scenario setup for: [InfoBaseNode]'");
	Title = StrReplace(Title, "[InfoBaseNode]", String(Parameters.InfoBaseNode));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_DataExchangeScenarios" Then
		
		Items.List.Refresh();
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FORM TABLE EVENT HANDLERS OF List TABLE 

&AtClient
Procedure ListChoice(Item, SelectedRow, Field, StandardProcessing)
	
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

////////////////////////////////////////////////////////////////////////////////
// FORM COMMAND HANDLERS

&AtClient
Procedure Create(Command)
	
	FormParameters = New Structure("InfoBaseNode", Parameters.InfoBaseNode);
	
	OpenFormModal("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure EditDataExchangeScenario(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", CurrentData.Ref);
	
	OpenFormModal("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisForm);
	
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
	
	Message = NStr("en = 'Executing the data exchange by the %1 script...'");
	Message = StringFunctionsClientServer.SubstituteParametersInString(Message, String(CurrentData.Ref));
	
	Status(Message);
	
	Cancel = False;
	
	// Starting the exchange
	DataExchangeServer.ExecuteDataExchangeByDataExchangeScenario(Cancel, CurrentData.Ref);
	
	If Cancel Then
		Message = NStr("en = 'Error executing the exchange script.'");
		Picture = PictureLib.Error32;
	Else
		Message = NStr("en = 'The exchange script executed successfully.'");
		Picture = Undefined;
	EndIf;
	
	Status(Message,,, Picture);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

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
		
		Catalogs.DataExchangeScenarios.DeleteExportFromDataExchangeScenario(DataExchangeScenario, Parameters.InfoBaseNode);
		
	Else
		
		Catalogs.DataExchangeScenarios.AddExportToDataExchangeScenarios(DataExchangeScenario, Parameters.InfoBaseNode);
		
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableImportAtServer(Val UseImportFlag, Val DataExchangeScenario)
	
	If UseImportFlag Then
		
		Catalogs.DataExchangeScenarios.DeleteImportFromDataExchangeScenario(DataExchangeScenario, Parameters.InfoBaseNode);
		
	Else
		
		Catalogs.DataExchangeScenarios.AddImportToDataExchangeScenarios(DataExchangeScenario, Parameters.InfoBaseNode);
		
	EndIf;
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure EnableDisableImportExportAtServer(Val UsageFlag, Val DataExchangeScenario)
	
	EnableDisableImportAtServer(UsageFlag, DataExchangeScenario);
	
	EnableDisableExportAtServer(UsageFlag, DataExchangeScenario);
	
EndProcedure
