#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region InternalProceduresAndFunctions

Procedure DeleteVersionAuthorInfo(Val VersionAuthor) Export
	
	If Not CommonUseCached.CanUseSeparatedData() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ObjectVersions.Object,
	|	ObjectVersions.VersionNumber,
	|	ObjectVersions.ObjectVersion,
	|	UNDEFINED AS VersionAuthor,
	|	ObjectVersions.VersionDate,
	|	ObjectVersions.Comment,
	|	ObjectVersions.ObjectVersionType,
	|	ObjectVersions.VersionIgnored
	|FROM
	|	InformationRegister.ObjectVersions AS ObjectVersions
	|WHERE
	|	ObjectVersions.VersionAuthor = &VersionAuthor";
	
	Query.SetParameter("VersionAuthor", VersionAuthor);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RecordSet = InformationRegisters.ObjectVersions.CreateRecordSet();
		
		RecordSet.Filter["Object"].Set(Selection["Object"]);
		RecordSet.Filter["VersionNumber"].Set(Selection["VersionNumber"]);
		
		FillPropertyValues(RecordSet.Add(), Selection);
		
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf