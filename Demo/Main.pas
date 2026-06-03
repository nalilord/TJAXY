unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

type
  TfrmMain = class(TForm)
    btnTest: TButton;
    mTestOutput: TMemo;
    btnTestJson5: TButton;
    mJson5TestOutput: TMemo;
    procedure btnTestClick(Sender: TObject);
    procedure btnTestJson5Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  TJAXY.Core, TJAXY.JSON;

{$R *.dfm}

procedure TfrmMain.btnTestClick(Sender: TObject);
var
  JSON: TJSON;
  Items: TTJAXYArray;
begin
  mTestOutput.Clear;

  JSON:=TJSON.CreateObjectRoot;
  try
    JSON.AsObject.Add('int', 1337);
    JSON.AsObject.Add('float', 3.14);
    JSON.AsObject.Add('str', 'fooBar');
    JSON.AsObject.Add('bool', True);
    Items:=JSON.AsObject.AddArray('arr');
    Items.Add(1);
    Items.Add(2);
    Items.Add(3);
    Items.Add(4);
    mTestOutput.Lines.Text:=JSON.WriteToString(tjaxywmReadable);
  finally
    JSON.Free;
  end;

  JSON:=TJSON.CreateFromString(mTestOutput.Lines.Text);
  try
    mTestOutput.Lines.Add('----------');

    mTestOutput.Lines.Add('Count: ' + IntToStr(JSON.AsObject.Count));

    mTestOutput.Lines.Add('  int: ' + IntToStr(JSON.AsObject['int'].AsInteger));
    mTestOutput.Lines.Add('  float: ' + FloatToStr(JSON.AsObject['float'].AsFloat));
    mTestOutput.Lines.Add('  str: ' + JSON.AsObject['str'].AsString);
    mTestOutput.Lines.Add('  bool: ' + BoolToStr(JSON.AsObject['bool'].AsBoolean, True));
  finally
    FreeAndNil(JSON);
  end;
end;

procedure TfrmMain.btnTestJson5Click(Sender: TObject);
var
  JSON: TJSON;
begin
  JSON:=TJSON.CreateFromFile('.\test.json5', jeJSON5);
  try
  finally
    FreeAndNil(JSON);
  end;
end;

end.
