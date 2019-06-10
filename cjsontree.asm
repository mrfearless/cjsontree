.686
.MMX
.XMM
.model flat,stdcall
option casemap:none
include \masm32\macros\macros.asm

;DEBUG32 EQU 1

;EXPERIMENTAL_ARRAYNAME_STACK EQU 1 ; Experimental, doesnt seem to work properly, so use if you uncomment, use with caution

IFDEF DEBUG32
    echo
    echo ------------------------------------------
    echo DEBUG32 - Debugging Enabled
    echo ------------------------------------------
    echo
    PRESERVEXMMREGS equ 1
    includelib M:\Masm32\lib\Debug32.lib
    DBG32LIB equ 1
    DEBUGEXE textequ <'M:\Masm32\DbgWin.exe'>
    include M:\Masm32\include\debug32.inc
ENDIF

;LIBCJSON EQU 1 ; comment out to use cjson.lib library instead of libcjson.lib 

include cjsontree.inc
include statusbar.asm
include ini.asm
include menus.asm
include toolbar.asm
include edit.asm
;include TVFind.asm
include search.asm
include saveexport.asm
include clipboard.asm

IFDEF EXPERIMENTAL_ARRAYNAME_STACK
include stack.asm
ENDIF

.code

start:

    Invoke GetModuleHandle,NULL
    mov hInstance, eax
    invoke LoadAccelerators, hInstance, ACCTABLE
    mov hAcc, eax    
    Invoke GetCommandLine
    mov CommandLine, eax
    Invoke InitCommonControls
    mov icc.dwSize, sizeof INITCOMMONCONTROLSEX
    mov icc.dwICC, ICC_COOL_CLASSES or ICC_STANDARD_CLASSES or ICC_WIN95_CLASSES
    Invoke InitCommonControlsEx, offset icc
    
    Invoke IniCreateFilename, Addr szIniFilename, NULL
    Invoke CmdLineProcess
    
    Invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
    Invoke ExitProcess, eax

;-------------------------------------------------------------------------------------
; WinMain
;-------------------------------------------------------------------------------------
WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
    LOCAL   wc:WNDCLASSEX
    LOCAL   msg:MSG

    mov     wc.cbSize, sizeof WNDCLASSEX
    mov     wc.style, CS_HREDRAW or CS_VREDRAW
    mov     wc.lpfnWndProc, offset WndProc
    mov     wc.cbClsExtra, NULL
    mov     wc.cbWndExtra, DLGWINDOWEXTRA
    push    hInst
    pop     wc.hInstance
    mov     wc.hbrBackground, COLOR_BTNFACE+1 ; COLOR_WINDOW+1
    mov     wc.lpszMenuName, IDM_MENU
    mov     wc.lpszClassName, offset ClassName
    Invoke LoadIcon, hInstance, ICO_MAIN ; resource icon for main application icon
    mov hICO_MAIN, eax ; main application icon
    mov     wc.hIcon, eax
    mov     wc.hIconSm, eax
    Invoke LoadCursor, NULL, IDC_ARROW
    mov     wc.hCursor,eax
    Invoke RegisterClassEx, addr wc
    Invoke CreateDialogParam, hInstance, IDD_DIALOG, NULL, addr WndProc, NULL
    mov hWnd, eax
    Invoke ShowWindow, hWnd, SW_SHOWNORMAL
    Invoke UpdateWindow, hWnd
    .WHILE TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .BREAK .if !eax

        Invoke TranslateAccelerator, hWnd, hAcc, addr msg
        .IF eax == 0
            Invoke IsDialogMessage, hWnd, addr msg
            .IF eax == 0
                Invoke TranslateMessage, addr msg
                Invoke DispatchMessage, addr msg
            .ENDIF
        .ENDIF
    .ENDW
    mov eax,msg.wParam
    ret
WinMain endp

