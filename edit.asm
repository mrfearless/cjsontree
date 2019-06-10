JSONNew                         PROTO :DWORD                        ; 'Creates' a new json file state. New treeview items can be added to this and saved 

JSONAddItem                     PROTO :DWORD, :DWORD                ; Add a json item to the treeview
JSONDelItem                     PROTO :DWORD                        ; Delete a json item from the treeview
JSONEditItem                    PROTO :DWORD                        ; Edit currently selected treeview item text

JSONCreateItem                  PROTO :DWORD, :DWORD, :DWORD        ; called from JSONAddItem and JSONPasteItem to create new json item
JSONRemoveItem                  PROTO :DWORD, :DWORD                ; called from JSONDelItem and JSONPasteItem (cut mode) to detach and delete json object
JSONUpdateItem                  PROTO :DWORD, :DWORD, :DWORD        ; called from TVN_ENDLABELEDIT
JSONUpdateArrayCount            PROTO :DWORD

SeperateNameValue               PROTO :DWORD, :DWORD, :DWORD
SeperateArrayName               PROTO :DWORD, :DWORD

.DATA

szNewObjectName                 DB 'Object',0
szNewArrayName                  DB 'Array',0
szNewStringName                 DB 'String',0
szNewTrueName                   DB 'BoolTrue',0
szNewFalseName                  DB 'BoolFalse',0
szNewNumberName                 DB 'Number',0
szNewNullName                   DB 'Null',0

szNewObject                     DB 'Object',0
szNewArray                      DB 'Array[]',0
szNewString                     DB 'String: ',0
szNewTrue                       DB 'BoolTrue: true',0
szNewFalse                      DB 'BoolFalse: false',0
szNewNumber                     DB 'Number: 0',0
szNewNull                       DB 'Null: null',0



.CODE


;-------------------------------------------------------------------------------------
; Creates a new json treeview
;-------------------------------------------------------------------------------------
JSONNew PROC USES EBX hWin:DWORD
    Invoke JSONFileClose, hWin

    Invoke cJSON_CreateObject
    mov hJSON_Object_Root, eax
    
    Invoke StatusBarSetPanelText, 2, Addr szJSONCreatedNewData
    Invoke SetWindowTitle, hWin, Addr szJSONNew
    mov g_nTVIndex, 0
    Invoke TreeViewItemInsert, hTV, NULL, Addr szJSONNewData, g_nTVIndex, TVI_ROOT, IL_ICO_MAIN, IL_ICO_MAIN, hJSON_Object_Root
    mov hTVRoot, eax
    inc g_nTVIndex
    Invoke TreeViewSetSelectedItem, hTV, hTVRoot, TRUE
    Invoke TreeViewItemExpand, hTV, hTVRoot
    ret
JSONNew ENDP

