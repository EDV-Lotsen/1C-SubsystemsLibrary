////////////////////////////////////////////////////////////////////////////////
// Access management subsystem
 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Fills access kinds used in access restrictions.
// Users and ExternalUsers access kinds are already filled.
// They can be deleted if they are not used in access restrictions.
// Parameters:
//  AccessKinds - ValueTable - with columns:
//   * Name                - String     - name used in definitions of supplied access group
//                                       profiles and in RLS texts.
//   * Presentation        - String     - access kind presentation in profiles and access groups.
//   * ValueType           - Type       - access value reference type. Example: Type("CatalogRef.ProductsAndServices").
//   * ValueGroupType      - Type       - access value group reference type. For example, Type("CatalogRef.ProductAndServiceAccessGroups").
//   * MultipleValueGroups - Boolean    - if True, multiple value groups (Items access
//                           groups) can be selected for a single access value (Items).
//
 
Procedure OnFillAccessKinds(AccessKinds) Export
	
	// _Demo begin example
	//_DemoStandardSubsystems.OnFillAccessKinds(AccessKinds);
	// _Demo end example
	
EndProcedure

// Fills descriptions of supplied access group profiles and overrides update
// parameters of profiles and access groups.
// To generate the procedure content automatically, it is recommended that you
// use developer tools from the Access management subsystem.
// Parameters:
//  ProfileDescriptions - Array - array of structures where descriptions must be
//                        added. An empty structure must be generated using the
//                        AccessManagement.NewAccessGroupProfileDescription
//                        function. 
//  UpdateParameters    - Structure - structure with the following properties:
//   * UpdateModifiedProfiles - Boolean - the initial value is True.
//   * DenyProfileChange                      - Boolean - the initial value
//                                              is True.
//                                              If False, the supplied profiles
//                                              can only be viewed
//                                              but not edited.
//   * UpdateAccessGroups                     - Boolean - the initial value
//                                              is True.
//   * UpdateAccessGroupsWithObsoleteSettings - Boolean - the initial value
//                                              is False. If True, the value
//                                              settings made by the 
//                                              administrator for the access kind
//                                              which was deleted from the 
//                                              profile are also deleted
//                                              from the access groups.
//
 
Procedure OnFillSuppliedAccessGroupProfiles(ProfileDescriptions, UpdateParameters) Export
	
	// _Demo begin example
	//_DemoStandardSubsystems.OnFillSuppliedAccessGroupProfiles(ProfileDescriptions);
	// _Demo end example
	
EndProcedure

// Fills the non-standard access right dependencies between the subordinate object and the main
// object. For example, fills access right dependencies between PerformerTask task and Job
// business process.
// Right dependencies are used in a standard access restriction 
// template for Object access kind:
// 1) By default, when reading a subordinate object a check is made
//    whether the user has the right to read the head object and has 
//    no restrictions to read it;
// 2) When adding, changing, or deleting a subordinate object, the following standard checks
// are performed: whether the user has the right to edit the head object and whether the user
// has no restrictions for editing the head object. 
//
// A single variation of this procedure is allowed:
// in paragraph 2 above, checking the right to edit the head object can be replaced by checking the right to read the head object.
// Parameters:
//  RightDependencies   - ValueTable - with columns:
//   * LeadingTable     - String     - for example, "BusinessProcess.Task".
//   * SubordinateTable - String     - for example, "Task.PerformerTask".
//
 
Procedure OnFillAccessRightDependencies(RightDependencies) Export
	
	// _Demo begin example
	//_DemoStandardSubsystems.OnFillAccessRightDependencies(RightDependencies);
	// _Demo end example
	
EndProcedure

// Fills the description of possible rights assigned for the specified object types.
// Parameters:
// AvailableRights - ValueTable - see description of the table columns in the
//                   comment to the
//                   InformationRegisters.ObjectRightsSettings.AvailableRights()
//                   function.
//
 
Procedure OnFillAvailableRightsForObjectRightsSettings(AvailableRights) Export
	
EndProcedure

// Defines the user interface type used for the access management.
// Parameters:
//  SimplifiedInterface - Boolean - the initial value is False.

Procedure OnDefineAccessSettingsInterface(SimplifiedInterface) Export
	
EndProcedure

// Fills the usage of access kinds depending on the configuration functional
// options, for example, UseProductAndServiceAccessGroups
// Parameters:
//  AccessKind    - String  - access kind name specified in the OnFillAccessKinds procedure.
//  Use           - Boolean - the initial value is True.
//

Procedure OnFillAccessKindUse(AccessKind, Use) Export
	
	// _Demo begin example
	//_DemoStandardSubsystems.OnFillAccessKindUse(AccessKind, Use);
	// _Demo end example
	
EndProcedure

// Fills the list of access kinds that are used to set metadata object right restrictions.
// If the list of access kinds is not filled, the Access rights report displays incorrect data.
// Only access kinds that are explicitly used in access restriction templates must be filled,
// while access kinds used in access value sets can alternately be obtained from the current
// state of the AccessValueSets information register.
// To generate the procedure script automatically, it is recommended that you use the developer
// tools from the Access management subsystem.
// Parameters:
// Description     - String - multiline string of following format:
//                            <Table>.<Right>.<AccessKind>[.Table object]
//                            Example: Document.GoodsReceipt.Read.Companies
//                                     Document.GoodsReceipt.Read.Counterparties
//                                     Document.GoodsReceipt.Update.Companies
//                                         Document.GoodsReceipt.Update.Counterparties              
//                                      Document.EmailMessages.Read.Object.Document.EmailMessages
//                                        Document.EmailMessages.Update.Object.Document.EmailMessages
//                                      Document.Files.Read.Object.Catalog.FileFolders
//                                        Document.Files.Read.Object.Document.EmailMessage
//                                      Document.Files.Update.Object.Catalog.FileFolders
//                                      Document.Files.Update.Object.Document.EmailMessage.
//                   The Object access kind is predefined as a literal. 
//                   This access kind is used in access restriction templates as
//                   a reference to another object that is used for applying
//                   restrictions to the current table item.
//                   If Object access kind is specified, table types that are
//                   used in the access kind must be specified too (in other
//                   words, you have to list the types that match the access
//                   restriction template field that describes the Object access
//                   kind). The list of types for the Object access kinds should
//                   only include the field types available for the
//                   InformationRegisters.AccessValueSets.Object field.
//
 
Procedure OnFillMetadataObjectAccessRestrictionKinds(Description) Export
	
	// _Demo begin example
	//_DemoStandardSubsystems.OnFillMetadataObjectAccessRestrictionKinds(Description);
	// _Demo end example
	
EndProcedure

// Allows to overwrite the dependent access value sets of other objects.
// Called from procedures:
//  AccessManagementInternal.WriteAccessValueSets(),
//  AccessManagementInternal.WriteDependentAccessValueSets().
// Parameters:
//  Ref                    - CatalogRef, DocumentRef,.. - reference to the
//                           object for which the access value sets are written.
//  RefsToDependentObjects - Array - array with elements of the CatalogRef
//                           type, the DocumentRef type, ...
//                           Contains references to the objects with the dependent
//                           access value sets. Initial value is an empty array.
 
Procedure OnChangeAccessValueSets(Ref, RefsToDependentObjects) Export
	
	// _Demo begin example
	//_DemoStandardSubsystems.OnChangeAccessValueSets(Ref, RefsToDependentObjects);
	// _Demo end example
	
EndProcedure

#EndRegion
