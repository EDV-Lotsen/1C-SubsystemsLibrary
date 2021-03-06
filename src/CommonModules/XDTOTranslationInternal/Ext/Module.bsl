﻿////////////////////////////////////////////////////////////////////////////////
// XDTO translation subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// Returns a message version description. The return value is passed to FindTranslationChains() 
// procedure in InitialVersionDescription and ResultingVersionDescription parameters.
//
// Parameters:
//  Number - String - message version number in RR.{S|SS}.VV.BB format.
//  Package - String - message version namespace.
//
// Returns:
//  Structure(Number, Package).
//
Function GenerateVersionDescription(Number = Undefined, Package = Undefined) Export
	
	Return New Structure("Number, Package", Number, Package);
	
EndFunction //GenerateVersionDescription()

// Generates a human-readable presentation for a message interface version.
//
// Parameters:
//  VersionDetails - Structure - GenerateVersionDescription() procedure execution result.
//
// Returns: 
//  String.
//
Function GenerateVersionPresentation(VersionDetails) Export
	
	Result = "";
	
	If ValueIsFilled(VersionDetails.Number) Then
		
		Result = VersionDetails.Number;
		
	EndIf;
	
	If ValueIsFilled(VersionDetails.Package) Then
		
		PackagePresentation = "{" + VersionDetails.Package + "}";
		
		If Not IsBlankString(Result) Then
			Result = Result + " (" +  PackagePresentation + ")";
		Else
			Result = PackagePresentation;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

// If multiple message version translation chains are available,
// returns the shortest chain (containing the least number of steps).
//
// Parameters:
//  TranslationChains - Array - translation chains generated by FindTranslationChains() function.
//
// Returns:
//  ValueTable - array item - translation chain containing the least number of steps.
Function SelectTranslationChain(Val TranslationChains) Export
	
	If TranslationChains.Count() = 1 Then
		Return TranslationChains.Get(0);
	Else
		
		CurrentSelection = Undefined;
		
		For Each TranslationChain In TranslationChains Do
			
			If CurrentSelection = Undefined Then
				CurrentSelection = TranslationChain;
			Else
				CurrentSelection = ?(TranslationChain.Count() < CurrentSelection.Count(),
						TranslationChain, CurrentSelection);
			EndIf;
			
		EndDo;
		
		Return CurrentSelection;
		
	EndIf;
	
EndFunction

// For internal use
Function GetMessageInterface(Val Message) Export
	
	InitialMessagePackages = GetMessagePackages(Message);
	RegisteredInterfaces = MessageInterfacesSaaS.GetOutgoingMessageInterfaces();
	
	For Each InitialMessagePackage In InitialMessagePackages Do
		
		MessageInterface = RegisteredInterfaces.Get(InitialMessagePackage);
		If ValueIsFilled(MessageInterface) Then
			
			Return New Structure("Interface, Namespace", MessageInterface, InitialMessagePackage);
			
		EndIf;
		
	EndDo;
	
EndFunction

