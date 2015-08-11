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
// Return:
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

// Returns map of session parameter names and their initialize handlers.
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
	
	//// _Demo example start
	//
	//// Questioning
	//CommonUse.AddID(IDs, "bee5156e-0e5c-476f-ab09-384f407ab751", Metadata.Subsystems._DemoQuestioning);
	//CommonUse.AddID(IDs, "de8850cf-f6e2-4f8d-bdd9-2e8119c05294", Metadata.Subsystems._DemoQuestioning.Subsystems._DemoRespondents);
	//CommonUse.AddID(IDs, "51a3de9c-25de-442b-a2ba-ea6901ecb224", Metadata.Subsystems._DemoQuestioning.Subsystems._DemoCreatingQuestionnairesAndPolls);
	//CommonUse.AddID(IDs, "b581ac99-f561-4426-aa50-67af159ae6b5", Metadata.Subsystems._DemoQuestioning.Subsystems._DemoExternalUserManagement);
	//CommonUse.AddID(IDs, "b1d909a2-e298-42b7-8361-cc3ab8d5beef", Metadata.Subsystems._DemoQuestioning.Subsystems._DemoQuestioningProgressAndAnalysis);
	//
	//// Business processes and tasks
	//CommonUse.AddID(IDs, "c9a466b0-2929-4089-841e-2ef6064e1617", Metadata.Subsystems._DemoBusinessProcessesAndTasks);
	//CommonUse.AddID(IDs, "ef3a6b7b-d5d5-44ba-aa5f-0735c0e68ca5", Metadata.Subsystems._DemoBusinessProcessesAndTasks.Subsystems._DemoIssuingTasks);
	//CommonUse.AddID(IDs, "2e3a2528-4878-4a09-8610-fa6c30f357fc", Metadata.Subsystems._DemoBusinessProcessesAndTasks.Subsystems._DemoTasksCompletion);
	//CommonUse.AddID(IDs, "92d0f422-bb4f-46f1-aaf0-711668dae3de", Metadata.Subsystems._DemoBusinessProcessesAndTasks.Subsystems._DemoCompletionControl);
	//CommonUse.AddID(IDs, "8ac82481-f2da-470a-9852-6db5978d4ac6", Metadata.Subsystems._DemoBusinessProcessesAndTasks.Subsystems._DemoTaskMonitoring);
	//CommonUse.AddID(IDs, "40e09e88-aa81-4b47-8dff-aa3cd56a97a0", Metadata.Subsystems._DemoBusinessProcessesAndTasks.Subsystems._DemoRoleAddressingSetup);
	//
	//// Developer tools
	//CommonUse.AddID(IDs, "fb2646a3-9e56-44ff-be54-895795bd5708", Metadata.Subsystems._DemoDeveloperTools);
	//CommonUse.AddID(IDs, "359eef9f-fd20-417e-bc27-c84e3d32ddf8", Metadata.Subsystems._DemoDeveloperTools.Subsystems.BaseFunctionality);
	//CommonUse.AddID(IDs, "8d9f2584-789f-4eb7-ad15-1503b753db81", Metadata.Subsystems._DemoDeveloperTools.Subsystems.ReportVariants);
	//CommonUse.AddID(IDs, "6713e0a1-c6a6-45cb-9efa-418a06b7dcc5", Metadata.Subsystems._DemoDeveloperTools.Subsystems.AdditionalReportsAndDataProcessors);
	//CommonUse.AddID(IDs, "e7bbacc8-29b7-45c5-8a60-22e4d12495d5", Metadata.Subsystems._DemoDeveloperTools.Subsystems.DataExchange);
	//CommonUse.AddID(IDs, "baaa4b08-ea37-4d13-a566-5bd260bbb762", Metadata.Subsystems._DemoDeveloperTools.Subsystems.InfoBaseVersionUpdate);
	//CommonUse.AddID(IDs, "17fc3346-bfe1-4aba-a175-b0913b5dfc80", Metadata.Subsystems._DemoDeveloperTools.Subsystems.ConfigurationUpdate);
	//CommonUse.AddID(IDs, "c6ab98ae-9a67-4749-a66e-27e9607b5272", Metadata.Subsystems._DemoDeveloperTools.Subsystems.InfoBaseBackup);
	//CommonUse.AddID(IDs, "62719e42-aca4-4f5d-9a69-3a56141298ba", Metadata.Subsystems._DemoDeveloperTools.Subsystems.AccessManagement);
	//
	//// Integrable subsystems
	//CommonUse.AddID(IDs, "363d00c5-a2ef-4726-a810-cc3f90fcc0a9", Metadata.Subsystems._DemoIntegrableSubsystemsPart1);
	//CommonUse.AddID(IDs, "83da4248-96a0-4579-b09a-c3b42f7c524d", Metadata.Subsystems._DemoIntegrableSubsystemsPart1.Subsystems._DemoVersioning);
	//CommonUse.AddID(IDs, "33a2e758-3f06-428c-bd81-b47df993beb4", Metadata.Subsystems._DemoIntegrableSubsystemsPart1.Subsystems._DemoAdditionalReportsAndDataProcessors);
	//CommonUse.AddID(IDs, "e11b1922-c7e7-4933-a313-1bad4aa319f5", Metadata.Subsystems._DemoIntegrableSubsystemsPart1.Subsystems._DemoContactInformation);
	//CommonUse.AddID(IDs, "494e121e-4e7e-4b45-9384-314f73f86d85", Metadata.Subsystems._DemoIntegrableSubsystemsPart1.Subsystems._DemoPrint);
	//CommonUse.AddID(IDs, "309be704-af25-4542-874e-db8990803678", Metadata.Subsystems._DemoIntegrableSubsystemsPart1.Subsystems._DemoReportMailings);
	//CommonUse.AddID(IDs, "f5d4b1fe-2b72-4e6e-bafc-7c19986c3e03", Metadata.Subsystems._DemoIntegrableSubsystemsPart1.Subsystems._DemoProperties);
	//
	//// Integrable subsystems part 2
	//CommonUse.AddID(IDs, "ebf42785-8a47-4470-9abb-7e0667902479", Metadata.Subsystems._DemoIntegrableSubsystemsPart2);
	//CommonUse.AddID(IDs, "7366b067-14b0-49be-beb0-5a83fb1a02a5", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoBatchObjectChanging);
	//CommonUse.AddID(IDs, "c17fc950-a449-45e9-a26e-e8bc0ffb11b8", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoEditProhibitionDates);
	//CommonUse.AddID(IDs, "40af5545-e5a7-4d85-877e-b102cb1bdb48", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoUserNotes);
	//CommonUse.AddID(IDs, "543f9b2e-25b6-4253-98ec-c5800f0d6003", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoAttributeEditProhibition);
	//CommonUse.AddID(IDs, "5b0fafce-41e8-466a-bb02-dabfaf9373af", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoPersonalDataProtection);
	//CommonUse.AddID(IDs, "03e0c66a-efb1-4719-abe5-b038bce2219a", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoDocumentManagementIntegration);
	//CommonUse.AddID(IDs, "69edbd48-53a1-4d12-88da-2704ba92964d", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoUserReminders);
	//CommonUse.AddID(IDs, "a681fc0d-71cc-44ae-82a4-0c0005d27a63", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoItemOrderSetup);
	//CommonUse.AddID(IDs, "fa6b472f-4dfb-432a-88ca-a3736556c501", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoAttachedFiles);
	//CommonUse.AddID(IDs, "8a9fadfc-b39b-467e-82c2-482223166164", Metadata.Subsystems._DemoIntegrableSubsystemsPart2.Subsystems._DemoDependencies);
	//
	//// Setup and administration
	//CommonUse.AddID(IDs, "d7e1820e-a20c-45fa-97a9-f93c05c55de5", Metadata.Subsystems._DemoSetupAndAdministration);
	//CommonUse.AddID(IDs, "6ef905b0-8b1a-4b6e-ad9d-bcbfaed8b409", Metadata.Subsystems._DemoSetupAndAdministration.Subsystems._DemoSuppliedData);
	//CommonUse.AddID(IDs, "4b2f4945-b47b-4550-a808-4b45b8a63033", Metadata.Subsystems._DemoSetupAndAdministration.Subsystems._DemoServiceModeOperations);
	//
	//// Data exchange
	//CommonUse.AddID(IDs, "429cc866-acc2-41ca-b80b-41dac2adca02", Metadata.Subsystems._DemoDataExchange);
	//CommonUse.AddID(IDs, "5f92f952-c2bd-43ea-a23b-577fa4e26f6c", Metadata.Subsystems._DemoDataExchange.Subsystems._DemoDataExchangeExecution);
	//CommonUse.AddID(IDs, "b4202e4f-6269-41b2-b22d-efe58ac7f82d", Metadata.Subsystems._DemoDataExchange.Subsystems._DemoExchangeMonitor);
	//CommonUse.AddID(IDs, "1507b563-260d-465e-a84b-0b5e4d07b0d8", Metadata.Subsystems._DemoDataExchange.Subsystems._DemoExchangeSetup);
	//CommonUse.AddID(IDs, "2a2efcc7-0c3c-483f-ab6c-67a42e71a066", Metadata.Subsystems._DemoDataExchange.Subsystems._DemoExchangeObjects);
	//CommonUse.AddID(IDs, "1de9d497-b5f9-4cb8-ba08-eba64f815b2f", Metadata.Subsystems._DemoDataExchange.Subsystems._DemoAccountingPolicy);
	//
	//// Subsystems
	//CommonUse.AddID(IDs, "fbf1213c-0372-4ec9-b0fc-06e457853c73", Metadata.Subsystems._DemoSubsystems);
	//CommonUse.AddID(IDs, "ac24e85c-f63e-4d2c-a605-d66cadff0805", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoBaseFunctionality);
	//CommonUse.AddID(IDs, "26c9c2fe-6513-4d1f-ae3e-8d6d034454e1", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoBanks);
	//CommonUse.AddID(IDs, "cbdb1fbc-58eb-4611-bb84-5cbaa418a7e9", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoCurrencies);
	//CommonUse.AddID(IDs, "e6b53e16-a17b-475b-8d2c-486108fe4e5f", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoInteractions);
	//CommonUse.AddID(IDs, "acec8ce5-d72d-4db0-97c3-89326ef633d9", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoCalendarSchedules);
	//CommonUse.AddID(IDs, "4d51098c-fa33-4e7a-923f-057ed7affee4", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoPerformanceEstimation);
	//CommonUse.AddID(IDs, "89d89bde-534a-4262-9d2a-7161143a4549", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoGetFilesFromInternet);
	//CommonUse.AddID(IDs, "578d535c-eaa6-404b-a484-be90c63d1631", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoObjectPrefixation);
	//CommonUse.AddID(IDs, "155e1c3a-aaac-462c-9883-459ef8039d15", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoUpdateObtainingLegalityCheck);
	//CommonUse.AddID(IDs, "7de0a0e3-f8b6-4e2b-a784-b3f74f5f1e2a", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoEmailOperations);
	//CommonUse.AddID(IDs, "6b4c483f-fd56-4213-9a6d-5d32d0d65c6c", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoTotalAndAggregateManagement);
	//CommonUse.AddID(IDs, "0e81eb21-f210-4810-8ddf-31066f20920d", Metadata.Subsystems._DemoSubsystems.Subsystems._DemoIndividuals);
	//
	//// Service mode
	//CommonUse.AddID(IDs, "b76c397f-5fd5-4a7d-8185-fc0e60280e0a", Metadata.Subsystems._DemoServiceModeOperations);
	//CommonUse.AddID(IDs, "c56d3bd6-be5d-4e14-96d2-0d09e4d824da", Metadata.Subsystems._DemoServiceModeOperations.Subsystems._DemoMessageExchange);
	//
	//// Access management
	//CommonUse.AddID(IDs, "9682e4bd-519b-42f6-87d7-244304d94d49", Metadata.Subsystems._DemoAccessManagement);
	//CommonUse.AddID(IDs, "b699e923-7bc4-4497-ad90-661d3a358afd", Metadata.Subsystems._DemoAccessManagement.Subsystems._DemoAccessManagementInternalData);
	//CommonUse.AddID(IDs, "b283ef2b-8b29-4ef0-ab1f-3fbf77916aa0", Metadata.Subsystems._DemoAccessManagement.Subsystems._DemoAccessManagementUsage);
	//CommonUse.AddID(IDs, "382585c4-7703-4184-a560-de2a45c1b95f", Metadata.Subsystems._DemoAccessManagement.Subsystems._DemoAccessManagementSetup);
	//CommonUse.AddID(IDs, "9ffaf761-0192-473e-bc02-c093b6118fde", Metadata.Subsystems._DemoAccessManagement.Subsystems._DemoAccessManagementSetupAdditional);
	//
	//// Files
	//CommonUse.AddID(IDs, "876840f0-e549-4531-ae12-2ceec5bdac47", Metadata.Subsystems._DemoFileOperations);
	//CommonUse.AddID(IDs, "4c512f8c-b07d-4fe7-88fe-e8a58053f3ec", Metadata.Subsystems._DemoFileOperations.Subsystems._DemoFileOperationWebServices);
	//CommonUse.AddID(IDs, "0774c2bf-ab93-44ca-9552-f5d9fdf627e4", Metadata.Subsystems._DemoFileOperations.Subsystems._DemoAttachedFiles);
	//CommonUse.AddID(IDs, "15fef107-4964-4dc8-a2d9-e5771ccdbccd", Metadata.Subsystems._DemoFileOperations.Subsystems._DemoFileOperationsSetup);
	//
	//// _Demo end of example
	
EndProcedure

// Internal use only.
Procedure OnGetInterfaceFunctionalOptionParameters(InterfaceOptions) Export
	
EndProcedure

// Internal use only.
Procedure BasicFunctionalityCommonParametersOnDefine(CommonParameters) Export
	
	SystemSettings.BasicFunctionalityCommonParametersOnDefine(CommonParameters);
	
EndProcedure

// Internal use only.
Procedure PersonalSettingsFormName(FormName) Export
	
EndProcedure

// Internal use only.
Procedure GetMinRequiredPlatformVersion(CheckParameters) Export
	
EndProcedure

// Internal use only.
Procedure ClientParametersOnStart(Parameters) Export
	
EndProcedure

// Internal use only.
Procedure ClientParameters(Parameters) Export
	
EndProcedure

// Internal use only.
Procedure SessionParameterSettingHandlersOnAdd(Handlers) Export
	
EndProcedure
