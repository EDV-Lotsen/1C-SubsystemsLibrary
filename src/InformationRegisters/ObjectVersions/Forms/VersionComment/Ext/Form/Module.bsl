
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
	If Parameters.Property("Autotest") Then 
		Return;
	EndIf;
	
	ObjectRef = Parameters.ObjectRef;
	VersionNumber = ObjectVersioning.LastVersionNumber(ObjectRef);
EndProcedure

&AtClient
Procedure OK(Command)
	If Modified Then
		AddCommentToVersion();
	EndIf;
	Close();
EndProcedure

&AtServer
Procedure AddCommentToVersion()
	ObjectVersioning.AddCommentToVersion(ObjectRef, VersionNumber, Comment);
EndProcedure



