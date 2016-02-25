
//Document posting 
&AtClient
Procedure PostExecute()
	
	If Object.SelectedDocuments.Count() = 0 Then
		ShowMessageBox(,NStr("en = 'Documents are not selected!'"));
		Return;
	EndIf;	
	
	If Not ValueIsFilled(StartDate) Or  Not ValueIsFilled(EndDate) Then
		ShowMessageBox(,NStr("en = 'Invalid interval!'"));
		Return;
	EndIf;	
	
	If StartDate > EndDate Then
		ShowMessageBox(,NStr("en = 'Invalid interval!'"));
		Return;
	EndIf;	
	
	//Posting documents in the cycle by days of the selected interval
	PostedCount = 0;
	PostDate = StartDate;
	While PostDate <= EndDate Do
		
		UserInterruptProcessing();
		Status(NStr("en = 'The posting is performed for '") 
			+ Format(PostDate, "DLF=DD") 
			+ Chars.LF 
			+ NStr("en = 'Posted'") 
			+ PostedCount);
				  
		//Calling posting within one day at server
		CurrentPostedCount = 0;		  
		PostAtServer(PostDate, CurrentPostedCount);
		PostedCount = PostedCount + CurrentPostedCount;
		
		PostDate = PostDate + 24 * 60 * 60;	
		
	EndDo;
	
	Status(NStr("en = 'Document posting completed'")
		+ Chars.LF 
		+ NStr("en = 'Posted'") 
		+ PostedCount);
EndProcedure

//Posting documents within one day
&AtServer
Procedure PostAtServer(PostDate, CurrentPostedCount)
	DataProcessor = FormAttributeToValue("Object");
	DataProcessor.Post(PostDate, EndOfDay(PostDate), CurrentPostedCount);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	StartDate = BegOfDay(CurrentDate());
	EndDate = BegOfDay(CurrentDate());
	Posted = "Posted";
	
	//Preparing the list of document types
	DataProcessor = FormAttributeToValue("Object");
	DataProcessor.FillList();
	ValueToFormAttribute(DataProcessor, "Object");
EndProcedure

//Excluding documents from the list of selected
&AtClient
Procedure Exclude()
	For Each ItemID In Items.SelectedDocuments.SelectedRows Do
		Object.SelectedDocuments.Delete(Object.SelectedDocuments.FindByID(ItemID)); 
	EndDo;	
EndProcedure

//Adding documents to the list of selected
&AtClient
Procedure Add()
	For Each ItemID In Items.DocumentsList.SelectedRows Do
		Element = Object.DocumentsList.FindByID(ItemID);
		If Object.SelectedDocuments.FindByValue(Element.Value) <> Undefined Then
			Continue;
		EndIf;	
		Object.SelectedDocuments.Add(Element.Value, Element.Presentation);
	EndDo;	
	Object.SelectedDocuments.SortByPresentation();
EndProcedure

&AtClient
Procedure SelectedDocumentsChoice(Element, SelectedRow, Field, StandardProcessing)
	Exclude();
EndProcedure

&AtClient
Procedure DocumentListChoice(Element, SelectedRow, Field, StandardProcessing)
	Add();
EndProcedure

&AtClient
Procedure ExcludeExecute()
	Exclude();
EndProcedure

&AtClient
Procedure AddExecute()
	Add();
EndProcedure

