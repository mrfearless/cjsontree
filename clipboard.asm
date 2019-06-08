JSONCutItem                     PROTO :DWORD                    ; Cut a json treeview item (wrapper for call to JSONCopyItem)
JSONCopyItem                    PROTO :DWORD, :DWORD            ; Copy (or cut) a json treeview item
JSONPasteItem                   PROTO :DWORD, :DWORD            ; Paste a previously copied or cut json treeview item (from JSONCopyItem)

JSONCopyBranch                  PROTO :DWORD, :DWORD            ; NOT WORKING - WIP TODO - Copy (or cut) a json treeview branch
JSONPasteBranch                 PROTO :DWORD, :DWORD            ; NOT WORKING - WIP TODO - Paste a previously copied or cut json treeview branch (from JSONCopyBranch)
JSONPasteBranchProcessNodes     PROTO :DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD,:DWORD ; NOT WORKING - WIP TODO

PasteJSON                       PROTO :DWORD                    ; Paste / Import Json text from clipboard
CopyToClipboard                 PROTO :DWORD, :DWORD            ; Copy to clipboard text or text value of treeview item
CopyBranchToClipboard           PROTO :DWORD, :DWORD            ; hWin, hItemClip



.DATA
szCopyTextSuccess               DB 'Copied json item text to clipboard',0
szCopyValueSuccess              DB 'Copied json item value to clipboard',0
szCopyTextEmpty                 DB 'json item text is empty, no text copied to clipboard',0
szCopyValueEmpty                DB 'json item value is empty, no text copied to clipboard',0
szCutItemSuccess                DB 'Cut: Currently selected json item copied',0
szCutBranchSuccess              DB 'Cut: Currently selected json branch item and children copied',0
szCopyItemSuccess               DB 'Copy: Currently selected json item copied',0
szCopyBranchSuccess             DB 'Copy: Currently selected json branch item and children copied',0
szPasteItemSuccess              DB 'Paste: copied json item pasted',0
szPasteBranchSuccess            DB 'Paste: copied json branch item and children pasted',0

szJSONLoadedClipData            DB 'Loaded JSON data from clipboard',0
szClipboardData                 DB '[clipboard data]',0
szJSONErrorClipData             DB 'Clipboard data does not contain valid JSON data',0
szJSONErrorEmptyClipData        DB 'JSON clipboard data is empty',0

szPasteFromClipboardJSON        DB 'Do you wish to paste JSON text from the clipboard?',0

szCopyPasteNodeText             DB JSON_ITEM_MAX_TEXTLENGTH DUP (0)

hPasteToBranchNode              DD 0



.CODE


;-------------------------------------------------------------------------------------
; PasteJSON - paste json from clipboard to create a tree
;-------------------------------------------------------------------------------------
PasteJSON PROC USES EBX hWin:DWORD
    LOCAL ptrClipData:DWORD

    Invoke IsClipboardFormatAvailable, CF_TEXT
    .IF eax == FALSE
        ret
    .ENDIF
    
    Invoke MessageBox, hWin, Addr szPasteFromClipboardJSON, Addr AppName, MB_YESNO
    .IF eax == IDNO
        Invoke SetFocus, hTV
        ret
    .ENDIF
    
    Invoke JSONFileClose, hWin

    Invoke OpenClipboard, hWin
    Invoke GetClipboardData, CF_TEXT
    .IF eax == NULL
        Invoke CloseClipboard
        xor eax, eax
        ret
    .ENDIF
    mov ptrClipData, eax
    Invoke JSONDataProcess, hWin, NULL, ptrClipData
    .IF eax == TRUE
        mov g_Edit, TRUE
        Invoke MenuSaveEnable, hWin, TRUE
        Invoke MenuSaveAsEnable, hWin, TRUE
        Invoke ToolbarButtonSaveEnable, hWin, TRUE
        Invoke ToolbarButtonSaveAsEnable, hWin, TRUE
        Invoke MenusUpdate, hWin, NULL
        Invoke ToolBarUpdate, hWin, NULL    
    .ENDIF    
    Invoke CloseClipboard
    
    mov eax, TRUE
    ret
PasteJSON ENDP


