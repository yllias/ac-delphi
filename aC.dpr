library aC;

{
  author: yll kryeziu
  date: 05/02/2021
  name: aC
}

{$R *.res}

uses
    WinProcs,
    WinTypes,
    SysUtils,
    Controls,
    Forms,
    Math,
    Dialogs,
    aCDlg in 'aCDlg.pas' {aCForm};

type
    PUserData = ^TUserData;

    TUserData = record
        ComPort, Baudrate, Mode, Analog: integer;
    end;

    PParameterStruct = ^TParameterStruct;

    TParameterStruct = packed record
        NuE: Byte; { Anzahl reeller Zahlenwerte }
        NuI: Byte; { Anzahl ganzer Zahlenwerte }
        NuB: Byte; { Anzahl Schalter }
        E: Array [0 .. 31] of Extended; { reelle Zahlenwerte }
        I: Array [0 .. 31] of integer; { ganze Zahlenwerte }
        B: Array [0 .. 31] of Byte; { Schalter }
        D: Array [0 .. 255] of AnsiChar; { event. Dateiname f�r weitere Daten. }
        EMin: Array [0 .. 31] of Extended;
        { untere Eingabegrenze f�r jeden reellen Zahlenwert }
        EMax: Array [0 .. 31] of Extended;
        { obere Eingabegrenze f�r jeden rellen Zahlenwert }
        IMin: Array [0 .. 31] of integer;
        { untere Eingabegrenze f�r jeden ganzzahligen Zahlenwert }
        IMax: Array [0 .. 31] of integer;
        { obere Eingabegrenze f�r jeden ganzzahligen Zahlenwert }
        NaE: Array [0 .. 31, 0 .. 40] of AnsiChar;
        { Namen der reellen Zahlenwerten }
        NaI: Array [0 .. 31, 0 .. 40] of AnsiChar;
        { Namen der ganzen Zahlenwerten }
        NaB: Array [0 .. 31, 0 .. 40] of AnsiChar; { Namen der Schalter }
        UserDataPtr: PUserData; { Zeiger auf weitere Blockvariablen }
        ParentPtr: Pointer; { Zeiger auf User-DLL-Block }
        ParentHWnd: HWnd; { Handle des User-DLL-Blocks }
        ParentName: PAnsiChar; { Name des User-DLL-Blocks }
        UserHWindow: HWnd;
        { Benutzerdef. Fensterhandle, z. B. f�r Ausgabefenster }
        DataFile: text; { Textdatei f�r universelle Zwecke }
    end;

    PDialogEnableStruct = ^TDialogEnableStruct;

    TDialogEnableStruct = packed record
        AllowE: Longint; { Soll die Eingabe eines Wertes }
        AllowI: Longint; { un-/zul�ssig sein so ist das Bit }
        AllowB: Longint; { des Allow?-Feldes 0 bzw. 1 }
        AllowD: Byte;
    end;

    PNumberOfInputsOutputs = ^TNumberOfInputsOutputs;

    TNumberOfInputsOutputs = packed record
        Inputs: Byte; { Anzahl Eing�nge }
        Outputs: Byte; { Anzahl Ausg�nge }
        NameI: Array [0 .. 49, 0 .. 40] of AnsiChar;
        NameO: Array [0 .. 49, 0 .. 40] of AnsiChar;
    end;

    PInputArray = ^TInputArray;
    TInputArray = packed array [1 .. 30] of Extended;
    POutputArray = ^TOutputArray;
    TOutputArray = packed array [1 .. 30] of Extended;

var
    Opened: array [1 .. 255] of integer;
    hCom: array [1 .. 255] of THandle;
    I: integer;

function Connect(ComPort, Baudrate: integer): boolean; export; stdcall;
var
    DCB: TDCB;
    CommTimeOuts: TCommTimeOuts;
    F: TextFile;