;-------------------------------------------------------------------------------------
; WndProc - Main Window Message Loop
;-------------------------------------------------------------------------------------
WndProc proc USES EBX hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
    LOCAL tvhi:TV_HITTESTINFO
    LOCAL hItem:DWORD
    LOCAL wNotifyCode:DWORD
    
    mov eax, uMsg
    .IF eax == WM_INITDIALOG
        push hWin
        pop hWnd
        ; Init Stuff Here
        
        mov hJSONFile, NULL
        mov hJSONTreeRoot, NULL
        
        Invoke InitGUI, hWin

        Invoke DragAcceptFiles, hWin, TRUE
        Invoke SetFocus, hTV
        
    .ELSEIF eax == WM_COMMAND
		mov eax, wParam
		shr eax, 16
		mov wNotifyCode, eax
		mov	eax,wParam
		and	eax,0FFFFh
        .IF eax == IDM_FILE_EXIT
            Invoke SendMessage,hWin,WM_CLOSE,0,0

        .ELSEIF eax == IDM_FILE_OPEN || eax == ACC_FILE_OPEN || eax == TB_FILE_OPEN
            Invoke szCopy, Addr szNullNull, Addr JsonOpenedFilename
            Invoke szCopy, Addr szNullNull, Addr JsonSavedFilename
            Invoke szCopy, Addr szNullNull, Addr JsonExportFilename        
            Invoke JSONFileOpenBrowse, hWin
            .IF eax == TRUE
                Invoke JSONFileOpen, hWin, Addr JsonOpenedFilename
                .IF eax == TRUE
                    ; Start processing JSON file
                    Invoke JSONDataProcess, hWin, Addr JsonOpenedFilename, NULL
                .ENDIF
            .ENDIF
          
        .ELSEIF eax == IDM_FILE_CLOSE || eax == ACC_FILE_CLOSE || eax == TB_FILE_CLOSE
            ;Invoke TreeViewDeleteAll, hTV
            Invoke JSONFileClose, hWin
            ;Invoke MenusReset, hWin
            ;Invoke ToolbarsReset, hWin
        
        .ELSEIF eax == IDM_FILE_NEW || eax == ACC_FILE_NEW || eax == TB_FILE_NEW
            Invoke szCopy, Addr szNullNull, Addr JsonOpenedFilename
            Invoke szCopy, Addr szNullNull, Addr JsonSavedFilename
            Invoke szCopy, Addr szNullNull, Addr JsonExportFilename
            Invoke JSONNew, hWin
            ;Invoke MenuSaveEnable, hWin, TRUE
            ;Invoke ToolbarButtonSaveEnable, hWin, TRUE
        
        .ELSEIF eax == IDM_FILE_SAVE || eax == ACC_FILE_SAVE || eax == TB_FILE_SAVE
            .IF g_Edit == TRUE && g_Save == TRUE
                Invoke JSONFileSave, hWin, FALSE
            .ENDIF
            
        .ELSEIF eax == IDM_FILE_SAVEAS || eax == ACC_FILE_SAVEAS || eax == TB_FILE_SAVEAS
            .IF g_SaveAs == TRUE
                Invoke TreeViewCountItems, hTV
                .IF eax != 0
                    Invoke JSONFileSave, hWin, TRUE
                .ENDIF
            .ENDIF
        
        .ELSEIF eax == IDM_HELP_ABOUT
            Invoke ShellAbout,hWin,addr AppName,addr AboutMsg,NULL
        
        .ELSEIF eax == IDM_EDIT_PASTE_JSON || eax == IDM_CMD_PASTE_JSON
            Invoke PasteJSON, hWin
        
        .ELSEIF eax == IDM_EDIT_COPY_TEXT || eax == IDM_CMD_COPY_TEXT
            Invoke CopyToClipboard, hWin, FALSE
        
        .ELSEIF eax == IDM_EDIT_COPY_VALUE || eax == IDM_CMD_COPY_VALUE
            Invoke CopyToClipboard, hWin, TRUE
        
        .ELSEIF eax == IDM_EDIT_CUT_ITEM || eax == IDM_CMD_CUT_ITEM ;|| eax == ACC_EDIT_CUT_ITEM || eax == TB_EDIT_CUT_ITEM
            Invoke JSONCutItem, NULL
            
        .ELSEIF eax == IDM_EDIT_COPY_ITEM || eax == IDM_CMD_COPY_ITEM || eax == ACC_EDIT_COPY_ITEM || eax == TB_EDIT_COPY_ITEM
            Invoke JSONCopyItem, NULL, FALSE
            
        .ELSEIF eax == IDM_EDIT_COPY_BRANCH || eax == IDM_CMD_COPY_BRANCH || eax == ACC_EDIT_COPY_BRANCH || eax == TB_EDIT_COPY_BRANCH
            ;Invoke JSONCopyBranch, NULL, FALSE
            
        .ELSEIF eax == IDM_EDIT_PASTE_ITEM || eax == IDM_CMD_PASTE_ITEM || eax == ACC_EDIT_PASTE_ITEM || eax == TB_EDIT_PASTE_ITEM
            Invoke JSONPasteItem, hWin, NULL
        
        .ELSEIF eax == IDM_EDIT_PASTE_BRANCH || eax == IDM_CMD_PASTE_BRANCH || eax == ACC_EDIT_PASTE_BRANCH || eax == TB_EDIT_PASTE_BRANCH
            ;Invoke JSONPasteBranch, hWin, NULL
            
        .ELSEIF eax == IDM_EDIT_FIND || eax == IDM_CMD_FIND || eax == ACC_EDIT_FIND || eax == TB_EDIT_FIND
            Invoke SetFocus, hTxtSearchTextbox
            ;Invoke SearchTextboxStartSearch, hWin

        .ELSEIF eax == IDM_CMD_EXPORT_BRANCH_FILE || eax == ACC_EXPORT_BRANCHFILE
            Invoke TreeViewGetSelectedItem, hTV
            .IF eax != 0
                Invoke ExportJSONBranchToFile, hWin, eax
            .ENDIF
            
        .ELSEIF eax == IDM_CMD_EXPORT_ROOT_FILE || eax == ACC_EXPORT_TREEFILE
            Invoke ExportJSONBranchToFile, hWin, 0
        
        .ELSEIF eax == IDM_CMD_EXPORT_BRANCH_CLIP || eax == ACC_EXPORT_BRANCHCLIP
            Invoke TreeViewGetSelectedItem, hTV
            .IF eax != 0        
                Invoke CopyBranchToClipboard, hWin, eax
            .ENDIF
            
        .ELSEIF eax == IDM_CMD_EXPORT_ROOT_CLIP || eax == ACC_EXPORT_TREECLIP
            Invoke CopyBranchToClipboard, hWin, 0
        
        .ELSEIF eax == IDM_CMD_COLLAPSE_BRANCH
            Invoke TreeViewGetSelectedItem, hTV
            Invoke TreeViewBranchCollapse, hTV, eax
            
        .ELSEIF eax == IDM_CMD_EXPAND_BRANCH
            Invoke TreeViewGetSelectedItem, hTV
            Invoke TreeViewBranchExpand, hTV, eax

        .ELSEIF eax == IDM_CMD_COLLAPSE_ALL || eax == ACC_COLLAPSE_ALL
            .IF hTVEditControl == NULL
                Invoke TreeViewRootCollapse, hTV
                Invoke TreeViewSetSelectedItem, hTV, hTVRoot, TRUE
                Invoke ToolBarUpdate, hWin, hTVRoot
                Invoke MenusUpdate, hWin, hTVRoot
                Invoke EditBoxUpdate, hWin, hTVRoot
            .ENDIF 
            
        .ELSEIF eax == IDM_CMD_EXPAND_ALL || eax == ACC_EXPAND_ALL
            .IF hTVEditControl == NULL        
                Invoke TreeViewRootExpand, hTV
                Invoke TreeViewSetSelectedItem, hTV, hTVRoot, TRUE
                Invoke ToolBarUpdate, hWin, hTVRoot
                Invoke MenusUpdate, hWin, hTVRoot
                Invoke EditBoxUpdate, hWin, hTVRoot
            .ENDIF
        
        .ELSEIF eax == IDM_CMD_ADD_ITEM || eax == ACC_EDIT_ADD_ITEM
            ; submenu is processed
            Invoke MenuRCAddShow, hWin
        
        .ELSEIF eax == TB_ADD_ITEM
            Invoke ToolBarDropdownAddMenuShow, hWin
        
        .ELSEIF eax == IDM_CMD_DEL_ITEM || eax == TB_DEL_ITEM
            Invoke JSONDelItem, hWin
        
        .ELSEIF eax == IDM_CMD_EDIT_ITEM
            Invoke JSONEditItem, hWin
            
        .ELSEIF eax == IDM_CMD_ADD_ITEM_STRING || eax == TB_ADD_ITEM_STRING || eax == ACC_ADD_ITEM_STRING
            Invoke JSONAddItem, hWin, cJSON_String
            
        .ELSEIF eax == IDM_CMD_ADD_ITEM_NUMBER || eax == TB_ADD_ITEM_NUMBER || eax == ACC_ADD_ITEM_NUMBER
            Invoke JSONAddItem, hWin, cJSON_Number
            
        .ELSEIF eax == IDM_CMD_ADD_ITEM_TRUE || eax == TB_ADD_ITEM_TRUE || eax == ACC_ADD_ITEM_TRUE
            Invoke JSONAddItem, hWin, cJSON_True
            
        .ELSEIF eax == IDM_CMD_ADD_ITEM_FALSE || eax == TB_ADD_ITEM_FALSE || eax == ACC_ADD_ITEM_FALSE
            Invoke JSONAddItem, hWin, cJSON_False
            
        .ELSEIF eax == IDM_CMD_ADD_ITEM_ARRAY || eax == TB_ADD_ITEM_ARRAY || eax == ACC_ADD_ITEM_ARRAY
            Invoke JSONAddItem, hWin, cJSON_Array
            
        .ELSEIF eax == IDM_CMD_ADD_ITEM_OBJECT    || eax == TB_ADD_ITEM_OBJECT || eax == ACC_ADD_ITEM_OBJECT
            Invoke JSONAddItem, hWin, cJSON_Object

		.ELSEIF eax >= IDM_MRU_1 && eax <= IDM_MRU_9
			Invoke GetMenuString, hMainWindowMenu, eax, Addr szMenuString, SIZEOF szMenuString, MF_BYCOMMAND
			.IF eax != 0
			    Invoke szLen, Addr szMenuString
			    .IF eax != 0
				    Invoke IniMRUEntryOpenFile, hWin, Addr szMenuString
				.ENDIF
			.ENDIF
        
        .ELSEIF eax == IDM_OPTIONS_EXPANDALL
            Invoke IniToggleExpandAllOnLoad
            Invoke MenuOptionsUpdate, hWin
        
        .ELSEIF eax == IDM_OPTIONS_CASESEARCH || eax == ACC_OPTIONS_CASESEARCH
            Invoke IniToggleCaseSensitiveSearch
            Invoke MenuOptionsUpdate, hWin
            Invoke InvalidateRect, hTxtSearchTextbox, NULL, TRUE
            
        .ENDIF
    
    .ELSEIF eax == WM_DROPFILES
        mov eax, wParam
        mov hDrop, eax
        
        Invoke DragQueryFile, hDrop, 0, Addr JsonOpenedFilename, SIZEOF JsonOpenedFilename
        .IF eax != 0
            Invoke JSONFileOpen, hWin, Addr JsonOpenedFilename
            .IF eax == TRUE
                ; Start processing JSON file
                Invoke JSONDataProcess, hWin, Addr JsonOpenedFilename, NULL
            .ENDIF
        .ENDIF
        mov eax, 0
        ret

    .ELSEIF eax == WM_WINDOWPOSCHANGED
        mov ebx, lParam
        mov eax, (WINDOWPOS ptr [ebx]).flags
        and eax, SWP_SHOWWINDOW
        .IF eax == SWP_SHOWWINDOW && g_fShown == FALSE
            mov g_fShown, TRUE
            Invoke PostMessage, hWin, WM_APP, 0, 0
        .ENDIF
        Invoke DefWindowProc,hWin,uMsg,wParam,lParam
        xor eax, eax
        ret
        
    .ELSEIF eax == WM_APP
        .IF CmdLineProcessFileFlag == 1
            Invoke CmdLineOpenFile, hWin
        .ENDIF
        Invoke DefWindowProc,hWin,uMsg,wParam,lParam
        ret      
    
    .ELSEIF eax == WM_CTLCOLORDLG
        mov eax, hWhiteBrush
        ret

    .ELSEIF eax == WM_SIZE
        Invoke SendMessage, hSB, WM_SIZE, 0, 0
        mov eax, lParam
        and eax, 0FFFFh
        mov dwClientWidth, eax
        mov eax, lParam
        shr eax, 16d
        mov dwClientHeight, eax
        sub eax, 23d ; take away statusbar height
        sub eax, 28d ; take away toolbar height
        .IF g_ShowEditBox == 1
        sub eax, g_EditBoxHeight ; take away height of editbox if shown
        dec eax
        .ENDIF
        Invoke SetWindowPos, hTV, HWND_TOP, 0, 29, dwClientWidth, eax, SWP_NOZORDER
        
        .IF g_ShowEditBox == 1
            ; set editbox position
            mov eax, dwClientHeight
            sub eax, 23d ; take away statusbar height
            sub eax, 28d ; take away toolbar height
            sub eax, 29d
            sub eax, 27d
            Invoke SetWindowPos, hEdtText, HWND_TOP, 0, eax, dwClientWidth, g_EditBoxHeight, SWP_NOZORDER
        .ENDIF    
        
        Invoke SendMessage, hToolBar, TB_AUTOSIZE, 0, 0
        Invoke SendMessage, hSB, WM_SIZE, 0, 0

    .ELSEIF eax == WM_MOUSEMOVE
        .IF g_DragMode == TRUE
            mov eax, lParam
            and eax, 0ffffh
            mov ebx, lParam
            shr ebx, 16
            sub ebx, 29d  ; substract top of treeview (based on pos on dialog, at the momement its always 29)
            mov tvhi.pt.x, eax
            mov tvhi.pt.y, ebx
            Invoke ImageList_DragMove, eax, ebx
            Invoke ImageList_DragShowNolock, FALSE
            Invoke SendMessage, hTV, TVM_HITTEST, NULL, addr tvhi
            .IF eax != NULL
                Invoke SendMessage, hTV, TVM_SELECTITEM, TVGN_DROPHILITE, eax
            .ENDIF
            Invoke UpdateWindow, hTV
            Invoke ImageList_DragShowNolock, TRUE
        .ENDIF
    
    .ELSEIF eax == WM_LBUTTONUP
        .IF g_DragMode == TRUE
            Invoke ImageList_DragLeave, hTV
            Invoke ImageList_EndDrag
            Invoke ImageList_Destroy, hDragImageList
            Invoke SendMessage, hTV, TVM_GETNEXTITEM, TVGN_DROPHILITE,0
            Invoke SendMessage, hTV, TVM_SELECTITEM, TVGN_CARET, eax
            Invoke SendMessage, hTV, TVM_SELECTITEM, TVGN_DROPHILITE,0
            Invoke ReleaseCapture
            mov g_DragMode, FALSE
            ; store dragged node somewhere so we can do something with it after drop
            ; todo add code to handle what we do once we have dropped on target
            ; popup menu: insert before/after? copy/cut?
            ; handle child items of dragged node
        .ENDIF

    .ELSEIF eax==WM_NOTIFY
        mov ebx,lParam
        mov eax, (NMHDR PTR [ebx]).code
        mov ebx, (NMHDR PTR [ebx]).hwndFrom
        
        .IF ebx == hTV
            .IF eax == NM_RCLICK
    	        Invoke MenusUpdate, hWin, NULL
    	        Invoke ToolBarUpdate, hWin, NULL
                Invoke MenuRCShow, hWin
            
            .ELSEIF eax == NM_CLICK
                Invoke GetCursorPos, Addr tvhi.pt
                Invoke ScreenToClient, hTV, addr tvhi.pt
                Invoke SendMessage, hTV, TVM_HITTEST, 0, Addr tvhi
                .IF tvhi.flags == TVHT_ONITEMLABEL
                    mov eax, tvhi.hItem
                    mov hFoundItem, eax
                    ;mov hTVSelectedItem, eax
                    ;PrintDec hTVSelectedItem
                    ;mov bSearchTermNew, TRUE
                    
                    Invoke ToolBarUpdate, hWin, tvhi.hItem
                    Invoke MenusUpdate, hWin, tvhi.hItem
                    Invoke EditBoxUpdate, hWin, tvhi.hItem                    
                    
                .ENDIF
                ;Invoke SearchTextboxShow, hWin, FALSE
                ;Invoke MenusUpdate, hWin, NULL
                ;Invoke ToolBarUpdate, hWin, NULL
            
            .ELSEIF eax == NM_DBLCLK
                Invoke JSONEditItem, hWin
                
            ;----------------------------------------------------------
            ; WM_NOTIFY:TVN_KEYDOWN
            ;----------------------------------------------------------
            .ELSEIF eax == TVN_KEYDOWN
                mov ebx, lParam
                movzx eax, (TV_KEYDOWN ptr [ebx]).wVKey
                .IF eax == VK_F2
                    Invoke JSONEditItem, hWin
                
                .ELSEIF eax == VK_F3
                    ;Invoke SetFocus, hTxtSearchTextbox
                    Invoke SearchTextboxStartSearch, hWin
                    ;Invoke TreeViewGetSelectedItem, hTV
                    ;Invoke TreeViewSetSelectedItem, hTV, eax, TRUE
                
                .ELSEIF eax == VK_F4
                    Invoke IniToggleCaseSensitiveSearch
                    Invoke MenuOptionsUpdate, hWin
                    Invoke InvalidateRect, hTxtSearchTextbox, NULL, TRUE
                    ;Invoke SearchTextboxStartSearch, hWin
                
                .ELSEIF eax == VK_F
                    Invoke GetAsyncKeyState, VK_CONTROL
                    .IF eax != 0
                        ;PrintText 'TVN_KEYDOWN:CTRL+F'
                        Invoke SetFocus, hTxtSearchTextbox
                    .ENDIF

                .ELSEIF eax == VK_V
                    Invoke GetAsyncKeyState, VK_CONTROL
                    .IF eax != 0
                        Invoke PasteJSON, hWin
                    .ENDIF
                
                .ELSEIF eax == VK_DELETE
                    Invoke JSONDelItem, hWin
                
                .ELSEIF eax == VK_INSERT ; show add submenu only if on an item with children or on an object or array item
                    ;Invoke GetAsyncKeyState, VK_CONTROL
                    ;.IF eax != 0
            	        Invoke MenuRCAddShow, hWin
                    ;.ENDIF
                .ENDIF
            
            ;----------------------------------------------------------
            ; WM_NOTIFY:TVN_SELCHANGED
            ;----------------------------------------------------------
            .ELSEIF eax == TVN_SELCHANGED
                mov ebx, lParam
                mov eax, (NM_TREEVIEW PTR [ebx]).itemNew.hItem
                mov hItem, eax
                Invoke ToolBarUpdate, hWin, hItem
                Invoke MenusUpdate, hWin, hItem
                Invoke EditBoxUpdate, hWin, hItem
            
            ;----------------------------------------------------------
            ; WM_NOTIFY:TVN_BEGINLABELEDIT
            ;----------------------------------------------------------
            .ELSEIF eax == TVN_BEGINLABELEDIT
                ; Prevent label editing if root and/or an object
                mov ebx, lParam
                mov eax, (TV_DISPINFO PTR [ebx]).item.hItem
                .IF eax == hTVRoot
                    mov eax, TRUE
                    ret
                .ENDIF
                mov eax, (TV_DISPINFO PTR [ebx]).item.lParam
                .IF eax != NULL ; eax = hJSON
                    mov ebx, eax
                    mov eax, [ebx].cJSON.itemtype
                    .IF eax == cJSON_Object
                        mov eax, TRUE
                        ret
                    .ENDIF
                .ENDIF                
                
                ; Show Editbox instead? 
                Invoke EditLabelTextLength, lParam
                .IF sdword ptr eax > JSON_ITEM_MAX_TEXTLENGTH
                    .IF g_ShowEditBox == 1
                        Invoke SetFocus, hEdtText
                        mov eax, TRUE
                        ret
                    .ENDIF
                .ENDIF
                
                ; Subclass treeview edit control
                mov eax, hTV
                mov tve.hTreeview, eax
                mov ebx, lParam
                mov eax, (TV_DISPINFO PTR [ebx]).item.pszText
                mov tve.lpszItemTextOld, eax
                .IF eax != NULL
                    Invoke szCopy, eax, Addr szTVLabelEditOldText
                .ENDIF
                mov ebx, lParam
                mov eax, (TV_DISPINFO PTR [ebx]).item.hItem
                mov tve.hItem, eax
                Invoke TreeViewGetItemParam, hTV, eax
                mov tve.lParam, eax
                Invoke SendMessage, hTV, TVM_GETEDITCONTROL, 0, 0
                mov hTVEditControl, eax
                Invoke SetWindowLong, hTVEditControl, GWL_WNDPROC, Addr TreeViewEditSubclass
                mov tve.lpdwOldProc, eax
                Invoke SetWindowLong, hTVEditControl, GWL_USERDATA, Addr tve ;eax

                Invoke TVEditControlSelectInitial, hTVEditControl, tve.lpszItemTextOld, tve.lParam
                mov eax, FALSE
                ret
            
            ;----------------------------------------------------------
            ; WM_NOTIFY:TVN_ENDLABELEDIT
            ;----------------------------------------------------------
            .ELSEIF eax == TVN_ENDLABELEDIT
                mov ebx, lParam
                mov eax, (TV_DISPINFO PTR [ebx]).item.pszText
                .IF eax != NULL
                    Invoke szCopy, eax, Addr szTVLabelEditNewText
                    Invoke szCmp, Addr szTVLabelEditOldText, Addr szTVLabelEditNewText
                    .IF eax == 0
                        mov g_Edit, TRUE
                        mov ebx, lParam
                        mov eax, (TV_DISPINFO PTR [ebx]).item.hItem
                        mov hItem, eax
                        Invoke JSONUpdateItem, hTV, hItem, Addr szTVLabelEditNewText
                        Invoke ToolBarUpdate, hWin, hItem
                        Invoke MenusUpdate, hWin, hItem
                    .ENDIF
                    mov hTVEditControl, NULL
                    mov eax, TRUE
                    ret
                .ELSE
                    mov hTVEditControl, NULL
                    mov eax, TRUE
                    ret
                .ENDIF

            ;----------------------------------------------------------
            ; WM_NOTIFY:TVN_BEGINDRAG
            ;----------------------------------------------------------
            .ELSEIF eax == TVN_BEGINDRAG
                mov ebx, lParam
                Invoke SendMessage, hTV, TVM_CREATEDRAGIMAGE, 0, (NM_TREEVIEW ptr [ebx]).itemNew.hItem
                mov hDragImageList, eax
                Invoke ImageList_BeginDrag, hDragImageList, 0, 0, 0
                mov ebx, lParam
                Invoke ImageList_DragEnter, hTV, (NM_TREEVIEW ptr [ebx]).ptDrag.x, (NM_TREEVIEW ptr [ebx]).ptDrag.y
                Invoke SetCapture, hWin
                mov g_DragMode, TRUE
            .ENDIF
        
        .ELSE
        
            .IF eax == TBN_DROPDOWN
                Invoke ToolBarDropdownAddMenuShow, hWin
            .ELSE
                Invoke ToolBarTips, lParam
            .ENDIF
            
        .ENDIF
    
    .ELSEIF eax == WM_TIMER
        mov eax, wParam
        .IF eax == TIMER_ARRAY_UPDATE_ID
            .IF hTVArrayUpdate != 0
                Invoke KillTimer, hWin, TIMER_ARRAY_UPDATE_ID
                Invoke JSONUpdateArrayCount, hTVArrayUpdate
                mov hTVArrayUpdate, NULL
            .ENDIF
        .ENDIF
    
    .ELSEIF eax == WM_CLOSE
        .IF g_Edit == TRUE
    		Invoke MessageBox, hWin, Addr szJSONSaveChanges, Addr AppName, MB_ICONQUESTION+MB_YESNO
    		.IF eax == IDYES
    			Invoke JSONFileSave, hWin, FALSE
    		.ENDIF         
        .ENDIF
        Invoke DestroyWindow,hWin
        
    .ELSEIF eax == WM_DESTROY
        Invoke PostQuitMessage,NULL
        
    .ELSE
        Invoke DefWindowProc,hWin,uMsg,wParam,lParam
        ret
    .ENDIF
    xor    eax,eax
    ret
