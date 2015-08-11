// Internal use only.
Function SubsystemNames() Export
	
	Names = New Map;
	AddSubordinateSubysystemNames(Names, Metadata);
	
	Return New FixedMap(Names);
	
EndFunction

// Internal use only.
Procedure AddSubordinateSubysystemNames(Names, ParentSubsystem, All = False, ParentSubsystemName = "")
	
	For Each CurrentSubsystem In ParentSubsystem.Subsystems Do
		
		If CurrentSubsystem.IncludeInCommandInterface And Not All Then
			Continue;
		EndIf;
		
		CurrentSubsystemName = ParentSubsystemName + CurrentSubsystem.Name;
		Names.Insert(CurrentSubsystemName, True);
		
		If CurrentSubsystem.Subsystems.Count() = 0 Then
			Continue;
		EndIf;
		
		AddSubordinateSubysystemNames(Names, CurrentSubsystem, All, CurrentSubsystemName + ".");
	EndDo;
	
EndProcedure

// Internal use only.
Function ProgramEventParameters() Export
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationParameters(
		"InternalEventParameters");
	SetPrivilegedMode(False);
	
	StandardSubsystemsServer.CheckIfApplicationRunParametersUpdated(
		"InternalEventParameters",
		"EventHandlers");
	
	If Not SavedParameters.Property("EventHandlers") Then
		StandardSubsystemsServerCall.EventHandlersGettingOnError();
	EndIf;
	
	SetPrivilegedMode(True);
	SavedParameters = StandardSubsystemsServer.ApplicationParameters(
		"InternalEventParameters");
	SetPrivilegedMode(False);
	
	ParameterPresentation = "";
	
	If Not SavedParameters.Property("EventHandlers") Then
		ParameterPresentation = NStr("en='Event handlers'");
	EndIf;
	
	If ValueIsFilled(ParameterPresentation) Then
		
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en='Error updating the infobase."
"The following internal event parameter is not filled:"
"%1.'")
			+ StandardSubsystemsServer.ApplicationRunParameterErrorClarificationForDeveloper(),
			ParameterPresentation);
	EndIf;
	
	Return SavedParameters;
	
EndFunction

// Internal use only.
Function ApplicationParameters(ConstantName) Export
	
	Parameters = Constants[ConstantName].Get().Get();
	
	If TypeOf(Parameters) <> Type("Structure") Then
		Parameters = New Structure;
	EndIf;
	
	Return New FixedStructure(Parameters);
	
EndFunction