;-------------------------------------------------------------------------------------
; Copies selected treeview item text to clipboard. if bValueOnly == TRUE then 
; extracts the value from the colon in the text and copies it to clipboard
;-------------------------------------------------------------------------------------
CopyToClipboard PROC USES EBX hWin:DWORD, bValueOnly:DWORD
    LOCAL ptrClipboardData:DWORD
    LOCAL hClipData:DWORD
    LOCAL pClipData:DWORD
    LOCAL LenData:DWORD
    
    Invoke OpenClipboard, hWin
    .IF eax == 0
        ret
    .ENDIF
    Invoke EmptyClipboard
    
    Invoke GlobalAlloc, GMEM_FIXED + GMEM_ZEROINIT, JSON_ITEM_MAX_TEXTLENGTH ;1024d
    mov ptrClipboardData, eax
    
    Invoke TreeViewGetSelectedText, hTV, Addr szSelectedTreeviewText, SIZEOF szSelectedTreeviewText
    .IF eax == 0
        Invoke StatusBarSetPanelText, 2, Addr szCopyTextEmpty
        Invoke GlobalFree, ptrClipboardData
        Invoke CloseClipboard
        ret
    .ENDIF
    Invoke szLen, Addr szSelectedTreeviewText
    mov LenData, eax
    
    .IF bValueOnly == TRUE
        Invoke InString, 1, Addr szSelectedTreeviewText, Addr szColon
        .IF eax == 0 ; no match
            Invoke StatusBarSetPanelText, 2, Addr szCopyValueEmpty
            Invoke GlobalFree, ptrClipboardData
            Invoke CloseClipboard
            ret
        .ENDIF
        mov ebx, eax
        mov eax, LenData
        sub eax, ebx
        
        .IF sdword ptr eax > 1
            dec eax ; skip any space
        .ELSE
            Invoke StatusBarSetPanelText, 2, Addr szCopyValueEmpty
            Invoke GlobalFree, ptrClipboardData
            Invoke CloseClipboard
            ret
        .ENDIF
        Invoke szRight, Addr szSelectedTreeviewText, ptrClipboardData, eax
        
        Invoke szLen, ptrClipboardData
        .IF eax == 0
            Invoke StatusBarSetPanelText, 2, Addr szCopyValueEmpty
            Invoke GlobalFree, ptrClipboardData
            Invoke CloseClipboard
            ret
        .ENDIF
        mov LenData, eax
    .ELSE
        Invoke RtlMoveMemory, ptrClipboardData, Addr szSelectedTreeviewText, LenData
    .ENDIF
    
    .IF LenData == 0
        .IF bValueOnly == TRUE
            Invoke StatusBarSetPanelText, 2, Addr szCopyValueEmpty
        .ELSE
            Invoke StatusBarSetPanelText, 2, Addr szCopyTextEmpty
        .ENDIF
        Invoke GlobalFree, ptrClipboardData
        Invoke CloseClipboard
        ret
    .ENDIF
    
    mov eax, LenData
    inc eax
    Invoke GlobalAlloc, GMEM_MOVEABLE, eax ;+GMEM_DDESHARE
    .IF eax == NULL
        Invoke GlobalFree, ptrClipboardData
        Invoke CloseClipboard
        ret
    .ENDIF
    mov hClipData, eax
    
    Invoke GlobalLock, hClipData
    .IF eax == NULL
        Invoke GlobalFree, ptrClipboardData
        Invoke GlobalFree, hClipData
        Invoke CloseClipboard
        ret
    .ENDIF
    mov pClipData, eax
    mov eax, LenData
    Invoke RtlMoveMemory, pClipData, ptrClipboardData, eax
    
    Invoke GlobalUnlock, hClipData 
    invoke SetClipboardData, CF_TEXT, hClipData
    Invoke CloseClipboard

    Invoke GlobalFree, ptrClipboardData
    
    .IF bValueOnly == TRUE
        Invoke StatusBarSetPanelText, 2, Addr szCopyValueSuccess
    .ELSE
        Invoke StatusBarSetPanelText, 2, Addr szCopyTextSuccess
    .ENDIF
    
    ret
CopyToClipboard ENDP