// For internal use
Function ExecuteTranslation(Val InitialObject, Val InitialVersionDescription, Val ResultingVersionDescription) Export
	
	InterfaceTranslationChain = GetTranslationChain(
			InitialVersionDescription,
			ResultingVersionDescription);
	If InterfaceTranslationChain = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Version %1 to %2 translation handler is not registered in the application.'"),
			GenerateVersionPresentation(InitialVersionDescription),
			GenerateVersionPresentation(ResultingVersionDescription));
	Else
		
		InterfaceTranslationTable = New ValueTable();
		InterfaceTranslationTable.Columns.Add("Key", New TypeDescription("String"));
		InterfaceTranslationTable.Columns.Add("Value", New TypeDescription("CommonModule"));
		InterfaceTranslationTable.Columns.Add("VersionNumber", New TypeDescription("Number"));
		
		For Each InterfaceTranslationStage In InterfaceTranslationChain Do
			
			TableStage = InterfaceTranslationTable.Add();
			FillPropertyValues(TableStage, InterfaceTranslationStage);
			Version = InterfaceTranslationStage.Value.ResultingVersion();
			Digits = StringFunctionsClientServer.SplitStringIntoSubstringArray(Version, ".");
			Iterator = 0;
			VersionNumber = 0;
			For Each Digit In Digits Do
				
				VersionNumber = VersionNumber + (Number(Digit) * Pow(1000, Digits.Count() - Iterator));
				Iterator = Iterator + 1;
				
			EndDo;
			TableStage.VersionNumber = VersionNumber;
			
		EndDo;
		
		InterfaceTranslationTable.Sort("VersionAsNumber Desc");
		
	EndIf;
	
	For Each InterfaceTranslationStage In InterfaceTranslationTable Do
		
		Handler = InterfaceTranslationStage.Value;
		
		ExecuteStandardProcessing = True;
		Handler.BeforeTranslation(InitialObject, ExecuteStandardProcessing);
		
		If ExecuteStandardProcessing Then
			InterfaceTranslationRules = GenerateInterfaceTranslationRules(InitialObject, InterfaceTranslationStage);
			InitialObject = TranslateObject(InitialObject, InterfaceTranslationRules);
		Else
			InitialObject = Handler.MessageTranslation(InitialObject);
		EndIf;
		
	EndDo;
	
	Return InitialObject;
	
EndFunction

// Returns a translation handler execution chain applicable for translation between message interface versions.
// If multiple translation chains applicable for translation between message interface versions 
// are registered in the application, returns the shortest one (with the least number of steps).
//
// Parameters:
//  InitialVersionDescription - Structure - description of initial version of the translated message,
//                                          sufficient for unambiguous definition of handlers 
//                                          in the translation table. 
//    Structure fields:
//      Number  - String - initial message version number in RR.{S|SS}.VV.BB format.
//      Package - String - namespace of the initial message version.
//  ResultingVersionDescription - Structure - description of resulting version of the translated message, 
//                                            sufficient for unambiguous definition of handlers 
//                                            in the translation table. 
//    Structure fields:
//      Number  - String - resulting message version number in RR.{S|SS}.VV.BB format.
//      Package - String - resulting message version namespace.
//
// Returns:
//  FixedMap:
//    Key   - package with the resulting message version.
//    Value - CommonModule - translation handler.
//
Function GetTranslationChain(Val InitialVersionDescription, Val ResultingVersionDescription) Export
	
	RegisteredTranslationHandlers = GetTranslationHandlers();
	
	TranslationChains = New Array();
	FindTranslationChains(
			RegisteredTranslationHandlers,
			InitialVersionDescription,
			ResultingVersionDescription,
			TranslationChains);
	
	If TranslationChains.Count() = 0 Then
		Return Undefined;
	Else
		Return SelectTranslationChain(TranslationChains);
	EndIf;
	
EndFunction

// Returns a list of packages included in the initial package dependencies.
//
// Parameters:
//  MessageObjectPackage - String - namespace of the package whose dependencies are to be analyzed.
//
// Returns:
//  FixedArray containing a set of strings.
//
Function GetPackageDependencies(Val MessageObjectPackage) Export
	
	Result = New Array();
	PackageDependencies = XDTOFactory.Packages.Get(MessageObjectPackage).Dependencies;
	For Each Relation In PackageDependencies Do
		
		MessageDependencyPackage = Relation.NamespaceURI;
		Result.Add(MessageDependencyPackage);
		NestedDependencies = GetPackageDependencies(MessageDependencyPackage);
		CommonUseClientServer.SupplementArray(Result, NestedDependencies, True);
		
	EndDo;
	
	Return New FixedArray(Result);
	
EndFunction

#EndRegion

#Region InternalProceduresAndFunctions

