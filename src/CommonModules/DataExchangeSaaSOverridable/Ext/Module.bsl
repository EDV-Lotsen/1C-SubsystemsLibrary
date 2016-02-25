////////////////////////////////////////////////////////////////////////////////
// Data exchange SaaS subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Obsolete. Call the RequiredApplicationVersionOnDefine instead procedure.
//
Function RequiredApplicationVersion() Export
	
EndFunction

// Defines the 1C:Enterprise application version that is required for
// a standalone workstation. Application with this version must be
// installed on the user's local computer.
// If the return value is not specified, the default version is used: first
// three digits of the current application version available on the Internet, for example, "8.3.3".
// The procedure is used in the Standalone workstation generation wizard.
//
// Parameters:
//  Version - String -  1C:Enterprise application version in the following
//  format: <revision>.<subrevision>.<version>.<build>.
// For example, "8.3.3.715".
//
Procedure RequiredApplicationVersionOnDefine(Version) Export
	
EndProcedure

#EndRegion