begin
    if Opened[ComPort] = 0 then
    begin
        if ComPort < 10 then
            hCom[ComPort] := CreateFile(PChar('COM' + IntToStr(ComPort)),
              GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0)
        else
            hCom[ComPort] := CreateFile(PChar('\\.\COM' + IntToStr(ComPort)),
              GENERIC_READ or GENERIC_WRITE, 0, nil, OPEN_EXISTING, 0, 0);
        if hCom[ComPort] <> INVALID_HANDLE_VALUE then
        begin
            DCB.DCBlength := SizeOf(DCB);
            GetCommState(hCom[ComPort], DCB);
            DCB.Baudrate := Baudrate;
            DCB.ByteSize := 8;
            DCB.Parity := 0;
            DCB.StopBits := ONESTOPBIT;
            DCB.Flags := 1;
            SetCommState(hCom[ComPort], DCB);
            GetCommTimeOuts(hCom[ComPort], CommTimeOuts);
            CommTimeOuts.ReadTotalTimeoutConstant := 10;
            SetCommTimeOuts(hCom[ComPort], CommTimeOuts);
            sleep(100);
            Result := true;
        end
        else
        begin
            hCom[ComPort] := 0;
            Result := false;
        end;
    end
    else
        Result := true;
    if Result then
        inc(Opened[ComPort]);
end;

procedure Disconnect(ComPort: integer); export; stdcall;
begin
    dec(Opened[ComPort]);
    if Opened[ComPort] = 0 then
    begin
        CloseHandle(hCom[ComPort]);
        hCom[ComPort] := 0;
    end;
end;

function GetComHandle(ComPort: integer): THandle; export; stdcall;
begin
    Result := hCom[ComPort];
end;

procedure SendString(ComPort: integer; Command: AnsiString);
var
    BytesWritten: DWORD;
    I: integer;
    Buffer: array [1 .. 1000] of Byte;
    F: TextFile;
begin
    for I := 1 to Length(Command) do
        Buffer[I] := ord(Command[I]);
    WriteFile(ComPort, Buffer, Length(Command), BytesWritten, nil);
end;

procedure GetParameterStruct(D: PParameterStruct);
export stdcall;
begin
    // Anzahl der Parameter
    D^.NuE := 0;
    D^.NuI := 0;
    D^.NuB := 0;
end;

procedure GetDialogEnableStruct(D: PDialogEnableStruct; D2: PParameterStruct);
export stdcall;
begin
end;

procedure GetNumberOfInputsOutputs(D: PNumberOfInputsOutputs);
export stdcall;
begin
    D^.Inputs := 3;
    D^.Outputs := 0;
    D^.NameI[0] := 'Kanal 1 %';
    D^.NameI[1] := 'Kanal 2 %';
    D^.NameI[2] := 'Kanal 3 %';
end;

Procedure CallParameterDialogDLL(D1: PParameterStruct;
  D2: PNumberOfInputsOutputs);
export stdcall;
var
    I: integer;
    DialogForm: TaCForm;
    Dummy: Extended;
    s: array [0 .. 1000] of AnsiChar;
begin
    DialogForm := TaCForm.Create(Application);
    with DialogForm do
    begin
        comUpDown.Position := D1^.UserDataPtr.ComPort;
        baudEdit.text := IntToStr(D1^.UserDataPtr.Baudrate);
        modeEdit.text := IntToStr(D1^.UserDataPtr.Mode);
        if ShowModal = mrOK then
        begin
            D1^.UserDataPtr.ComPort := comUpDown.Position;
            D1^.UserDataPtr.Baudrate := strtoint(baudEdit.text);
            D1^.UserDataPtr.Mode := strtoint(modeEdit.text);
        end;
        Free;
    end;
end;

function CanSimulateDLL(D: PParameterStruct): integer;
export stdcall;
begin
    if Connect(D^.UserDataPtr.COMPort, D^.UserDataPtr.Baudrate) then with D^.UserDataPtr^ do begin
    Disconnect(D^.UserDataPtr.COMPort);
    Result := 1;
  end else
    Application.MessageBox(PChar('Verbindung mit COM-Port ' +inttostr(D^.UserDataPtr.ComPort)+ ' konnte nicht hergestellt werden!'), 'Fehler bei Verbindung', MB_OK or MB_ICONERROR);
    Result := 0;