// For internal use
Function TranslateObject(Val Object, Val InterfaceTranslationRules)
	
	InitialObjectPackage = Object.Type().NamespaceURI;
	InterfaceTranslationChain = InterfaceTranslationRules.Get(InitialObjectPackage);
	
	If InterfaceTranslationChain = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot determine a translation handler for package {%1}. Standard translation required to handle this property cannot be performed.'"), 
			InitialObjectPackage);
	EndIf;
	
	If InterfaceTranslationChain.Count() > 0 Then
		
		For Each TranslationIteration In InterfaceTranslationChain Do
			
			Handler = TranslationIteration.Value;
			
			ExecuteStandardProcessing = True;
			Handler.BeforeTranslation(Object, ExecuteStandardProcessing);
			
			If ExecuteStandardProcessing Then
				Object = StandardProcessing(Object, Handler.ResultingVersionPackage(), InterfaceTranslationRules);
			Else
				Object = Handler.MessageTranslation(Object);
			EndIf;
			
		EndDo;
		
	Else
		
		// When a translation chain contains no iterations, this means that version number was not changed
		//  and you only need to copy property values from the initial object to the resulting object
		Object = StandardProcessing(Object, Object.Type().NamespaceURI, InterfaceTranslationRules);
		
	EndIf;
	
	Return Object;
	
EndFunction

// For internal use
Function StandardProcessing(Val Object, Val ResultingObjectPackage, Val InterfaceTranslationRules)
	
	InitialObjectType = Object.Type();
	If InitialObjectType.NamespaceURI = ResultingObjectPackage Then
		ResultingObjectType = InitialObjectType;
	Else
		ResultingObjectType = XDTOFactory.Type(ResultingObjectPackage, InitialObjectType.Name);
		If ResultingObjectType = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot execute standard translation of type %1 to package %2: type %1 is not available in package %2.'"),
				"{" + InitialObjectType.NamespaceURI + "}" + InitialObjectType.Name,
				"{" + ResultingObjectPackage + "}");
		EndIf;
	EndIf;
		
	ResultingObject = XDTOFactory.Create(ResultingObjectType);
	InitialObjectProperties = Object.Properties();
	
	For Each Property In ResultingObjectType.Properties Do
		
		OriginalProperty = InitialObjectType.Properties.Get(Property.LocalName);
		If OriginalProperty = Undefined Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot execute standard conversion of type %1 to type %2: property %3 is not defined for type %1.'"),
				"{" + InitialObjectType.NamespaceURI + "}" + InitialObjectType.Name,
				"{" + ResultingObjectType.NamespaceURI + "}" + ResultingObjectType.Name,
				Property.LocalName);
			
		EndIf;
		
	EndDo;
	
	For Each Property In InitialObjectType.Properties Do
		
		PropertyToTranslate = ResultingObjectType.Properties.Get(Property.LocalName);
		If PropertyToTranslate = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Cannot execute standard conversion of type %1 to type %2: property %3 is not defined for type %2.'"),
				"{" + InitialObjectType.NamespaceURI + "}" + InitialObjectType.Name,
				"{" + ResultingObjectType.NamespaceURI + "}" + ResultingObjectType.Name,
				Property.LocalName);
		EndIf;
			
		If Object.IsSet(Property) Then
			
			If Property.UpperBound = 1 Then
				
				// XDTODataObject or XDTODataValue
				ValueToTranslate = Object.GetXDTO(Property);
				
				If TypeOf(ValueToTranslate) = Type("XDTODataObject") Then
					ResultingObject.Set(PropertyToTranslate, TranslateObject(ValueToTranslate, InterfaceTranslationRules));
				Else
					ResultingObject.Set(PropertyToTranslate, ValueToTranslate);
				EndIf;
				
			Else
				
				// XDTOList
				ListToTranslate = Object.GetList(Property);
				
				For Iterator = 0 To ListToTranslate.Count() - 1 Do
					
					ListItem = ListToTranslate.GetXDTO(Iterator);
					
					If TypeOf(ListItem) = Type("XDTODataObject") Then
						ResultingObject[Property.LocalName].Add(TranslateObject(ListItem, InterfaceTranslationRules));
					Else
						ResultingObject[Property.LocalName].Add(ListItem);
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return ResultingObject;
	
EndFunction

