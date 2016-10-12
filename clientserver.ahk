; Server/Client socket w/ upnp v0.1
;
; code gathered from various sources
; hacking and improvements by: rZr/opicr0n
;
;program used for upnp mapping
;   http://miniupnp.tuxfamily.org/
;
;want to know if your port is open?
;   http://www.canyouseeme.org/

; configuration

spawnServer := "xxx.xxx.xx.xxx"
serverPort := "44444"

; initialisation

#SingleInstance off
#include Socket.ahk
onexit _Exit

connected := False
mode := ""
clientCount = -1
client := {} ; if !client

;
; main program
;

; check if client has external server ip

ExternalIP := URLToVar("http://www.netikus.net/show_ip.html")    

if (ExternalIP == spawnServer) 
{
    spawnServer := A_IPAddress1 ; use local ip instead
    mode := "server"
} 

myTcp := new SocketTCP()
result := myTcp.bind(spawnServer, serverPort)

if (result == 1 && mode == "server")
{
    ; start server

	myTcp.listen()
	myTcp.onAccept := Func("OnTCPAccept")
    Menu, Tray, Icon, gfx\server_on.ico, 0

    ; open upnp port

    RunWait, upnpc.exe -a %A_IPAddress1% %serverPort% %serverPort% TCP,, Hide
    
} else { 		
     
    ; connect to server
    
    mode := "client"

    connected := myTcp.connect(spawnServer, serverPort) ;extern
    if (connected)
    {
        myTcp.onRecv := Func("OnTcpClientRecv")
        ;MsgBox, %result%
    }
}

ShowGUI()
return

;
; GUI
;

ShowGUI() {
    global 

    ;Set up the GUI

    Gui, +Resize +OwnDialogs
    Gui, Add, Edit, r10 w300 vtxtDialog ReadOnly hwndhtxtDialog  
    Gui, Add, Edit, xm w250 vtxtInput hwndhtxtInput gtxtInput Limit65535 ; limit to 65535 max length of stream
    Gui, Add, Button, x+5 w45 hp vbtnSend hwndhbtnSend Default gbtnSend, Send

    ;Gui, Add, Text, xm w300 vlblStatus hwndhlblStatus, Not connected...

    Gui, +MinSize
    
    if (Mode == "server")
        Gui, Show, , SpawnTimer [Server]
    else
        Gui, Show, , SpawnTimer [Client]
}

txtInput:
    ;Get text entered, if any
    GuiControlGet, sText,, txtInput
    
    ;Create a boolean value
    bTypingUpdate := (StrLen(sText) = 0) ? 1 : 0
    
    ;Send a typing update frame only if the boolean value is different from the last one we sent. We do this check so that
    ;we don't drown the peer with updates everytime the user types an additional character in the Edit control box.
    If (bTypingUpdate == bLastTypingUpdate || bLastTypingUpdate := StrLen(sText) = 0)
        Return   
    
    ;send typing update
    if (Mode == "server")
    {
        Loop, % clientCount + 1
        {
            curClient := A_Index - 1
            client[curClient].sendText("[server typing]")            
        }
    } else {
        myTcp.sendText("[client typing]")

    }

    bLastTypingUpdate := bTypingUpdate

    ;Remember the boolean value of the typing update frame we just sent
    ;bLastTypingUpdate := sText ? 1 : 0   
    ;bLastTypingUpdate := bTypingUpdate
    
Return

btnSend:
    global client, clientCount

    ;Get the text to send
    GuiControlGet, sText,, txtInput
    
    ;Make sure we even have something to send
    If Not sText
        Return

    if (Mode == "server")
    {
        Loop, % clientCount + 1
        {
            curClient := A_Index - 1
            client[curClient].sendText(sText)            
        }

        AddDialog(&sText)
    } else {
        myTcp.sendText(sText)
    }
    
    ;Data was sent. Add it to the dialog.
    ;AddDialog(&sText)
    
    ;Clear the Edit control and give focus
    GuiControl,, txtInput
    GuiControl, Focus, txtInput
Return

;AddDialog(ptrText, bYou = True) {
AddDialog(ptrText) {
    Global htxtDialog
    
    ;Append the interlocutor
    ;sAppend := bYou ? "You > " : "Peer > "
    ;InsertText(htxtDialog, &sAppend)
    
    ;Append the new text
    InsertText(htxtDialog, ptrText)
    
    ;Append a new line
    sAppend := "`r`n"
    InsertText(htxtDialog, &sAppend)
    
    ;Scroll to bottom
    SendMessage, 0x0115, 7, 0,, ahk_id %htxtDialog% ;WM_VSCROLL
}

/*! TheGood
    Append text to an Edit control
    http://www.autohotkey.com/forum/viewtopic.php?t=56717
*/
InsertText(hEdit, ptrText, iPos = -1) {
    
    If (iPos = -1) {
        SendMessage, 0x000E, 0, 0,, ahk_id %hEdit% ;WM_GETTEXTLENGTH
        iPos := ErrorLevel
    }
    
    SendMessage, 0x00B1, iPos, iPos,, ahk_id %hEdit% ;EM_SETSEL
    SendMessage, 0x00C2, False, ptrText,, ahk_id %hEdit% ;EM_REPLACESEL
}

; 
; Server code
;

OnTCPAccept(this)
{
	global client, clientCount += 1

    client[clientCount] := this.accept()
    client[clientCount].onRecv := Func("OnTCPRecv")
    client[clientCount].sendText("Connected to server " clientCount)

    ; send update to all other connected clients

    Loop, % clientCount ; client is initially -1 ; this dont send to connected client
    {
        Sleep 100
        ;MsgBox, % A_Index ; when removed clients are not updated
		curClient := A_Index - 1
		client[curClient].sendText("Another client connected " A_Index)
	}   

    msg := "Client connected"
    AddDialog(&msg)
}

OnTCPRecv(this)
{
    global client, clientCount
    ; process client messages

    msg := this.recvText()
    AddDialog(&msg)
    ;FileAppend SERVER received: %msg%`n, data.log

    ; relay msg to clients

    Loop, % clientCount + 1
    {
        ;Sleep 100
        curClient := A_Index - 1
        client[curClient].sendText("relayed: " msg)
    }   

}

; 
; Client code
;

OnTcpClientRecv(this)
{
    ; process server messages

    msg := this.recvText()   
    AddDialog(&msg)
    ;FileAppend CLIENT received: %msg%`n, data.log
}

;
; Various functions
;

URLToVar(URL)
{
    ComObjError(0)
    WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    WebRequest.Open("GET", URL)
    WebRequest.Send()
    Return WebRequest.ResponseText()
}

;
;
;

GuiClose:
    ExitApp
Return

_Exit:

    global client, clientCount

    if (Mode == "server")
    {
        ; server close

        ; send disconnect to all other connected clients

        Loop, % clientCount + 1
        {
            ;Sleep 100
            curClient := A_Index - 1
            client[curClient].sendText("Server disconnected " %A_Index%)
        }

        ; close upnp port

        RunWait, upnpc.exe -d %A_IPAddress1% %serverPort% %serverPort% TCP,, Hide
    }
    else
    {
        ; client close

        myTcp.sendText("An client disconnected")

        myTcp.disconnect()
    } 

ExitApp