;-------------------------------------------------------------------------------------
; Copies branch and all descendants to json formatted text to clipboard
;-------------------------------------------------------------------------------------
CopyBranchToClipboard PROC hWin:DWORD, hItem:DWORD
    LOCAL hItemClip:DWORD
    LOCAL LenData:DWORD
    LOCAL ptrClipboardData:DWORD
    LOCAL hClipData:DWORD
    LOCAL pClipData:DWORD
    LOCAL hJSON:DWORD
    
    .IF hItem == 0
        Invoke SendMessage, hTV, TVM_GETNEXTITEM, TVGN_ROOT, NULL
        .IF eax == 0
            ret
        .ENDIF
    .ELSE
        mov eax, hItem
    .ENDIF
    mov hItemClip, eax

    Invoke TreeViewGetItemParam, hTV, hItemClip
    mov hJSON, eax
    .IF hJSON == NULL
        xor eax, eax
        ret
    .ENDIF
    
    Invoke cJSON_PrintBuffered, hJSON, 4096d, TRUE
    .IF eax != NULL
        mov ptrClipboardData, eax
        
        Invoke OpenClipboard, hWin
        .IF eax == 0
            Invoke cJSON_free, ptrClipboardData
            xor eax, eax
            ret
        .ENDIF
        Invoke EmptyClipboard
        
        Invoke szLen, ptrClipboardData
        mov LenData, eax
        inc eax
        Invoke GlobalAlloc, GMEM_MOVEABLE, eax ;+GMEM_DDESHARE
        .IF eax == NULL
            Invoke GlobalFree, ptrClipboardData
            Invoke CloseClipboard
            ret
        .ENDIF
        mov hClipData, eax
        
        Invoke GlobalLock, hClipData
        .IF eax == NULL
            Invoke GlobalFree, ptrClipboardData
            Invoke GlobalFree, hClipData
            Invoke CloseClipboard
            ret
        .ENDIF
        mov pClipData, eax
        mov eax, LenData
        Invoke RtlMoveMemory, pClipData, ptrClipboardData, eax
        
        Invoke GlobalUnlock, hClipData 
        invoke SetClipboardData, CF_TEXT, hClipData

        Invoke CloseClipboard
        Invoke cJSON_free, ptrClipboardData
        mov eax, TRUE
    .ELSE
        xor eax, eax
    .ENDIF
    ret
CopyBranchToClipboard ENDP


;-------------------------------------------------------------------------------------
; Cut a node item (calls JSONCopyItem)
;-------------------------------------------------------------------------------------
JSONCutItem PROC hItem:DWORD
    Invoke JSONCopyItem, hItem, TRUE
    ret
JSONCutItem ENDP


;-------------------------------------------------------------------------------------
; Copy node item
;-------------------------------------------------------------------------------------
JSONCopyItem PROC USES EBX hItem:DWORD, bCut:DWORD
    LOCAL tvhi:TV_HITTESTINFO
    LOCAL hJSON:DWORD
    
    .IF hItem == NULL
        Invoke TreeViewGetSelectedItem, hTV
        .IF eax == 0
            Invoke GetCursorPos, Addr tvhi.pt
            Invoke ScreenToClient, hTV, addr tvhi.pt
            Invoke SendMessage, hTV, TVM_HITTEST, 0, Addr tvhi        
            mov eax, tvhi.hItem
        .ENDIF
    .ELSE
        mov eax, hItem
    .ENDIF
    mov g_hCutCopyNode, eax
    
    .IF eax != 0
        .IF bCut == TRUE
            mov g_Cut, TRUE
            Invoke TreeViewGetItemParam, hTV, g_hCutCopyNode
            mov ebx, eax
            mov eax, [ebx].cJSON.itemtype
            mov g_CutJsonType, eax
            Invoke TreeViewGetItemImage, hTV, g_hCutCopyNode
            mov g_CutIcon, eax
            Invoke TreeViewGetItemText, hTV, g_hCutCopyNode, Addr g_CutText, SIZEOF g_CutText
            Invoke JSONRemoveItem, hTV, g_hCutCopyNode
            Invoke StatusBarSetPanelText, 2, Addr szCutItemSuccess
        .ELSE
            mov g_Cut, FALSE
            Invoke StatusBarSetPanelText, 2, Addr szCopyItemSuccess
        .ENDIF
    .ENDIF
    ret