;-------------------------------------------------------------------------------------
; Add a new json item (treeview item) under current branch
;-------------------------------------------------------------------------------------
JSONAddItem PROC USES EBX hWin:DWORD, dwJsonType:DWORD
    LOCAL hJSON:DWORD
    LOCAL hJSONAdd:DWORD
    LOCAL nIcon:DWORD
    LOCAL hTVItem:DWORD
    LOCAL ParentJsonType:DWORD
    
    Invoke TreeViewCountItems, hTV
    .IF eax == 0    
        ret
    .ENDIF
    
    Invoke TreeViewGetSelectedItem, hTV
    .IF eax == NULL
        Invoke SendMessage, hTV, TVM_GETNEXTITEM, TVGN_ROOT, NULL
        .IF eax == NULL
            ret
        .ENDIF
    .ENDIF
    mov hTVNode, eax
    
    Invoke TreeViewGetItemParam, hTV, hTVNode
    .IF eax == NULL
        ret
    .ENDIF
    mov hJSON, eax
    
    ; Only add if root of tree, or an object or an array
    mov eax, hTVNode
    .IF eax != hTVRoot
        mov ebx, hJSON
        mov eax, [ebx].cJSON.itemtype
        .IF eax == cJSON_Object || eax == cJSON_Array
            mov ParentJsonType, eax
        .ELSE
            xor eax, eax
            ret
        .ENDIF
    .ENDIF    
    
    Invoke JSONCreateItem, hTV, hTVNode, dwJsonType
    mov hJSONAdd, eax

    .IF hJSONAdd == 0
        ;PrintText 'hJSONAdd == 0'
        ret
    .ENDIF

    mov eax, dwJsonType
    .IF eax == cJSON_Object
        mov eax, IL_ICO_JSON_OBJECT
        mov nIcon, eax
        Invoke szCopy, Addr szNewObject, Addr szItemText
        Invoke szCopy, Addr szNewObjectName, Addr szItemTextName
        
    .ELSEIF eax == cJSON_Array
        mov eax, IL_ICO_JSON_ARRAY
        mov nIcon, eax
        Invoke szCopy, Addr szNewArray, Addr szItemText
        Invoke szCopy, Addr szNewArrayName, Addr szItemTextName

    .ELSEIF eax == cJSON_String
        mov eax, IL_ICO_JSON_STRING
        mov nIcon, eax
        Invoke szCopy, Addr szNewString, Addr szItemText
        Invoke szCopy, Addr szNewStringName, Addr szItemTextName
      
    .ELSEIF eax == cJSON_Number
        mov eax, IL_ICO_JSON_NUMBER
        mov nIcon, eax
        Invoke szCopy, Addr szNewNumber, Addr szItemText
        Invoke szCopy, Addr szNewNumberName, Addr szItemTextName
     
    .ELSEIF eax == cJSON_True
        mov eax, IL_ICO_JSON_LOGICAL
        mov nIcon, eax
        Invoke szCopy, Addr szNewTrue, Addr szItemText
        Invoke szCopy, Addr szNewTrueName, Addr szItemTextName

    .ELSEIF eax == cJSON_False
        mov eax, IL_ICO_JSON_LOGICAL
        mov nIcon, eax
        Invoke szCopy, Addr szNewFalse, Addr szItemText
        Invoke szCopy, Addr szNewFalseName, Addr szItemTextName

    .ELSEIF eax == cJSON_NULL
        mov eax, IL_ICO_JSON_NULL
        mov nIcon, eax
        Invoke szCopy, Addr szNewNull, Addr szItemText
        Invoke szCopy, Addr szNewNullName, Addr szItemTextName

    .ENDIF

    .IF hJSONAdd != NULL
        mov eax, dwJsonType
        .IF eax != cJSON_Object 
            ; Update New cJSON Item name
            Invoke lstrlen, Addr szItemTextName
            inc eax
            inc eax
            Invoke cJSON_malloc, eax
            .IF eax != 0
                mov lpszItemString, eax
                Invoke lstrcpy, lpszItemString, Addr szItemTextName ;, dwLengthItemTextName
                mov ebx, hJSONAdd
                mov eax, lpszItemString
                mov [ebx].cJSON.itemstring, eax
            .ENDIF
        .ENDIF
    
        mov g_Edit, TRUE
        Invoke MenuSaveEnable, hWin, TRUE
        Invoke MenuSaveAsEnable, hWin, TRUE
        Invoke ToolbarButtonSaveEnable, hWin, TRUE
        Invoke ToolbarButtonSaveAsEnable, hWin, TRUE

        Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, nIcon, nIcon, hJSONAdd
        mov hTVItem, eax
        inc g_nTVIndex
        Invoke TreeViewItemExpand, hTV, hTVNode
        
        ; Update array count if parent node is array ;and new item is an object
        mov eax, ParentJsonType
        .IF eax == cJSON_Array ;&& dwJsonType == cJSON_Object
            Invoke JSONUpdateArrayCount, hTVNode
        .ENDIF
        
        Invoke TreeViewSetSelectedItem, hTV, hTVItem, TRUE
        Invoke TreeViewItemExpand, hTV, hTVItem
        Invoke SendMessage, hTV, TVM_EDITLABEL, 0, hTVItem
    .ENDIF
    
    ret
JSONAddItem ENDP

