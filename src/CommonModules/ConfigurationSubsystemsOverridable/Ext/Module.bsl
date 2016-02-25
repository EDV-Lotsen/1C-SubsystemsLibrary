////////////////////////////////////////////////////////////////////////////////
// Base functionality subsystem.
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// Defines the list of configuration and library modules that provide the following 
// general details: name, version, update handler list, and its dependence on other
// libraries.
//
// See the content of the mandatory module procedures in the INTERFACE section of the
// SLInfobaseUpdate common module.
//
// Parameters:
//  SubsystemModules - Array - names of the common server library modules and the
//                             configuration. For example: SLInfobaseUpdate.
//                    
// Note: there is no need to add the SLInfobaseUpdate module to the SubsystemModules
// array.
//
Procedure SubsystemsOnAdd(SubsystemModules) Export
	
	//PARTIALLY_DELETED
	// _Demo beginning example
	//SubsystemModules.Add("_DemoSLInfobaseUpdate");
	// _Demo the end example
	
	// CloudTechnology
	SubsystemModules.Add("CTLInfobaseUpdate");
	// End CloudTechnology
	
EndProcedure

#EndRegion