JSONCopyItem ENDP


;-------------------------------------------------------------------------------------
; Paste node item
;-------------------------------------------------------------------------------------
JSONPasteItem PROC USES EBX hWin:DWORD, hItem:DWORD
    LOCAL tvhi:TV_HITTESTINFO
    LOCAL tvi:TV_ITEM
    LOCAL hPasteToNode:DWORD
    LOCAL hCopyFromNode:DWORD
    LOCAL hNewNode:DWORD
    LOCAL hJSONCopyFrom:DWORD
    LOCAL hJSONPasteTo:DWORD
    LOCAL dwJsonType:DWORD
    LOCAL nIcon:DWORD
    LOCAL hItemPrev:DWORD
    
    .IF g_hCutCopyNode == 0
        ret
    .ELSE
        mov eax, g_hCutCopyNode
        mov hCopyFromNode, eax
    .ENDIF
    
    mov eax, hItem
    .IF eax == 0
        Invoke TreeViewGetSelectedItem, hTV
        .IF eax == 0
            Invoke GetCursorPos, Addr tvhi.pt
            Invoke ScreenToClient, hTV, addr tvhi.pt
            Invoke SendMessage, hTV, TVM_HITTEST, 0, Addr tvhi        
            mov eax, tvhi.hItem
        .ENDIF
    .ELSE
        mov eax, hItem
    .ENDIF
    mov hPasteToNode, eax
    
    .IF hPasteToNode == 0
        ret
    .ENDIF
    
    IFDEF DEBUG32
    ;PrintDec hCopyFromNode
    ;PrintDec hPasteToNode
    ENDIF
    
    .IF g_Cut == FALSE
        ; got copy and paste nodes
        Invoke TreeViewGetItemText, hTV, hCopyFromNode, Addr szCopyPasteNodeText, SIZEOF szCopyPasteNodeText
        Invoke TreeViewGetItemImage, hTV, hCopyFromNode
        mov nIcon, eax
        Invoke TreeViewGetItemParam, hTV, hCopyFromNode
        mov hJSONCopyFrom, eax
        mov ebx, eax
        mov eax, [ebx].cJSON.itemtype
        mov dwJsonType, eax
    .ELSE
        mov eax, g_CutIcon
        mov nIcon, eax
        mov eax, g_CutJsonType
        mov dwJsonType, eax
        Invoke szCopy, Addr g_CutText, Addr szCopyPasteNodeText
    .ENDIF
    Invoke JSONCreateItem, hTV, hPasteToNode, dwJsonType
    mov hJSONPasteTo, eax

    .IF hJSONPasteTo == 0
        ;PrintText 'hJSONAdd == 0'
        ret
    .ENDIF

    .IF hJSONPasteTo != 0

        Invoke TreeViewItemInsert, hTV, hPasteToNode, Addr szCopyPasteNodeText, g_nTVIndex, TVI_LAST, nIcon, nIcon, hJSONPasteTo
        mov hNewNode, eax
        inc g_nTVIndex
    
        .IF g_Cut == TRUE
            mov g_Cut, FALSE
            mov g_hCutCopyNode, NULL
        .ENDIF
        
        Invoke StatusBarSetPanelText, 2, Addr szPasteItemSuccess    
    
        mov g_Edit, TRUE
        Invoke MenuSaveEnable, hWin, TRUE
        Invoke MenuSaveAsEnable, hWin, TRUE
        Invoke ToolbarButtonSaveEnable, hWin, TRUE
        Invoke ToolbarButtonSaveAsEnable, hWin, TRUE
        
    .ENDIF
    ;Invoke TreeViewSetSelectedItem, hTV, hNewNode, TRUE
    ;Invoke TreeViewItemExpand, hTV, hNewNode
    
    ret
JSONPasteItem ENDP


