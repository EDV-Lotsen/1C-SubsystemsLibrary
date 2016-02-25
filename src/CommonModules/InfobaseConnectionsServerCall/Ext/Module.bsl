////////////////////////////////////////////////////////////////////////////////
// User sessions subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalProceduresAndFunctions

// Gets the infobase connection lock parameters to be used at client side.
//
// Parameters:
//  GetSessionCount - Boolean - if True, the SessionCount field in the returned structure is filled.
//
// Returns:
//   Structure - with the following fields:
//     Use                       - Boolean - True if lock is set, False otherwise. 
//     Beginning                 - Date    - lock beginning date. 
//     End                       - Date    - lock end date. 
//     Message                   - String  - user message. 
//     SessionTerminationTimeout - Number  - timeout in seconds.
//     SessionCount                        - 0 if GetSessionCount = False.
//     CurrentSessionDate        - Date    - current session date.
//
Function SessionLockParameters(GetSessionCount = False) Export
	
	Return InfobaseConnections.SessionLockParameters(GetSessionCount);
	
EndFunction

// Sets the infobase connection lock. If this function is called from a session 
// with separator values set, it sets the data area session lock.
//
// Parameters
//  MessageText - String - text to be used in the error message displayed upon attempt to
//                         connect to the locked infobase.
// 
//  KeyCode     - String - string to be added to "/uc" command-line parameter
//                         or to "uc" connection-string parameter in order to establish
//                         connection to the infobase regardless of the lock.
//                         Cannot be used for data area session locks.
//
// Returns:
//   Boolean   - True if the lock is set successfully.
//               False if the lock cannot be set due to insufficient rights.
//
Function SetConnectionLock(MessageText = "",
	KeyCode = "KeyCode") Export
	
	Return InfobaseConnections.SetConnectionLock(MessageText, KeyCode);
	
EndFunction

// Sets the data area session lock.
// 
// Parameters:
//   Parameters  - Structure - see NewConnectionLockParameters.
//   LocalTime   - Boolean   - if True, lock beginning time and lock end time values are expressed
//                             in the local session time.
//                             If False, these values are expressed in universal time.
//
Procedure SetDataAreaSessionLock(Parameters, LocalTime = True) Export
	
	InfobaseConnections.SetDataAreaSessionLock(Parameters, LocalTime);
	
EndProcedure

// Removes the infobase lock.
//
// Returns:
//   Boolean   - True if the operation is successful.
//               False if the operation cannot be performed due to insufficient rights.
//
Function AllowUserLogon() Export
	
	Return InfobaseConnections.AllowUserLogon();
	
EndFunction

// Gets information on the data area session lock.
// 
// Parameters:
//   LocalTime - Boolean - if True, lock beginning time and lock end time values are returned
//                         in the local session time. 
//                         If False, these values are returned in universal time.
//
// Returns:
//   Structure - see NewConnectionLockParameters.
//
Function GetDataAreaSessionLock(LocalTime = True) Export
	
	Return InfobaseConnections.GetDataAreaSessionLock(LocalTime);
	
EndFunction

#EndRegion