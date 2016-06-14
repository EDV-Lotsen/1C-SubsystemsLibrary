////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE
 
////////////////////////////////////////////////////////////////////////////////
// Operations with shared infobase users

// Called when setting session parameters.
//
// Parameters:
//  SessionParameterNames - Array, Undefined.
//
Procedure OnSetSessionSettings(SessionParameterNames) Export
	
	If SessionParameterNames = Undefined Then
		
		If IsSharedInfobaseUser() Then
			RecordSharedUserInRegister();
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks whether an infobase user
// with the specified ID is in the list of shared user.
//
// Parameters:
// InfobaseUserID - UUID - ID
// of the user to
// be checked.
//
Function UserRegisteredAsShared(Val InfobaseUserID) Export
	
	If Not ValueIsFilled(InfobaseUserID) Then
		Return False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SharedUserIDs.InfobaseUserID
	|FROM
	|	InformationRegister.SharedUsers AS SharedUserIDs
	|WHERE
	|	SharedUserIDs.InfobaseUserID = &InfobaseUserID";
	Query.SetParameter("InfobaseUserID", InfobaseUserID);
	
	DataLock = New DataLock;
	LockItem = DataLock.Add("InformationRegister.SharedUsers");
	LockItem.SetValue("InfobaseUserID", InfobaseUserID);
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		DataLock.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return Not Result.IsEmpty();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Adds handlers of internal events (subscriptions).

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	////////////////////////////////////////////////////////////////////////////////
	// Users SL subsystem event handlers
	
	ServerHandlers["StandardSubsystems.Users\OnCreateUserAtLogonTime"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["StandardSubsystems.Users\OnAuthorizeNewInfobaseUser"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["StandardSubsystems.Users\OnStartInfobaseUserProcessing"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["StandardSubsystems.Users\BeforeWriteInfobaseUser"].Add(
		"UsersInternalSaaSCTL");
		
	////////////////////////////////////////////////////////////////////////////////
	// SaaS operations SL subsystem event handlers
	
	ServerHandlers["StandardSubsystems.SaaSOperations\UserAliasOnDetermine"].Add(
		"UsersInternalSaaSCTL");
	
	////////////////////////////////////////////////////////////////////////////////
	// DataImportExport CTL subsystem event handlers; infobase
	// user import and export
	
	ServerHandlers["CloudTechnology.DataImportExport\OnImportInfobaseUser"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\AfterImportInfobaseUser"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\AfterImportInfobaseUsers"].Add(
		"UsersInternalSaaSCTL");
	
	////////////////////////////////////////////////////////////////////////////////
	// DataImportExport CTL subsystem event handlers; infobase
	// data import and export
	
	ServerHandlers["CloudTechnology.DataImportExport\OnFillTypesThatRequireRefAnnotationOnImport"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\BeforeDataExport"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\OnRegisterDataExportHandlers"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\BeforeDataImport"].Add(
		"UsersInternalSaaSCTL");
	
	ServerHandlers["CloudTechnology.DataImportExport\OnRegisterDataImportHandlers"].Add(
		"UsersInternalSaaSCTL");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Users SL subsystem event handlers

// The procedure is called when creating a Users catalog item, when a user logs on interactively.
//
// Parameters:
//  NewUser        - CatalogObject.Users,
//  InfobaseUserID - UUID.
//
Procedure OnCreateUserAtLogonTime(NewUser) Export
	
	If IsSharedInfobaseUser() Then
		
		NewUser.Internal = True;
		NewUser.Description = InternalUserFullName(
			InfobaseUsers.CurrentUser().UUID
		);
		
	EndIf;
	
EndProcedure

// The procedure is called during the authorization of a new infobase user.
//
// Parameters:
//  IBUser - InfobaseUser - current infobase user.
//  StandardProcessing - Boolean - value can be is set inside the handler.
//                       In this case the standard processing of a new infobase user
//                       authorization is not performed.
//
Procedure OnAuthorizeNewInfobaseUser(Val CurrentInfobaseUser, StandardProcessing) Export
	
	If IsSharedInfobaseUser() Then
		
		// The user is shared, an item in the current area must be created.
		BeginTransaction();
		Try
			//UserObject = Catalogs.Users.CreateItem();
			//UserObject.Description = InternalUserFullName(
			//	CurrentInfobaseUser.UUID);
			//
			//InfobaseUserDescription = New Structure;
			//InfobaseUserDescription.Insert("Action", "Write");
			//InfobaseUserDescription.Insert(
			//	"UUID", CurrentInfobaseUser.UUID);
			//
			//UserObject.AdditionalProperties.Insert(
			//	"InfobaseUserDescription", InfobaseUserDescription);
			//
			//UserObject.Internal = True;
			//
			//UserObject.Write();
			
			If Not UsersInternal.UserByIDExists(CurrentInfobaseUser.UUID) Тогда
				
				UserObject = Catalogs.Users.CreateItem();
				UserObject.Description = InternalUserFullName(CurrentInfobaseUser.UUID);
				UserObject.Internal = True;
				UserObject.Write();
				
				UserObject.InfobaseUserID = CurrentInfobaseUser.UUID;
				UserObject.DataExchange.Load = True;
				UserObject.Write();
				
			EndIf;
		
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// The procedure is called at the start of infobase user processing.
//
// Parameters:
//  ProcessingParameters    - Structure - see StartInfobaseUserProcessing() for details.
//  InfobaseUserDescription - Structure - see StartInfobaseUserProcessing() for details.
//
Procedure OnStartInfobaseUserProcessing(ProcessingParameters, InfobaseUserDescription) Export
	
	If InfobaseUserDescription.Property("UUID")
	        And ValueIsFilled(InfobaseUserDescription.UUID)
	        And CommonUseCached.DataSeparationEnabled()
	        And UserRegisteredAsShared(
	              InfobaseUserDescription.UUID) Then
		
		// Preventing infobase user overwriting when
		// writing User catalog items, that correspond to shared users.
		ProcessingParameters.Delete("Action");
		
		If InfobaseUserDescription.Count() > 2
		 Or InfobaseUserDescription.Action = "Delete" Then
			
			Raise SharedUserCannotBeWrittenExceptionText();
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is called before writing an infobase user.
//
// Parameters:
//  InfobaseUserID - UUID.
//
Procedure BeforeWriteInfobaseUser(Val ID) Export
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If UserRegisteredAsShared(ID) Then
			
			Raise SharedUserCannotBeWrittenExceptionText();
			
		EndIf;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SaaS operations SL subsystem event handlers

// Called when determining the user alias to be displayed in the Interface.
//
// Parameters:
//  UserID - UUID,
//  Alias - String, user alias.
//
Procedure UserAliasOnDetermine(UserID, Alias) Export
	
	If UserRegisteredAsShared(UserID) Then
		Alias = InternalUserFullName(UserID);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DataImportExport CTL subsystem event handlers; infobase
// user import and export


// Called before importing an infobase user.
//
// Parameters:
//  Container     - DataProcessorObject.ImportExportContainerManagerData - container
//                  manager used for data import. For more
//                  information, see the comment to ImportExportContainerManagerData interface.
//  Serialization - XDTODataObject {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfoBaseUser - 
//                  infobase user serialization.
//  IBUser        - InfabaseUser deserialized from the export data.
//  Cancel        - Boolean - when the values is swiched inside
//                  the procedure to False, infobase user import is skipped.
//
Procedure OnImportInfobaseUser(Container, Serialization, IBUser, Cancel) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		
		IBUser.ShowInList = True;
		// Adding the FullAdministrator role to the user with the FullAccess.
		If IBUser.Roles.Contains(Metadata.Roles.FullAccess) Then
			IBUser.Roles.Add(Metadata.Roles.FullAdministrator);
		EndIf;
		
		InfobaseUpdateInternal.SetDisplayNewUserDescriptionsFlag(IBUser.Name);
		
	EndIf;
	
EndProcedure

// Called after infobase user import.
//
// Parameters:
//  Container     - DataProcessorObject.ImportExportContainerManagerData - container
//                  manager used for data import. For more
//                  information, see the comment to ImportExportContainerManagerData interface.
//  Serialization - XDTODataObject {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}InfoBaseUser - 
//                  infobase user serialization.
//  IBUser        - InfabaseUser deserialized from the export data.
//
Procedure AfterImportInfobaseUser(Container, Serialization, IBUser) Export
	
	If Not Container.AdditionalProperties.Property("UserMap") Then
		Container.AdditionalProperties.Insert("UserMap", New Map());
	EndIf;
	
	Container.AdditionalProperties.UserMap.Insert(Serialization.UUID, IBUser.UUID);
	
EndProcedure

// Called after all infobase users are imported.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//              manager used for data import. For more
//              information, see the comment to ImportExportContainerManagerData interface.
//
Procedure AfterImportInfobaseUsers(Container) Export
	
	If Container.AdditionalProperties.Property("UserMap") Then
		UpdateInfobaseUserIDs(Container.AdditionalProperties.UserMap);
	Else
		UpdateInfobaseUserIDs(New Map);
	EndIf;
	
	Container.AdditionalProperties.Insert("UserMap", Undefined);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DataImportExport CTL subsystem event handlers; infobase
// data import and export

// Fills array of types for which the reference annotation
// in files must be used when exporting.
//
// Parameters:
//  Types - Array of MetadataObject
//
Procedure OnFillTypesThatRequireRefAnnotationOnImport(Types) Export
	
	Types.Add(Metadata.Catalogs.Users);
	
EndProcedure

// Called before data export.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data export. For more
//    information, see the comment to ImportExportContainerManagerData interface.
//
Procedure BeforeDataExport(Container) Export
	
	UnspecifiedUserID = UsersInternal.CreateUnspecifiedUser().UUID();
	
	Container.AdditionalProperties.Insert("UnspecifiedUserID", UnspecifiedUserID);
	
	FileName = Container.CreateArbitraryFile("xml", DataTypeForUnspecifiedUserID());
	DataExportImportInternal.WriteObjectToFile(UnspecifiedUserID, FileName);
	
	Container.AdditionalProperties.Insert("RegistersContainingRefsToUnspecifiedUsers", New Map());
	Container.AdditionalProperties.Insert("ListOfRegistersContainingRefsToUsers", RecordSetsWithRefsToUsersList());
	
EndProcedure


// Called during registration of arbitrary data export handlers.
//
// Parameters:
// HandlerTable - ValueTable. This procedure requires that you add information on
//  the arbitrary data export handlers to the value table. Columns:
//    MetadataObject     - MetadataObject. When exporting its data, thehandler to be registered is called.
//    Handler            - CommonModule. A common module implemnting an arbitrary data export handler. The list of
//                         export procedures to be implemented in the handler depends on the values of the following
//                         value table columns.
//    BeforeExportType   - Boolean. Flag specifying whether the handler must be called before exporting all infobase
//                         objects associated with this metadata object. If set to True - the common module of the
//                         handler must include the exportable procedure BeforeExportType() supporting the following
//                         parameters:
//                         Container      - DataProcessorObject.ImportExportContainerManagerData - container manager used
//                                          for data export. For more information, see the comment to
//                                          ImportExportContainerManagerData interface.
//                         Serializer     - XDTOSerializer initialized with reference annotation support. If an arbitrary
//                                          export handler requires additional data export, it is recommended that you use
//                                          XDTOSerializer passed to BeforeExportType() as Serializer parameter, not obtained
//                                          using XDTOSerializer global context property.
//                         MetadataObject - MetadataObject whose data is exported after calling the handler.
//                         Cancel         - Boolean. If set to True in BeforeExportType(), objects associated to the current
//                                          metadata objects are not exported.
//    BeforeExportObject - Boolean. Flag specifying whether the handler must be called before exporting a specific infobase
//                         object. If set to True, the common module of the handler must include the exportable procedure
//                         BeforeExportObject() supporting the following parameters:
//                         Container  - DataProcessorObject.ImportExportContainerManagerData - container manager used for
//                                      data export. For more information, see the comment to ImportExportContainerManagerData
//                                      interface. 
//                         Serializer - XDTOSerializer initialized with reference annotation support. If an arbitrary export
//                                      handler requires additional data export, it is recommended that you use XDTOSerializer
//                                      passed to BeforeExportObject() as Serializer parameter, not obtained using XDTOSerializer
//                                      global context property.
//                         Object     - ConstantValueManager.*, CatalogObject.*, DocumentObject.*, BusinessProcessObject.*,
//                                      TaskObject.*, ChartOfAccountsObject.*, ExchangePlanObject.*, ChartOfCharacteristicTypesObject.*,
//                                      ChartOfCalculationTypesObject.*, InformationRegisterRecordSet.*, AccumulationRegisterRecordSet.*,
//                                      AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*,
//                                      RecalculationRecordSet.*, infobase data object exported after calling the handler.
//                                      The value passed to BeforeExportObject() procedure as value of the Object parameter
//                                      can be changed in the BeforeExportObject() handler. The changes will be reflected
//                                      in the object serialization in export files, but not in the infobase. 
//                          Artifacts - Array of XDTODataObject - set of additional information logically associated with
//                                      the object but not contained in it (object artifacts). Artifacts must be created
//                                      in the BeforeExportObject() handler and added to the array that is passed as Artifacts
//                                      parameter value. Each artifact is a XDTO object with abstract XDTO type used as its
//                                      basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages
//                                      not included in the DataImportExport subsystem can be used too. The artifacts
//                                      generated in the BeforeExportObject() procedure will be available in the data import
//                                      handler procedures (see the comment to OnRegisterDataImportHandlers() procedure).
//                          Cancel    - Boolean. If set to True in BeforeExportObject() - the corresponding object
//                                      is not exported.
//    AfterExportType     - Boolean. Flag specifying whether the handler is called after all infobase objects associated
//                          with this metadata object are exported. If set to True, the common module of the handler must
//                          include the exportable procedure AfterExportType() supporting the following parameters:
//                          Container      - DataProcessorObject.ImportExportContainerManagerData - container manager used
//                                           for data export. For more information, see the comment to
//                                             ImportExportContainerManagerData interface.
//                          Serializer     - XDTOSerializer initialized with reference annotation support. If an arbitrary
//                                           export handler requires additional data export, it is recommended that you use
//                                           XDTOSerializer passed to AfterExportType() as Serializer parameter, not obtained
//                                           using XDTOSerializer global context property.
//                          MetadataObject - MetadataObject whose data is exported before calling the handler.
//
Procedure OnRegisterDataExportHandlers(HandlerTable) Export
	
	NewHandler = HandlerTable.Add();
	NewHandler.MetadataObject = Metadata.Catalogs.Users;
	NewHandler.Handler = UsersInternalSaaSCTL;
	NewHandler.BeforeExportObject = True;
	
EndProcedure

// Called during registration of arbitrary data import handlers.
//
// Parameters: HandlerTable - ValueTable. The procedure presumes that information on registered arbitrary data import
//                            handlers must be added to this table. Columns:
//    MetadataObject   - MetadataObject. When importinп its data, the handler to be registered is called.
//    Handler          - CommonModule. A common module implementing an arbitrary data import handler. Set of export
//                       procedures to be implemented in the handler depends on the values of the following value table
//                       columns.
//    BeforeRefMapping - Boolean. Flag specifying whether the handler must be called before mapping the source infobase
//                       references and the current infobase references associated with this metadata object. If set to
//                       True - the common module of the handler must include the exportable procedure
//                       BeforeRefMapping() supporting the following parameters:
//                        Container          - DataProcessorObject.ImportExportContainerManagerData - container manager
//                                             used for data import. For more information, see the comment to
//                                             ImportExportContainerManagerData interface.
//                        MetadataObject     - MetadataObject. The handler is called before the object references are
//                                             mapped.
//                        StandardProcessing - Boolean. If set to False in BeforeRefMapping(), the MapRefs() function of
//                                             the corresponding common module will be called instead of the standard
//                                             reference mapping (searching the current infobase for objects with the
//                                             natural key values identical to the values exported from he source infobase).
//                                             MapRefs() function parameters:
//                                              Container      - DataProcessorObject.ImportExportContainerManagerData - 
//                                                               container manager used for data import. For more
//                                                               information, see the comment to
//                                                               ImportExportContainerManagerData interface.
//                                              SourceRefTable - ValueTable, contains details on references exported
//                                                               from original infobase. Columns:
//                                                               SourceRef - AnyRef, a source infobase object
//                                                                           reference to be mapped to a current infobase
//                                                                           reference.
//                                                               The other columns are identical to the object's natural
//                                                               key fields that were passed
//                                                               to ImportExportInfobaseData.RefMappingRequiredOnImport()
//                                                               during data export. MapRefs() returns: ValueTable with
//                                                               the following columns:
//                                                               SourceRef - AnyRef, object reference exported from the
//                                                                           original infobase, Ref - AnyRef mapped the
//                                                                           original reference in the current infobase.
//                                                               Cancel    - Boolean. If set to True in BeforeRefMapping(),
//                                                                           references corresponding to the current
//                                                                           metadata object are not mapped.
//    BeforeImportType   - Boolean. Flag specifying whether the handler must be called before importing all infobase
//                         objects associated with this metadata object. If set to True - the common module of the
//                         handler must include the exportable procedure BeforeImportType() supporting the following
//                         parameters:
//                          Container      - DataProcessorObject.ImportExportContainerManagerData - container manager
//                                           used for data import. For more information, see the comment to
//                                           ImportExportContainerManagerData interface.
//                          MetadataObject - MetadataObject. The handler is called before the object data is imported.
//                          Cancel         - Boolean. If set to True in AfterImportType(), the data objects corresponding
//                                           to the current metadata object are not imported.
//    BeforeImportObject - Boolean. Flag specifying whether the handler must be called before importing the infobase object
//                         associated with this metadata object. If set to True, the common module of the handler must
//                         include the exportable procedure BeforeImportObject() supporting the following parameters:
//                          Container - DataProcessorObject.ImportExportContainerManagerData - container manager used for
//                                      data import. For more information, see the comment to ImportExportContainerManagerData
//                                      interface.
//                          Object    - ConstantValueManager.*, CatalogObject.*, DocumentObject.*, BusinessProcessObject.*,
//                                      TaskObject.*, ChartOfAccountsObject.*, ExchangePlanObject.*,
//                                      ChartOfCharacteristicTypesObject.*, ChartOfCalculationTypesObject.*,
//                                      InformationRegisterRecordSet.*, AccumulationRegisterRecordSet.*,
//                                      AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*,
//                                      RecalculationRecordSet. - infobase data object imported after the handler is called.
//                                      Value passed to the BeforeImportObject() procedure as Object parameter value can be
//                                      modified in the BeforeImportObject() handler procedure.
//                          Artifacts - Array of XDTODataObject - additional data logically
//                                      associated with the data object but not contained in it. Generated in
//                                      BeforeExportObject() exportable procedures of data export handlers (see the comment
//                                      to the OnRegisterDataExportHandlers() procedure). Each artifact is a XDTO object
//                                      with abstract XDTO type used as its basic type
//                                      {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages not included in
//                                      the DataImportExport subsystem can be used too.
//                          Cancel    - Boolean. If set to True in BeforeImportObject(), the data object is not imported.
//    AfterImportObject  - Boolean. Flag specifying whether the handler must be called after importing the infobase object
//                         associated with this metadata object. If set to True - the common module of the handler must
//                         include the exportable procedure AfterImportObject() supporting the following parameters:
//                          Container - DataProcessorObject.ImportExportContainerManagerData - container manager used for
//                                      data import. For more information, see the comment to
//                                      ImportExportContainerManagerData interface.
//                          Object    - ConstantValueManager.*,  CatalogObject.*, DocumentObject.*, BusinessProcessObject.*,
//                                      TaskObject.*, ChartOfAccountsObject.*, ExchangePlanObject.*,
//                                      ChartOfCharacteristicTypesObject.*, ChartOfCalculationTypesObject.*,
//                                      InformationRegisterRecordSet.*, AccumulationRegisterRecordSet.*,
//                                      AccountingRegisterRecordSet.*, CalculationRegisterRecordSet.*, SequenceRecordSet.*,
//                                      RecalculationRecordSet.* - infobase data object imported before the handler is called.
//        Artifacts      - Array of XDTODataObject - additional data logically associated with the data object but not contained in
//                         it. Generated in BeforeExportObject() exportable procedures of data export handlers (see the comment to
//                         the OnRegisterDataExportHandlers() procedure). Each artifact is a XDTO object with abstract XDTO type
//                         used as its basic type {http://www.1c.ru/1cFresh/Data/Dump/1.0.2.1}Artefact. XDTO packages not included
//                         in the DataImportExport subsystem can be used too.
//    AfterImportType    - Boolean. Flag specifying whether the handler must be called after importing all infobase objects
//                         associated with this metadata object. If set to True - the common module of the handler must include the
//                         exportable procedure AfterImportType() supporting the following parameters:
//        Container      - DataProcessorObject.ImportExportContainerManagerData - container manager used for data import. For more
//                         information, see the comment to ImportExportContainerManagerData interface.
//        MetadataObject - MetadataObject. The handler is called after the object data is imported.
//
Procedure OnRegisterDataImportHandlers(HandlerTable) Export
	
	NewHandler = HandlerTable.Add();
	NewHandler.MetadataObject = Metadata.Catalogs.Users;
	NewHandler.Handler = UsersInternalSaaSCTL;
	NewHandler.BeforeMapRefs = True;
	NewHandler.BeforeImportObject = True;
	
	RegisterList = RecordSetsWithRefsToUsersList();
	For Each ListItem In RegisterList Do
		
		NewHandler = HandlerTable.Add();
		NewHandler.MetadataObject = ListItem.Key;
		NewHandler.Handler = UsersInternalSaaSCTL;
		NewHandler.BeforeImportObject = True;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DataImportExport CTL subsystem data export handlers

Procedure BeforeExportObject(Container, Serializer, Object, Artifacts, Cancel) Export
	
	If TypeOf(Object) = Type("CatalogObject.Users") Then
		
		If Object.Ref.UUID() <> Container.AdditionalProperties.UnspecifiedUserID Then
			
			NaturalKey = New Structure("Undistributed", UserRegisteredAsShared(Object.InfobaseUserID));
			ImportExportInfobaseData.MustMapRefOnImport(Container, Object.Ref, NaturalKey);
			
		EndIf;
		
		If UserRegisteredAsShared(Object.InfobaseUserID) Then
			
			NewArtifact = XDTOFactory.Create(SharedUserArtifactType());
			NewArtifact.UserName = InnerServiceUserName(Object.InfobaseUserID);
			Artifacts.Add(NewArtifact);
			
		EndIf;
		
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = '%1 metadata object not can be processed with the UsersInternalSaaSCTL.BeforeExportObject() handler.'"),
			Object.Metadata().FullName());
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// DataImportExport CTL subsystem data import handlers

// Called before data import.
//
// Parameters:
//  Container - DataProcessorObject.ImportExportContainerManagerData - container
//    manager used for data import. For more
//    information, see the comment to ImportExportContainerManagerData interface.
//
Procedure BeforeDataImport(Container) Export
	
	Container.AdditionalProperties.Insert("ListOfRegistersContainingRefsToUsers", RecordSetsWithRefsToUsersList());
	Container.AdditionalProperties.Insert("RegistersContainingRefsToUnspecifiedUsers", New Map());
	
	Container.AdditionalProperties.Insert(
		"UnspecifiedUserID",
		UsersInternal.CreateUnspecifiedUser().UUID()
	);
	
	FileName = Container.GetArbitraryFile(DataTypeForUnspecifiedUserID());
	
	Container.AdditionalProperties.Insert(
		"IDUnspecifiedUserInOriginalIB",
		DataExportImportInternal.ReadObjectFromFile(FileName));
	
EndProcedure

Procedure BeforeMapRefs(Container, MetadataObject, SourceRefTable, StandardProcessing, Cancel) Export
	
	If MetadataObject = Metadata.Catalogs.Users Then
		
		StandardProcessing = False;
		
	Else
		
		Raise NStr("en = 'Data type specified incorrectly'");
		
	EndIf;
	
EndProcedure

Function MapRefs(Container, SourceRefTable) Export
	
	ColumnName = DataExportImportInternal.SourceURLColumnName(Container);
	
	Result = New ValueTable();
	Result.Columns.Add(ColumnName, New TypeDescription("CatalogRef.Users"));
	Result.Columns.Add("Ref", New TypeDescription("CatalogRef.Users"));
	
	UnspecifiedUserMapping = Result.Add();
	UnspecifiedUserMapping[ColumnName] = Catalogs.Users.GetRef(
		Container.AdditionalProperties.IDUnspecifiedUserInOriginalIB);
	UnspecifiedUserMapping.Ref = Catalogs.Users.GetRef(
		Container.AdditionalProperties.UnspecifiedUserID);
	
	MergeSharedUsers = False;
	MergeSeparatedUsers = False;
	
	If CommonUseCached.DataSeparationEnabled() Then
		
		If Container.ImportParameters().Property("CollapseSeparatedUsers") Then
			
			MergeSeparatedUsers = Container.ImportParameters().CollapseSeparatedUsers;
			
		Else
			
			MergeSeparatedUsers = False;
			
		EndIf;
		
	Else
		MergeSharedUsers = True;
		MergeSeparatedUsers = True;
	EndIf;
	
	For Each SourceRefTablesRow In SourceRefTable Do
		
		If SourceRefTablesRow.Undistributed Then
			
			If MergeSharedUsers Then
				
				UserMapping = Result.Add();
				UserMapping[ColumnName] = SourceRefTablesRow[ColumnName];
				UserMapping.Ref = Catalogs.Users.GetRef(
					Container.AdditionalProperties.UnspecifiedUserID);
				
			EndIf;
			
		Else
			
			If MergeSeparatedUsers Then
				
				UserMapping = Result.Add();
				UserMapping[ColumnName] = SourceRefTablesRow[ColumnName];
				UserMapping.Ref = Catalogs.Users.GetRef(
					Container.AdditionalProperties.UnspecifiedUserID);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure BeforeImportObject(Container, Object, Artifacts, Cancel) Export
	
	MetadataObject = Object.Metadata();
	
	If TypeOf(Object) = Type("CatalogObject.Users") Then
		
		If Object.Ref.UUID() = Container.AdditionalProperties.UnspecifiedUserID Then
			Cancel = True;
			Return;
		EndIf;
		
		For Each Artifact In Artifacts Do
			
			If Artifact.Type() = SharedUserArtifactType() Then
				
				InnerName = Artifact.UserName;
				ID = ServiceUserIDByInternalName(InnerName);
				
				Object.InfobaseUserID = ID;
				
				If UserRegisteredAsShared(ID) Then
					Object.Description = InternalUserFullName(ID);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	ElsIf IsRegisterWithRefsToUsers(Container, MetadataObject) Then
		
		If RecordSetContainsRefToCollapsibleUsers(Container, MetadataObject, Object) Then
			
			Cancel = True;
			
		EndIf;
		
	Else
		
		Raise CTLAndSLIntegration.SubstituteParametersInString(
			NStr("en = '%1 metadata object cannot be processed by the UsersInternalSaaS.BeforeImportObject() handler.'"),
			MetadataObject.FullName());
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Update handlers

Procedure RegisterUpdateHandlers(Val Handlers) Export
	
	Handler               = Handlers.Add();
	Handler.Version       = "*";
	Handler.ExclusiveMode = False;
	Handler.SharedData    = True;
	Handler.Procedure     = "UsersInternalSaaSCTL.FillRecordSetListWithRefsToUsers";
	
	Handler               = Handlers.Add();
	Handler.Version       = "1.0.2.10";
	Handler.ExclusiveMode = False;
	Handler.SharedData    = True;
	Handler.Procedure     = "UsersInternalSaaS.FillSharedUserNames";
	
EndProcedure

// Configuration update handler. Fills the RecordSetsWithRefsToUsersList constant, the 
// ValueTable that contains the register details with references to teh Users catalog in dimensions.
//
Procedure FillRecordSetListWithRefsToUsers() Export
	
	MetadataDescription = New ValueTable;
	MetadataDescription.Columns.Add("Collection", New TypeDescription("String"));
	MetadataDescription.Columns.Add("Object", New TypeDescription("String"));
	MetadataDescription.Columns.Add("Dimensions", New TypeDescription("Array"));
	
	For Each InformationRegister In Metadata.InformationRegisters Do
		AddToMetadataList(MetadataDescription, InformationRegister, "InformationRegisters");
	EndDo;
	
	For Each Sequence In Metadata.Sequences Do
		AddToMetadataList(MetadataDescription, Sequence, "Sequences");
	EndDo;
	
	Constants.RecordSetsWithRefsToUsersList.Set(New ValueStorage(MetadataDescription));
	
EndProcedure

Procedure FillSharedUserNames() Export
	
	QueryText = "SELECT
	               |	SharedUsers.InfobaseUserID,
	               |	SharedUsers.SequenceNumber
	               |FROM
	               |	InformationRegister.SharedUsers AS SharedUsers
	               |WHERE
	               |	SharedUsers.UserName = """"";
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		User = InfobaseUsers.FindByUUID(Selection.InfobaseUserID);
		If User = Undefined Then
			Continue;
		EndIf;
		
		Set = InformationRegisters.SharedUsers.CreateRecordSet();
		Set.Filter.InfobaseUserID.Set(Selection.InfobaseUserID);
		Write = Set.Add();
		Write.InfobaseUserID = Selection.InfobaseUserID;
		Write.SequenceNumber = Selection.SequenceNumber;
		Write.UserName = User.Name;
		Set.Write();
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers


Procedure GetUserFormProcessing(Source, FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing) Export
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If FormType = "ObjectForm"
		And Parameters.Property("Key") And Not Parameters.Key.IsEmpty() Then
		
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	1
		|FROM
		|	InformationRegister.SharedUsers AS SharedUsers
		|		INNER JOIN Catalog.Users AS Users
		|		ON SharedUsers.InfobaseUserID = Users.InfobaseUserID
		|			AND (Users.Ref = &Ref)";
		Query.SetParameter("Ref", Parameters.Key);
		If Not Query.Execute().IsEmpty() Then
			StandardProcessing = False;
			SelectedForm = Metadata.CommonForms.SharedUserInfo;
			Return;
		EndIf;
		
	EndIf;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// INTERNAL PROCEDURES AND FUNCTIONS

////////////////////////////////////////////////////////////////////////////////
// Operations with shared infobase users

// Returns a full name of the internal user to be displayed in interfaces.
//
// Parameters:
//  ID - infobase user UUID or CatalogRef.Users.
//
// Returns:
//  String
//
Function InternalUserFullName(Val ID = Undefined)
	
	Result = NStr("en = '<Internal user %1>'");
	
	If ValueIsFilled(ID) Then
		
		If TypeOf(ID) = Type("CatalogRef.Users") Then
			ID = CommonUse.ObjectAttributeValue(ID, "InfobaseUserID");
		EndIf;
		
		SequenceNumber = Format(InformationRegisters.SharedUsers.InfobaseUserSequenceNumber(ID), "NFD=0; NG=0");
		Result = StringFunctionsClientServer.SubstituteParametersInString(Result, SequenceNumber);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function InnerServiceUserName(Val ID)
	
	Manager = InformationRegisters.SharedUsers.CreateRecordManager();
	Manager.InfobaseUserID = ID;
	Manager.Read();
	If Manager.Selected() Then
		Return Manager.UserName;
	Else
		Return "";
	EndIf;
	
EndFunction

Function ServiceUserIDByInternalName(Val InnerName)
	
	QueryText =
		"SELECT
		|	SharedUsers.InfobaseUserID AS InfobaseUserID
		|FROM
		|	InformationRegister.SharedUsers AS SharedUsers
		|WHERE
		|	SharedUsers.UserName = &UserName";
	Query = New Query(QueryText);
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return New UUID("00000000-0000-0000-0000-000000000000");
	Else
		Selection = QueryResult.Select();
		Selection.Next();
		Return Selection.InfobaseUserID;
	EndIf;
	
EndFunction

// Checks whether the current infobase user shared.
//
// Return value: Boolean.
//
Function IsSharedInfobaseUser()
	
	If IsBlankString(InfobaseUsers.CurrentUser().Name) Then
		Return False;
	EndIf;
	
	If Not CommonUseCached.DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If InfobaseUsers.CurrentUser().DataSeparation.Count() = 0 Then
		
		If CommonUseCached.CanUseSeparatedData() Then
			
			UserID = InfobaseUsers.CurrentUser().UUID;
			
			If Not UserRegisteredAsShared(UserID) Then
				
				Raise StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'User with the ID %1 is not registered as shared.'"),
					String(UserID)
				);
				
			EndIf;
			
		EndIf;
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// In SaaS mode, adds the current user to the
// list of shared ones if usage of separators are not set for it.
//
Procedure RecordSharedUserInRegister() Export
	
	BeginTransaction();
	Try
		
		DataLock = New DataLock;
		LockItem = DataLock.Add("InformationRegister.SharedUsers");
		DataLock.Lock();
		
		RecordManager = InformationRegisters.SharedUsers.CreateRecordManager();
		RecordManager.InfobaseUserID = InfobaseUsers.CurrentUser().UUID;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			RecordManager.InfobaseUserID = InfobaseUsers.CurrentUser().UUID;
			RecordManager.SequenceNumber = InformationRegisters.SharedUsers.MaximumSequenceNumber() + 1;
			RecordManager.UserName = InfobaseUsers.CurrentUser().Name;
			RecordManager.Write();
		ElsIf RecordManager.UserName <> InfobaseUsers.CurrentUser().Name Then
			RecordManager.UserName = InfobaseUsers.CurrentUser().Name;
			RecordManager.Write();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Function SharedUserCannotBeWrittenExceptionText()
	
	Return NStr("en = 'Cannot save
                  |shared users when separators are enabled.'");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Integration with the Users SL subsystem

// Updates infobase user IDs in the user catalog, cleans the ServiceUserID field
//
// Parameters:
//  UserTable - Map - Key is the original
//                         infobase user ID, Value - current infobase user ID
//
Procedure UpdateInfobaseUserIDs(Val IDMapping)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Users.Ref AS Ref,
	|	Users.InfobaseUserID AS InfobaseUserID
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.InfobaseUserID <> &EmptyID";
	Query.SetParameter("EmptyID", New UUID("00000000-0000-0000-0000-000000000000"));
	Result = Query.Execute();
	Selection = Result.Select();
	While Selection.Next() Do
		UserObject = Selection.Ref.GetObject();
		UserObject.DataExchange.Load = True;
		UserObject.ServiceUserID = Undefined;
		UserObject.InfobaseUserID 
			= IDMapping[Selection.InfobaseUserID];
		UserObject.Write();
	EndDo;
	
EndProcedure


////////////////////////////////////////////////////////////////////////////////
// Integration with the DataImportExport CTL subsystem

Function DataTypeForUnspecifiedUserID()
	
	Return "1cfresh\ApplicationData\DefaultUserRef";
	
EndFunction

Function RecordSetContainsRefToCollapsibleUsers(Container, MetadataObject, RecordSet)
	
	Dimensions = Container.AdditionalProperties.ListOfRegistersContainingRefsToUsers.Get(MetadataObject);
	
	For Each Dimension In Dimensions Do
		
		For Each Write In RecordSet Do
			
			ValidatedValue = Write[Dimension];
			
			If TypeOf(ValidatedValue) = Type("CatalogRef.Users") Then
				
				If ValidatedValue.UUID() = Container.AdditionalProperties.UnspecifiedUserID Then
					Return True;
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return False;
	
EndFunction

Function IsRegisterWithRefsToUsers(Container, MetadataObject)
	
	Return (Container.AdditionalProperties.ListOfRegistersContainingRefsToUsers.Get(MetadataObject) <> Undefined);
	
EndFunction


//Reads details on registers from constants and generates a map for ListOfRegistersWithRefsToUsers
//
Function RecordSetsWithRefsToUsersList()
	
	SetPrivilegedMode(True);
	MetadataDescription = Constants.RecordSetsWithRefsToUsersList.Get().Get();
	
	MetadataList = New Map;
	For Each Row In MetadataDescription Do
		MetadataList.Insert(Metadata[Row.Collection][Row.Object], Row.Dimensions);
	EndDo;
	
	Return MetadataList;
	
EndFunction

Function SharedUserArtifactType() Export
	
	Return XDTOFactory.Type(Package(), "UnseparatedUser");
	
EndFunction

Function Package()
	
	Return "http://www.1c.ru/1cFresh/Data/Artefacts/ServiceUsers/1.0.0.1";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary update handler functions


Procedure AddToMetadataList(Val MetadataList, Val ObjectMetadata, Val CollectionName)
	
	UserRefType = Type("CatalogRef.Users");
	
	Dimensions = New Array;
	For Each Dimension In ObjectMetadata.Dimensions Do 
		
		If (Dimension.Type.ContainsType(UserRefType)) Then
			Dimensions.Add(Dimension.Name);
		EndIf;
		
	EndDo;
	
	If Dimensions.Count() > 0 Then
		Row = MetadataList.Add();
		Row.Collection = CollectionName;
		Row.Object = ObjectMetadata.Name;
		Row.Dimensions = Dimensions;
	EndIf;
	
EndProcedure