;-------------------------------------------------------------------------------------
; Deletes a selected json item (treeview item)
; detachs json item from parent item and deletes the cJSON items and children
;-------------------------------------------------------------------------------------
JSONDelItem PROC USES EBX hWin:DWORD
    LOCAL hItem:DWORD
    LOCAL hParent:DWORD
    LOCAL hJSON:DWORD
    LOCAL hJSONParent:DWORD
    
    Invoke TreeViewGetSelectedItem, hTV
    mov hItem, eax
    
    Invoke JSONRemoveItem, hTV, hItem
    
;    Invoke TreeViewGetItemParam, hTV, hItem
;    mov hJSON, eax
;    .IF eax != 0 
;        Invoke SendMessage, hTV, TVM_GETNEXTITEM, TVGN_PARENT, hItem ; get parent item
;        mov hParent, eax
;        .IF eax != 0
;            Invoke TreeViewGetItemParam, hTV, hParent ; get parents json
;            mov hJSONParent, eax
;            .IF eax != 0
;                Invoke cJSON_DetachItemViaPointer, hJSONParent, hJSON ; detach object from rest of json stuff
;            .ENDIF
;        .ENDIF
;        Invoke cJSON_Delete, hJSON ; delete json item and all children it has
;    .ENDIF  
    


    Invoke SendMessage, hTV, TVM_GETCOUNT, 0, 0
    .IF eax == 0
        mov g_nTVIndex, 0
        mov g_Edit, FALSE
        Invoke StatusBarSetPanelText, 2, Addr szSpace
        Invoke SetWindowTitle, hWin, NULL
        Invoke MenuSaveEnable, hWin, FALSE
        Invoke MenuSaveAsEnable, hWin, FALSE
        Invoke ToolbarButtonSaveEnable, hWin, FALSE
        Invoke ToolbarButtonSaveAsEnable, hWin, FALSE
    .ELSE
        mov g_Edit, TRUE
        Invoke MenuSaveEnable, hWin, TRUE
        Invoke MenuSaveAsEnable, hWin, TRUE
        Invoke ToolbarButtonSaveEnable, hWin, TRUE
        Invoke ToolbarButtonSaveAsEnable, hWin, TRUE
    .ENDIF

    Invoke MenusUpdate, hWin, NULL
    Invoke ToolBarUpdate, hWin, NULL    
    ret

JSONDelItem ENDP

;-------------------------------------------------------------------------------------
; Edit the json item (treeview item) text, F2 or double clicking on label does the same
;-------------------------------------------------------------------------------------
JSONEditItem PROC USES EBX hWin:DWORD
    LOCAL hItem:DWORD
    
    ; Prevent edit if root and/or an object
    Invoke TreeViewGetSelectedItem, hTV
    .IF eax != 0 && eax != hTVRoot
        mov hItem, eax
        Invoke TreeViewGetItemParam, hTV, hItem
        .IF eax != NULL ; eax = hJSON
            mov ebx, eax
            mov eax, [ebx].cJSON.itemtype
            .IF eax == cJSON_Object
                ret
            .ENDIF
        .ENDIF
        Invoke SendMessage, hTV, TVM_EDITLABEL, 0, hItem
    .ENDIF
    ret
JSONEditItem ENDP

