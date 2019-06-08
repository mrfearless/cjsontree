Spaces                          PROTO :DWORD, :DWORD
SeperateNameValue               PROTO :DWORD, :DWORD, :DWORD
SeperateArrayName               PROTO :DWORD, :DWORD
ExportJSONBranchToFile          PROTO :DWORD, :DWORD
SaveJSONBranchToFile            PROTO :DWORD, :DWORD, :DWORD



SAVEJSON                        STRUCT
    dwOutputType                DD 0 ; 0 = clip, 1 = file
    ptrOutputData               DD 0
    dwBufferPos                 DD 0
SAVEJSON                        ENDS



.DATA
; JSON Export / Copy
szJSONExportStart               DB '{',13,10,0
szJSONExportEnd                 DB '}',13,10,0
szJSONExportObjectStart         DB '{',13,10,0
szJSONExportObjectEnd           DB '}',0;13,10,0
szJSONExportObjectCommaEnd      DB '},',13,10,0
szJSONExportArrayStart          DB '[',0 ;13,10,0
szJSONExportArrayEnd            DB ']',0;13,10,0
szJSONExportArrayEmpty          DB '[]',13,10,0
szJSONExportCRLF                DB 13,10,0
szJSONExportCommaCRLF           DB ',',13,10,0
szJSONExportMiddleString        DB '": "',0
szJSONExportMiddleOther         DB '": ',0
szJSONExportIndentSpaces        DB 32 DUP (32d)
szJSONExportSpacesBuffer        DB 32 DUP (0)

szJSONExportFileSuccess         DB 'JSON data exported to: ',0
szJSONExportFileFailed          DB 'Error exporting JSON data',0

dwLastItemType                  DD 0
dwLastLevel                     DD 0
dwLastStatus                    DD 0
dwTotalBytesToWrite             DD 0
SaveJsonData                    SAVEJSON <>
szTestFile                      DB "M:\radasm\Masm\projects\Test Projects\cjsontree\jsontest.json",0

.CODE


;-------------------------------------------------------------------------------------
; Spaces - add x amount of spaces to string
;-------------------------------------------------------------------------------------
Spaces PROC lpszBuffer:DWORD, nAmount:DWORD
    LOCAL nCount:DWORD
    mov nCount, 0
    mov eax, 0
    .WHILE eax <= nAmount
        Invoke szCatStr, lpszBuffer, Addr szSpace
        inc nCount
        mov eax, nCount
    .ENDW
    ret
Spaces ENDP


;-------------------------------------------------------------------------------------
; SeperateNameValue - seperates name and value from text string
;-------------------------------------------------------------------------------------
SeperateNameValue PROC USES EBX lpszString:DWORD, lpszName:DWORD, lpszValue:DWORD
    LOCAL dwColonPos:DWORD
    LOCAL LenString:DWORD
    
    .IF lpszString == 0
        mov ebx, lpszName
        mov byte ptr [ebx], 0
        mov ebx, lpszValue
        mov byte ptr [ebx], 0
        xor eax, eax
        ret
    .ENDIF
   
    Invoke szLen, lpszString
    mov LenString, eax 
    
    Invoke InString, 1, lpszString, Addr szColon
    mov dwColonPos, eax
    .IF eax != 0 ; match
        dec dwColonPos ; adjust for 1 based
        Invoke szLeft, lpszString, lpszName, dwColonPos
    .ELSE
        mov ebx, lpszName
        mov byte ptr [ebx], 0
        dec dwColonPos ; adjust for 1 based
    .ENDIF
    
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
    ret

SeperateNameValue ENDP


;-------------------------------------------------------------------------------------
; SeperateArrayName - seperates array name from text string
;-------------------------------------------------------------------------------------
SeperateArrayName PROC USES EBX lpszString:DWORD, lpszName:DWORD
    LOCAL dwBracketPos:DWORD
    LOCAL LenString:DWORD
    
    .IF lpszString == 0
        mov ebx, lpszName
        mov byte ptr [ebx], 0
        xor eax, eax
        ret
    .ENDIF
   
    Invoke szLen, lpszString
    mov LenString, eax 
    
    Invoke InString, 1, lpszString, Addr szLeftSquareBracket
    mov dwBracketPos, eax
    .IF eax != 0 ; match
        dec dwBracketPos ; adjust for 1 based
        Invoke szLeft, lpszString, lpszName, dwBracketPos
    .ELSE
        mov ebx, lpszName
        mov byte ptr [ebx], 0
    .ENDIF

    ret

SeperateArrayName ENDP


