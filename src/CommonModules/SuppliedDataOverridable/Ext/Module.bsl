///////////////////////////////////////////////////////////////////////////////////
// SuppliedDataOverridable: the supplied data service mechanism.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Generates a map table of separated and shared data.
// It is recommended that you call this procedure through the function with the same name from the SuppliedData module.
//
// Parameters:
//  MapTable - ValueTable - table to be filled with type maps.
//
Procedure GetSeparatedAndSharedDataMapTable(MapTable) Export
	
EndProcedure

// Overrides actions to be done when filling the data area with supplied data.
//
// Parameters:
// SharedDataRef - Ref - reference to the supplied data item.
//
Procedure OnFillDataAreaWithSuppliedData(SharedDataRef) Export

EndProcedure

// Overrides actions to be done when registering the new supplied data item.
//
// Parameters:
//  SharedDataRef - Ref - reference to the supplied data item.
//
Procedure OnRecordNewSuppliedDataObjectChange(SharedDataItem) Export

EndProcedure

// Is called before updating the separated record set with data from the shared one. 
//
// Parameters:
//  Prototype          - InformationRegisterRecordSet - shared record set that will be 
//                       a prototype to the separated one.
//  MDObject           - MetadataObject - shared information register metadata.
//  Manager            - InformationRegisterManager - separated information register
//                       manager.
//  SourceType         - Type - shared register record key type.
//  TargetType         - Type - separated register record key type.
//  TargetObject       - InformationRegisterRecordSet - if standard update processing  
//                       is overridden in this procedure, the record set that is not
//                       written must be passed to this parameter.
//  StandardProcessing - Boolean - if standard update processing is overridden in this
//                       procedure, False must be passed to this parameter.
//
Procedure BeforeCopyRecordSetFromPrototype(Prototype, MDObject, Manager, SourceType, 
		TargetType, TargetObject, StandardProcessing) Export
		
EndProcedure
	
	
// Is called before updating the separated object with data from the shared one.
//
// Parameters:
//  Prototype          - CatalogObject - shared object that will be a prototype to the
//                       separated one.
//  MDObject           - MetadataObject - shared catalog metadata.
//  Manager            - CatalogManager - separated catalog manager.
//  SourceType         - Type - shared catalog reference type.
//  TargetType         - Type - separated catalog reference type.
//  TargetObject       - CatalogObject - if standard update processing was overridden
//                       in this procedure, the object that is not written must be
//                       passed to this parameter.
//  StandardProcessing - Boolean - if standard update processing is overridden in this
//                                 procedure, False must be passed to this parameter.
//
Procedure BeforeCopyObjectFromPrototype(Prototype, MDObject, Manager, SourceType, 
		TargetType, TargetObject, StandardProcessing) Export
		
EndProcedure