;-------------------------------------------------------------------------------------
; Creates a new json item and adds it as a child of current json item
; Called from JSONAddItem and JSONPasteItem
; Returns NULL or handle to the new json created item if successful.
;-------------------------------------------------------------------------------------
JSONCreateItem PROC USES EBX hTreeview:DWORD, hParentItem:DWORD, dwJsonObjectType:DWORD
    LOCAL hItem:DWORD
    LOCAL hJSONParent:DWORD
    LOCAL hJSONAdd:DWORD
    LOCAL bArray:DWORD
    
    .IF hTreeview == NULL
        xor eax, eax
        ret
    .ENDIF
    
    .IF hParentItem == NULL
        Invoke TreeViewGetSelectedItem, hTreeview
    .ELSE    
        mov eax, hParentItem
    .ENDIF
    mov hItem, eax
    
    .IF hItem == NULL
        xor eax, eax
        ret
    .ENDIF

    Invoke TreeViewGetItemParam, hTreeview, hItem
    mov hJSONParent, eax
    .IF eax == NULL
        xor eax, eax
        ret
    .ENDIF

    Invoke cJSON_IsArray, hJSONParent
    mov bArray, eax

    mov eax, dwJsonObjectType
    .IF eax == cJSON_Object
        .IF bArray == FALSE
            Invoke cJSON_AddStringToObject, hJSONParent, Addr szNullNull, Addr szNullNull
        .ELSE
            Invoke cJSON_AddStringToArray, hJSONParent, Addr szNullNull
        .ENDIF
        mov hJSONAdd, eax
        
    .ELSEIF eax == cJSON_Array
        .IF bArray == FALSE
            Invoke cJSON_AddArrayToObject, hJSONParent, Addr szNullNull
        .ELSE
            Invoke cJSON_AddArrayToArray, hJSONParent
        .ENDIF
        mov hJSONAdd, eax
        
    .ELSEIF eax == cJSON_String
        .IF bArray == FALSE
            Invoke cJSON_AddStringToObject, hJSONParent, Addr szNullNull, Addr szNullNull
        .ELSE
            Invoke cJSON_AddStringToArray, hJSONParent, Addr szNullNull
        .ENDIF
        mov hJSONAdd, eax        
        
    .ELSEIF eax == cJSON_Number
        .IF bArray == FALSE
            Invoke cJSON_AddNumberToObjectEx, hJSONParent, Addr szNullNull, 0
        .ELSE
            Invoke cJSON_AddNumberToArray, hJSONParent, 0
        .ENDIF
        mov hJSONAdd, eax        
        
    .ELSEIF eax == cJSON_True
        .IF bArray == FALSE
            Invoke cJSON_AddTrueToObject, hJSONParent, Addr szNullNull
        .ELSE
            Invoke cJSON_AddTrueToArray, hJSONParent
        .ENDIF
        mov hJSONAdd, eax        
        
    .ELSEIF eax == cJSON_False
        .IF bArray == FALSE
            Invoke cJSON_AddFalseToObject, hJSONParent, Addr szNullNull
        .ELSE
            Invoke cJSON_AddFalseToArray, hJSONParent
        .ENDIF
        mov hJSONAdd, eax
        
    .ENDIF

    .IF hJSONAdd == 0
        ;PrintText 'hJSONAdd == 0'
        xor eax, eax
        ret
    .ENDIF

    mov ebx, hJSONAdd
    mov eax, dwJsonObjectType
    mov [ebx].cJSON.itemtype, eax
    mov [ebx].cJSON.valuestring, 0
    mov [ebx].cJSON.itemstring, 0

    mov eax, hJSONAdd

    ret

JSONCreateItem ENDP

;-------------------------------------------------------------------------------------
; Removes a json item (detaches from parent json item and deletes it and children)
; Called from JSONDelItem and JSONPasteItem (Cut Mode)
;-------------------------------------------------------------------------------------
JSONRemoveItem PROC USES EBX hTreeview:DWORD, hItem:DWORD
    LOCAL hParent:DWORD
    LOCAL hJSON:DWORD
    LOCAL hJSONParent:DWORD
    ;LOCAL jsontype:DWORD
    
    .IF hItem == 0
        xor eax, eax
        ret
    .ENDIF
    
    Invoke TreeViewGetItemParam, hTreeview, hItem
    mov hJSON, eax
    .IF eax != 0 
        Invoke SendMessage, hTreeview, TVM_GETNEXTITEM, TVGN_PARENT, hItem ; get parent item
        mov hParent, eax
        .IF eax != 0
            Invoke TreeViewGetItemParam, hTreeview, hParent ; get parents json
            mov hJSONParent, eax
            .IF eax != 0
                ;mov ebx, hJSON
                ;mov eax, [ebx].cJSON.itemtype ; get deleted item json type
                ;mov jsontype, eax
                Invoke cJSON_DetachItemViaPointer, hJSONParent, hJSON ; detach object from rest of json stuff
                ;mov eax, jsontype
                mov ebx, hJSONParent
                .IF [ebx].cJSON.itemtype == cJSON_Array ;&& eax == cJSON_Object; Update array count if parent node is array and deleted type was an object
                    Invoke JSONUpdateArrayCount, hTVNode
                .ENDIF
            .ENDIF
        .ENDIF
        Invoke cJSON_Delete, hJSON ; delete json item and all children it has
    .ENDIF
    
    Invoke TreeViewSetItemParam, hTV, hItem, NULL
    Invoke TreeViewItemDelete, hTV, hItem
    
    mov eax, TRUE 
    ret
