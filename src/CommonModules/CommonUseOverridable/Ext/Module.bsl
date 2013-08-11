////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//
//////////////////////////////////////////////////////////////////////////////// 

////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns a metadata object name list, which data can contain various metadata object references,
// that should not be considered in application business logic.
//
// Example:
// The Object Versioning subsystem and the Properties subsystem are configured for 
// an Invoice document. There can be a lot of references to this document
// in the Infobase (in other documents, registers, and other objects). Some of them are important for business logic
// (like register records). Other part is a technical references,
// refered to the Object Versioning subsystem and the Properties subsystem. Such technical
// references should be filtered, for example, in the marked object deletion handler or when references to objects are being searched
// in the Object Attribute Edit Prohibition subsystem.
// Technical object list should be specified in this function.
//
// Returns:
// Array - Row array - "InformationRegister.ObjectVersions", for example.
//
Function GetRefSearchExceptions() Export
	
	Array = New Array;
	
	Return Array;
	
EndFunction 

// The handler of event, raising on 
// MetadataObjectIDs catalog data update. 
//
// Parameters:
// EventKind - String - "Adding", "Editing", "Deletion"
// Properties - Structure:
// Old - Structure - basic fields and values of an old catalog item;
// New - Structure - basic fields and values of a new catalog item;
// ReplaceRefs
// - Boolean - if it is set to True,
// then Properties.New.Ref will replace 
// Properties.Old.Ref in the Infobase.
// if it is set to False, replacement will not happen.
// Replacement happens whan predefined item is added instead of 
// usual one or when one metadata object replaces
// another for accurate restructuring.
//
Procedure OnChangeMetadataObjectID(EventKind, Properties) Export
	
	
	
EndProcedure

// Returns a map of session parameter names to their initialize handlers.
//
Function SessionParameterInitHandlers() Export
	
	// You should use a following template to set session parameter handlers:
	// Handlers.Insert("<SessionParameterName>|<SessionParameterNamePrefix*>,"Handler");
	//
	// Note: The * character is used in the end of the session parameter name to indicate,
	// that one handler will be called to initialize all of session parameters
	// which names beginning from SessionParameterNamePrefix
	//


	Handlers = New Map;
	
	Return Handlers;
	
EndFunction

// Sets subject presentation
//
// Parameters
// SubjectRef – AnyRef – reference type object;
// Presentation	- String - text details should be put here.
Procedure SetSubjectPresentation(SubjectRef, Presentation) Export
	
EndProcedure

// Fills IDs of metadata object, that cannot be found
// by type automatically but have to be saved in the Infobase (like Subsystems).
//
// See CommonUse.AddID for details
//
Procedure FillPresetMetadataObjectIDs(IDs) Export
	
EndProcedure