WndProc endp

;-------------------------------------------------------------------------------------
; CmdLineProcess - has user passed a file at the command line 
;-------------------------------------------------------------------------------------
CmdLineProcess PROC
    Invoke getcl_ex, 1, ADDR CmdLineFilename
    .IF eax == 1
        mov CmdLineProcessFileFlag, 1 ; filename specified, attempt to open it
    .ELSE
        mov CmdLineProcessFileFlag, 0 ; do nothing, continue as normal
    .ENDIF
    ret
CmdLineProcess endp

;------------------------------------------------------------------------------
; Opens a file from the command line or shell explorer call
;------------------------------------------------------------------------------
CmdLineOpenFile PROC hWin:DWORD
    Invoke InString, 1, Addr CmdLineFilename, Addr szBackslash
    .IF eax == 0
        Invoke GetCurrentDirectory, MAX_PATH, Addr CmdLineFullPathFilename
        Invoke szCatStr, Addr CmdLineFullPathFilename, Addr szBackslash
        Invoke szCatStr, Addr CmdLineFullPathFilename, Addr CmdLineFilename
    .ELSE
        Invoke szCopy, Addr CmdLineFilename, Addr CmdLineFullPathFilename
    .ENDIF
    
    Invoke exist, Addr CmdLineFullPathFilename
    .IF eax == 0 ; does not exist
        Invoke szCopy, Addr szCmdLineFilenameDoesNotExist, Addr szJSONErrorMessage
        Invoke szCatStr, Addr szJSONErrorMessage, Addr CmdLineFullPathFilename
        Invoke  StatusBarSetPanelText, 2, Addr szJSONErrorMessage    
        ret
    .ENDIF

    Invoke JSONFileOpen, hWin, Addr CmdLineFullPathFilename
    .IF eax == TRUE
        Invoke szCopy, Addr CmdLineFullPathFilename, Addr JsonOpenedFilename
        ; Start processing JSON file
        Invoke JSONDataProcess, hWin, Addr CmdLineFullPathFilename, NULL
    .ENDIF
    ret
CmdLineOpenFile endp

;-------------------------------------------------------------------------------------
; InitGUI - Initialize GUI stuff
;-------------------------------------------------------------------------------------
InitGUI PROC USES EBX hWin:DWORD
    LOCAL ncm:NONCLIENTMETRICS
    LOCAL lfnt:LOGFONT
    
    Invoke GetMenu, hWin
    mov hMainWindowMenu, eax
    
    Invoke CreateSolidBrush, 0FFFFFFh
    mov hWhiteBrush, eax

    Invoke CreateSolidBrush, 0F7F7F7h ; 240,240,240
    mov hMenuGreyBrush, eax

    Invoke CreateSolidBrush, 0EDEDF1h ; 241,237,237
    mov hStatusbarGreyBrush, eax
    

	mov ncm.cbSize, SIZEOF NONCLIENTMETRICS
	Invoke SystemParametersInfo, SPI_GETNONCLIENTMETRICS, SIZEOF NONCLIENTMETRICS, Addr ncm, 0
	Invoke CreateFontIndirect, Addr ncm.lfMessageFont
	mov hFontNormal, eax
	Invoke GetObject, hFontNormal, SIZEOF lfnt, Addr lfnt
	mov lfnt.lfWeight, FW_BOLD
	Invoke CreateFontIndirect, Addr lfnt
	mov hFontBold, eax
    Invoke GetObject, hFontNormal, SIZEOF lfnt, Addr lfnt
    mov lfnt.lfWeight, FW_NORMAL
    lea eax, szFontCourier
    lea ebx, lfnt.lfFaceName
    Invoke lstrcpyn, ebx, eax, 32d
    mov lfnt.lfHeight, -11d
    Invoke CreateFontIndirect, Addr lfnt
    mov hFontCourier, eax

    Invoke GetDlgItem, hWin, IDC_TV
    mov hTV, eax
    
    Invoke GetDlgItem, hWin, IDC_SB
    mov hSB, eax
    
    Invoke GetDlgItem, hWin, IDC_EdtText
    mov hEdtText, eax
    Invoke SendMessage, hEdtText, WM_SETFONT, hFontCourier, TRUE
    .IF g_ShowEditBox == 1
        Invoke EnableWindow, hEdtText, TRUE
        Invoke ShowWindow, hEdtText, SW_SHOW
    .ELSE
        Invoke EnableWindow, hEdtText, FALSE
        Invoke ShowWindow, hEdtText, SW_HIDE
    .ENDIF
    
    Invoke LoadIcon, hInstance, ICO_MAIN
    mov hICO_MAIN, eax
    
    Invoke LoadIcon, hInstance, ICO_JSON_STRING
    mov hICO_JSON_STRING, eax
    Invoke LoadIcon, hInstance, ICO_JSON_INTEGER
    mov hICO_JSON_INTEGER, eax
    Invoke LoadIcon, hInstance, ICO_JSON_FLOAT
    mov hICO_JSON_FLOAT, eax
    Invoke LoadIcon, hInstance, ICO_JSON_CUSTOM
    mov hICO_JSON_CUSTOM, eax
    Invoke LoadIcon, hInstance, ICO_JSON_TRUE
    mov hICO_JSON_TRUE, eax    
    Invoke LoadIcon, hInstance, ICO_JSON_FALSE
    mov hICO_JSON_FALSE, eax    
    Invoke LoadIcon, hInstance, ICO_JSON_ARRAY
    mov hICO_JSON_ARRAY, eax    
    Invoke LoadIcon, hInstance, ICO_JSON_OBJECT
    mov hICO_JSON_OBJECT, eax    
    Invoke LoadIcon, hInstance, ICO_JSON_NULL
    mov hICO_JSON_NULL, eax    
    Invoke LoadIcon, hInstance, ICO_JSON_INVALID
    mov hICO_JSON_INVALID, eax    
    Invoke LoadIcon, hInstance, ICO_JSON_LOGICAL
    mov hICO_JSON_LOGICAL, eax
    
    Invoke ImageList_Create, 16, 16, ILC_COLOR32, 16, 16
    mov hIL, eax
    
    Invoke ImageList_AddIcon, hIL, hICO_MAIN
    Invoke ImageList_AddIcon, hIL, hICO_JSON_STRING
    Invoke ImageList_AddIcon, hIL, hICO_JSON_INTEGER
    Invoke ImageList_AddIcon, hIL, hICO_JSON_FLOAT
    Invoke ImageList_AddIcon, hIL, hICO_JSON_CUSTOM
    Invoke ImageList_AddIcon, hIL, hICO_JSON_TRUE
    Invoke ImageList_AddIcon, hIL, hICO_JSON_FALSE
    Invoke ImageList_AddIcon, hIL, hICO_JSON_ARRAY
    Invoke ImageList_AddIcon, hIL, hICO_JSON_OBJECT
    Invoke ImageList_AddIcon, hIL, hICO_JSON_NULL
    Invoke ImageList_AddIcon, hIL, hICO_JSON_INVALID
    Invoke ImageList_AddIcon, hIL, hICO_JSON_LOGICAL
    
    ; Init other controls
    Invoke IniGetSettingExpandAllOnLoad
    Invoke IniGetSettingCaseSensitiveSearch    
    
    Invoke MenusInit, hWin
    Invoke ToolbarInit, hWin, 16, 16
    Invoke TreeViewInit, hWin
    Invoke StatusBarInit, hWin
    Invoke SearchTextboxInit, hWin
    
    Invoke IniMRULoadListToMenu, hWin

    
    
    ret

InitGUI ENDP

;-------------------------------------------------------------------------------------
; ResetGUI - reset GUI back to normal - like when closing a file etc
;-------------------------------------------------------------------------------------
ResetGUI PROC hWin:DWORD
    
    Invoke TreeViewDeleteAll, hTV
    Invoke SetWindowTitle, hWin, NULL
    Invoke StatusBarSetPanelText, 2, Addr szSpace

    mov g_nTVIndex, 0
    mov g_Edit, FALSE
    
    .IF g_ShowEditBox == 1
    Invoke SetWindowText, hEdtText, Addr szNullNull
    .ENDIF
    
    Invoke MenusReset, hWin
    Invoke ToolbarsReset, hWin

    .IF hJSONTreeRoot != NULL
        mov hJSONTreeRoot, NULL
    .ENDIF

    .IF hJSON_Object_Root != NULL
        Invoke cJSON_Delete, hJSON_Object_Root
        mov hJSON_Object_Root, NULL
    .ENDIF

    ret
ResetGUI ENDP


;-------------------------------------------------------------------------------------
; TreeViewInit - Initialize JSON Treeview
;-------------------------------------------------------------------------------------
TreeViewInit PROC hWin:DWORD
    Invoke SendMessage, hTV, TVM_SETEXTENDEDSTYLE, TVS_EX_DOUBLEBUFFER, TVS_EX_DOUBLEBUFFER
    Invoke TreeViewLinkImageList, hTV, hIL, TVSIL_NORMAL
    Invoke TreeViewSubClassProc, hTV, Addr TreeViewSubclass
    mov pOldTVProc, eax
    Invoke TreeViewSubClassData, hTV, pOldTVProc
    ret
TreeViewInit ENDP