JSONRemoveItem ENDP

;-------------------------------------------------------------------------------------
; Updates a treeview item's JSON object with the string name and value
;-------------------------------------------------------------------------------------
JSONUpdateItem PROC hTreeview:DWORD, hItem:DWORD, lpszNewText:DWORD
    LOCAL hJSON:DWORD
    LOCAL hJSONNewItem:DWORD
    LOCAL jsontype:DWORD
    LOCAL bReplaceName:DWORD
    LOCAL dwLengthItemTextName:DWORD
    LOCAL dwLengthItemTextValue:DWORD
    LOCAL qwValue:QWORD
    
    .IF hItem == 0 || lpszNewText == 0
        xor eax, eax
        ret
    .ENDIF
    
    Invoke TreeViewGetItemParam, hTreeview, hItem
    mov hJSON, eax    
    .IF eax != 0
        Invoke SeperateNameValue, lpszNewText, Addr szItemTextName, Addr szItemTextValue

        Invoke lstrlen, Addr szItemTextName
        mov dwLengthItemTextName, eax
        Invoke lstrlen, Addr szItemTextValue
        mov dwLengthItemTextValue, eax

        mov ebx, hJSON
        mov eax, [ebx].cJSON.itemtype
        mov jsontype, eax
        
        mov eax, [ebx].cJSON.itemstring
        mov lpszItemString, eax
        .IF eax != 0
            Invoke lstrcpyn, Addr szJsonStringName, lpszItemString, SIZEOF szJsonStringName
        .ENDIF
        
        mov eax, jsontype
        .IF eax == cJSON_False
        
        .ELSEIF eax == cJSON_True
        
        .ELSEIF eax == cJSON_NULL
        
        .ELSEIF eax == cJSON_Number
            Invoke atol, Addr szItemTextValue
            mov ebx, hJSON
            mov [ebx].cJSON.valueint, eax
            ; store double / float 
            finit
            fild [ebx].cJSON.valueint
            fstp qword ptr [qwValue]
            mov eax, dword ptr [qwValue]
            mov dword ptr [ebx].cJSON.valuedouble, eax
            mov eax, dword ptr [qwValue+4]
            mov dword ptr [ebx+4].cJSON.valuedouble, eax
        
        .ELSEIF eax == cJSON_String
            mov ebx, hJSON
            mov eax, [ebx].cJSON.valuestring
            mov lpszItemStringValue, eax
            .IF eax != 0
                Invoke cJSON_free, lpszItemStringValue
            .ENDIF
            mov eax, dwLengthItemTextValue
            inc eax
            inc eax
            Invoke cJSON_malloc, eax
            .IF eax != 0
                mov lpszItemStringValue, eax
                Invoke lstrcpy, lpszItemStringValue, Addr szItemTextValue ; , dwLengthItemTextValue
                mov ebx, hJSON
                mov eax, lpszItemStringValue
                mov [ebx].cJSON.valuestring, eax
            .ENDIF
            
        .ELSEIF eax == cJSON_Array
            ; hack to update array text brackets after editing
            mov eax, hItem
            mov hTVArrayUpdate, eax
            Invoke GetParent, hTreeview
            Invoke SetTimer, eax, TIMER_ARRAY_UPDATE_ID, TIMER_ARRAY_UPDATE_TIME, NULL
            
        .ELSEIF eax == cJSON_Object
            mov eax, TRUE
            ret
            
        .ENDIF
        
        ; Update cJSON Object Name
        Invoke lstrlen, Addr szItemTextName
        .IF eax != 0
            .IF lpszItemString != 0
                Invoke lstrcmp, Addr szJsonStringName, Addr szItemTextName
                .IF eax != 0 ; not equal
                    mov bReplaceName, TRUE
                .ELSE
                    mov bReplaceName, FALSE
                .ENDIF
            .ELSE
                mov bReplaceName, TRUE
            .ENDIF
            
            .IF bReplaceName == TRUE
                .IF lpszItemString != 0
                    Invoke cJSON_free, lpszItemString
                .ENDIF
                mov eax, dwLengthItemTextName
                inc eax
                inc eax
                Invoke cJSON_malloc, eax
                .IF eax != 0
                    mov lpszItemString, eax
                    Invoke lstrcpy, lpszItemString, Addr szItemTextName ;, dwLengthItemTextName
                    mov ebx, hJSON
                    mov eax, lpszItemString
                    mov [ebx].cJSON.itemstring, eax
                .ENDIF 
            .ENDIF
        .ENDIF
        
    .ELSE
        xor eax, eax
        ret
    .ENDIF
    mov eax, TRUE
    ret