end;

procedure SimulateDLL(T: Extended; D1: PParameterStruct; Inputs: PInputArray;
  Outputs: POutputArray);
export stdcall;
var
    s: string;
    F: TextFile;
begin
    s := inttostr(D1^.UserDataPtr.Mode) +'-'+ floattostr(extended(Inputs^[1]))+'-'+ floattostr(extended(Inputs^[2]))+'-'+ floattostr(extended(Inputs^[3]));
    SendString(GetComHandle(D1.UserDataPtr^.ComPort), s);
end;

procedure InitSimulationDLL(D: PParameterStruct; Inputs: PInputArray;
  Outputs: POutputArray);
export stdcall;
var
    I: integer;
begin
    Connect(D^.UserDataPtr.ComPort, D^.UserDataPtr.Baudrate);
    SimulateDLL(0, D, Inputs, Outputs);
end;

procedure EndSimulationDLL2(D: PParameterStruct);
export stdcall;
begin
    Disconnect(D^.UserDataPtr.ComPort);
end;

procedure InitUserDLL(D: PParameterStruct);
export stdcall;
begin
    Application.Handle := D^.ParentHWnd;
    D^.UserDataPtr := new(PUserData);
    D^.UserDataPtr.ComPort := 1;
    D^.UserDataPtr.Baudrate := 9600;
    D^.UserDataPtr.Mode := 1;
end;

procedure DisposeUserDLL(D: PParameterStruct);
export stdcall;
begin
    Application.Handle := 0;
    dispose(D^.UserDataPtr);
end;

function GetDLLName: PAnsiChar;
export stdcall;
begin
    GetDLLName := 'AlphaController';
end;

Procedure WriteToFile(AFileHandle: Word; D: PParameterStruct);
export stdcall;
var
    I: integer;
    s: array [0 .. 1000] of AnsiChar;
begin
    with D^.UserDataPtr^ do
    begin
        StrPCopy(s, IntToStr(ComPort) + #13#10);
        _lWrite(AFileHandle, s, StrLen(s));
        StrPCopy(s, IntToStr(Baudrate) + #13#10);
        _lWrite(AFileHandle, s, StrLen(s));
    end;
end;

Procedure ReadFromFile(AFileHandle: Word; D: PParameterStruct);
export stdcall;
var
    I, Code: integer;
    s: array [0 .. 1000] of AnsiChar;
    procedure ReadOneLine(FHandle: Word; Aps: PAnsiChar);
    var
        I: integer;
    begin
        I := 0;
        _lRead(FHandle, @Aps[I], 1);
        repeat
            inc(I);
            _lRead(FHandle, @Aps[I], 1);
        until (Aps[I - 1] = #13) and (Aps[I] = #10);
        Aps[I - 1] := #0;
    end;

begin
    ReadOneLine(AFileHandle, s);
    D^.UserDataPtr.ComPort := strtoint(StrPas(s));
    ReadOneLine(AFileHandle, s);
    D^.UserDataPtr.Baudrate := strtoint(StrPas(s));
end;

function NumberOfLinesInSystemFile: integer;
export stdcall;
begin
end;

procedure IsUserDLL32;
export stdcall;
begin
    //
end;

procedure IsDemoDLL;
export stdcall;
begin
    //
end;

{ Exportieren der notwendigen Funktionen und Prozeduren }
exports
    WriteToFile,
    ReadFromFile,
    NumberOfLinesInSystemFile,
    GetParameterStruct,
    GetDialogEnableStruct,
    GetNumberOfInputsOutputs,
    CanSimulateDLL,
    InitSimulationDLL,
    SimulateDLL,
    InitUserDLL,
    DisposeUserDLL,
    EndSimulationDLL2,
    GetDLLName,
    CallParameterDialogDLL,
    IsUserDLL32,
    Connect,
    Disconnect,
    GetComHandle,
    SendString,
    IsDemoDLL;

begin
    { Weitere Initialisierung der DLL }
    for I := 1 to 255 do
    begin
        Opened[I] := 0;
        hCom[I] := 0;
    end;

end.