;-------------------------------------------------------------------------------------
; Subclass to capture and handle enter key pressed in labels
;-------------------------------------------------------------------------------------
TreeViewSubclass PROC hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	mov eax, uMsg
	.IF eax == WM_GETDLGCODE
	    mov eax, DLGC_WANTARROWS or DLGC_WANTTAB or DLGC_WANTALLKEYS ; DLGC_WANTARROWS or 
	    ret
	
	.ELSEIF eax == WM_COMMAND
        mov eax, lParam
		.IF eax == hTVEditControl
		    mov eax, wParam
		    shr eax, 16		
    		.IF eax == EN_CHANGE ; Treeview Edit control is subclassed but sents WM_COMMAND to parent
    		    Invoke TreeViewEditValidate, hWin, lParam
    		    Invoke UpdateWindow, hTVEditControl
    		.ENDIF
        .ENDIF
	
    .ELSEIF eax == WM_CHAR
        mov eax, wParam
        .IF eax == VK_TAB || eax == VK_ADD || eax == VK_SUBTRACT ;|| eax == VK_LEFT || eax == VK_RIGHT ;|| eax == VK_INSERT
            xor eax, eax
            ret
            
        .ELSE
	        Invoke GetWindowLong, hWin, GWL_USERDATA
	        Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
	        ret
        .ENDIF
    
    .ELSEIF eax == WM_KEYDOWN
        mov eax, wParam
        .IF eax == VK_TAB
            Invoke SetFocus, hTxtSearchTextbox
            xor eax, eax
            ret
        
;        .ELSEIF eax == VK_INSERT
;            ;PrintText 'WM_KEYDOWN:VK_INSERT'
;	        Invoke GetWindowLong, hWin, GWL_USERDATA
;	        Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
;	        ret
;	        
;        .ELSEIF eax == VK_LEFT
;            PrintText 'WM_KEYDOWN:VK_LEFT'
;	        Invoke GetWindowLong, hWin, GWL_USERDATA
;	        Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
;	        ret
;	        
;        .ELSEIF eax == VK_RIGHT
;            PrintText 'WM_KEYDOWN:VK_RIGHT'
;	        Invoke GetWindowLong, hWin, GWL_USERDATA
;	        Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
;	        ret
            
;        .ELSEIF eax == VK_F
;            Invoke GetAsyncKeyState, VK_CONTROL
;            .IF eax != 0
;                PrintText 'WM_KEYDOWN:CTRL+F'
;                Invoke SetFocus, hTxtSearchTextbox
;                xor eax, eax
;                ret                
;            .ELSE
;	            Invoke GetWindowLong, hWin, GWL_USERDATA
;	            Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
;	            ret
;            .ENDIF
        .ELSE
	        Invoke GetWindowLong, hWin, GWL_USERDATA
	        Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
	        ret
        .ENDIF
    
	.ELSE
	    invoke GetWindowLong, hWin, GWL_USERDATA
	    invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
	    ret
	.ENDIF
	
	Invoke GetWindowLong, hWin, GWL_USERDATA
	Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam		
    ret
TreeViewSubclass ENDP

;-------------------------------------------------------------------------------------
; Subclass to capture and handle enter key pressed in labels
;-------------------------------------------------------------------------------------
TreeViewEditSubclass PROC hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
    
	mov eax, uMsg
	.IF eax == WM_GETDLGCODE
	    mov eax, DLGC_WANTALLKEYS
	    ret
    
;    .ELSEIF eax == WM_CHAR
;        PrintText 'TreeViewEditSubclass:WM_CHAR'
;        mov eax, wParam
;        .IF eax == VK_RETURN
;            PrintText 'TreeViewEditSubclass:WM_CHAR:VK_RETURN'
;            xor eax, eax
;            ret
;        .ENDIF
    
;    .ELSEIF eax == WM_KEYDOWN
;        PrintText 'TreeViewEditSubclass:WM_KEYDOWN'
;        mov eax, wParam
;        .IF eax == VK_RETURN
;            PrintText 'TreeViewEditSubclass:WM_KEYDOWN:VK_RETURN'
;            xor eax, eax
;            ret
;        .ENDIF
    
	.ELSE
	    Invoke GetWindowLong, hWin, GWL_USERDATA
	    mov eax, [eax].TVEDIT.lpdwOldProc
	    Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
	    ret
	.ENDIF

	Invoke GetWindowLong, hWin, GWL_USERDATA
	mov eax, [eax].TVEDIT.lpdwOldProc
	Invoke CallWindowProc, eax, hWin, uMsg, wParam, lParam
    ret
TreeViewEditSubclass ENDP

;-------------------------------------------------------------------------------------
; TreeViewEditValidate - validate text in treeview edit control
;-------------------------------------------------------------------------------------
TreeViewEditValidate PROC USES EBX hWin:DWORD, hEdit:DWORD
    LOCAL lpTveditStruct:DWORD
    LOCAL hTreeview:DWORD
    LOCAL hItem:DWORD
    LOCAL hJSON:DWORD
    LOCAL jsontype:DWORD
    LOCAL lpszItemTextOld:DWORD
    LOCAL dwLengthItemTextName:DWORD
    LOCAL dwLengthItemTextValue:DWORD
    LOCAL dwArrayCount:DWORD
    
    ;PrintText 'TreeViewEditValidate'
    
    Invoke GetWindowLong, hEdit, GWL_USERDATA
    mov lpTveditStruct, eax
    mov ebx, eax
    
    mov eax, [ebx].TVEDIT.lParam
    mov hJSON, eax
    mov eax, [ebx].TVEDIT.hItem
    mov hItem, eax
    mov eax, [ebx].TVEDIT.hTreeview
    mov hTreeview, eax
    mov eax, [ebx].TVEDIT.lpszItemTextOld
    mov lpszItemTextOld, eax
    mov ebx, hJSON
    mov eax, [ebx].cJSON.itemtype
    mov jsontype, eax
    
    Invoke GetWindowText, hEdit, Addr szItemTextString, SIZEOF szItemTextString
    .IF eax != 0
        ;PrintText 'SeperateNameValue'
        Invoke SeperateNameValue, Addr szItemTextString, Addr szItemTextName, Addr szItemTextValue
        Invoke lstrlen, Addr szItemTextName
        mov dwLengthItemTextName, eax
        Invoke lstrlen, Addr szItemTextValue
        mov dwLengthItemTextValue, eax
        ;PrintDec dwLengthItemTextName
        ;PrintDec dwLengthItemTextValue
        
        mov eax, jsontype
        .IF eax == cJSON_False
            .IF dwLengthItemTextName == 0
                Invoke lstrcpy, Addr szItemText, Addr szDefaultFalse
                Invoke SetWindowText, hEdit, Addr szItemText
                Invoke SendMessage, hEdit, EM_SETSEL, 0, 9
            .ELSE        
                .IF dwLengthItemTextValue == 0
                    Invoke lstrcpy, Addr szItemText, Addr szItemTextName
                    Invoke lstrcat, Addr szItemText, CTEXT(": false")
                    Invoke SetWindowText, hEdit, Addr szItemText
                    Invoke SendMessage, hEdit, EM_SETSEL, 0, dwLengthItemTextName
                .ENDIF
            .ENDIF
            
        .ELSEIF eax == cJSON_True
            .IF dwLengthItemTextName == 0
                Invoke lstrcpy, Addr szItemText, Addr szDefaultTrue
                Invoke SetWindowText, hEdit, Addr szItemText
                Invoke SendMessage, hEdit, EM_SETSEL, 0, 8
            .ELSE        
                .IF dwLengthItemTextValue == 0
                    Invoke lstrcpy, Addr szItemText, Addr szItemTextName
                    Invoke lstrcat, Addr szItemText, CTEXT(": true")
                    Invoke SetWindowText, hEdit, Addr szItemText
                    Invoke SendMessage, hEdit, EM_SETSEL, 0, dwLengthItemTextName
                .ENDIF
            .ENDIF
            
        .ELSEIF eax == cJSON_NULL
            .IF dwLengthItemTextName == 0
                Invoke lstrcpy, Addr szItemText, Addr szDefaultNull
                Invoke SetWindowText, hEdit, Addr szItemText
                Invoke SendMessage, hEdit, EM_SETSEL, 0, 4
            .ELSE
                .IF dwLengthItemTextValue == 0
                    Invoke lstrcpy, Addr szItemText, Addr szItemTextName
                    Invoke lstrcat, Addr szItemText, CTEXT(": null")
                    Invoke SetWindowText, hEdit, Addr szItemText
                    Invoke SendMessage, hEdit, EM_SETSEL, 0, dwLengthItemTextName
                .ENDIF
            .ENDIF
            
        .ELSEIF eax == cJSON_Number
            .IF dwLengthItemTextName == 0
                ;PrintDec dwLengthItemTextValue
                ;PrintString szItemTextValue
                Invoke lstrcpy, Addr szItemText, Addr szDefaultNumber
                .IF dwLengthItemTextValue == 0
                    Invoke lstrcat, Addr szItemText, CTEXT("0")
                .ELSE
                    Invoke lstrcat, Addr szItemText, Addr szItemTextValue
                .ENDIF
                ;PrintString szItemText
                Invoke SetWindowText, hEdit, Addr szItemText
                Invoke SendMessage, hEdit, EM_SETSEL, 8, -1
            .ELSE
               .IF dwLengthItemTextValue == 0
                    ;PrintText 'dwLengthItemTextValue == 0'
                    Invoke lstrcpy, Addr szItemText, Addr szItemTextName
                    Invoke lstrcat, Addr szItemText, CTEXT(": 0")
                    Invoke SetWindowText, hEdit, Addr szItemText
                    mov eax, dwLengthItemTextName
                    add eax, 2
                    Invoke SendMessage, hEdit, EM_SETSEL, eax, -1
                .ENDIF
            .ENDIF
            
        .ELSEIF eax == cJSON_String
            .IF dwLengthItemTextName == 0
                Invoke lstrcpy, Addr szItemText, Addr szDefaultString
                .IF dwLengthItemTextValue == 0
                .ELSE
                    Invoke lstrcat, Addr szItemText, Addr szItemTextValue
                .ENDIF
                Invoke SetWindowText, hEdit, Addr szItemText
                Invoke SendMessage, hEdit, EM_SETSEL, 8, -1
            .ELSE          
                .IF dwLengthItemTextValue == 0
                    Invoke lstrcpy, Addr szItemText, Addr szItemTextName
                    Invoke lstrcat, Addr szItemText, CTEXT(": ")
                    Invoke SetWindowText, hEdit, Addr szItemText
                    mov eax, dwLengthItemTextName
                    add eax, 2
                    Invoke SendMessage, hEdit, EM_SETSEL, eax, -1
                .ENDIF
            .ENDIF
            
        .ELSEIF eax == cJSON_Array
;            Invoke SeperateArrayName, Addr szItemTextString, Addr szItemTextName
;            PrintString szItemTextName
;            Invoke lstrlen, Addr szItemTextName
;            mov dwLengthItemTextName, eax
;            PrintDec dwLengthItemTextName
;            .IF dwLengthItemTextName == 0
;                Invoke lstrcpy, Addr szItemText, Addr szDefaultArray
;            .ELSE
;                Invoke lstrcpy, Addr szItemText, Addr szItemTextName
;            .ENDIF
;            Invoke cJSON_GetArraySize, hJSON
;            mov dwArrayCount, eax
;            Invoke dwtoa, dwArrayCount, Addr szItemIntValue
;            Invoke szCatStr, Addr szItemText, Addr szLeftSquareBracket
;            Invoke szCatStr, Addr szItemText, Addr szItemIntValue
;            Invoke szCatStr, Addr szItemText, Addr szRightSquareBracket
;            Invoke SetWindowText, hEdit, Addr szItemText
;            .IF dwLengthItemTextName == 0
;                Invoke SendMessage, hEdit, EM_SETSEL, 0, 5
;            .ELSE
;                mov eax, dwLengthItemTextName
;                Invoke SendMessage, hEdit, EM_SETSEL, eax, eax
;            .ENDIF
        
        .ELSEIF eax == cJSON_Object
            Invoke SetWindowText, hEdit, Addr szDefaultObject
            Invoke SendMessage, hEdit, EM_SETSEL, 0, -1
            
        .ENDIF
        
    .ELSE ; no text, so set default
        mov eax, jsontype
        .IF eax == cJSON_False
            Invoke SetWindowText, hEdit, Addr szDefaultFalse
            Invoke SendMessage, hEdit, EM_SETSEL, 0, 9
            
        .ELSEIF eax == cJSON_True
            Invoke SetWindowText, hEdit, Addr szDefaultTrue
            Invoke SendMessage, hEdit, EM_SETSEL, 0, 8
            
        .ELSEIF eax == cJSON_NULL
            Invoke SetWindowText, hEdit, Addr szDefaultNull
            Invoke SendMessage, hEdit, EM_SETSEL, 0, 4
            
        .ELSEIF eax == cJSON_Number
            Invoke SetWindowText, hEdit, Addr szDefaultNumber
            Invoke SendMessage, hEdit, EM_SETSEL, 8, -1
            
        .ELSEIF eax == cJSON_String
            Invoke SetWindowText, hEdit, Addr szDefaultString
            Invoke SendMessage, hEdit, EM_SETSEL, 8, -1
            
        .ELSEIF eax == cJSON_Array
            Invoke SetWindowText, hEdit, Addr szDefaultArray
            Invoke SendMessage, hEdit, EM_SETSEL, 0, -1
        
        .ELSEIF eax == cJSON_Object
            Invoke SetWindowText, hEdit, Addr szDefaultObject
            Invoke SendMessage, hEdit, EM_SETSEL, 0, -1
            
        .ENDIF
    .ENDIF

    mov eax, TRUE
    ret
