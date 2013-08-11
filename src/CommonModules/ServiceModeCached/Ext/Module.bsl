///////////////////////////////////////////////////////////////////////////////////
// ServiceModeCached.
//
///////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////
// INTERFACE

// Returns the end point for sending messages to the service manager.
//
// Returns:
//  ExchangePlanRef.MessageExchange - Node which corresponds to the service manager
//
Function ServiceManagerEndPoint() Export
	
	Return Constants.ServiceManagerEndPoint.Get();
	
EndFunction

// Returns an array of currently supported serializable structural types.
//
// Returns:
//  FixedArray of Type
// 
Function StructuralTypesToSerialize() Export
	
	TypeArray = New Array;
	
	TypeArray.Add(Type("Structure"));
	TypeArray.Add(Type("FixedStructure"));
	TypeArray.Add(Type("Array"));
	TypeArray.Add(Type("FixedArray"));
	TypeArray.Add(Type("Map"));
	TypeArray.Add(Type("FixedMap"));
	TypeArray.Add(Type("KeyAndValue"));
	TypeArray.Add(Type("ValueTable"));
	
	Return New FixedArray(TypeArray);
	
EndFunction