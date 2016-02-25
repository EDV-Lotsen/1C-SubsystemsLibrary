////////////////////////////////////////////////////////////////////////////////
// XDTO translation subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Performs version translation for an XDTO object by using registered translation handlers.
// The resulting version is determined by the resulting message namespace.
//
// Parameters:
//  InitialObject    - XDTODataObject - object to be translated. 
//  ResultingVersion - String - resulting interface version number in RR.{S|SS}.VV.BB format.
//
// Returns:
//  XDTODataObject - object translation result.
//
Function TranslateToVersion(Val InitialObject, Val ResultingVersion, Val SourceVersionPackage = "") Export
	
	If SourceVersionPackage = "" Then
		SourceVersionPackage = InitialObject.Type().NamespaceURI;
	EndIf;
	
	InitialVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		,
		SourceVersionPackage);
	ResultingVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		ResultingVersion);
	
	Return XDTOTranslationInternal.ExecuteTranslation(
		InitialObject,
		InitialVersionDescription,
		ResultingVersionDescription);
	
EndFunction

// Performs version translation for an XDTO object by using registered translation handlers.
// The resulting version is determined by the resulting message namespace.
//
// Parameters:
//  InitialObject    - XDTODataObject - object to be translated.
//  ResultingVersion - String - resulting version namespace.
//
// Returns:
//  XDTODataObject - object translation result.
//
Function TranslateToNamespace(Val InitialObject, Val ResultingVersionPackage, Val SourceVersionPackage = "") Export
	
	If InitialObject.Type().NamespaceURI = ResultingVersionPackage Then
		Return InitialObject;
	EndIf;
	
	If SourceVersionPackage = "" Then
		SourceVersionPackage = InitialObject.Type().NamespaceURI;
	EndIf;
	
	InitialVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		,
		SourceVersionPackage);
	ResultingVersionDescription = XDTOTranslationInternal.GenerateVersionDescription(
		,
		ResultingVersionPackage);
	
	Return XDTOTranslationInternal.ExecuteTranslation(
		InitialObject,
		InitialVersionDescription,
		ResultingVersionDescription);
	
EndFunction

#EndRegion