;-------------------------------------------------------------------------------------
; Copy node branch and children
;-------------------------------------------------------------------------------------
JSONCopyBranch PROC USES EBX hItem:DWORD, bCut:DWORD
    LOCAL tvhi:TV_HITTESTINFO
    LOCAL hJSON:DWORD
    
    .IF hItem == NULL
        Invoke TreeViewGetSelectedItem, hTV
        .IF eax == 0
            Invoke GetCursorPos, Addr tvhi.pt
            Invoke ScreenToClient, hTV, addr tvhi.pt
            Invoke SendMessage, hTV, TVM_HITTEST, 0, Addr tvhi        
            mov eax, tvhi.hItem
        .ENDIF
    .ELSE
        mov eax, hItem
    .ENDIF
    mov g_hCutCopyBranchNode, eax
    
    .IF eax != 0
        .IF g_CutBranch == TRUE
            mov g_CutBranch, TRUE
;            Invoke TreeViewGetItemParam, hTV, g_hCutCopyBranchNode
;            mov ebx, eax
;            mov eax, [ebx].cJSON.itemtype
;            mov g_CutJsonType, eax
;            Invoke TreeViewGetItemImage, hTV, g_hCutCopyBranchNode
;            mov g_CutIcon, eax
;            Invoke TreeViewGetItemText, hTV, g_hCutCopyBranchNode, Addr g_CutText, SIZEOF g_CutText
;            Invoke JSONRemoveItem, hTV, g_hCutCopyBranchNode
;            Invoke StatusBarSetPanelText, 2, Addr szCutItemSuccess
        .ELSE
            mov g_CutBranch, FALSE
            Invoke StatusBarSetPanelText, 2, Addr szCopyBranchSuccess
        .ENDIF
    .ENDIF
    ret
JSONCopyBranch ENDP



;-------------------------------------------------------------------------------------
; Paste node item
;-------------------------------------------------------------------------------------
JSONPasteBranch PROC USES EBX hWin:DWORD, hItem:DWORD
    LOCAL tvhi:TV_HITTESTINFO
    LOCAL tvi:TV_ITEM
    LOCAL hCopyFromNode:DWORD
    ;LOCAL hNewNode:DWORD
    LOCAL hJSONCopyFrom:DWORD
    ;LOCAL hJSONPasteTo:DWORD
    ;LOCAL dwJsonType:DWORD
    ;LOCAL nIcon:DWORD
    ;LOCAL hItemPrev:DWORD
    
    .IF g_hCutCopyBranchNode == 0
        ret
    .ELSE
        mov eax, g_hCutCopyBranchNode
        mov hJSONCopyFrom, eax
    .ENDIF
    
    mov eax, hItem
    .IF eax == 0
        Invoke TreeViewGetSelectedItem, hTV
        .IF eax == 0
            Invoke GetCursorPos, Addr tvhi.pt
            Invoke ScreenToClient, hTV, addr tvhi.pt
            Invoke SendMessage, hTV, TVM_HITTEST, 0, Addr tvhi        
            mov eax, tvhi.hItem
        .ENDIF
    .ELSE
        mov eax, hItem
    .ENDIF
    mov hPasteToBranchNode, eax
    
    .IF hPasteToBranchNode == 0
        ret
    .ENDIF
    
    IFDEF DEBUG32
    ;PrintDec hCopyFromNode
    ;PrintDec hPasteToNode
    ENDIF
    
    
    Invoke TreeViewWalk, hTV, hJSONCopyFrom, Addr JSONPasteBranchProcessNodes, NULL
    .IF eax == TRUE
    
    