;-------------------------------------------------------------------------------------
; SaveJSONBranchToFile - saves/exports json data to file
;-------------------------------------------------------------------------------------
ExportJSONBranchToFile PROC hWin:DWORD, hItem:DWORD
    LOCAL hItemExport:DWORD

    .IF hItem == 0
        Invoke SendMessage, hTV, TVM_GETNEXTITEM, TVGN_ROOT, NULL
    .ELSE
        mov eax, hItem
    .ENDIF
    mov hItemExport, eax

    Invoke RtlZeroMemory, Addr ExportFile, SIZEOF ExportFile
    push hWin
    pop ExportFile.hwndOwner
    lea eax, JsonExportFileFilter
    mov ExportFile.lpstrFilter, eax
    lea eax, JsonExportFilename
    mov ExportFile.lpstrFile, eax
    lea eax, JsonExportFileFileTitle
    mov ExportFile.lpstrTitle, eax
    mov ExportFile.nMaxFile, SIZEOF JsonExportFilename
    lea eax, JsonExportDefExt
    mov ExportFile.lpstrDefExt, eax
    mov ExportFile.nFilterIndex, 1 ; json
    mov ExportFile.Flags, OFN_EXPLORER
    mov ExportFile.lStructSize, SIZEOF ExportFile
    Invoke GetSaveFileName, Addr ExportFile
    
    .IF eax !=0
        Invoke SaveJSONBranchToFile, hWin, Addr JsonExportFilename, hItemExport
        .IF eax == TRUE
            Invoke szCopy, Addr szJSONExportFileSuccess, Addr szJSONErrorMessage
            Invoke szCatStr, Addr szJSONErrorMessage, Addr JsonExportFilename
            Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
        .ELSE
            Invoke StatusBarSetPanelText, 2, Addr szJSONExportFileFailed
        .ENDIF
    .ENDIF
    ret
ExportJSONBranchToFile ENDP


;-------------------------------------------------------------------------------------
; SaveJSONBranchToFile - saves/exports json data to file
;-------------------------------------------------------------------------------------
SaveJSONBranchToFile PROC hWin:DWORD, lpszSaveFilename:DWORD, hItem:DWORD
    LOCAL hJSON:DWORD
    LOCAL hFile:DWORD
    LOCAL hItemSave:DWORD
    LOCAL dwMaxSize:DWORD
    LOCAL pData:DWORD
    LOCAL dwTotalBytesWritten:DWORD
    LOCAL ReturnVal:DWORD
    
    mov dwTotalBytesToWrite, 0
    
    Invoke CloseJSONFileHandles, hWin
    
    .IF lpszSaveFilename == NULL
        ret
    .ENDIF
    
    .IF hItem == 0
        Invoke SendMessage, hTV, TVM_GETNEXTITEM, TVGN_ROOT, NULL
        .IF eax == 0
            ret
        .ENDIF
    .ELSE
        mov eax, hItem
    .ENDIF
    mov hItemSave, eax

    Invoke TreeViewGetItemParam, hTV, hItemSave
    mov hJSON, eax
    .IF hJSON == NULL
        ret
    .ENDIF
    
    Invoke CreateFile, lpszSaveFilename, GENERIC_READ + GENERIC_WRITE, FILE_SHARE_READ+FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_FLAG_WRITE_THROUGH, NULL
    .IF eax == INVALID_HANDLE_VALUE
        mov eax, FALSE
        ret
    .ENDIF
    mov hFile, eax    
    
    Invoke cJSON_PrintBuffered, hJSON, 4096d, TRUE
    .IF eax != NULL
        mov pData, eax
        Invoke szLen, pData
        mov dwTotalBytesToWrite, eax
        
        .IF sdword ptr dwTotalBytesToWrite > 0
            ;PrintDec dwTotalBytesToWrite
            Invoke SetFilePointer, hFile, 0, 0, FILE_BEGIN	
            Invoke WriteFile, hFile, pData, dwTotalBytesToWrite, Addr dwTotalBytesWritten, NULL
            .IF eax != TRUE
                Invoke GetLastError
                ;PrintDec eax
            .ENDIF
            Invoke SetEndOfFile, hFile
            mov ReturnVal, TRUE
        .ELSE
            mov ReturnVal, FALSE
        .ENDIF
        Invoke cJSON_free, pData
    .ELSE
        mov ReturnVal, FALSE
    .ENDIF
    
    Invoke CloseHandle, hFile
     
    mov eax, ReturnVal
    ret
SaveJSONBranchToFile ENDP



















