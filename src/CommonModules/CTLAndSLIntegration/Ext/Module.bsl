////////////////////////////////////////////////////////////////////////////////
// Information center subsystem.
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// INTERNAL INTERFACE

////////////////////////////////////////////////////////////////////////////////
// Base functionality

// See CommonUse.WSProxy()
//
Function WSProxy(
			Val WSDLAddress,
			Val NamespaceURI,
			Val ServiceName,
			Val EndpointName = "",
			Val UserName,
			Val Password,
			Val Timeout = Undefined,
			Val ProbingCallRequired = False) Export
	
	Return CommonUse.WSProxy(WSDLAddress,
			NamespaceURI,
			ServiceName,
			EndpointName,
			UserName,
			Password,
			Timeout,
			ProbingCallRequired);
	
EndFunction

Function ValueToXMLString(Val Value) Export
	Return CommonUse.ValueToXMLString(Value);
EndFunction

Procedure SetSessionSeparation(Val Use, Val DataArea = Undefined) Export
	
	CommonUse.SetSessionSeparation(Use, DataArea);
	
EndProcedure

Procedure LockInfobase(Val CheckNoOtherSessions = True) Export
	
	CommonUse.LockInfobase(CheckNoOtherSessions);
	
EndProcedure

Procedure UnlockInfobase() Export
	CommonUse.UnlockInfobase();
EndProcedure

Function SubjectString(Val SubjectRef) Export
	Return CommonUse.SubjectString(SubjectRef);
EndFunction

// See CommonUseCached.DataSeparationEnabled()
//
Function DataSeparationEnabled() Export
	
	Return CommonUseCached.DataSeparationEnabled();
	
EndFunction

// See CommonUseCached.CanUseSeparatedData()
//
Function CanUseSeparatedData() Export
	
	Return CommonUseCached.CanUseSeparatedData();
	
EndFunction

// See CommonUseCached.SessionSeparatorValue()
//
Function SessionSeparatorValue() Export
	
	Return CommonUse.SessionSeparatorValue();
	
EndFunction

Function AuxiliaryDataSeparator() Export
	Return CommonUseCached.AuxiliaryDataSeparator();
EndFunction

// See CommonUse.OnCreateAtServer()
//
Function OnCreateAtServer(Form, Cancel, StandardProcessing) Export
	
	Return CommonUse.OnCreateAtServer(Form, Cancel, StandardProcessing);
	
EndFunction

// See CommonUseClientServer.ObjectManagerByFullName()
//
Function ObjectManagerByFullName(MetadataObjectFullName) Export
	
	Return CommonUse.ObjectManagerByFullName(MetadataObjectFullName)
	
EndFunction

// See StandardSubsystemsCached.IsPlatform83WithoutCompatibilityMode()
//
Function IsPlatform83WithoutCompatibilityMode() Export 
	
	Return CommonUseClientServer.IsPlatform83WithoutCompatibilityMode();
	
EndFunction

// See CommonUseClientServer.SupplementTable()
//
Procedure SupplementTable(SourceTable, TargetTable) Export
	
	CommonUseClientServer.SupplementTable(SourceTable, TargetTable);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// CommonUseClientServer

// See CommonUseClientServer.SubsystemExists()
//
Function SubsystemExists(FullSubsystemName) Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return CommonUse.SubsystemExists(FullSubsystemName);
#Else
	Return CommonUseClient.SubsystemExists(FullSubsystemName);
#EndIf
	
EndFunction

// See CommonUseClientServer.CommonModule()
//
Function CommonModule(Name) Export
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return CommonUse.CommonModule(Name);
#Else
	Return CommonUseClient.CommonModule(Name);
#EndIf
	
EndFunction

// See CommonUseClientServer.UsualGroupRepresentationLine()
//
Function UsualGroupRepresentationLine() Export
	
	Return CommonUseClientServer.UsualGroupRepresentationLine();
	
EndFunction

Function DefaultLanguageCode() Export
	Return CommonUseClientServer.DefaultLanguageCode();
EndFunction

Function CompareVersions(Val VersionString1, Val VersionString2) Export
	Return CommonUseClientServer.CompareVersions(VersionString1, VersionString2);
EndFunction

Procedure MessageToUser(
		Val MessageToUserText,
		Val DataKey = Undefined,
		Val Field = "",
		Val DataPath = "",
		Cancel = False) Export
	CommonUseClientServer.MessageToUser(MessageToUserText,
		DataKey,	Field, DataPath, Cancel);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// StringFunctionsClientServer

Function SubstituteParametersInString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined,
	Val Parameter4 = Undefined, Val Parameter5 = Undefined, Val Parameter6 = Undefined,
	Val Parameter7 = Undefined, Val Parameter8 = Undefined, Val Parameter9 = Undefined) Export
	Return StringFunctionsClientServer.SubstituteParametersInString(SubstitutionString,
	Parameter1, Parameter2, Parameter3, Parameter4, Parameter5, Parameter6, Parameter7, Parameter8, Parameter9);
EndFunction

Function IsUUID(Val String) Export
	Return StringFunctionsClientServer.IsUUID(String);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Basic functionality SaaS

// See MessagesSaaSCached.TypeBody()
//
Function TypeBody() Export 
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// See SaaSOperationsCached.ServiceManagerEndpoint()
//
Function ServiceManagerEndpoint() Export
	
	Return SaaSOperationsCached.ServiceManagerEndpoint();
	
EndFunction

// See SaaSOperations.SelectionParameters()
//
Function SelectionParameters(MetadataObjectFullName) Export 
	
	Return SaaSOperations.SelectionParameters(MetadataObjectFullName);
	
EndFunction

Procedure LockCurrentDataArea(Val CheckNoOtherSessions = False, Val SeparatedLock = False) Export
	SaaSOperations.LockCurrentDataArea(CheckNoOtherSessions, SeparatedLock);
EndProcedure

Procedure UnlockCurrentDataArea() Export
	SaaSOperations.UnlockCurrentDataArea();
EndProcedure

Function GetDataAreaModel() Export
	Return SaaSOperationsCached.GetDataAreaModel();
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Message exchange

// See MessageExchange.SendMessage()
//
Procedure SendMessage(MessageChannel, Body, Recipient) Export
	
	MessageExchange.SendMessage(MessageChannel, Body, Recipient);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Users

Function InfobaseUserWithFullAccess(User = Undefined,
                                    CheckSystemAdministrationRights = False,
                                    ForPrivilegedMode = True) Export
	
	Return Users.InfobaseUserWithFullAccess(User, CheckSystemAdministrationRights, ForPrivilegedMode);
	
EndFunction