// Internal use only.
Function SubsystemDescriptions() Export
	
	SubsystemModules = New Array;
	SubsystemModules.Add("InfoBaseUpdateSL");
	
	ConfigurationSubsystemsOverridable.SubsystemOnAdd(SubsystemModules);
	
	ConfigurationDescriptionFound = False;
	SubsystemDescriptions = New Structure;
	SubsystemDescriptions.Insert("Order",  New Array);
	SubsystemDescriptions.Insert("ByNames", New Map);
	
	AllRequiredSubsystems = New Map;
	
	For Each ModuleName In SubsystemModules Do
		
		Description = NewSubsystemDescription();
		Module = CommonUse.CommonModule(ModuleName);
		Module.SubsystemOnAdd(Description);
		
		If Description.Name = "StandardSubsystems" Then

			Description.AddInternalEvents            = True;
			Description.AddInternalEventHandlers = True;
		EndIf;
		
		CommonUseClientServer.Validate(SubsystemDescriptions.ByNames.Get(Description.Name) = Undefined,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr(""),
				ModuleName, Description.Name));
		
		If Description.Name = Metadata.Name Then
			ConfigurationDescriptionFound = True;
			Description.Insert("IsConfiguration", True);
		Else
			Description.Insert("IsConfiguration", False);
		EndIf;
		
		Description.Insert("MainServerModule", ModuleName);
		
		SubsystemDescriptions.ByNames.Insert(Description.Name, Description);

		SubsystemDescriptions.Order.Add(Description.Name);

		For Each RequiredSubsystem In Description.RequiredSubsystems Do
			If AllRequiredSubsystems.Get(RequiredSubsystem) = Undefined Then
				AllRequiredSubsystems.Insert(RequiredSubsystem, New Array);
			EndIf;
			AllRequiredSubsystems[RequiredSubsystem].Add(Description.Name);
		EndDo;
	EndDo;
	
	If ConfigurationDescriptionFound Then
		Description = SubsystemDescriptions.ByNames[Metadata.Name];
		
		CommonUseClientServer.Validate(Description.Version = Metadata.Version,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error preparing subsystem descriptions:"
"%2 version of %1 configuration does not match %4"
"metadata version of the configuration. See %3.SubsystemOnAdd procedure.'"),
				Description.Name,
				Description.Version,
				Description.MainServerModule,
				Metadata.Version));
	Else
		Description = NewSubsystemDescription();
		Description.Insert("Name",    Metadata.Name);
		Description.Insert("Version", Metadata.Version);
		Description.Insert("IsConfiguration", True);
		SubsystemDescriptions.ByNames.Insert(Description.Name, Description);
		SubsystemDescriptions.Order.Add(Description.Name);
	EndIf;
	
	For Each KeyAndValue In AllRequiredSubsystems Do
		If SubsystemDescriptions.ByNames.Get(KeyAndValue.Key) = Undefined Then
			DependentSubsystems = "";
			For Each DependentSubsystem In KeyAndValue.Value Do
				DependentSubsystems = Chars.LF + DependentSubsystem;
			EndDo;
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='Error preparing subsystem descriptions:"
"%2 subsystem depends on %1 subsystem, which is not found.'"),
				KeyAndValue.Key,
				DependentSubsystems);
		EndIf;
	EndDo;
	
	For Each KeyAndValue In SubsystemDescriptions.ByNames Do
		Name = KeyAndValue.Key;
		Order = SubsystemDescriptions.Order.Find(Name);
		For Each RequiredSubsystem In KeyAndValue.Value.RequiredSubsystems Do
			RequiredSubsystemOrder = SubsystemDescriptions.Order.Find(RequiredSubsystem);
			If Order < RequiredSubsystemOrder Then
				Interinfluence = SubsystemDescriptions.ByNames[RequiredSubsystem
					].RequiredSubsystems.Find(Name) <> Undefined;
				If Interinfluence Then
					NewOrder = RequiredSubsystemOrder;
				Else
					NewOrder = RequiredSubsystemOrder + 1;
				EndIf;
				If Order <> NewOrder Then
					SubsystemDescriptions.Order.Insert(NewOrder, Name);
					SubsystemDescriptions.Order.Delete(Order);
					Order = NewOrder - 1;
				EndIf;
			EndIf;
		EndDo;
	EndDo;

	Index = SubsystemDescriptions.Order.Find(Metadata.Name);
	If SubsystemDescriptions.Order.Count() > Index + 1 Then
		SubsystemDescriptions.Order.Delete(Index);
		SubsystemDescriptions.Order.Add(Metadata.Name);
	EndIf;
	
	For Each KeyAndValue In SubsystemDescriptions.ByNames Do
		
		KeyAndValue.Value.RequiredSubsystems =
			New FixedArray(KeyAndValue.Value.RequiredSubsystems);
		
		SubsystemDescriptions.ByNames[KeyAndValue.Key] =
			New FixedStructure(KeyAndValue.Value);
	EndDo;
	
	SubsystemDescriptions.Order  = New FixedArray(SubsystemDescriptions.Order);
	SubsystemDescriptions.ByNames = New FixedMap(SubsystemDescriptions.ByNames);
	
	Return New FixedStructure(SubsystemDescriptions);
	
EndFunction

// Internal use only.
Function NewSubsystemDescription()
	
	Description = New Structure;
	Description.Insert("Name",    "");
	Description.Insert("Version", "");
	Description.Insert("RequiredSubsystems", New Array);
	
	Description.Insert("IsConfiguration", False);
	
	Description.Insert("MainServerModule", "");
	
	Description.Insert("AddEvents",        False);
	Description.Insert("AddEventHandlers", False);
	
	Description.Insert("AddInternalEvents",        False);
	Description.Insert("AddInternalEventHandlers", False);
	
	Return Description;
	
EndFunction

// Internal use only.
Function ServerEventHandlers(Event, Internal = False) Export
	
	PreparedHandlers = PreparedServerEventHandlers(Event, Internal);
	
	If PreparedHandlers = Undefined Then
		StandardSubsystemsServerCall.EventHandlersGettingOnError();
		RefreshReusableValues();
		PreparedHandlers = PreparedServerEventHandlers(Event, Internal, False);
	EndIf;
	
	Return PreparedHandlers;
	
EndFunction

// Internal use only.
Function PreparedServerEventHandlers(Event, Internal = False, FirstAttempt = True)
	
	Parameters = StandardSubsystemsCached.ProgramEventParameters()
		.EventHandlers.AtServer;
	
	If Internal Then
		Handlers = Parameters.InternalEventHandlers.Get(Event);
	Else
		Handlers = Parameters.EventHandlers.Get(Event);
	EndIf;
	
	If FirstAttempt And Handlers = Undefined Then
		Return Undefined;
	EndIf;
	
	If Handlers = Undefined Then
		If Internal Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 internal server message not found.'"), Event);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en='%1 server message not found.'"), Event);
		EndIf;
	EndIf;
	
	Array = New Array;
	
	For Each Handler In Handlers Do
		Element = New Structure;
		Module = Undefined;
		If FirstAttempt Then
			Try
				Module = CommonUse.CommonModule(Handler.Module);
			Except
				Return Undefined;
			EndTry;
		Else
			Module = CommonUse.CommonModule(Handler.Module);
		EndIf;
		Element.Insert("Module",    Module);
		Element.Insert("Version",   Handler.Version);
		Element.Insert("Subsystem", Handler.Subsystem);
		Array.Add(New FixedStructure(Element));
	EndDo;
	
	Return New FixedArray(Array);
	
EndFunction