JSONUpdateItem ENDP

;-------------------------------------------------------------------------------------
; JSONUpdateArrayCount - updates the array brackets and count after add/del
;-------------------------------------------------------------------------------------
JSONUpdateArrayCount PROC USES EBX hItem:DWORD
    LOCAL hJSON:DWORD
    LOCAL dwArrayCount:DWORD
    
    Invoke TreeViewGetItemParam, hTV, hItem
    .IF eax == NULL
        ret
    .ENDIF
    mov hJSON, eax
    
    mov ebx, hJSON
    mov eax, [ebx].cJSON.itemtype
    .IF eax != cJSON_Array
        xor eax, eax
        ret
    .ENDIF
    
    Invoke TreeViewGetItemText, hTV, hItem, Addr szItemTextString, SIZEOF szItemTextString
    Invoke SeperateArrayName, Addr szItemTextString, Addr szItemText
    .IF eax != 0
        Invoke cJSON_GetArraySize, hJSON
        mov dwArrayCount, eax
        Invoke dwtoa, dwArrayCount, Addr szItemIntValue
        Invoke szCatStr, Addr szItemText, Addr szLeftSquareBracket
        Invoke szCatStr, Addr szItemText, Addr szItemIntValue
        Invoke szCatStr, Addr szItemText, Addr szRightSquareBracket
        Invoke TreeViewSetItemText, hTV, hItem, Addr szItemText
        mov eax, TRUE
    .ELSE
        xor eax, eax
    .ENDIF
    ret
JSONUpdateArrayCount ENDP

