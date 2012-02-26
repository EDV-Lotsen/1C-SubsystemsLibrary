

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.OpenCommentEditForm(Item.EditText, Object.Comment, Modified);
	
EndProcedure
