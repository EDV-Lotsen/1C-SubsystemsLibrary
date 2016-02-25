////////////////////////////////////////////////////////////////////////////////
// Information center subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Adds handlers of internal events (subscriptions).

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	If CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations.MessageExchange") Then
		ServerHandlers["StandardSubsystems.SaaSOperations.MessageExchange\MessageChannelHandlersOnDefine"].Add(
			"InformationCenterInternal");
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations.SuppliedData") Then
		ServerHandlers["StandardSubsystems.SaaSOperations.SuppliedData\OnDefineSuppliedDataHandlers"].Add(
			"InformationCenterInternal");
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		ServerHandlers[
			"StandardSubsystems.SaaSOperations\InfobaseParameterTableOnFill"].Add(
				"InformationCenterInternal");
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("StandardSubsystems.SaaSOperations") Then
		ServerHandlers["StandardSubsystems.SaaSOperations.MessageExchange\RecordingIncomingMessageInterfaces"].Add(
			"InformationCenterInternal");
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.DataImportExport") Then
		ServerHandlers[
			"CloudTechnology.DataImportExport\OnFillExcludedFromImportExportTypes"].Add(
				"InformationCenterInternal");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal event handlers of SL subsystems

// Fills the passed array with common modules that contain handlers for interfaces of incoming messages.
//
// Parameters:
//  HandlerArray - array.
//
Procedure RecordingIncomingMessageInterfaces(HandlerArray) Export
	
	HandlerArray.Add(InformationCenterMessagesInterface);
	
EndProcedure

// Generates the list of infobase parameters.
//
// Parameters:
// ParameterTable - ValueTable - parameter description table.
// For description of column content, see SaaSOperations.GetInfobaseParameterTable().
//
Procedure InfobaseParameterTableOnFill(Val ParameterTable) Export
	
	SaasOperationsModule = CTLAndSLIntegration.CommonModule("SaaSOperations");
	SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "ForumManagementURL");
	SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "InformationCenterForumUserName");
	SaasOperationsModule.AddConstantToInfobaseParameterTable(ParameterTable, "InformationCenterForumPassword");
	
EndProcedure

// Gets the list of message handlers that are processed by the library subsystems.
// 
// Parameters:
//  Handlers - ValueTable - see the field structure in MessageExchange.NewMessageHandlerTable.
// 
Procedure MessageChannelHandlersOnDefine(Handlers) Export
	
	InformationCenterMessagesMessageHandler.GetMessageChannelHandlers(Handlers);
	
EndProcedure

// Registers supplied data handlers
//
// When a new shared data notification is received, NewDataAvailable
// procedures from modules registered with GetSuppliedDataHandlers are called.
// The descriptor passed to the procedure is XDTODataObject Descriptor.
// 
// If NewDataAvailable sets Import to True, the data is imported, and the descriptor and the path to the data file are passed to ProcessNewData() procedure. The file is automatically deleted once the procedure is executed.
// If the file is not specified in Service Manager, the parameter value is Undefined.
//
// Parameters: 
//   Handlers - ValueTable - table for adding handlers. 
//       Columns:
//        DataKind - String - code of the data kind processed by the handler. 
//        HandlerCode - Sting(20) - used for recovery after a data processing error.
//        Handler, CommonModule - module that contains the following procedures:
//          NewDataAvailable(Descriptor, Import) Export
//          ProcessNewData(Descriptor, Import) Export
//          DataProcessingCanceled(Descriptor) Export
//
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	InformationCenterInternal.RegisterSuppliedDataHandlers(Handlers);
	
EndProcedure

// Fills the array of types excluded from data import and export.
//
// Parameters:
//  Types - Array(Types).
//
Procedure OnFillExcludedFromImportExportTypes(Types) Export
	
	Types.Add(Metadata.InformationRegisters.ViewedInformationCenterData);
	
EndProcedure

// Adds update handlers that are required by the subsystem.
//
// Parameters:
//  Handlers - ValueTable - see the description of NewUpdateHandlerTable function 
//                          in the InfobaseUpdate common module.
//
Procedure OnAddUpdateHandlers(Handlers) Export
	
	InformationCenterInternal.RegisterUpdateHandlers(Handlers);
	
EndProcedure

