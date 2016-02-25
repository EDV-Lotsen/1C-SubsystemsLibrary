#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record In ThisObject Do
		Record.DataSize = DataSize(Record.ObjectVersion);
		ObjectVersion = Record.ObjectVersion.Get();
		Record.HasVersionData = ObjectVersion <> Undefined;
		If Record.HasVersionData Then
			Record.CheckSum = ObjectVersioning.CheckSum(ObjectVersion);
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

Function DataSize(Data)
	Return Base64Value(XDTOSerializer.XMLString(Data)).Size();
EndFunction

#EndRegion

#EndIf