TreeViewEditValidate ENDP

;-------------------------------------------------------------------------------------
; TVEditControlSelectInitial - Selects the value (or name) of the text control (name: value)
;-------------------------------------------------------------------------------------
TVEditControlSelectInitial PROC USES EBX hEdit:DWORD, lpszEditText:DWORD, hJSON:DWORD
    LOCAL dwLenEditText:DWORD
    LOCAL dwCurPos:DWORD
    LOCAL dwSepPos:DWORD
    LOCAL jsontype:DWORD
    
    .IF lpszEditText == 0
        xor eax, eax
        ret
    .ENDIF

    Invoke lstrlen, lpszEditText
    .IF eax == 0
        xor eax, eax
        ret
    .ENDIF
    mov dwLenEditText, eax

    mov ebx, hJSON
    mov eax, [ebx].cJSON.itemtype
    mov jsontype, eax    
    
    mov dwSepPos, 0
    mov eax, 0
    mov dwCurPos, 0

    .WHILE eax < dwLenEditText
        mov ebx, lpszEditText
        add ebx, dwCurPos
        movzx eax, byte ptr [ebx]
        .IF al == ':'
            inc dwCurPos
            mov eax, jsontype
            .IF eax == cJSON_False || eax == cJSON_True || eax == cJSON_NULL
            .ELSE
                movzx eax, byte ptr [ebx+1]
                .IF al == ' '
                    inc dwCurPos
                .ENDIF
            .ENDIF
            mov eax, dwCurPos
            mov dwSepPos, eax
            .BREAK
        .ELSEIF al == '['
            mov eax, jsontype
            .IF eax == cJSON_Array
                mov eax, dwCurPos
                mov dwSepPos, eax
                .BREAK
            .ENDIF
        .ENDIF
        
        inc dwCurPos
        mov eax, dwCurPos
    .ENDW
    
    .IF dwSepPos == 0 ; select all
        Invoke SendMessage, hEdit, EM_SETSEL, 0, -1
    .ELSE
        mov eax, jsontype
        .IF eax == cJSON_False
            dec dwSepPos
            Invoke SendMessage, hEdit, EM_SETSEL, 0, dwSepPos
            
        .ELSEIF eax == cJSON_True
            dec dwSepPos
            Invoke SendMessage, hEdit, EM_SETSEL, 0, dwSepPos
            
        .ELSEIF eax == cJSON_NULL
            dec dwSepPos
            Invoke SendMessage, hEdit, EM_SETSEL, 0, dwSepPos
            
        .ELSEIF eax == cJSON_Number
            Invoke SendMessage, hEdit, EM_SETSEL, dwSepPos, -1
            
        .ELSEIF eax == cJSON_String
            Invoke SendMessage, hEdit, EM_SETSEL, dwSepPos, -1
            
        .ELSEIF eax == cJSON_Array
            Invoke SendMessage, hEdit, EM_SETSEL, 0, -1 ;dwSepPos
        
        .ELSEIF eax == cJSON_Object
            Invoke SendMessage, hEdit, EM_SETSEL, 0, -1
        
        .ELSE
            Invoke SendMessage, hEdit, EM_SETSEL, 0, -1
        .ENDIF
        
    .ENDIF
    
    mov eax, TRUE
    ret
TVEditControlSelectInitial ENDP


;-------------------------------------------------------------------------------------
; JSONFileOpenBrowse - Browse for JSON file to open
;-------------------------------------------------------------------------------------
JSONFileOpenBrowse PROC hWin:DWORD
    
    ; Browse for JSON file to open
    Invoke RtlZeroMemory, Addr BrowseFile, SIZEOF BrowseFile
    push hWin
    pop BrowseFile.hwndOwner
    lea eax, JsonOpenFileFilter
    mov BrowseFile.lpstrFilter, eax
    lea eax, JsonOpenedFilename
    mov BrowseFile.lpstrFile, eax
    lea eax, JsonOpenFileFileTitle
    mov BrowseFile.lpstrTitle, eax
    mov BrowseFile.nMaxFile, SIZEOF JsonOpenedFilename
    mov BrowseFile.lpstrDefExt, 0
    mov BrowseFile.Flags, OFN_EXPLORER
    mov BrowseFile.lStructSize, SIZEOF BrowseFile
    Invoke GetOpenFileName, Addr BrowseFile

    ; If user selected an JSON and didnt cancel browse operation...
    .IF eax !=0
        mov eax, TRUE
    .ELSE
        mov eax, FALSE
    .ENDIF
    ret

JSONFileOpenBrowse ENDP

;-------------------------------------------------------------------------------------
; JSONFileOpen - Open JSON file to process
;-------------------------------------------------------------------------------------
JSONFileOpen PROC hWin:DWORD, lpszJSONFile:DWORD
    
    Invoke ResetGUI, hWin
    ;.IF hJSONFile != NULL
    ;    Invoke JSONFileClose, hWin
    ;.ENDIF
    
    ; Tell user we are loading file
    Invoke szCopy, Addr szJSONLoadingFile, Addr szJSONErrorMessage
    Invoke szCatStr, Addr szJSONErrorMessage, lpszJSONFile
    Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
    ;Invoke StatusBarSetPanelText, 2, lpszJSONFile

    Invoke CreateFile, lpszJSONFile, GENERIC_READ + GENERIC_WRITE, FILE_SHARE_READ + FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    .IF eax == INVALID_HANDLE_VALUE
        ; Tell user via statusbar that JSON file did not load
        Invoke szCopy, Addr szJSONErrorLoadingFile, Addr szJSONErrorMessage
        Invoke szCatStr, Addr szJSONErrorMessage, lpszJSONFile
        Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
        mov eax, FALSE
        ret
    .ENDIF
    mov hJSONFile, eax

    Invoke CreateFileMapping, hJSONFile, NULL, PAGE_READWRITE, 0, 0, NULL ; Create memory mapped file
    .IF eax == NULL
        ; Tell user via statusbar that JSON file did not map
        Invoke szCopy, Addr szJSONErrorMappingFile, Addr szJSONErrorMessage
        Invoke szCatStr, Addr szJSONErrorMessage, lpszJSONFile
        Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
        Invoke CloseHandle, hJSONFile
        mov eax, FALSE
        ret
    .ENDIF
    mov JSONMemMapHandle, eax

    Invoke MapViewOfFileEx, JSONMemMapHandle, FILE_MAP_ALL_ACCESS, 0, 0, 0, NULL
    .IF eax == NULL
        ; Tell user via statusbar that JSON file did not map
        Invoke szCopy, Addr szJSONErrorMappingFile, Addr szJSONErrorMessage
        Invoke szCatStr, Addr szJSONErrorMessage, lpszJSONFile
        Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
        Invoke CloseHandle, JSONMemMapHandle
        Invoke CloseHandle, hJSONFile
        mov eax, FALSE
        ret
    .ENDIF
    mov JSONMemMapPtr, eax  
    
    Invoke GetFileSize, hJSONFile, NULL
    mov dwFileSize, eax
    
    Invoke IniMRUEntrySaveFilename, hWin, lpszJSONFile
    Invoke IniMRUReloadListToMenu, hWin
    
    mov eax, TRUE
    
    ret

JSONFileOpen ENDP

;-------------------------------------------------------------------------------------
; JSONFileClose - Closes JSON file and deletes any treeview data and json data
;-------------------------------------------------------------------------------------
JSONFileClose PROC hWin:DWORD
    .IF g_Edit == TRUE
		Invoke MessageBox, hWin, Addr szJSONSaveChanges, Addr AppName, MB_ICONQUESTION+MB_YESNO
		.IF eax == IDYES
			Invoke JSONFileSave, hWin, FALSE
		.ENDIF         
    .ENDIF

    .IF JSONMemMapPtr != NULL
        Invoke UnmapViewOfFile, JSONMemMapPtr
        mov JSONMemMapPtr, NULL
    .ENDIF
    .IF JSONMemMapHandle != NULL
        Invoke CloseHandle, JSONMemMapHandle
        mov JSONMemMapHandle, NULL
    .ENDIF
    .IF hJSONFile != NULL
        Invoke CloseHandle, hJSONFile
        mov hJSONFile, NULL
    .ENDIF
    
    .IF hJSONTreeRoot != NULL
        mov hJSONTreeRoot, NULL
    .ENDIF

    .IF hJSON_Object_Root != NULL
        Invoke cJSON_Delete, hJSON_Object_Root
        mov hJSON_Object_Root, NULL
    .ENDIF

    Invoke RtlZeroMemory, Addr JsonOpenedFilename, SIZEOF JsonOpenedFilename

    Invoke ResetGUI, hWin
    Invoke SetFocus, hTV

    ret
JSONFileClose ENDP

;-------------------------------------------------------------------------------------
; CloseJSONFileHandles
;-------------------------------------------------------------------------------------
CloseJSONFileHandles PROC hWin:DWORD
    
    .IF JSONMemMapPtr != NULL
        Invoke UnmapViewOfFile, JSONMemMapPtr
        mov JSONMemMapPtr, NULL
    .ENDIF
    .IF JSONMemMapHandle != NULL
        Invoke CloseHandle, JSONMemMapHandle
        mov JSONMemMapHandle, NULL
    .ENDIF
    .IF hJSONFile != NULL
        Invoke CloseHandle, hJSONFile
        mov hJSONFile, NULL
    .ENDIF    
    ret

CloseJSONFileHandles ENDP

;-------------------------------------------------------------------------------------
; JSONFileSave - Saves json file
;-------------------------------------------------------------------------------------
JSONFileSave PROC hWin:DWORD, bSaveAs:DWORD
    LOCAL bShowSaveAsDialog:DWORD
    
    mov bShowSaveAsDialog, FALSE
    
    mov eax, bSaveAs
    .IF bSaveAs == TRUE
        mov bShowSaveAsDialog, TRUE
    .ELSE
        .IF JsonOpenedFilename == 0
            mov bShowSaveAsDialog, TRUE
        .ELSE
            Invoke szLen, Addr JsonOpenedFilename
            .IF eax == 0
                mov bShowSaveAsDialog, TRUE
            .ENDIF
        .ENDIF
    .ENDIF
    
    .IF bShowSaveAsDialog == TRUE
        
        Invoke RtlZeroMemory, Addr SaveFile, SIZEOF SaveFile
        push hWin
        pop SaveFile.hwndOwner
        lea eax, JsonSaveFileFilter
        mov SaveFile.lpstrFilter, eax
        lea eax, JsonSavedFilename
        mov SaveFile.lpstrFile, eax
        lea eax, JsonSaveFileFileTitle
        mov SaveFile.lpstrTitle, eax
        mov SaveFile.nMaxFile, SIZEOF JsonSavedFilename
        lea eax, JsonSaveDefExt
        mov SaveFile.lpstrDefExt, eax
        mov SaveFile.nFilterIndex, 1 ; json
        mov SaveFile.Flags, OFN_EXPLORER
        mov SaveFile.lStructSize, SIZEOF SaveFile
        Invoke GetSaveFileName, Addr SaveFile

    .ELSE
        Invoke szCopy, Addr JsonOpenedFilename, Addr JsonSavedFilename
        mov eax, TRUE
    .ENDIF

    .IF eax !=0
        ; save actual file contents
        Invoke SaveJSONBranchToFile, hWin, Addr JsonSavedFilename, 0
        .IF eax == TRUE
            Invoke szCopy, Addr JsonSavedFilename, Addr JsonOpenedFilename
            Invoke SetWindowTitle, hWin, Addr JsonSavedFilename

            Invoke JustFnameExt, Addr JsonSavedFilename, Addr szJustFilename
            Invoke TreeViewSetItemText, hTV, hTVRoot, Addr szJustFilename
            
            Invoke szCopy, Addr szJSONSavedFile, Addr szJSONErrorMessage
            Invoke szCatStr, Addr szJSONErrorMessage, Addr szJustFilename
            Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage    
            
            mov g_Edit, FALSE
            Invoke MenuSaveEnable, hWin, FALSE
            Invoke ToolbarButtonSaveEnable, hWin, FALSE
            
            Invoke IniMRUEntrySaveFilename, hWin, Addr JsonSavedFilename
            Invoke IniMRUReloadListToMenu, hWin
            mov eax, TRUE
        .ELSE
            Invoke szCopy, Addr szJSONSaveFileFailed, Addr szJSONErrorMessage
            Invoke szCatStr, Addr szJSONErrorMessage, Addr JsonSavedFilename
            Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
            mov eax, FALSE
        .ENDIF
    .ENDIF    
    ret
