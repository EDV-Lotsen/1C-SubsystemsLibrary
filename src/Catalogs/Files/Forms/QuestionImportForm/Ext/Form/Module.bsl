

&AtServer
Procedure OnCreateAtServer(Cancellation, StandardProcessing)
	
	FilesBig = Parameters.FilesBig;
	
	MaximumFileSize = Int(Constants.MaximumFileSize.Get() / (1024 * 1024));
	
	Message =
	StringFunctionsClientServer.SubstitureParametersInString(
	    NStr(	"en = 'Some of the files exceed the storage size limit (%1 MB) and will not be added to the storage. Do you want to proceed?'"),
	    String(MaximumFileSize) );
		
	If Parameters.Property("LoadMode") Then
		If Parameters.LoadMode Then
			
			Message =
			StringFunctionsClientServer.SubstitureParametersInString(
			    NStr(	"en = 'Some of the files exceed the storage size limit (%1 MB) and will not be added to the storage. Do you want to proceed?'"),
			    String(MaximumFileSize) );
			
		EndIf;
	EndIf;	
		
	If Parameters.Property("Title") Then
		Title = Parameters.Title;
	EndIf;	
		
EndProcedure
