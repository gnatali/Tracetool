{ TTrayIcon VCL. Version 1.3

  Requires:  Delphi 2.0 32 bit.

  Function: Adds an icon to the Windows 95 Tool Tray and
      has events to respond to mouse clicks.

  This component is based on the TToolIcon VCL that was written by
  Derek Stutsman (dereks@metronet.com).  He based his component on
  TWinControl, so it showed up as a clear, blank, resizable window at
  design time and also had more properties than the component actually
  needed.  This made it really hard to find on a busy form sometimes.

  I changed it so it would be based on TComponent so that it was readily
  visible at design time and also did not cover anything at run-time.
  The additional Top, left, width, etc. properties are also no longer
  necessary.  I added a ShowDesigning property so that you could test
  it at design time, but then turn it off so that TWO icons weren't shown
  on the tool tray when developing and testing.

  One strange anomaly that I worked around but don't know why it happens -
  if a ToolTip is not specified, then at run-time the icon shows up as
  blank.  If a ToolTip is specified, everything works fine.  To fix this,
  I set up another windows message that set the tool tip if it was blank -
  this ensures proper operation at all times, but I don't know why this
  is necessary.  If you can figure it out, send me some mail and let me
  know! (4/17/96 note - still no solution for this!)

  This is freeware (as was the original).  If you make cool changes to it,
  please send them to me.

  Enjoy!

  Pete Ness
  Compuserve ID: 102347,710
  Internet: 102347.710@compuserve.com
  http:\\ourworld.compuserve.com\homepages\peteness

  Release history:

  3/8/96 - Version 1.0
     Release by Derek Stutsman of TToolIcon version 1.0

  3/12/96 - Version 1.1

     Changed as outlined above by me (Pete Ness) and renamed to TTrayIcon.

  3/29/96 - Version 1.2
     Add default window handling to allow closing when Win95 shutdown.
     Previously, you had to manually close your application before closing
     Windows 95.

  4/17/96 - Version 1.3
     Added a PopupMenu property to automatically handle right clicking on
     the tray icon.
     Fixed bug that would not allow you to instantiate a TTrayIcon instance
     at run-time.
     Added an example program to show how to do some of the things I've
     gotten the most questions on.
     This version is available from my super lame web page - see above for
     the address.

  7/24/96 - Version 1.?
     Added a ShowApp and IDMessage property. TrayIcon apps mostly don't show
     a button on the taskbar and can't start multiple times. If you set the
     property ShowApp to 'true' there will be a button on the windows 95
     taskbar else it won't. If IDMessage is empty, multiple instances can run
     the same time, when you type an identification string you can run only
     one instance. For the IDMessage property I've used a freeware (JustOne
     v2.0) component from Eric Pankoke (epankoke@cencom.net)
     I don't know if I've made a good job (doing it the right way), it's the
     first time I change a component.

     Don't mention my (bad) English, Dutch is my natural language. You can reach
     me by e-mail at: ameeder@dds.nl, Alexander Meeder.
  }


unit TrayIcon;

interface

uses
  SysUtils, Windows, Messages, Classes, Graphics, Controls, ShellAPI, Forms, Menus;

const WM_TOOLTRAYICON = WM_USER+1;
      WM_RESETTOOLTIP = WM_USER+2;

type

  TTrayIcon = class(TComponent)

  private

  // BDS
  { internal use }

    hMapping: THandle;

  { Field Variables }

    IconData: TNOTIFYICONDATA;
    fIcon : TIcon;
    fToolTip : String;
    fWindowHandle : HWND;
    fActive : boolean;
    fShowApp : boolean;                                     // A. Meeder
    fSendMsg : string;
    fShowDesigning : Boolean;

  { Events }

    fOnClick     : TNotifyEvent;
    fOnDblClick  : TNotifyEvent;
    fOnRightClick : TMouseEvent;
    fPopupMenu   : TPopupMenu;

    function AddIcon : boolean;
    function ModifyIcon : boolean;
    function DeleteIcon : boolean;

    procedure SetActive(Value : boolean);
    procedure SetShowApp(Value : boolean);                  // A. Meeder
    procedure SetShowDesigning(Value : boolean);
    procedure SetIcon(Value : TIcon);
    procedure SetToolTip(Value : String);
    procedure WndProc(var msg : TMessage);

    procedure FillDataStructure;
    procedure DoRightClick( Sender : TObject );

  protected

  public
    FMessageID: DWORD;

    constructor Create(aOwner : TComponent); override;
    procedure Loaded; override;                             // A. Meeder
    destructor Destroy; override;
    procedure GoToPreviousInstance;

  published

    property Active : boolean read fActive write SetActive;
    property ShowDesigning : boolean read fShowDesigning write SetShowDesigning;
    property Icon : TIcon read fIcon write SetIcon;
    property IDMessage : string read fSendMsg write fSendMsg;
    property ShowApp : boolean read fShowApp write SetShowApp; // A. Meeder
    property ToolTip : string read fTooltip write SetToolTip;

    property OnClick     : TNotifyEvent read FOnClick write FOnClick;
    property OnDblClick  : TNotifyEvent read FOnDblClick write FOnDblClick;
    property OnRightClick : TMouseEvent  read FOnRightClick write FonRightClick;
    property PopupMenu : TPopupMenu read fPopupMenu write fPopupMenu;

  end;

procedure Register;

type
   PHWND = ^HWND;

implementation

{$R TrayIcon.res}

procedure TTrayIcon.GoToPreviousInstance;
begin
  PostMessage(hwnd_Broadcast, fMessageID, 0, 0);
end;