// Adds update handlers required by the subsystem to the Handlers list.
//
// Parameters:
//   Handlers - ValueTable - see the description of NewUpdateHandlerTable function 
//                           in the InfobaseUpdate common module.
// 
Procedure RegisterUpdateHandlers(Handlers) Export
	
	Handler               = Handlers.Add();
	Handler.Version       = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData    = True;
	Handler.Procedure     = "InformationCenterInternal.GenerateFullPathToFormsCatalog";
	
	If CTLAndSLIntegration.DataSeparationEnabled() Then
		Handler               = Handlers.Add();
		Handler.Version       = "*";
		Handler.ExclusiveMode = False;
		Handler.SharedData    = True;
		Handler.Procedure     = "InformationCenterInternal.UpdateInformationLinksForFormsSaaS";
	Else
		Handler               = Handlers.Add();
		Handler.Version       = "*";
		Handler.ExclusiveMode = False;
		Handler.Procedure     = "InformationCenterInternal.UpdateInformationLinksForFormsInLocalMode";
	EndIf;
	
EndProcedure

// Populates the FullPathToForms catalog with full paths to forms.
//
Procedure GenerateFullPathToFormsCatalog() Export
	
	// Generating a table with a list of full configuration forms
	FormTable = New ValueTable;
	FormTable.Columns.Add("FullPathToForm", New TypeDescription("String"));
	
	AddFormsToCatalog(FormTable, "CommonForms");
	AddFormsToCatalog(FormTable, "ExchangePlans");
	AddFormsToCatalog(FormTable, "Catalogs");
	AddFormsToCatalog(FormTable, "Documents");
	AddFormsToCatalog(FormTable, "DocumentJournals");
	AddFormsToCatalog(FormTable, "Enums");
	AddFormsToCatalog(FormTable, "Reports");
	AddFormsToCatalog(FormTable, "DataProcessors");
	AddFormsToCatalog(FormTable, "ChartsOfCharacteristicTypes");
	AddFormsToCatalog(FormTable, "ChartsOfAccounts");
	AddFormsToCatalog(FormTable, "ChartsOfCalculationTypes");
	AddFormsToCatalog(FormTable, "InformationRegisters");
	AddFormsToCatalog(FormTable, "AccumulationRegisters");
	AddFormsToCatalog(FormTable, "AccountingRegisters");
	AddFormsToCatalog(FormTable, "CalculationRegisters");
	AddFormsToCatalog(FormTable, "BusinessProcesses");
	AddFormsToCatalog(FormTable, "Tasks");
	AddFormsToCatalog(FormTable, "SettingsStorages");
	AddFormsToCatalog(FormTable, "FilterCriteria");
	
	// Populating the FullPathsToForms catalog
	Query = New Query;
	Query.SetParameter("FormTable", FormTable);
	Query.Text =
	"SELECT
	|	FormTable.FullPathToForm AS FullPathToForm
	|INTO FormTable
	|FROM
	|	&FormTable AS FormTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FullPathToForms.Ref AS Ref,
	|	FormTable.FullPathToForm AS FullPathToForm
	|FROM
	|	Catalog.FullPathToForms AS FullPathToForms
	|		FULL JOIN FormTable AS FormTable
	|		ON (SUBSTRING(FullPathToForms.FullPathToForm, 1, 1000) = SUBSTRING(FormTable.FullPathToForm, 1, 1000))
	|WHERE
	|	FullPathToForms.Ref IS NULL ";
	FormSelection = Query.Execute().Select();
	While FormSelection.Next() Do 
		AddFullNameToCatalog(FormSelection.FullPathToForm);
	EndDo;
	
EndProcedure

// When updating configuration, the list of information links for forms must be updated as well.
// Service manager should used for this purpose.
//
Procedure UpdateInformationLinksForFormsSaaS() Export
	
	Try
		SetPrivilegedMode(True);
		ConfigurationName = Metadata.Name;
		SetPrivilegedMode(False);
		WebServiceProxy = InformationCenterServer.GetInformationCenterProxy_1_0_1_1();
		Result = WebServiceProxy.UpdateInfoReference(ConfigurationName);
		If Result Then 
			Return;
		EndIf;
		
		ErrorText = NStr("en = 'Cannot update information links'");
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , ErrorText);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// When updating configuration, the list of information links for forms must be updated as well.
// Service manager should used for this purpose.
//
Procedure UpdateInformationLinksForFormsInLocalMode() Export
	
	PathToFile = GetTempFileName("xml");
	If IsBlankString(PathToFile) Then 
		Return;
	EndIf;
	
	TextDocument = GetCommonTemplate("InformationLinks");
	TextDocument.Write(PathToFile);
	Try
		LoadInformationLinks(PathToFile);
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Returns numerical presentation of a version string.
//
// Parameters:
// Version - String - version.
//
// Returns:
// Number - numerical version presentation.
//
Function GetVersionNumber(Version) Export
	
	NumberArray = StringFunctionsClientServer.SplitStringIntoSubstringArray(Version, ".");
	
	Iteration           = 1;
	VersionNumber       = 0;
	CountInArray = NumberArray.Count();
	
	If CountInArray = 0 Then 
		Return 0;
	EndIf;
	
	For Each VersionDigit In NumberArray Do 
		
		Try
			CurrentNumber = Number(VersionDigit);
			VersionNumber = VersionNumber + CurrentNumber * RiseNumberToPositivePower(1000, CountInArray - Iteration);
		Except
			Return 0;
		EndTry;
		
		Iteration = Iteration + 1;
		
	EndDo;
	
	Return VersionNumber;
	