;-------------------------------------------------------------------------------------
; SeperateNameValue - seperates name and value from text string
;-------------------------------------------------------------------------------------
SeperateNameValue PROC USES EBX lpszString:DWORD, lpszName:DWORD, lpszValue:DWORD
    LOCAL dwColonPos:DWORD
    LOCAL LenString:DWORD
    
    .IF lpszString == 0
        .IF lpszName != NULL
            mov ebx, lpszName
            mov byte ptr [ebx], 0
        .ENDIF
        .IF lpszValue != NULL
            mov ebx, lpszValue
            mov byte ptr [ebx], 0
        .ENDIF
        xor eax, eax
        ret
    .ENDIF
   
    Invoke szLen, lpszString
    .IF eax == 0
        .IF lpszName != NULL
            mov ebx, lpszName
            mov byte ptr [ebx], 0
        .ENDIF
        .IF lpszValue != NULL
            mov ebx, lpszValue
            mov byte ptr [ebx], 0
        .ENDIF
        xor eax, eax
        ret
    .ELSEIF eax == 1
        mov ebx, lpszString
        movzx eax, byte ptr [ebx]
        .IF al == ':'
            .IF lpszName != NULL
                mov ebx, lpszName
                mov byte ptr [ebx], 0
            .ENDIF
        .ELSE
            .IF lpszName != NULL
                mov ebx, lpszName
                mov byte ptr [ebx], al
                mov byte ptr [ebx+1], 0
            .ENDIF
        .ENDIF
        .IF lpszValue != NULL
            mov ebx, lpszValue
            mov byte ptr [ebx], 0
        .ENDIF
        mov eax, TRUE
        ret
    .ENDIF
    mov LenString, eax    

    Invoke InString, 1, lpszString, Addr szColon
    mov dwColonPos, eax
    .IF sdword ptr eax > 0 ; match
        dec dwColonPos ; adjust for 1 based
        ;PrintDec dwColonPos
        .IF dwColonPos > 0
            Invoke szLeft, lpszString, lpszName, dwColonPos
        .ELSE
            .IF lpszName != NULL
                mov ebx, lpszName
                mov byte ptr [ebx], 0
            .ENDIF
        .ENDIF
        ;PrintText 'after szLeft'
    .ELSEIF sdword ptr eax < 0
        .IF lpszName != NULL
            mov ebx, lpszName
            mov byte ptr [ebx], 0
        .ENDIF
        .IF lpszValue != NULL
            mov ebx, lpszValue
            mov byte ptr [ebx], 0
        .ENDIF
        xor eax, eax
        ret
    .ELSE
        Invoke lstrcpy, lpszName, lpszString
        .IF lpszValue != NULL
            mov ebx, lpszValue
            mov byte ptr [ebx], 0
        .ENDIF
        mov eax, TRUE
        ret
    .ENDIF
    
    ;PrintText 'fetch after colon'
    inc dwColonPos  ; adjust for 1 based
    mov ebx, dwColonPos
    mov eax, LenString
    sub eax, ebx
    .IF sdword ptr eax > 1
        dec eax ; skip any space
        Invoke szRight, lpszString, lpszValue, eax
    .ELSE
        mov ebx, lpszValue
        mov byte ptr [ebx], 0    
    .ENDIF
    mov eax, TRUE
    ret
SeperateNameValue ENDP

;-------------------------------------------------------------------------------------
; SeperateArrayName - seperates array name from text string
;-------------------------------------------------------------------------------------
SeperateArrayName PROC USES EBX lpszString:DWORD, lpszName:DWORD
    LOCAL dwBracketPos:DWORD
    LOCAL LenString:DWORD
    
    .IF lpszString == 0
        .IF lpszName != 0
            mov ebx, lpszName
            mov byte ptr [ebx], 0
        .ENDIF
        xor eax, eax
        ret
    .ENDIF
   
    Invoke szLen, lpszString
    .IF eax == 0
        .IF lpszName != 0
            mov ebx, lpszName
            mov byte ptr [ebx], 0
        .ENDIF
        xor eax, eax
        ret
    .ELSEIF eax == 1
        mov ebx, lpszString
        movzx eax, byte ptr [ebx]
        .IF al == '['
            .IF lpszName != NULL
                mov ebx, lpszName
                mov byte ptr [ebx], 0
            .ENDIF
            xor eax, eax
            ret
        .ELSE
            .IF lpszName != NULL
                mov ebx, lpszName
                mov byte ptr [ebx], al
                mov byte ptr [ebx+1], 0
            .ENDIF
        .ENDIF
        mov eax, TRUE
        ret
    .ENDIF
    mov LenString, eax 
    
    Invoke InString, 1, lpszString, Addr szLeftSquareBracket
    mov dwBracketPos, eax
    .IF sdword ptr eax > 0 ; match
        dec dwBracketPos ; adjust for 1 based
        .IF dwBracketPos > 0
            Invoke szLeft, lpszString, lpszName, dwBracketPos
        .ELSE
            .IF lpszName != NULL
                mov ebx, lpszName
                mov byte ptr [ebx], 0
            .ENDIF
            xor eax, eax
            ret
        .ENDIF
    .ELSEIF sdword ptr eax < 0
        .IF lpszName != NULL
            mov ebx, lpszName
            mov byte ptr [ebx], 0
        .ENDIF
        xor eax, eax
        ret
    .ELSE
        Invoke lstrcpy, lpszName, lpszString
    .ENDIF
    
    mov eax, TRUE
    ret
SeperateArrayName ENDP