procedure TTrayIcon.SetActive(Value : boolean);
begin
   if value <> fActive then begin
     fActive := Value;
     if not (csdesigning in ComponentState) then begin
        if Value then begin
           AddIcon;
        end else begin
           DeleteIcon;
        end;
     end;
  end;
end;

procedure TTrayIcon.SetShowApp(Value : boolean);      // A. Meeder
begin
  if value <> fShowApp then fShowApp := value;
  if not (csdesigning in ComponentState) then
  begin
    if Value then
    begin
      ShowWindow(Application.Handle, SW_SHOW);
    end
    else
    begin
      ShowWindow(Application.Handle, SW_HIDE);
    end;
  end;
end;

procedure TTrayIcon.SetShowDesigning(Value : boolean);
begin
  if csdesigning in ComponentState then begin
     if value <> fShowDesigning then begin
        fShowDesigning := Value;
        if Value then begin
           AddIcon;
        end else begin
           DeleteIcon;
        end;
     end;
  end;
end;

procedure TTrayIcon.SetIcon(Value : Ticon);
begin
  if Value <> fIcon then
    begin
      fIcon.Assign(value);
      ModifyIcon;
    end;
end;

procedure TTrayIcon.SetToolTip(Value : string);
begin

   // This routine ALWAYS re-sets the field value and re-loads the
   // icon.  This is so the ToolTip can be set blank when the component
   // is first loaded.  If this is changed, the icon will be blank on
   // the tray when no ToolTip is specified.

   if length( Value ) > 62 then
      Value := copy(Value,1,62);
   fToolTip := value;
   ModifyIcon;

end;

constructor TTrayIcon.create(aOwner : Tcomponent);
begin
  inherited create(aOwner);
  FWindowHandle := Classes.AllocateHWnd(WndProc);
  FIcon := TIcon.Create;

  SetShowApp(False);
end;

destructor TTrayIcon.destroy;
begin

  // BDS
  CloseHandle(hMapping);

  if (not (csDesigning in ComponentState) and fActive)
     or ((csDesigning in ComponentState) and fShowDesigning) then
        DeleteIcon;

  FIcon.Free;
  Classes.DeallocateHWnd(FWindowHandle);
  inherited destroy;

end;

procedure TTrayIcon.Loaded;                                  // A. Meeder
var
  // BDS
  // hMapping: HWND;
  tmp, tmpID: PChar;
begin
  inherited Loaded;
  if fSendMsg <> '' then
  begin
    GetMem(tmp, Length(fSendMsg) + 1);
    GetMem(tmpID, Length(fSendMsg) + 1);
    StrPCopy(tmp, fSendMsg);
    StrPCopy(tmpID, fSendMsg);
    fMessageID := RegisterWindowMessage(tmp);
    FreeMem(tmp);
    hMapping := CreateFileMapping(HWND($FFFFFFFF), nil, PAGE_READONLY, 0, 32, tmpID);
    if (hMapping <> 0) and (GetLastError = ERROR_ALREADY_EXISTS) then
    begin
      if not (csDesigning in ComponentState) then
      begin
        GotoPreviousInstance;
        FreeMem(tmpID);
        halt;
      end;
    end;
    FreeMem(tmpID);
  end;

  SetShowApp(fShowApp);
end;

procedure TTrayIcon.FillDataStructure;
begin

  with IconData do begin

     cbSize := System.sizeof(TNOTIFYICONDATA);
     wnd := FWindowHandle;
     uID := 0; // is not passed in with message so make it 0
     uFlags := NIF_MESSAGE + NIF_ICON + NIF_TIP;
     hIcon := fIcon.Handle;
     StrPCopy(szTip,fToolTip);
     uCallbackMessage := WM_TOOLTRAYICON;

  end;

end;

function TTrayIcon.AddIcon : boolean;
begin
   FillDataStructure;
   result := Shell_NotifyIcon(NIM_ADD,@IconData);

   // For some reason, if there is no tool tip set up, then the icon
   // doesn't display.  This fixes that.

   if fToolTip = '' then
      PostMessage( fWindowHandle, WM_RESETTOOLTIP,0,0 );

end;

function TTrayIcon.ModifyIcon : boolean;
begin

   FillDataStructure;
   if fActive then
      result := Shell_NotifyIcon(NIM_MODIFY,@IconData)
   else
      result := True;

end;

procedure TTrayIcon.DoRightClick( Sender : TObject );
var MouseCo: Tpoint;
begin

   GetCursorPos(MouseCo);

   if assigned( fPopupMenu ) then begin
      SetForegroundWindow( Application.Handle );
      Application.ProcessMessages;
      fPopupmenu.Popup( Mouseco.X, Mouseco.Y );
   end;

   if assigned( FOnRightClick ) then
      begin
         FOnRightClick(self,mbRight,[],MouseCo.x,MouseCo.y);
      end;
end;

function TTrayIcon.DeleteIcon : boolean;
begin
   result := Shell_NotifyIcon(NIM_DELETE,@IconData);
end;

procedure TTrayIcon.WndProc(var msg : TMessage);
begin
   with msg do
     if (msg = WM_RESETTOOLTIP) then
        SetToolTip( fToolTip )
     else if (msg = WM_TOOLTRAYICON) then begin
        case lParam of
           WM_LBUTTONDBLCLK   : if assigned (FOnDblClick) then FOnDblClick(self);
           WM_LBUTTONUP       : if assigned(FOnClick)then FOnClick(self);
           WM_RBUTTONUP       : DoRightClick(self);
        end;
     end
     else // Handle all messages with the default handler
        Result := DefWindowProc(FWindowHandle, Msg, wParam, lParam);

end;

procedure Register;
begin
  RegisterComponents('Win95', [TTrayIcon]);
end;

end.
