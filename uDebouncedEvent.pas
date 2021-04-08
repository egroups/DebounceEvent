unit uDebouncedEvent;

{
  Inspired:
  https://github.com/Code-Partners/debounced-event

  Using:
  EditEmail.OnChange := TDebouncedEvent.Wrap(self.DoOnEmailEditChange, 200, self);
}
interface

uses
  System.Classes,
  System.SysUtils,
  System.DateUtils,
  Vcl.ExtCtrls, Vcl.Controls, Data.DB;

type
  TBaseDebouncedEvent=class(TComponent)

  private
    FInterval: Integer;
    FLastcallTimestamp: TDateTime;
    FSender: TObject;
    FTimer: TTimer;
    procedure DoOnTimer(Sender: TObject); virtual; abstract;
  protected
    property Interval: Integer read FInterval write FInterval;
    property LastcallTimestamp: TDateTime read FLastcallTimestamp write
        FLastcallTimestamp;
    property Sender: TObject read FSender write FSender;
    property Timer: TTimer read FTimer write FTimer;
  public
    constructor Create(AOwner: TComponent);
  end;

  TDebouncedEvent = class (TBaseDebouncedEvent)
  private
    FSourceEvent: TNotifyEvent;
    procedure DebouncedEvent(Sender: TObject);
    procedure DoCallEvent(Sender: TObject);
    procedure DoOnTimer(Sender: TObject); override;
  protected
    constructor Create(AOwner: TComponent; ASourceEvent: TNotifyEvent; AInterval:
        integer); reintroduce;
  public
    class function Wrap(ASourceEvent: TNotifyEvent; AInterval: integer; AOwner:
        TComponent): TNotifyEvent;
  end;

  TDebouncedKeyEvent = class (TBaseDebouncedEvent)

  private
    FKey: Word;
    FShift: TShiftState;
    FSourceEvent: TKeyEvent;
    procedure DebouncedEvent(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DoCallEvent(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DoOnTimer(Sender: TObject); override;
  protected
  public
    constructor Create(AOwner: TComponent; ASourceEvent: TKeyEvent; AInterval:
        integer); reintroduce;
    class function Wrap(ASourceEvent: TKeyEvent; AInterval: integer; AOwner:
        TComponent): TKeyEvent;
  end;

  TDebouncedKeyPressEvent=class(TBaseDebouncedEvent)

  private
    FKey: Char;
    FSourceEvent: TKeyPressEvent;
    procedure DebouncedEvent(Sender: TObject; var Key: Char);
    procedure DoCallEvent(Sender: TObject; var Key: Char);
    procedure DoOnTimer(Sender: TObject); override;
    property SourceEvent: TKeyPressEvent read FSourceEvent write FSourceEvent;
  protected
    property Key: Char read FKey write FKey;
  public
    constructor Create(AOwner: TComponent; ASourceEvent: TKeyPressEvent; AInterval:
        integer); reintroduce;
    class function Wrap(ASourceEvent: TKeyPressEvent; AInterval: integer; AOwner:
        TComponent): TKeyPressEvent;
  end;

  TDebouncedDatasetEvent = class(TBaseDebouncedEvent)
  private
    FDataset: TDataSet;
    FSourceEvent: TDataSetNotifyEvent;
    procedure DebouncedEvent(Dataset: TDataSet);
    procedure DoCallEvent(var Dataset: TDataSet);
    procedure DoOnTimer(Sender: TObject); override;
    property SourceEvent: TDataSetNotifyEvent read FSourceEvent write FSourceEvent;
  protected
    property Dataset: TDataSet read FDataset write FDataset;
  public
    constructor Create(AOwner: TComponent; ASourceEvent: TDataSetNotifyEvent;
        AInterval: integer); reintroduce;
    class function Wrap(ASourceEvent: TDataSetNotifyEvent; AInterval: integer;
        AOwner: TComponent): TDataSetNotifyEvent;
  end;

implementation

{ TDebouncedEvent }

constructor TDebouncedEvent.Create(AOwner: TComponent; ASourceEvent:
    TNotifyEvent; AInterval: integer);
begin
  inherited Create(AOwner);
  self.FSourceEvent := ASourceEvent;
  self.Interval := AInterval;

  self.Timer.Interval := Interval;
  self.Timer.OnTimer := self.DoOnTimer;
end;

procedure TDebouncedEvent.DebouncedEvent(Sender: TObject);
var
  Between: int64;
begin
  Between := MilliSecondsBetween(Now, self.LastcallTimestamp);

  // if timer is not enabled, it means that last call happened
  // earlier than <self.FInteval> milliseconds ago
  if Between >= self.Interval then begin
    self.DoCallEvent(Sender);
  end
  else begin
    // adjusting timer, so interval between calls will never be more than <FInterval> ms
    self.Timer.Interval := self.Interval - Between;

    // reset the timer
    self.Timer.Enabled := false;
    self.Timer.Enabled := true;

    // remember last Sender argument value to use it in a delayed call
    self.Sender := Sender;
  end;
end;

procedure TDebouncedEvent.DoCallEvent(Sender: TObject);
begin
  self.LastcallTimestamp := Now;
  self.FSourceEvent(Sender);
end;

procedure TDebouncedEvent.DoOnTimer(Sender: TObject);
begin
  self.Timer.Enabled := false;
  self.DoCallEvent(self.Sender);
end;

class function TDebouncedEvent.Wrap(ASourceEvent: TNotifyEvent; AInterval:
    integer; AOwner: TComponent): TNotifyEvent;
begin
  Result := TDebouncedEvent.Create(AOwner, ASourceEvent, AInterval).DebouncedEvent;
end;

{ TDebouncedKeyEvent }

constructor TDebouncedKeyEvent.Create(AOwner: TComponent; ASourceEvent:
    TKeyEvent; AInterval: integer);
begin
  inherited Create(AOwner);
  self.FSourceEvent := ASourceEvent;
  self.Interval := AInterval;

  self.Timer.Interval := AInterval;
  self.Timer.OnTimer := self.DoOnTimer;
end;

procedure TDebouncedKeyEvent.DebouncedEvent(Sender: TObject; var Key: Word;
    Shift: TShiftState);
var
  Between: int64;
begin
  Between := MilliSecondsBetween(Now, self.LastcallTimestamp);

  // if timer is not enabled, it means that last call happened
  // earlier than <self.FInteval> milliseconds ago
  if Between >= self.Interval then begin
    self.DoCallEvent(Sender,Key,Shift);
  end
  else begin
    // adjusting timer, so interval between calls will never be more than <FInterval> ms
    self.Timer.Interval := self.Interval - Between;

    // reset the timer
    self.Timer.Enabled := false;
    self.Timer.Enabled := true;

    // remember last Sender argument value to use it in a delayed call
    self.Sender := Sender;
  end;
end;

procedure TDebouncedKeyEvent.DoCallEvent(Sender: TObject; var Key: Word; Shift:
    TShiftState);
begin
  self.LastcallTimestamp := Now;
  self.FSourceEvent(Sender,Key,Shift);
end;

procedure TDebouncedKeyEvent.DoOnTimer(Sender: TObject);
begin
  self.Timer.Enabled := false;
  self.DoCallEvent(self.Sender,Self.FKey,Self.FShift);
end;

class function TDebouncedKeyEvent.Wrap(ASourceEvent: TKeyEvent; AInterval:
    integer; AOwner: TComponent): TKeyEvent;
begin
  Result := TDebouncedKeyEvent.Create(AOwner, ASourceEvent, AInterval).DebouncedEvent;
end;

{ TDebouncedKeyPressEvent }

constructor TDebouncedKeyPressEvent.Create(AOwner: TComponent; ASourceEvent:
    TKeyPressEvent; AInterval: integer);
begin
  inherited Create(AOwner);
  self.SourceEvent := ASourceEvent;
  self.Interval := AInterval;

  self.Timer.Interval := AInterval;
  self.Timer.OnTimer := self.DoOnTimer;
end;

procedure TDebouncedKeyPressEvent.DebouncedEvent(Sender: TObject; var Key:
    Char);
var
  Between: int64;
begin
  Between := MilliSecondsBetween(Now, self.LastcallTimestamp);

  // if timer is not enabled, it means that last call happened
  // earlier than <self.FInteval> milliseconds ago
  if Between >= self.Interval then begin
    self.DoCallEvent(Sender,Key);
  end
  else begin
    // adjusting timer, so interval between calls will never be more than <FInterval> ms
    self.Timer.Interval := self.Interval - Between;

    // reset the timer
    self.Timer.Enabled := false;
    self.Timer.Enabled := true;

    // remember last Sender argument value to use it in a delayed call
    self.Sender := Sender;
  end;
end;

procedure TDebouncedKeyPressEvent.DoCallEvent(Sender: TObject; var Key: Char);
begin
  self.LastcallTimestamp := Now;
  self.FSourceEvent(Sender,Key);
end;

procedure TDebouncedKeyPressEvent.DoOnTimer(Sender: TObject);
begin
  self.Timer.Enabled := false;
  self.DoCallEvent(self.Sender,Self.FKey);
end;

class function TDebouncedKeyPressEvent.Wrap(ASourceEvent: TKeyPressEvent;
    AInterval: integer; AOwner: TComponent): TKeyPressEvent;
begin
  Result := TDebouncedKeyPressEvent.Create(AOwner, ASourceEvent, AInterval).DebouncedEvent;
end;

constructor TBaseDebouncedEvent.Create(AOwner: TComponent);
begin
  inherited;
  self.Timer := TTimer.Create(self);
  self.Timer.Enabled := false;
end;

{ TDebouncedDatasetEvent }

constructor TDebouncedDatasetEvent.Create(AOwner: TComponent; ASourceEvent:
    TDataSetNotifyEvent; AInterval: integer);
begin
  inherited Create(AOwner);
  self.SourceEvent := ASourceEvent;
  self.Interval := AInterval;

  self.Timer.Interval := AInterval;
  self.Timer.OnTimer := self.DoOnTimer;
end;

procedure TDebouncedDatasetEvent.DebouncedEvent(Dataset: TDataSet);
var
  Between: int64;
begin
  Between := MilliSecondsBetween(Now, self.LastcallTimestamp);

  // if timer is not enabled, it means that last call happened
  // earlier than <self.FInteval> milliseconds ago
  if Between >= self.Interval then begin
    self.DoCallEvent(Dataset);
  end
  else begin
    // adjusting timer, so interval between calls will never be more than <FInterval> ms
    self.Timer.Interval := self.Interval - Between;

    // reset the timer
    self.Timer.Enabled := false;
    self.Timer.Enabled := true;

    // remember last Sender argument value to use it in a delayed call
    self.Sender := Sender;
  end;
end;

procedure TDebouncedDatasetEvent.DoCallEvent(var Dataset: TDataSet);
begin
  self.LastcallTimestamp := Now;
  self.FSourceEvent(self.Dataset);
end;

procedure TDebouncedDatasetEvent.DoOnTimer(Sender: TObject);
begin
  self.Timer.Enabled := false;
  self.DoCallEvent(Self.FDataset);
end;

class function TDebouncedDatasetEvent.Wrap(ASourceEvent: TDataSetNotifyEvent;
    AInterval: integer; AOwner: TComponent): TDataSetNotifyEvent;
begin
  Result := TDebouncedDatasetEvent.Create(AOwner, ASourceEvent, AInterval).DebouncedEvent;
end;

end.
