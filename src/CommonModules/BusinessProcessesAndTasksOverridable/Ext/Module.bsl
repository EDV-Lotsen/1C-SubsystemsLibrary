////////////////////////////////////////////////////////////////////////////////
// Business processes and tasks subsystem
//  
////////////////////////////////////////////////////////////////////////////////

#Region Interface

// The function is called to update business process data in BusinessProcessData information register.
// 
// Parameters
//  Write - InformationRegisterRecord.BusinessProcessData
//
Procedure OnWriteBusinessProcessList(Write) Export
	
EndProcedure

// The function is called to check the rights for pausing and resuming a business process
// for the current user.
//
// Parameters:
//  BusinessProcess    - BusinessProcessRef - business process reference.
//  HasRights          - Boolean            - if False, the rights are denied.
//  StandardProcessing - Boolean            - If False, the standard rights check is skipped.
//
Procedure OnCheckStopBusinessProcessRights(BusinessProcess, HasRights, StandardProcessing) Export
	
EndProcedure

// The function is called to fill the MainTask attribute of filling data.
//
// Parameters
//  BusinessProcessObject - BusinessProcessObject - business process.
//  FillingData           - Arbitrary             - filling data that is passed to the filling handler.
//  StandardProcessing    - Boolean               - If False, the standard filling processing is skipped.
//
Procedure OnFillMainBusinessProcessTask(BusinessProcessObject, FillingData, StandardProcessing) Export
	
EndProcedure

// The function is called to fill the external task form parameters.
//
// Parameters:
//  BusinessProcessName       - String                           - business process name.
//  TaskRef                   - TaskRef.PerformerTask            - task.
//  BusinessProcessRoutePoint - BusinessProcessRoutePointRef.Job - action.
//  FormParameters            - Structure                        - description of the task execution 
//                                                                 with the following properties:
//   * FormName       - form name passed to the OpenForm method. 
//   * FormParameters - contains parameters of the form to be opened.
//
// Filling example:
//  If BusinessProcessName = "Job" Then
//      FormName = "BusinessProcess.Job.Form.ExternalAction" + BusinessProcessRoutePoint.Name;
//      FormParameters.Insert("FormName", FormName);
//  EndIf;
//
Procedure OnReceiveTaskExecutionForm(BusinessProcessName, TaskRef,
	BusinessProcessRoutePoint, FormParameters) Export
	
EndProcedure

// Obsolete. Use OnCheckStopBusinessProcessRights instead.
// The function is called to check the rights for pausing and resuming a business process.
//
// Parameters
//  BusinessProcess - Business process reference.
//
Function HasStopBusinessProcessRights(BusinessProcess) Export
	
	Return Undefined;
	
EndFunction

// Obsolete. Use OnFillMainBusinessProcessTask instead.
// The function is called to fill the MainTask attribute of filling data.
// Parameters
//
//  BusinessProcessObject - business process.
//  FillingData           - filling data that is passed to the filling handler.	
//
Function FillPrimaryTask(BusinessProcessObject, FillingData) Export
	
	Return False;
	
EndFunction

#EndRegion