JSONFileSave ENDP

;-------------------------------------------------------------------------------------
; ProcessJSONFile - Process JSON file and load data into treeview
;-------------------------------------------------------------------------------------
JSONDataProcess PROC USES EBX hWin:DWORD, lpszJSONFile:DWORD, lpdwJSONData:DWORD
    ;LOCAL nTVIndex:DWORD
    LOCAL next:DWORD
    LOCAL prev:DWORD
    LOCAL child:DWORD
    LOCAL jsontype:DWORD
    LOCAL itemcount:DWORD
    LOCAL currentitem:DWORD
    LOCAL hJSON:DWORD
    LOCAL level:DWORD
    LOCAL dwArrayCount:DWORD
    
    ; JSONMemMapPtr is pointer to file in memory, mapped previously in JSONFileOpen
    ; Parse this with cJSON library cJSON_Parse function, returns root handle to JSON stuff
    
    .IF hJSON_Object_Root != NULL
        Invoke cJSON_Delete, hJSON_Object_Root
        mov hJSON_Object_Root, NULL
    .ENDIF
    
    .IF lpdwJSONData == NULL
        Invoke cJSON_Parse, JSONMemMapPtr
        .IF eax == NULL
            ;PrintText 'cJSON_Parse returned NULL'
            ;Invoke cJSON_GetErrorPtr
            ;mov DbgVar, eax
            ;PrintStringByAddr DbgVar
        .ENDIF
    .ELSE
        Invoke cJSON_Parse, lpdwJSONData
    .ENDIF
    mov hJSON_Object_Root, eax

    .IF hJSON_Object_Root == NULL && lpdwJSONData == NULL
        Invoke JSONFileClose, hWin
        ; If empty then tell user some error about reading file
        Invoke szCopy, Addr szJSONErrorReadingFile, Addr szJSONErrorMessage
        Invoke szCatStr, Addr szJSONErrorMessage, lpszJSONFile
        Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
        mov eax, FALSE
        ret        
    .ELSEIF hJSON_Object_Root == NULL && lpdwJSONData != NULL
        Invoke JSONFileClose, hWin
         ; If empty then tell user some error about reading clipboard data
        Invoke szCopy, Addr szJSONErrorClipData, Addr szJSONErrorMessage
        Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
        mov eax, FALSE
        ret  
    .ENDIF

    ; Just a check to make sure JSON has some stuff to process