EndFunction


////////////////////////////////////////////////////////////////////////////////
// SUPPLIED DATA GETTING HANDLERS

// Registers supplied data handlers, both daily and total.
//
Procedure RegisterSuppliedDataHandlers(Val Handlers) Export
	
	Handler                = Handlers.Add();
	Handler.DataKind      = "InformationLinks";
	Handler.HandlerCode = "InformationLinks";
	Handler.Handler     = InformationCenterInternal;
	
EndProcedure

// The procedure is called when a new data notification is received.
// In the procedure body, check whether the application requires this data. If it does, set the Import flag.
// 
// Parameters:
//   Descriptor - XDTODataObject Descriptor.
//   Import     - Boolean - return value.
//
Procedure NewDataAvailable(Val Descriptor, Import) Export
	
	If Descriptor.DataType = "InformationLinks" Then
		
		ConfigurationName = GetConfigurationNameByDescriptor(Descriptor);
		If ConfigurationName = Undefined Then 
			Import = False;
			Return;
		EndIf;
		
		Import = ?(Upper(Metadata.Name) = Upper(ConfigurationName), True, False);
		
	EndIf;
	
EndProcedure

// The procedure is called after calling NewDataAvailable, it parses the data.
//
// Parameters:
//   Descriptor   - XDTODataObject Descriptor.
//   PathToFile   - String or Undefined. Extracted file full name. 
//                  The file is automatically deleted once the procedure is executed. 
//                  If the file is not specified in Service Manager, the parameter value is Undefined.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	If Descriptor.DataType = "InformationLinks" Then
		ProcessInformationLinks(Descriptor, PathToFile);
	EndIf;
	
EndProcedure

// The procedure is called if data processing is canceled due to an error.
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

Procedure ProcessInformationLinks(Descriptor, PathToFile)
	
	LoadInformationLinks(PathToFile);
	
EndProcedure

Function GetConfigurationNameByDescriptor(Descriptor)
	
	For Each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.Code = "PlacementObject" Then
			Try
				Return Characteristic.Value;
			Except
				EventName = InformationCenterServer.GetEventNameForEventLog();
				WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
				Return Undefined;
			EndTry;
			Break;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Procedure LoadInformationLinks(PathToFile)
	
	// Generating tag tree
	TagTree = GetTagTree();
	
	UpdateDate = CurrentDate(); // SL project design
	
	InformationLinkType    = XDTOFactory.Type("http://www.1c.ru/SaaS/1.0/XMLSchema/ManageInfoCenter/InformationReferences", "reference"); 
	InformationLinksReader = New XMLReader; 
	InformationLinksReader.OpenFile(PathToFile); 
	
	InformationLinksReader.MoveToContent();
	InformationLinksReader.Read();
	
	While InformationLinksReader.NodeType = XMLNodeType.StartElement Do 
		
		InformationLink = XDTOFactory.ReadXML(InformationLinksReader, InformationLinkType);
		
		// Predefined item
		If Not IsBlankString(InformationLink.namePredifined) Then 
			Try
				WritePredefinedInformationLink(InformationLink);
			Except
				EventName = InformationCenterServer.GetEventNameForEventLog();
				WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
			EndTry;
			Continue;
		EndIf;
		
		// Standard item
		If TypeOf(InformationLink.context) = Type("XDTOList") Then 
			For Each Context In InformationLink.context Do 
				Try
					WriteLinkByContexts(TagTree, InformationLink, Context, UpdateDate);
				Except
					EventName = InformationCenterServer.GetEventNameForEventLog();
					WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
				EndTry;
			EndDo;
		Else
			WriteLinkByContexts(TagTree, InformationLink, InformationLink.context, UpdateDate);
		EndIf;
		
	EndDo;
	
	InformationLinksReader.Close();
	
	ClearNotUpdatedLinks(UpdateDate);
	