// For internal use
Function GenerateInterfaceTranslationRules(Val Message, Val InterfaceTranslationIteration)
	
	InterfaceTranslationRules = New Map();
	
	InitialMessagePackages = New Array();
	ResultingMessagePackages = New Array();
	
	InitialMessagePackages = GetMessagePackages(Message);
	
	InterfaceTranslationHandler = InterfaceTranslationIteration.Value;
	
	ResultingMessagePackages.Add(InterfaceTranslationHandler.ResultingVersionPackage());
	CorrespondentPackageDependencies = GetPackageDependencies(InterfaceTranslationHandler.ResultingVersionPackage());
	CommonUseClientServer.SupplementArray(ResultingMessagePackages, CorrespondentPackageDependencies, True);
	
	InterfaceTranslationRule = New Map();
	InterfaceTranslationRule.Insert(InterfaceTranslationIteration.Key, InterfaceTranslationIteration.Value);
	
	InterfaceTranslationRules.Insert(InterfaceTranslationHandler.SourceVersionPackage(), InterfaceTranslationRule);
	
	For Each InitialMessagePackage In InitialMessagePackages Do
		
		TranslationChain = InterfaceTranslationRules.Get(InitialMessagePackage);
		
		If TranslationChain = Undefined Then
			
			If ResultingMessagePackages.Find(InitialMessagePackage) <> Undefined Then
				
				// Both the initial and the resulting interface versions use the same package. 
				// Instead of translating the package, you only need to copy the property values.
				InterfaceTranslationRules.Insert(InitialMessagePackage, New Map());
				
			Else
				
				// The package is used in the initial message interface version but not in the resulting one.
				// It is necessary to determine a resulting version package 
				// to which the initial version package must be translated.
				
				AvailableChains = New Array();
				For Each ResultingMessagePackage In ResultingMessagePackages Do
					
					PackageChain = GetTranslationChain(
						GenerateVersionDescription(
								, InitialMessagePackage),
						GenerateVersionDescription(
								, ResultingMessagePackage));
						
					If ValueIsFilled(PackageChain) Then
						 AvailableChains.Add(PackageChain);
					EndIf;
					
				EndDo;
				
				If AvailableChains.Count() > 0 Then
					
					ChainUsed = SelectTranslationChain(AvailableChains);
					InterfaceTranslationRules.Insert(InitialMessagePackage, ChainUsed);
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return InterfaceTranslationRules;
	
EndFunction

