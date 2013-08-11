///////////////////////////////////////////////////////////////////////////////////
// ServiceModeOverridable.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Generates a name list of shared information registers that store separated data.
// 
// Parameters:
// CommonRegisters - Array - array of String.
//
Procedure GetSharedInformationRegistersWithSeparatedData(Val CommonRegisters) Export
	
EndProcedure

// Generates a list of data types that cannot be copied between separated data areas
// 
// Parameters:
// CommonRegisters - Array - array of Type.
//
Procedure GetNonImportableToDataAreaTypes(Val Types) Export
	
EndProcedure

// Is called on the data area deletion.
// All of data that cannot be deleted by the standard way should 
// be deleted in this procedure
//
// Parameters:
// DataArea - Separater value type - deleted data area separater value.
//
//
Procedure OnDeleteDataArea(Val DataArea) Export
	
EndProcedure

// Generates Infobase parameter list.
//
// Parameters:
// ParameterTable - table value - parameter description table.
// For column content details see ServiceMode.GetInfoBaseParameterTable()
//
Procedure GetInfoBaseParameterTable(Val ParameterTable) Export
	
EndProcedure

// Is called before the try of getting Infobase parameter value from 
// constants with same names.
//
// Parameters:
// ParameterNames - string array - parameter names of required values.
// If this procedure gets parameter value, parameter name must be deleted.
// ParameterValues - Structure - parameter value.
//
Procedure OnReceiveInfoBaseParameterValues(Val ParameterNames, Val ParameterValues) Export
	
EndProcedure

// Is called before the try of writing Infobase parameter value to
// constants with same names.
//
// Parameters:
// ParameterValues - structure - setting parameter values.
// If this procedure sets parameter value, KeyAndValue must be deleted.
//
Procedure OnSetInfoBaseParameterValues(Val ParameterValues) Export
	
EndProcedure

// Is called on enabling separation by data area
// at first launch with InitSeparatedInfoBase
// 
// Specifically, you should place here the script for enabling scheduled jobs
// that are only used when data separation is enabled
// (and disabling scheduled jobs that are only used when data separation is disabled).
//
// You may see an example in
// StandardSubsystemsOverridable.OnEnableSeparationByDataAreas() 
//
Procedure OnEnableSeparationByDataAreas() Export
	
EndProcedure