EndProcedure

Procedure WritePredefinedInformationLink(LinkObject)
	
	Try
		ItemCatalog = Catalogs.InformationLinksForForms[LinkObject.namePredifined].GetObject();
	Except
		EventName = InformationCenterServer.GetEventNameForEventLog();
		WriteLogEvent(EventName, EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	ItemCatalog.Address      = LinkObject.address;
	ItemCatalog.StartDate    = LinkObject.dateFrom;
	ItemCatalog.EndDate      = LinkObject.dateTo;
	ItemCatalog.Description  = LinkObject.name;
	ItemCatalog.Tooltip      = LinkObject.helpText;
	ItemCatalog.Write();
	
EndProcedure

Procedure ClearNotUpdatedLinks(UpdateDate)
	
	SetPrivilegedMode(True);
	CatalogSelection = Catalogs.InformationLinksForForms.Select();
	While CatalogSelection.Next() Do 
		
		If CatalogSelection.Predefined Then 
			Continue;
		EndIf;
		
		If CatalogSelection.UpdateDate = UpdateDate Then 
			Continue;
		EndIf;
		
		Object = CatalogSelection.GetObject();
		Object.DataExchange.Load = True;
		Object.Delete();
		
	EndDo;
	
EndProcedure

Procedure WriteLinkByContexts(TagTree, LinkObject, Context, UpdateDate)
	
	Result = ValidateFormNameExistenceByTag(Context.tag);
	If Result.IsPathToForm Then 
		WriteLinkByContext(LinkObject, Context, Result.PathToForm, UpdateDate);
		Return;
	EndIf;
	
	Tag      = Context.tag;
	FoundRow = TagTree.Rows.Find(Tag, "Name");
	If FoundRow = Undefined Then 
		Return;
	EndIf;
	
	For Each TreeRow In FoundRow.Rows Do 
		
		FormName = TreeRow.Name;
		ReferenceToPathToForm = PathToFormInCatalogRef(FormName);
		If ReferenceToPathToForm.IsEmpty() Then 
			Continue;
		EndIf;
		
		WriteLinkByContext(LinkObject, Context, ReferenceToPathToForm, UpdateDate);
		
	EndDo;
	
EndProcedure

Procedure WriteLinkByContext(LinkObject, Context, ReferenceToPathToForm, UpdateDate)
	
	SetPrivilegedMode(True);
	Ref = HasInformationLinkForCurrentForm(LinkObject.address, ReferenceToPathToForm);
	
	If Ref = Undefined Then 
		ItemCatalog = Catalogs.InformationLinksForForms.CreateItem();
	Else
		ItemCatalog = Ref.GetObject();
	EndIf;
	
	ItemCatalog.Address                         = LinkObject.address;
	ItemCatalog.Weight                          = Context.weight;
	ItemCatalog.StartDate                       = LinkObject.dateFrom;
	ItemCatalog.EndDate                         = LinkObject.dateTo;
	ItemCatalog.Description                     = LinkObject.name;
	ItemCatalog.Tooltip                         = LinkObject.helpText;
	ItemCatalog.FullPathToForm                  = ReferenceToPathToForm;
	ItemCatalog.ConfigurationVersionLaterThen   = GetVersionNumber(Context.versionFrom);
	ItemCatalog.ConfigurationVersionEarlierThen = GetVersionNumber(Context.versionTo);
	ItemCatalog.UpdateDate                      = UpdateDate;
	ItemCatalog.Write();
	
EndProcedure

Function HasInformationLinkForCurrentForm(Address, ReferenceToPathToForm)
	
	Query = New Query;
	Query.SetParameter("FullPathToForm", ReferenceToPathToForm);
	Query.SetParameter("Address",        Address);
	Query.Text = "SELECT
	               |	InformationLinksForForms.Ref AS Ref
	               |FROM
	               |	Catalog.InformationLinksForForms AS InformationLinksForForms
	               |WHERE
	               |	InformationLinksForForms.FullPathToForm = &FullPathToForm
	               |	AND InformationLinksForForms.Address LIKE &Address";
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do 
		Return Selection.Ref;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function ValidateFormNameExistenceByTag(Tag)
	
	Result = New Structure("IsPathToForm", False);
	
	Query = New Query;
	Query.SetParameter("FullPathToForm", Tag);
	Query.Text = 
	"SELECT
	|	FullPathToForms.Ref AS Ref
	|FROM
	|	Catalog.FullPathToForms AS FullPathToForms
	|WHERE
	|	FullPathToForms.FullPathToForm LIKE &FullPathToForm";
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then 
		Return Result;
	EndIf;
	
	Result.IsPathToForm = True;
	QuerySelection = QueryResult.Select();
	While QuerySelection.Next() Do 
		Result.Insert("PathToForm", QuerySelection.Ref);
		Return Result;
	EndDo;
	
EndFunction

Function GetTagTree()
	
	TagTree = New ValueTree;
	TagTree.Columns.Add("Name", New TypeDescription("String"));
	
	// Reading common template
	TemplateFileName = GetTempFileName("xml");
	GetCommonTemplate("TagAndCommonFormMap").Write(TemplateFileName);
	
	TagsAndFormsMapRecords = New XMLReader;
	TagsAndFormsMapRecords.OpenFile(TemplateFileName);
	
	CurrentTagInTree = Undefined;
	While TagsAndFormsMapRecords.Read() Do
		// Reading current tag
		IsTag = TagsAndFormsMapRecords.NodeType = XMLNodeType.StartElement and Upper(TrimAll(TagsAndFormsMapRecords.Name)) = Upper("tag");
		If IsTag Then 
			While TagsAndFormsMapRecords.ReadAttribute() Do 
				If Upper(TagsAndFormsMapRecords.Name) = Upper("name") Then
					CurrentTagInTree     = TagTree.Rows.Add();
					CurrentTagInTree.Name = TagsAndFormsMapRecords.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
		// Reading form
		IsForm = TagsAndFormsMapRecords.NodeType = XMLNodeType.StartElement and Upper(TrimAll(TagsAndFormsMapRecords.Name)) = Upper("form");
		If IsForm Then 
			While TagsAndFormsMapRecords.ReadAttribute() Do 
				If Upper(TagsAndFormsMapRecords.Name) = Upper("path") Then
					If CurrentTagInTree = Undefined Then 
						Break;
					EndIf;
					CurrentTreeItem      = CurrentTagInTree.Rows.Add();
					CurrentTreeItem.Name = TagsAndFormsMapRecords.Value;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return TagTree;
	
EndFunction

Procedure AddFormsToCatalog(FormTable, MetadataClassName)
	
	MetadataClass     = Metadata[MetadataClassName];
	ItemCount = MetadataClass.Count();
	If MetadataClassName = "CommonForms" Then 
		For ItemIteration = 0 To ItemCount - 1 Do 
			
			FullPathToForm = MetadataClass.Get(ItemIteration).FullName();
			
			TableItem                  = FormTable.Add();
			TableItem.FullPathToForm = FullPathToForm;
			
		EndDo;
		Return;
	EndIf;
	
	For ItemIteration = 0 To ItemCount - 1 Do 
		MetadataClassForms = MetadataClass.Get(ItemIteration).Forms;
		FormCount          = MetadataClassForms.Count();
		For FormIteration = 0 To FormCount - 1 Do 
			
			FullPathToForm = MetadataClassForms.Get(FormIteration).FullName();
			
			TableItem                = FormTable.Add();
			TableItem.FullPathToForm = FullPathToForm;
			
		EndDo;
	EndDo;
	
EndProcedure

Procedure AddFullNameToCatalog(FullFormName)
	
	SetPrivilegedMode(True);
	ItemCatalog = Catalogs.FullPathToForms.CreateItem();
	ItemCatalog.Description    = FullFormName;
	ItemCatalog.FullPathToForm = FullFormName;
	ItemCatalog.Write();
	
EndProcedure

Function PathToFormInCatalogRef(FullFormName)
	
	Query = New Query;
	Query.SetParameter("FullPathToForm", FullFormName);
	Query.Text = 
	"SELECT
	|	FullPathToForms.Ref AS Ref
	|FROM
	|	Catalog.FullPathToForms AS FullPathToForms
	|WHERE
	|	FullPathToForms.FullPathToForm LIKE &FullPathToForm";
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do 
		Return Selection.Ref;
	EndDo;
	
	Return Catalogs.FullPathToForms.EmptyRef();
	
EndFunction

// Raises a number to a power.
//
// Parameters:
// Number - Number - number to be raised to a power.
// Power - Number - number power.
//
// Returns:
// Number - number raised to the specified power.
//
Function RiseNumberToPositivePower(Number, Power)
	
	If Power = 0 Then 
		Return 1;
	EndIf;
	
	If Power = 1 Then 
		Return Number;
	EndIf;
	
	ReturnNumber = Number;
	
	For Iteration = 2 to Power Do 
		ReturnNumber = ReturnNumber * Number;
	EndDo;
	
	Return ReturnNumber;
	
EndFunction

