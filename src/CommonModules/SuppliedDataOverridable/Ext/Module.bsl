///////////////////////////////////////////////////////////////////////////////////
// SuppliedDataOverridable: The mechanism of supplied data service.
//
///////////////////////////////////////////////////////////////////////////////////

#Region Interface

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for the SuppliedData subsystem
// the SuppliedDataOverridable common module
//

// Registers supplied data handlers
//
// When a new shared data notification is received, NewDataAvailable
// procedures from modules registered with GetSuppliedDataHandlers are called.
// The descriptor passed to the procedure is XDTODataObject Descriptor.
// 
// If NewDataAvailable sets Import to True, the data is imported, and the descriptor and 
// the path to the data file are passed to ProcessNewData() procedure. The file is 
// automatically deleted once the procedure is executed.
// If the file is not specified in Service Manager, the parameter value is Undefined.
//
// Parameters: 
//   Handlers - ValueTable - table for adding handlers. 
//     Columns:
//       DataKind - String - code of the data kind processed by the handler.
//       HandlerCode - Sting(20) - used for recovery after a data processing error. 
//       Handler - CommonModule - module that contains the following procedures:
//         NewDataAvailable(Descriptor, Import) 
//         Export ProcessNewData(Descriptor, Import) 
//         Export DataProcessingCanceled(Descriptor) Export
//
Procedure GetSuppliedDataHandlers(Handlers) Export
	
EndProcedure

#EndRegion