// Returns an array filled with namespaces used in the message.
//
// Parameters:
//  Message - XDTODataObject - a message whose namespace list is requested.
//
// Returns:
//  Array containing a set of strings.
//
Function GetMessagePackages(Val Message)
	
	Result = New Array();
	
	// XDTO object package
	MessageObjectPackage = Message.Type().NamespaceURI;
	Result.Add(MessageObjectPackage);
	
	// XDTO object package dependencies
	Dependencies = GetPackageDependencies(MessageObjectPackage);
	CommonUseClientServer.SupplementArray(Result, Dependencies, True);
	
	// XDTO object properties
	ObjectProperties = Message.Properties();
	For Each Property In ObjectProperties Do
		
		If Message.IsSet(Property) Then
			
			If Property.UpperBound = 1 Then
				
				PropertyValue = Message.GetXDTO(Property);
				
				If TypeOf(PropertyValue) = Type("XDTODataObject") Then
				
					PropertyPackages = GetMessagePackages(PropertyValue);
					CommonUseClientServer.SupplementArray(Result, PropertyPackages, True);
					
				EndIf;
				
			Else
				
				ListOfProperties = Message.GetList(Property);
				Iterator = 0;
				
				For Iterator = 0 To ListOfProperties.Count() - 1 Do
					
					ListItem = ListOfProperties.GetXDTO(Iterator);
					
					If TypeOf(ListItem) = Type("XDTODataObject") Then
						
						PropertyPackages = GetMessagePackages(ListItem);
						CommonUseClientServer.SupplementArray(Result, PropertyPackages, True);
						
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// This procedure is used to generate translation handler execution chains
// required for message version translation.
//
// Parameters:
//  TranslationHandlers - ValueTable (whose structure was generated by GenerateTranslationHandlerTable()
//      function), containing all message translation handlers registered in the application.
//  InitialVersionDescription - Structure - description of initial version of the translated message,
//      sufficient for unambiguous definition of handlers in the translation table. 
//    Structure fields:
//      Number  - String - initial message version number in RR.{S|SS}.VV.BB format.
//      Package - String - namespace of the initial message version.
//  ResultingVersionDescription - Structure - description of resulting version of the translated message,
//      sufficient for unambiguous definition of handlers in the translation table.
//    Structure fields:
//      Number  - String - resulting message version number in RR.{S|SS}.VV.BB format. 
//      Package - String - namespace of the resulting message version.
//  TranslationChains - Array - once the procedure is completed, this parameter contains all translation 
//      chains available for message translation from the initial version to the resulting version. 
//      The array contains a set of fixed key-value pairs (key - namespace of the resulting version package,
//      value - CommonModule used as translation handler). 
//  CurrentChain - internal parameter used for recursive procedure execution. 
//      Must not be set during the initial call.
//
Procedure FindTranslationChains(Val TranslationHandlers, Val InitialVersionDescription, 
			Val ResultingVersionDescription, TranslationChains, CurrentChain = Undefined)
	
	Filter = New Structure();
	If ValueIsFilled(InitialVersionDescription.Number) Then
		Filter.Insert("SourceVersion", InitialVersionDescription.Number);
	EndIf;
	If ValueIsFilled(InitialVersionDescription.Package) Then
		Filter.Insert("SourceVersionPackage", InitialVersionDescription.Package);
	EndIf;
	
	Branches = TranslationHandlers.Copy(Filter);
	For Each Branch In Branches Do
		
		If CurrentChain = Undefined Then
			CurrentChain = New Map();
		EndIf;
		CurrentChain.Insert(Branch.ResultingVersionPackage, Branch.Handler);
		
		If Branch.ResultingVersion = ResultingVersionDescription.Number
				Or Branch.ResultingVersionPackage = ResultingVersionDescription.Package Then
			TranslationChains.Add(New FixedMap(CurrentChain));
		Else
			FindTranslationChains(TranslationHandlers,
					GenerateVersionDescription(
							, Branch.ResultingVersionPackage),
					GenerateVersionDescription(
							ResultingVersionDescription.Number, ResultingVersionDescription.Package),
					TranslationChains, CurrentChain);
		EndIf;
			
	EndDo;
	
EndProcedure

// Translation handler table constructor
Function CreateTranslationHandlerTable()
	
	Result = New ValueTable();
	Result.Columns.Add("SourceVersion");
	Result.Columns.Add("SourceVersionPackage");
	Result.Columns.Add("ResultingVersion");
	Result.Columns.Add("ResultingVersionPackage");
	Result.Columns.Add("Handler");
	
	Return Result;
	
EndFunction

// Returns a table of message translation handlers registered in the application.
//
Function GetTranslationHandlers()
	
	Result = CreateTranslationHandlerTable();
	TranslationHandlerArray = New Array();
	
	MessageTranslationHandlers = MessageInterfacesSaaS.GetMessageTranslationHandlers();
	CommonUseClientServer.SupplementArray(TranslationHandlerArray, MessageTranslationHandlers);
	
	XDTOTranslationOverridable.FillMessageTranslationHandlers(TranslationHandlerArray);
	
	For Each Handler In TranslationHandlerArray Do
		
		HandlerRegistration = Result.Add();
		HandlerRegistration.SourceVersion = Handler.SourceVersion();
		HandlerRegistration.ResultingVersion = Handler.ResultingVersion();
		HandlerRegistration.SourceVersionPackage = Handler.SourceVersionPackage();
		HandlerRegistration.ResultingVersionPackage = Handler.ResultingVersionPackage();
		HandlerRegistration.Handler = Handler;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion
