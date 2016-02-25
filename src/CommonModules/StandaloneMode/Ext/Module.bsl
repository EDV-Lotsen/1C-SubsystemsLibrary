////////////////////////////////////////////////////////////////////////////////
// Data exchange SaaS subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// OnReadAtServer form event handler, which is embedded into item forms
// (these include forms of catalog items, documents, register records, and
// more).
// It locks a form if this is an attempt to modify shared data received 
// from an application running in a standalone workplace.
//
// Parameters:
//  CurrentObject - Object being read from the infobase
//  ViewOnly      - Boolean - ViewOnly form parameter
//
Procedure ObjectOnReadAtServer(CurrentObject, ReadOnly) Export
	
	If Not ReadOnly Then
		
		MetadataObject = Metadata.FindByType(TypeOf(CurrentObject));
		StandaloneModeInternal.DefineDataChangeCapability(MetadataObject, ReadOnly);
		
	EndIf;
	
EndProcedure

#EndRegion
