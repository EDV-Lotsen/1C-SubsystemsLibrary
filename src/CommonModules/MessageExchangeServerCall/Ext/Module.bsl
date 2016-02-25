////////////////////////////////////////////////////////////////////////////////
// Message exchange subsystem.
// 
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Sends and receives system messages
//
// Parameters:
//  Cancel - Boolean. Сancellation flag. Appears on errors during operations.
//
Procedure SendAndReceiveMessages(Cancel) Export
	
	DataExchangeServer.CheckCanSynchronizeData();
	
	MessageExchangeInternal.SendAndReceiveMessages(Cancel);
	
EndProcedure

#EndRegion
