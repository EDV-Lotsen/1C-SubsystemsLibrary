////////////////////////////////////////////////////////////////////////////////
// InfobaseUpdateCTL: Cloud technology library (CTL).
// CTL procedures and functions.
//
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
// INTERFACE

Procedure OnAddSubsystem(Description) Export
	
	Description.Name    = "CloudTechnologyLibrary";
	Description.Version = CloudTechnology.LibVersion();
	
	// Using internal events and internal event handlers
	Description.AddInternalEvents        = True;
	Description.AddInternalEventHandlers = True;
	
	// Standard subsystems library is required
	Description.RequiredSubsystems.Add("StandardSubsystems");
	
EndProcedure

// Redefines events that can be complemented
// with extra handlers using the InternalEventHandlersOnAdd procedure.
//
// Parameters:
//  ClientEvents - Array containing full names of events (values of String type).
//  ServerEvents - Array containing full names of events (values of String type).
//
// We recommend that you call the same procedure in the common library module 
// to facilitate the support process.
//
// Example of usage in a common library module:
// //
// // Replaces the default notification with a custom form containing the active user list.
// //
// // Parameters:
// // FormName - String (return value).
// //
// // Syntax:
// // Procedure ActiveUserFormOnOpen(FormName) Export
// //
// ServerEvents.Add("StandardSubsystems.BaseFunctionality\ActiveUserFormOnDefine");
//
// You may copy the comment when creating a new handler.
// The Syntax section is used to create a new handler procedure.
//
Procedure OnAddInternalEvent(ClientEvents, ServerEvents) Export
	
	// Mandatory sybsystems
	DataExportImportInternalEvents.OnAddInternalEvent(ClientEvents, ServerEvents);
	
	// Optional subsystems
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.FileFunctionsSaaS") Then
		ModuleFileFunctionsInternalSaaSCTL = CTLAndSLIntegration.CommonModule("FileFunctionsInternalSaaSCTL");
		ModuleFileFunctionsInternalSaaSCTL.OnAddInternalEvent(ClientEvents, ServerEvents);
	EndIf;
	
EndProcedure

// See the description of this procedure in the StandardSubsystemsServer module.
Procedure InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers) Export
	
	// SERVER HANDLERS
	
	CloudTechnology.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.InformationCenter") Then
		
		ModuleInformationCenterInternal = CTLAndSLIntegration.CommonModule("InformationCenterInternal");
		ModuleInformationCenterInternal.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.DataExchangeSaaS") Then
		
		ModuleDataExchangeSaaSCTL = CTLAndSLIntegration.CommonModule("DataExchangeInternalSaaSCTL");
		ModuleDataExchangeSaaSCTL.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.InfobaseVersionUpdateSaaS") Then
		
		ModuleInfobaseUpdateInternalSaaSCTL = CTLAndSLIntegration.CommonModule("InfobaseUpdateInternalSaaSCTL");
		ModuleInfobaseUpdateInternalSaaSCTL.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.UsersSaaS") Then
		
		ModuleUsersInternalSaaSCTL = CTLAndSLIntegration.CommonModule("UsersInternalSaaSCTL");
		ModuleUsersInternalSaaSCTL.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.AccessManagementSaaS") Then
		
		ModuleAccessManagementInternalSaaSCTL = CTLAndSLIntegration.CommonModule("AccessManagementInternalSaaSCTL");
		ModuleAccessManagementInternalSaaSCTL.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.FileFunctionsSaaS") Then
		
		ModuleFileFunctionsInternalSaaSCTL = CTLAndSLIntegration.CommonModule("FileFunctionsInternalSaaSCTL");
		ModuleFileFunctionsInternalSaaSCTL.InternalEventHandlersOnAdd(ClientHandlers, ServerHandlers);
		
	EndIf;
	
EndProcedure

// Adds the Infobase data update handler procedures 
// for all supported versions of the library or configuration to the list.
// Called before the beginning of Infobase data update to build the update plan.
//
// Parameters:
//  Handlers - ValueTable - for field description, see the InfobaseUpdate.NewUpdateHandlerTable procedure.
//
// Example of adding a handler procedure to the list:
//  Handler = Handlers.Add();
//  Handler.Version        = "1.0.0.0";
//  Handler.Procedure      = "InfobaseUpdate.GoToVervion_1_0_0_0";
//  Handler.ExclusiveMode  = False;
//  Handler.Optional       = True;
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	CloudTechnology.RegisterUpdateHandlers(Handlers);
	
	// Mandatory sybsystems
	DataExportImportInternal.RegisterUpdateHandlers(Handlers);
	
	// Optional subsystems
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.InformationCenter") Then
		ModuleInformationCenterInternal = CTLAndSLIntegration.CommonModule("InformationCenterInternal");
		ModuleInformationCenterInternal.RegisterUpdateHandlers(Handlers);
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.UsersSaaS") Then
		ModuleUsersInternalSaaSCTL = CTLAndSLIntegration.CommonModule("UsersInternalSaaSCTL");
		ModuleUsersInternalSaaSCTL.RegisterUpdateHandlers(Handlers);
	EndIf;
	
	If CTLAndSLIntegration.SubsystemExists("CloudTechnology.SaaSOperations.FileFunctionsSaaS") Then
		ModuleFileFunctionsInternalSaaSCTL = CTLAndSLIntegration.CommonModule("FileFunctionsInternalSaaSCTL");
		ModuleFileFunctionsInternalSaaSCTL.RegisterUpdateHandlers(Handlers);
	EndIf;
	
EndProcedure

// The procedure is called before the infobase data update handler procedures.
//
Procedure InfobaseBeforeUpdate() Export
	
	
	
EndProcedure

// The procedure is called after the infobase data is updated.
//		
// Parameters:
//   PreviousVersion   - String    - version before update. "0.0.0.0" for an empty infobase.
//   CurrentVersion    - String    - version after update.
//   ExecutedHandlers  - ValueTree - The list of executed handlers grouped by version number.
//   ShowUpdateDetails - Boolean   - (return value) If True, the update description form is displayed. 
//                                   The default value is True.
//   ExclusiveMode     - Boolean   - flag specifying whether the update was performed in exclusive mode.
//		
// Example of iteration through executed update handlers:
//		
// For Each Version In CompletedHandlers.Rows Do
//		
// 	If Version.Version = "*" Then
// 		  // Handler that is executed with each version change
// 	Else
// 		  // Handler that is executed for a certain version
// 	EndIf;
//		
// 	For Each Handler In Version.Rows Do
// 		...
// 	EndDo;
//		
// EndDo;
//
Procedure AfterInfobaseUpdate(Val PreviousVersion, Val CurrentVersion,
		Val ExecutedHandlers, ShowUpdateDetails, ExclusiveMode) Export
	
	
	
EndProcedure

// Called when preparing the spreadsheet document with the application update list.
//
// Parameters:
//   Template - SpreadsheetDocument - all libraries and configuration update description.
//              Template can be supplemented or replaced.
//              See also common ApplicationReleaseNotes layout.
//
Procedure OnPrepareUpdateDetailsTemplate(Val Template) Export
	
	
	
EndProcedure