;    .IF g_CutBranch == FALSE
;        ; got copy and paste nodes
;        Invoke TreeViewGetItemText, hTV, hCopyFromNode, Addr szCopyPasteNodeText, SIZEOF szCopyPasteNodeText
;        Invoke TreeViewGetItemImage, hTV, hCopyFromNode
;        mov nIcon, eax
;        Invoke TreeViewGetItemParam, hTV, hCopyFromNode
;        mov hJSONCopyFrom, eax
;        mov ebx, eax
;        mov eax, [ebx].cJSON.itemtype
;        mov dwJsonType, eax
;    .ELSE
;;        mov eax, g_CutIcon
;;        mov nIcon, eax
;;        mov eax, g_CutJsonType
;;        mov dwJsonType, eax
;;        Invoke szCopy, Addr g_CutText, Addr szCopyPasteNodeText
;    .ENDIF
;    Invoke JSONCreateItem, hTV, hPasteToNode, dwJsonType
;    mov hJSONPasteTo, eax
;
;    .IF hJSONPasteTo == 0
;        PrintText 'hJSONAdd == 0'
;        ret
;    .ENDIF
;
;    .IF hJSONPasteTo != 0
;
;        Invoke TreeViewItemInsert, hTV, hPasteToNode, Addr szCopyPasteNodeText, g_nTVIndex, TVI_LAST, nIcon, nIcon, hJSONPasteTo
;        mov hNewNode, eax
;        inc g_nTVIndex
;    
;        .IF g_CutBranch == TRUE
;            mov g_CutBranch, FALSE
;            mov g_hCutCopyBranchNode, NULL
;        .ENDIF
        
        Invoke StatusBarSetPanelText, 2, Addr szPasteBranchSuccess    
    
        mov g_Edit, TRUE
        Invoke MenuSaveEnable, hWin, TRUE
        Invoke MenuSaveAsEnable, hWin, TRUE
        Invoke ToolbarButtonSaveEnable, hWin, TRUE
        Invoke ToolbarButtonSaveAsEnable, hWin, TRUE
        
    .ENDIF
    ;Invoke TreeViewSetSelectedItem, hTV, hNewNode, TRUE
    ;Invoke TreeViewItemExpand, hTV, hNewNode
    
    ret
JSONPasteBranch ENDP



;**************************************************************************
; JSONPasteBranchProcessNodes
;**************************************************************************
JSONPasteBranchProcessNodes PROC USES EBX hTreeview:DWORD, hItem:DWORD, dwStatus:DWORD, dwTotalItems:DWORD, dwItemNo:DWORD, dwLevel:DWORD, dwCustomData:DWORD
    LOCAL hJSONCopyFrom:DWORD
    LOCAL hJSONPasteTo:DWORD
    LOCAL hCopyFromNode:DWORD
    LOCAL hNewNode:DWORD
    LOCAL dwJsonType:DWORD
    LOCAL nIcon:DWORD
    

    mov eax, dwStatus
    .IF eax == TREEVIEWWALK_ITEM || eax == TREEVIEWWALK_ITEM_START || eax == TREEVIEWWALK_ITEM_FINISH
    ;-----------------------------------------------------------------------------
        .IF eax == TREEVIEWWALK_ITEM || eax == TREEVIEWWALK_ITEM_START
        ;-----------------------------------------------------------------------------
            mov eax, hItem
            mov hCopyFromNode, eax
        
            Invoke TreeViewGetItemText, hTreeview, hCopyFromNode, Addr szCopyPasteNodeText, SIZEOF szCopyPasteNodeText
            Invoke TreeViewGetItemImage, hTreeview, hCopyFromNode
            mov nIcon, eax
            Invoke TreeViewGetItemParam, hTreeview, hCopyFromNode
            mov hJSONCopyFrom, eax
            mov ebx, eax
            mov eax, [ebx].cJSON.itemtype
            mov dwJsonType, eax

            Invoke JSONCreateItem, hTreeview, hPasteToBranchNode, dwJsonType
            mov hJSONPasteTo, eax
            
            .IF hJSONPasteTo != 0
                Invoke TreeViewItemInsert, hTreeview, hPasteToBranchNode, Addr szCopyPasteNodeText, g_nTVIndex, TVI_LAST, nIcon, nIcon, hJSONPasteTo
                mov hNewNode, eax
                inc g_nTVIndex
            .ENDIF            
        .ENDIF
        ;-----------------------------------------------------------------------------
    
        mov eax, dwStatus
        .IF eax == TREEVIEWWALK_ITEM_START
            push hPasteToBranchNode
            mov eax, hNewNode
            mov hPasteToBranchNode, eax
            
        
        .ELSEIF eax == TREEVIEWWALK_ITEM_FINISH
            pop hPasteToBranchNode
        
        .ENDIF
        
    .ENDIF
    ;-----------------------------------------------------------------------------
    
    ret
JSONPasteBranchProcessNodes ENDP





















