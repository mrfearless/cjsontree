Spaces                          PROTO :DWORD, :DWORD

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
; SaveJSONBranchToFile - saves/exports json data to file
;-------------------------------------------------------------------------------------
ExportJSONBranchToFile PROC USES EBX hWin:DWORD, hItem:DWORD
    LOCAL hJSON:DWORD
    LOCAL hItemExport:DWORD

    .IF hItem == 0
        Invoke SendMessage, hTV, TVM_GETNEXTITEM, TVGN_ROOT, NULL
        .IF eax == 0
            ret
        .ENDIF
    .ELSE
        mov eax, hItem
    .ENDIF
    mov hItemExport, eax

    Invoke TreeViewGetItemParam, hTV, hItemExport
    .IF eax == NULL
        ret
    .ENDIF
    mov hJSON, eax
    
    mov ebx, hJSON
    mov eax, [ebx].cJSON.itemtype
    .IF eax == cJSON_Array || eax == cJSON_Object
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
                mov eax, TRUE
            .ELSE
                Invoke StatusBarSetPanelText, 2, Addr szJSONExportFileFailed
                xor eax, eax
            .ENDIF
        .ENDIF
    .ELSE
        xor eax, eax
    .ENDIF
    ret
ExportJSONBranchToFile ENDP


;-------------------------------------------------------------------------------------
; SaveJSONBranchToFile - saves/exports json data to file
;-------------------------------------------------------------------------------------
SaveJSONBranchToFile PROC USES EBX hWin:DWORD, lpszSaveFilename:DWORD, hItem:DWORD
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
    .IF eax == NULL
        ret
    .ENDIF
    mov hJSON, eax
        
    mov ebx, hJSON
    mov eax, [ebx].cJSON.itemtype
    .IF eax == cJSON_Array || eax == cJSON_Object
    
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
    .ELSE
        mov eax, FALSE
    .ENDIF
    ret
SaveJSONBranchToFile ENDP



