;    Invoke cJSON_GetArraySize, hJSON_Object_Root
;    .IF eax == 0
;        .IF lpdwJSONData == NULL
;            Invoke szCopy, Addr szJSONErrorEmptyFile, Addr szJSONErrorMessage
;            Invoke szCatStr, Addr szJSONErrorMessage, lpszJSONFile
;        .ELSE
;            Invoke szCopy, Addr szJSONErrorEmptyClipData, Addr szJSONErrorMessage
;        .ENDIF
;        Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage    
;        ret
;    .ENDIF

    ; Treeview Root is created, save handle to it, specifically we will need hTVNode later for when inserting children to treeview
    ;mov nTVIndex, 0
    .IF lpdwJSONData == NULL
        Invoke JustFnameExt, lpszJSONFile, Addr szJustFilename
        Invoke TreeViewItemInsert, hTV, NULL, Addr szJustFilename, g_nTVIndex, TVI_ROOT, IL_ICO_MAIN, IL_ICO_MAIN, hJSON_Object_Root
    .ELSE
        Invoke TreeViewItemInsert, hTV, NULL, Addr szJSONClipboard, g_nTVIndex, TVI_ROOT, IL_ICO_MAIN, IL_ICO_MAIN, hJSON_Object_Root
    .ENDIF
    mov hTVRoot, eax
    mov hTVNode, eax
    mov hTVCurrentNode, eax
    inc g_nTVIndex
    
    
    ; Each time we insert a treeview item we need to increment our nTVIndex counter



    mov level, -1000d ; hack to force our while loop below, only used for possibly debugging/tracking indented levels (children)
    mov eax, hJSON_Object_Root 
    mov hJSON, eax ; use hJSON as variable to process in our loop
    
    ;PrintDec hJSON_Object_Root
    ;mov ebx, hJSON
    ;mov eax, [ebx].cJSON.child
    ;mov ebx, eax
    ;mov eax, [ebx].cJSON.child    
    mov hJSON, eax
    
    ;PrintText 'hJSON_Object_Root child'
    ;PrintDec eax
    ;mov ebx, eax
    ;mov eax, [ebx].cJSON.child
    ;PrintText 'child child'
    ;PrintDec eax
    
    
    IFDEF EXPERIMENTAL_ARRAYNAME_STACK
    ; create virtual stack to hold array iterator names
    Invoke VirtualStackCreate, VIRTUALSTACK_SIZE_TINY, VIRTUALSTACK_OPTION_UNIQUE
    mov hVirtualStack, eax
    mov hArray, NULL
    mov hCurrentArray, NULL
    ENDIF

    Invoke SendMessage, hTV, WM_SETREDRAW, FALSE, 0

    .WHILE level != 0

        .IF level == -1000d
            mov level, 1 ; set our level to 1, useful for debugging and checking we havnt push/popd too much
            push hJSON ; push hJSON, then hTVNode. NOTE: we must pop these in reverse order to retrieve them when we fall back up the tree
            push hTVNode
            IFDEF EXPERIMENTAL_ARRAYNAME_STACK
            Invoke VirtualStackPush, hVirtualStack, hArray
            ENDIF
            ;Push hArray
        .ENDIF
        
        mov ebx, hJSON ; get our cJSON object (first time in loop is the hJSON_Object_Root, subsequent times it will be the next or child item
        
        ; Fetch some values for our cJSON object
        mov eax, [ebx].cJSON.itemtype
        mov jsontype, eax
        mov eax, [ebx].cJSON.child
        mov child, eax
        mov eax, [ebx].cJSON.next
        mov next, eax
        mov eax, [ebx].cJSON.prev
        mov prev, eax
        mov eax, [ebx].cJSON.itemstring
        mov lpszItemString, eax
        mov eax, [ebx].cJSON.valuestring
        mov lpszItemStringValue, eax  
        mov eax, [ebx].cJSON.valueint
        mov dwItemIntValue, eax          
        
        ; Check strings are present and > 0 in length (to stop crashes when copying etc)

        .IF lpszItemString == 0
            mov LenItemString, 0
        .ELSE
            Invoke szLen, lpszItemString
            mov LenItemString, eax
        .ENDIF
        
        .IF lpszItemStringValue == 0
            mov LenItemStringValue, 0
        .ELSE
            Invoke szLen, lpszItemStringValue
            mov LenItemStringValue, eax
        .ENDIF        
        
        IFDEF DEBUG32
            ;PrintDec jsontype
        ENDIF
        
        
        ; Determine the type of cJSON object, so we can decide what to do with it
        mov eax, jsontype
        .IF eax == cJSON_Object && g_nTVIndex != 1
            ;PrintText 'cJSON_Object'
            IFDEF EXPERIMENTAL_ARRAYNAME_STACK
            .IF hArray != NULL

                Invoke JSONStackItemArrayIteratorName, hArray, Addr szItemTextArrayName
                Invoke JSONStackItemIncCount, hArray
                
                .IF LenItemString == 0
                    .IF g_ShowJsonType == TRUE
                        ;Invoke szCatStr, Addr szItemTextArrayName, Addr szSpace
                        Invoke szCatStr, Addr szItemTextArrayName, Addr szColon
                        Invoke szCatStr, Addr szItemTextArrayName, Addr szSpace
                        Invoke szCatStr, Addr szItemTextArrayName, Addr szObject                    
                    .ENDIF
                    Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemTextArrayName, g_nTVIndex, TVI_LAST, IL_ICO_JSON_OBJECT, IL_ICO_JSON_OBJECT, hJSON
                    mov hTVCurrentNode, eax
                    inc g_nTVIndex
                    
                    Invoke TreeViewGetItemParam, hTV, hTVCurrentNode
                    ;PrintDec eax
                    ;PrintDec hTVCurrentNode
                .ELSE
                    
                    Invoke szCopy, Addr szItemTextArrayName, Addr szItemText
                    Invoke szCatStr, Addr szItemText, Addr szSpace
                    Invoke szCatStr, Addr szItemText, lpszItemString
                    Invoke szCatStr, Addr szItemText, Addr szColon
                    .IF LenItemStringValue != 0
                        Invoke szCatStr, Addr szItemText, Addr szSpace
                        Invoke szCatStr, Addr szItemText, lpszItemStringValue
                    .ENDIF
                
                    Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_OBJECT, IL_ICO_JSON_OBJECT, hJSON
                    mov hTVCurrentNode, eax
                    inc g_nTVIndex
                .ENDIF
                
            .ELSE
            ENDIF
            
                .IF LenItemString == 0
                    Invoke TreeViewItemInsert, hTV, hTVNode, Addr szObject, g_nTVIndex, TVI_LAST, IL_ICO_JSON_OBJECT, IL_ICO_JSON_OBJECT, hJSON
                    mov hTVCurrentNode, eax
                    inc g_nTVIndex
                .ELSE
                    
                    Invoke szCopy, lpszItemString, Addr szItemText
                    Invoke szCatStr, Addr szItemText, Addr szColon
                    .IF LenItemStringValue != 0
                        Invoke szCatStr, Addr szItemText, Addr szSpace
                        Invoke szCatStr, Addr szItemText, lpszItemStringValue
                    .ENDIF
                    Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_OBJECT, IL_ICO_JSON_OBJECT, hJSON
                    mov hTVCurrentNode, eax
                    inc g_nTVIndex
                    ;Invoke TreeViewItemExpand, hTV, hTVNode
                    ;Invoke TreeViewItemExpand, hTV, hTVCurrentNode
                .ENDIF
            
            IFDEF EXPERIMENTAL_ARRAYNAME_STACK
            .ENDIF
            ENDIF
            
        .ELSEIF eax == cJSON_String
            ;PrintText 'cJSON_String'
            .IF LenItemString == 0
                .IF LenItemStringValue != 0
                    Invoke szCopy, lpszItemStringValue, Addr szItemText
                .ELSE
                    Invoke szCopy, Addr szString, Addr szItemText
                .ENDIF                
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemText
                Invoke szCatStr, Addr szItemText, Addr szColon
                .IF LenItemStringValue > SIZEOF szItemTextValue ;!= 0
                    Invoke lstrcpyn, Addr szItemTextValue, lpszItemStringValue, SIZEOF szItemTextValue
                    Invoke szCatStr, Addr szItemText, Addr szSpace
                    Invoke szCatStr, Addr szItemText, Addr szItemTextValue
                .ELSE
                    .IF LenItemStringValue != 0
                        Invoke szCatStr, Addr szItemText, Addr szSpace
                        Invoke szCatStr, Addr szItemText, lpszItemStringValue
                    .ELSE
                        ;PrintText 'cJSON_String LenItemString!=0 LenItemStringValue==0'
                    .ENDIF
                .ENDIF
            .ENDIF
            Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_STRING, IL_ICO_JSON_STRING, hJSON
            mov hTVCurrentNode, eax
            inc g_nTVIndex

        .ELSEIF eax == cJSON_Number
            .IF LenItemString == 0
                Invoke szCopy, Addr szNullInteger, Addr szItemText
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemText
            .ENDIF
            Invoke szCatStr, Addr szItemText, Addr szColon
            Invoke szCatStr, Addr szItemText, Addr szSpace
            Invoke dwtoa, dwItemIntValue, Addr szItemIntValue
            Invoke szCatStr, Addr szItemText, Addr szItemIntValue
            Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_INTEGER, IL_ICO_JSON_INTEGER, hJSON
            mov hTVCurrentNode, eax
            inc g_nTVIndex
        
        .ELSEIF eax == cJSON_True
            .IF LenItemString == 0
                Invoke szCopy, Addr szNullLogical, Addr szItemText
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemText
            .ENDIF
            Invoke szCatStr, Addr szItemText, Addr szColon
            Invoke szCatStr, Addr szItemText, Addr szSpace
            Invoke szCatStr, Addr szItemText, Addr szTrue
            Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_LOGICAL, IL_ICO_JSON_LOGICAL, hJSON
            mov hTVCurrentNode, eax
            inc g_nTVIndex

        .ELSEIF eax == cJSON_False
            .IF LenItemString == 0
                Invoke szCopy, Addr szNullLogical, Addr szItemText
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemText
            .ENDIF
            Invoke szCatStr, Addr szItemText, Addr szColon
            Invoke szCatStr, Addr szItemText, Addr szSpace
            Invoke szCatStr, Addr szItemText, Addr szFalse
            Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_LOGICAL, IL_ICO_JSON_LOGICAL, hJSON
            mov hTVCurrentNode, eax
            inc g_nTVIndex

        .ELSEIF eax == cJSON_Array
            ;PrintText 'cJSON_Array'
            .IF LenItemString == 0
                Invoke szCopy, Addr szNullArray, Addr szItemText
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemText
            .ENDIF
            Invoke cJSON_GetArraySize, hJSON
            mov dwArrayCount, eax
            Invoke dwtoa, dwArrayCount, Addr szItemIntValue
            Invoke szCatStr, Addr szItemText, Addr szLeftSquareBracket
            Invoke szCatStr, Addr szItemText, Addr szItemIntValue
            Invoke szCatStr, Addr szItemText, Addr szRightSquareBracket
            .IF g_ShowJsonType == TRUE
                ;Invoke szCatStr, Addr szItemText, Addr szSpace
                Invoke szCatStr, Addr szItemText, Addr szColon
                Invoke szCatStr, Addr szItemText, Addr szSpace
                Invoke szCatStr, Addr szItemText, Addr szArray
            .ENDIF

            IFDEF EXPERIMENTAL_ARRAYNAME_STACK
            .IF LenItemString == 0
                Invoke szCopy, Addr szNullArray, Addr szItemTextArrayName
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemTextArrayName
            .ENDIF
            Invoke JSONStackItemCreate, Addr szItemTextArrayName
            mov hCurrentArray, eax
            ENDIF
            
            Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_ARRAY, IL_ICO_JSON_ARRAY, hJSON
            mov hTVCurrentNode, eax
            inc g_nTVIndex
            ;Invoke TreeViewItemExpand, hTV, hTVNode
            ;Invoke TreeViewItemExpand, hTV, hTVCurrentNode

        .ELSEIF eax == cJSON_NULL
            .IF LenItemString == 0
                Invoke szCopy, Addr szNullNull, Addr szItemText
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemText
            .ENDIF
            Invoke szCatStr, Addr szItemText, Addr szColon
            Invoke szCatStr, Addr szItemText, Addr szSpace
            Invoke szCatStr, Addr szItemText, Addr szNull
            Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_NULL, IL_ICO_JSON_NULL, hJSON
            mov hTVCurrentNode, eax
            inc g_nTVIndex

        .ELSEIF eax == cJSON_Invalid
            .IF LenItemString == 0
                Invoke szCopy, Addr szNullInvalid, Addr szItemText
            .ELSE
                Invoke szCopy, lpszItemString, Addr szItemText
            .ENDIF
            Invoke szCatStr, Addr szItemText, Addr szColon
            Invoke szCatStr, Addr szItemText, Addr szSpace
            Invoke szCatStr, Addr szItemText, Addr szInvalid
            Invoke TreeViewItemInsert, hTV, hTVNode, Addr szItemText, g_nTVIndex, TVI_LAST, IL_ICO_JSON_INVALID, IL_ICO_JSON_INVALID, hJSON
            mov hTVCurrentNode, eax
            inc g_nTVIndex

        .ELSEIF eax == cJSON_Raw

        .ENDIF
        
        .IF g_ExpandAllOnLoad == TRUE
            Invoke TreeViewItemExpand, hTV, hTVNode
        .ENDIF
        ;Invoke TreeViewItemExpand, hTV, hTVCurrentNode
        
        ; we have inserted a treeview item, now we check what the next cJSON item is and how to handle it
        ; get child if there is one, otherwise sibling if there is one
        .IF child != 0
        
            inc level ; we are moving up a level, so increment level
            push hJSON ; push hJSON, before hTVNode as always. Remember to pop them in reverse order later.
            push hTVNode
            
            mov eax, child ; set child cJSON object as the cJSON object to process in our loop
            mov hJSON, eax
            
            mov eax, hTVCurrentNode ; set currently inserted treeview item as hTVNode, so next one will be inserted as a child of this one.
            mov hTVNode, eax
            
            IFDEF EXPERIMENTAL_ARRAYNAME_STACK
            mov eax, jsontype
            .IF eax == cJSON_Array
                Invoke VirtualStackPush, hVirtualStack, hCurrentArray
                ;push hCurrentArray
                mov eax, hCurrentArray
                mov hArray, eax
                ;mov hCurrentArray, NULL
            .ELSE
                Invoke VirtualStackPush, hVirtualStack, hArray
                ;push hArray
                mov hArray, NULL
            .ENDIF
            mov eax, hArray
            mov hCurrentArray, eax
            ENDIF
            
        .ELSE ; No child cJSON object, so look for siblings
            .IF next != 0 ; we have a sibling
                mov eax, next ; set next cJSON object as the cJSON object to process in our loop
                mov hJSON, eax
            .ELSE ; No child or siblings, so must be at the last sibling, so here is the fun stuff

                IFDEF EXPERIMENTAL_ARRAYNAME_STACK
                Invoke VirtualStackPop, hVirtualStack, Addr VSValue
                .IF eax == TRUE
                    mov eax, VSValue
                    mov hArray, eax
                .ELSEIF eax == FALSE
                    IFDEF DEBUG32
                    PrintText 'VirtualStackPop Error'
                    ENDIF
                    ret
                .ELSE
                    IFDEF DEBUG32
                    PrintText 'VirtualStackPop End of Stack'
                    ENDIF
                    ret
                .ENDIF
                ;pop hArray
                ENDIF
                
                .IF level == 1
                    ;PrintText 'Error: No child, next or prev'
                    Invoke JSONFileClose, hWin
                    Invoke szCopy, Addr szJSONErrorIsolatedNode, Addr szJSONErrorMessage
                    Invoke szCatStr, Addr szJSONErrorMessage, lpszJSONFile
                    Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage
                    Invoke SendMessage, hTV, WM_SETREDRAW, TRUE, 0
                    Invoke MenusUpdate, hWin, NULL
                    Invoke ToolBarUpdate, hWin, NULL                    
                    Invoke SetFocus, hTV
                    mov eax, FALSE                  
                    ret
                .ENDIF
                pop hTVNode ; pop hTVNode before hJSON (reverse of what we pushed previously)
                pop hJSON ; we now have the last levels cJSON object and the parent of the last inserted treeview item
                dec level ; we are moving down a level, so decrement level
                
                mov ebx, hJSON ; fetch the next cJSON object of the cJSON object we just restored with the pop hJSON 
                mov eax, [ebx].cJSON.next
                
                .WHILE eax == 0 && level != 1 ; if next is 0 and we are still a level greater than 1 we loop, restoring previous cJSON objects and hTVNodes
                    
                    IFDEF EXPERIMENTAL_ARRAYNAME_STACK
                    Invoke VirtualStackPop, hVirtualStack, Addr VSValue
                    .IF eax == TRUE
                        mov eax, VSValue
                        mov hArray, eax
                    .ELSEIF eax == FALSE
                        IFDEF DEBUG32
                        PrintText 'VirtualStackPop Error'
                        ENDIF
                        ret
                    .ELSE
                        IFDEF DEBUG32
                        PrintText 'VirtualStackPop End of Stack'
                        ENDIF
                        ret
                    .ENDIF
                    ;pop hArray
                    ENDIF
                    
                    pop hTVNode
                    dec level
                    pop hJSON
                    mov ebx, hJSON
                    mov eax, [ebx].cJSON.next
                .ENDW
                ; we are now are level 1 (start) so the cJSON objects next object is either a value we can use in our loop or it is 0
                
                .IF eax == 0 ; no more left so exit as we are done
                    .BREAK
                .ELSE
                    mov hJSON, eax ; else we did find a new cJSON object which we can start the whole major loop process with again
                .ENDIF
            .ENDIF

        .ENDIF

    .ENDW

    Invoke SendMessage, hTV, WM_SETREDRAW, TRUE, 0

;    IFDEF DEBUG32
;        Invoke VirtualStackDepth, hVirtualStack
;        mov nStackDepth, eax
;        PrintDec nStackDepth
;        
;        Invoke VirtualStackUniqueCount, hVirtualStack
;        mov nUniqueCount, eax
;        PrintDec nUniqueCount
;        
;        Invoke VirtualStackData, hVirtualStack
;        mov pStackData, eax
;        PrintDec pStackData
;        mov eax, VIRTUALSTACK_SIZE_TINY
;        mov ebx, SIZEOF DWORD
;        mul ebx
;        DbgDump pStackData, eax
;    ENDIF

    ;.IF g_ExpandAllOnLoad == TRUE
    ;    Invoke TreeViewExpandAll, hTV
    ;.ENDIF
    Invoke TreeViewItemExpand, hTV, hTVRoot
    Invoke TreeViewSetSelectedItem, hTV, hTVRoot, TRUE
    
    IFDEF EXPERIMENTAL_ARRAYNAME_STACK
    Invoke VirtualStackDelete, hVirtualStack, Addr JSONStackItemsDeleteCallback
    ENDIF
    
    ; we have finished processing the cJSON objects, following children then following siblings, then moving back up the list/level, getting next object and 
    ; repeating till no more objects where left to process and all treeview items have been inserted at the correct 'level' indentation or whatever.

    ; Tell user via statusbar that JSON file was successfully loaded
    .IF lpdwJSONData == NULL
        ;Invoke CloseJSONFileHandles, hWin ; close handles as not needed anymore now
        Invoke szCopy, Addr szJSONLoadedFile, Addr szJSONErrorMessage
        Invoke JustFnameExt, lpszJSONFile, Addr szJustFilename
        Invoke szCatStr, Addr szJSONErrorMessage, Addr szJustFilename ;lpszJSONFile
        Invoke SetWindowTitle, hWin, lpszJSONFile
    .ELSE
        Invoke szCopy, Addr szJSONLoadedClipData, Addr szJSONErrorMessage
        Invoke SetWindowTitle, hWin, Addr szClipboardData
    .ENDIF
    Invoke StatusBarSetPanelText, 2, Addr szJSONErrorMessage  

ProcessingExit:
    
    ;Invoke cJSON_free, hJSON_Object_Root ; Clear up the mem alloced by cJSON_Parse

    Invoke MenusUpdate, hWin, hTVRoot
    Invoke ToolBarUpdate, hWin, hTVRoot
    Invoke MenuSaveAsEnable, hWin, TRUE
    Invoke ToolbarButtonSaveAsEnable, hWin, TRUE
    
    Invoke SetFocus, hTV
    
    mov eax, TRUE
    
    ret
JSONDataProcess ENDP

;-------------------------------------------------------------------------------------
; updated editbox with text from selected treeview item
;-------------------------------------------------------------------------------------
EditBoxUpdate PROC USES EBX hWin:DWORD, hItem:DWORD
    LOCAL hCurrentItem:DWORD
    LOCAL tvhi:TV_HITTESTINFO
    LOCAL hJSON:DWORD
    LOCAL lpszValueString:DWORD
    LOCAL pTxtBuffer:DWORD
    
    .IF hItem == NULL
        Invoke GetCursorPos, Addr tvhi.pt
        Invoke ScreenToClient, hTV, addr tvhi.pt
        Invoke SendMessage, hTV, TVM_HITTEST, 0, Addr tvhi
        mov eax, tvhi.hItem
    .ELSE
        mov eax, hItem
    .ENDIF
    mov hCurrentItem, eax
    
    
    Invoke TreeViewGetItemParam, hTV, hCurrentItem
    .IF eax != 0
        mov hJSON, eax
        mov ebx, eax
        mov eax, [ebx].cJSON.valuestring
        mov lpszValueString, eax
        .IF lpszValueString != 0
            Invoke szLen, lpszValueString
            .IF eax != 0
                .IF sdword ptr eax > JSON_ITEM_MAX_TEXTLENGTH
                    shl eax, 2d 
                    Invoke GlobalAlloc, GMEM_FIXED + GMEM_ZEROINIT, eax
                    .IF eax != NULL
                        mov pTxtBuffer, eax
                        Invoke NewLineReplace, lpszValueString, pTxtBuffer
                        Invoke SetWindowText, hEdtText, pTxtBuffer ;lpszValueString
                        Invoke GlobalFree, pTxtBuffer
                    .ELSE
                        Invoke SetWindowText, hEdtText, lpszValueString
                    .ENDIF
                    
                    ret
                .ENDIF
            .ENDIF
        .ENDIF
    .ENDIF
    
    Invoke TreeViewGetItemText, hTV, hCurrentItem, Addr szSelectedTreeviewText, SIZEOF szSelectedTreeviewText
    Invoke SetWindowText, hEdtText, Addr szSelectedTreeviewText
    
    ret
EditBoxUpdate ENDP

;-------------------------------------------------------------------------------------
; Checks label text length or underlying json text string length
;-------------------------------------------------------------------------------------
EditLabelTextLength PROC USES EBX lParam:DWORD
    LOCAL hJSON:DWORD
    LOCAL lpszValueString:DWORD
    LOCAL LenText:DWORD
    LOCAL hCurrentItem:DWORD

    mov ebx, lParam
    mov eax, (TV_DISPINFO PTR [ebx]).item.pszText
    mov eax, (TV_DISPINFO PTR [ebx]).item.cchTextMax
    mov LenText, eax
    
    mov ebx, lParam
    mov eax, (TV_DISPINFO PTR [ebx]).item.hItem
    mov hCurrentItem, eax
    
    Invoke TreeViewGetItemParam, hTV, hCurrentItem
    .IF eax != 0
        mov hJSON, eax
        mov ebx, eax
        mov eax, [ebx].cJSON.valuestring
        mov lpszValueString, eax
        .IF lpszValueString != 0
            Invoke szLen, lpszValueString
            .IF sdword ptr eax > JSON_ITEM_MAX_TEXTLENGTH
                ret
            .ELSE
                mov eax, LenText
            .ENDIF
        .ELSE
            mov eax, LenText
        .ENDIF
    .ELSE
        mov eax, LenText
    .ENDIF
    ret

EditLabelTextLength ENDP


;-------------------------------------------------------------------------------------
; Sets window title
;-------------------------------------------------------------------------------------
SetWindowTitle PROC hWin:DWORD, lpszTitleText:DWORD
    Invoke szCopy, Addr AppName, Addr TitleText
    .IF lpszTitleText != NULL
        Invoke szLen, lpszTitleText
        .IF eax != 0
            Invoke szCatStr, Addr TitleText, Addr szSpace
            Invoke szCatStr, Addr TitleText, Addr szDash
            Invoke szCatStr, Addr TitleText, Addr szSpace
            Invoke szCatStr, Addr TitleText, lpszTitleText
        .ENDIF
    .ENDIF
    Invoke SetWindowText, hWin, Addr TitleText
    ret
SetWindowTitle ENDP

;**************************************************************************
; Strip path name to just filename with extention
;**************************************************************************
JustFnameExt PROC USES ESI EDI szFilePathName:DWORD, szFileName:DWORD
	LOCAL LenFilePathName:DWORD
	LOCAL nPosition:DWORD
	
	Invoke szLen, szFilePathName
	mov LenFilePathName, eax
	mov nPosition, eax
	
	.IF LenFilePathName == 0
	    mov edi, szFileName
		mov byte ptr [edi], 0
		mov eax, FALSE
		ret
	.ENDIF
	
	mov esi, szFilePathName
	add esi, eax
	
	mov eax, nPosition
	.WHILE eax != 0
		movzx eax, byte ptr [esi]
		.IF al == '\' || al == ':' || al == '/'
			inc esi
			.BREAK
		.ENDIF
		dec esi
		dec nPosition
		mov eax, nPosition
	.ENDW
	mov edi, szFileName
	mov eax, nPosition
	.WHILE eax != LenFilePathName
		movzx eax, byte ptr [esi]
		mov byte ptr [edi], al
		inc edi
		inc esi
		inc nPosition
		mov eax, nPosition
	.ENDW
	mov byte ptr [edi], 0h ; null out filename
	mov eax, TRUE
	ret

JustFnameExt	ENDP

;**************************************************************************
;
;**************************************************************************
NewLineReplace PROC USES EBX EDI ESI src:DWORD,dst:DWORD
    
    mov esi, src
    mov edi, dst
    
    movzx eax, byte ptr [esi]
    .WHILE al != 0
        .IF al == 0
            .BREAK
        
        .ELSEIF al == 13
            mov byte ptr [edi], 13
            inc esi
            inc edi
            mov byte ptr [edi], 10
        
        .ELSEIF al == 10
            mov byte ptr [edi], 13
            inc esi
            inc edi
            mov byte ptr [edi], 10
        
        .ELSEIF al == '\'
            movzx ebx, byte ptr [esi+1]
            .IF bl == 0
                .BREAK
                
            .ELSEIF bl == 'r'
                mov byte ptr [edi], 13
                inc esi
                inc edi
                movzx eax, byte ptr [esi+1]
                .IF al == 0
                    .BREAK
                .ELSEIF al == '\'
                    movzx ebx, byte ptr [esi+2]
                    .IF bl == 0
                        .BREAK
                    .ELSEIF bl == 'n'
                        mov byte ptr [edi], 10
                        inc esi
                        inc esi
                        inc edi
                    .ELSE
                        mov byte ptr [edi], al
                    .ENDIF
                .ENDIF
                
            .ELSEIF bl == 'n'
                mov byte ptr [edi], 13
                inc esi
                inc edi
                mov byte ptr [edi], 10
            .ELSE
                mov byte ptr [edi], al
            .ENDIF
        
        .ELSE
            mov byte ptr [edi], al
        .ENDIF
        
        inc esi
        inc edi
        movzx eax, byte ptr [esi]
    .ENDW
    mov byte ptr [edi], 0
    
    ret

NewLineReplace ENDP


cJSON_AddNumberToObjectEx PROC hJSON:DWORD, lpszName:DWORD, dwNumberValue:DWORD
    LOCAL hJSONObjectNumber:DWORD
    LOCAL qwNumberValue:QWORD
    mov eax, dwNumberValue
    mov dword ptr [qwNumberValue+0], 0
    mov dword ptr [qwNumberValue+4], eax
    Invoke cJSON_CreateNumber, qwNumberValue
    mov hJSONObjectNumber, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectNumber
    mov eax, hJSONObjectNumber
    ret
cJSON_AddNumberToObjectEx ENDP


cJSON_SetIntegerValue PROC USES EBX hJSON:DWORD, dwIntegerValue:DWORD
    LOCAL qwNumberValue:QWORD
    
    mov ebx, hJSON
    .IF [ebx].cJSON.itemtype != cJSON_Number
        mov eax, NULL
        ret
    .ENDIF
    mov eax, dwIntegerValue
    mov [ebx].cJSON.valueint, eax    

    finit
    fild dwIntegerValue
    fstp qword ptr [qwNumberValue]
    
    mov eax, dword ptr [qwNumberValue]
    mov dword ptr [ebx].cJSON.valuedouble, eax
    mov eax, dword ptr [qwNumberValue+4]
    mov dword ptr [ebx+4].cJSON.valuedouble, eax
    
    mov eax, hJSON
    ret
cJSON_SetIntegerValue ENDP

IFDEF LIBCJSON

; Add To Object
cJSON_AddObjectToObject PROC hJSON:DWORD, lpszName:DWORD
    LOCAL hJSONObject:DWORD
    Invoke cJSON_CreateObject
    mov hJSONObject, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObject
    mov eax, hJSONObject
    ret
cJSON_AddObjectToObject ENDP

cJSON_AddArrayToObject PROC hJSON:DWORD, lpszName:DWORD
    LOCAL hJSONObjectArray:DWORD
    Invoke cJSON_CreateArray
    mov hJSONObjectArray, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectArray
    mov eax, hJSONObjectArray
    ret
cJSON_AddArrayToObject ENDP

cJSON_AddNullToObject PROC hJSON:DWORD, lpszName:DWORD
    LOCAL hJSONObjectNull:DWORD
    Invoke cJSON_CreateNull
    mov hJSONObjectNull, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectNull
    mov eax, hJSONObjectNull
    ret
cJSON_AddNullToObject ENDP

cJSON_AddTrueToObject PROC hJSON:DWORD, lpszName:DWORD
    LOCAL hJSONObjectTrue:DWORD
    Invoke cJSON_CreateTrue
    mov hJSONObjectTrue, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectTrue
    mov eax, hJSONObjectTrue
    ret
cJSON_AddTrueToObject ENDP

cJSON_AddFalseToObject PROC hJSON:DWORD, lpszName:DWORD
    LOCAL hJSONObjectFalse:DWORD
    Invoke cJSON_CreateFalse
    mov hJSONObjectFalse, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectFalse
    mov eax, hJSONObjectFalse
    ret
cJSON_AddFalseToObject ENDP

cJSON_AddBoolToObject PROC hJSON:DWORD, lpszName:DWORD, dwBoolValue:DWORD
    LOCAL hJSONObjectBool:DWORD
    Invoke cJSON_CreateBool, dwBoolValue
    mov hJSONObjectBool, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectBool
    mov eax, hJSONObjectBool
    ret
cJSON_AddBoolToObject ENDP

cJSON_AddNumberToObject PROC hJSON:DWORD, lpszName:DWORD, dwNumberValue:DWORD
    LOCAL hJSONObjectNumber:DWORD
    LOCAL qwNumberValue:QWORD
    mov eax, dwNumberValue
    mov dword ptr [qwNumberValue+0], eax
    mov dword ptr [qwNumberValue+4], eax
    Invoke cJSON_CreateNumber, qwNumberValue
    mov hJSONObjectNumber, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectNumber
    mov eax, hJSONObjectNumber
    ret
cJSON_AddNumberToObject ENDP

cJSON_AddStringToObject PROC hJSON:DWORD, lpszName:DWORD, lpszString:DWORD
    LOCAL hJSONObjectString:DWORD
    Invoke cJSON_CreateString, lpszString
    mov hJSONObjectString, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectString
    mov eax, hJSONObjectString
    ret
cJSON_AddStringToObject ENDP

cJSON_AddRawToObject PROC hJSON:DWORD, lpszName:DWORD, lpszRawJson:DWORD
    LOCAL hJSONObjectRaw:DWORD
    Invoke cJSON_CreateRaw, lpszRawJson
    mov hJSONObjectRaw, eax
    Invoke cJSON_AddItemToObject, hJSON, lpszName, hJSONObjectRaw
    mov eax, hJSONObjectRaw
    ret
cJSON_AddRawToObject ENDP

ENDIF

; Add To Array
cJSON_AddObjectToArray PROC hJSON:DWORD
    LOCAL hJSONObject:DWORD
    Invoke cJSON_CreateObject
    mov hJSONObject, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObject
    mov eax, hJSONObject
    ret
cJSON_AddObjectToArray ENDP

cJSON_AddArrayToArray PROC hJSON:DWORD
    LOCAL hJSONObjectArray:DWORD
    Invoke cJSON_CreateArray
    mov hJSONObjectArray, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectArray
    mov eax, hJSONObjectArray
    ret
cJSON_AddArrayToArray ENDP

cJSON_AddNullToArray PROC hJSON:DWORD
    LOCAL hJSONObjectNull:DWORD
    Invoke cJSON_CreateNull
    mov hJSONObjectNull, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectNull
    mov eax, hJSONObjectNull
    ret
cJSON_AddNullToArray ENDP

cJSON_AddTrueToArray PROC hJSON:DWORD
    LOCAL hJSONObjectTrue:DWORD
    Invoke cJSON_CreateTrue
    mov hJSONObjectTrue, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectTrue
    mov eax, hJSONObjectTrue
    ret
cJSON_AddTrueToArray ENDP

cJSON_AddFalseToArray PROC hJSON:DWORD
    LOCAL hJSONObjectFalse:DWORD
    Invoke cJSON_CreateFalse
    mov hJSONObjectFalse, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectFalse
    mov eax, hJSONObjectFalse
    ret
cJSON_AddFalseToArray ENDP

cJSON_AddBoolToArray PROC hJSON:DWORD, dwBoolValue:DWORD
    LOCAL hJSONObjectBool:DWORD
    Invoke cJSON_CreateBool, dwBoolValue
    mov hJSONObjectBool, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectBool
    mov eax, hJSONObjectBool
    ret
cJSON_AddBoolToArray ENDP

cJSON_AddNumberToArray PROC hJSON:DWORD, dwNumberValue:DWORD
    LOCAL hJSONObjectNumber:DWORD
    LOCAL qwNumberValue:QWORD
    mov eax, dwNumberValue
    mov dword ptr [qwNumberValue+0], eax
    mov dword ptr [qwNumberValue+4], eax
    Invoke cJSON_CreateNumber, qwNumberValue
    mov hJSONObjectNumber, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectNumber
    mov eax, hJSONObjectNumber
    ret
cJSON_AddNumberToArray ENDP

cJSON_AddStringToArray PROC hJSON:DWORD, lpszString:DWORD
    LOCAL hJSONObjectString:DWORD
    Invoke cJSON_CreateString, lpszString
    mov hJSONObjectString, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectString
    mov eax, hJSONObjectString
    ret
cJSON_AddStringToArray ENDP

cJSON_AddRawToArray PROC hJSON:DWORD, lpszRawJson:DWORD
    LOCAL hJSONObjectRaw:DWORD
    Invoke cJSON_CreateRaw, lpszRawJson
    mov hJSONObjectRaw, eax
    Invoke cJSON_AddItemToArray, hJSON, hJSONObjectRaw
    mov eax, hJSONObjectRaw
    ret
cJSON_AddRawToArray ENDP



IFDEF DEBUG32
    echo
    echo ------------------------------------------
    echo DEBUG32 - Debugging Enabled
    echo ------------------------------------------
ENDIF

end start
















