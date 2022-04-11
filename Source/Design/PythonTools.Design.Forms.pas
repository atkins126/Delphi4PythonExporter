unit PythonTools.Design.Forms;

interface

uses
  System.SysUtils, System.Variants, System.Classes,
  Data.DB, Datasnap.DBClient, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.Buttons, Vcl.Imaging.pngimage,
  Vcl.ExtCtrls, Vcl.Controls, Vcl.Forms, System.Types,
  PythonTools.Design, PythonTools.Model.Design.Forms;

{$WARN SYMBOL_PLATFORM OFF}

type
  TDBGrid = class(Vcl.DBGrids.TDBGrid)
  protected
    procedure DrawCell(ACol, ARow: Longint; ARect: TRect; AState: TGridDrawState); override;
  end;

  TFormsExportDialog = class(TDesignForm)
    FileOpenDialog1: TFileOpenDialog;
    pnlHeader: TPanel;
    imgExport: TImage;
    lblDescription: TLabel;
    lblExport: TLabel;
    spHeader: TShape;
    pnlContents: TPanel;
    pnlAppDir: TPanel;
    lblApplicationDirectory: TLabel;
    edtDirectory: TEdit;
    plnFooter: TPanel;
    btnCancel: TButton;
    btnExport: TButton;
    pnlGrid: TPanel;
    grForms: TDBGrid;
    cdsForms: TClientDataSet;
    dsForms: TDataSource;
    cdsFormsFL_EXPORT: TBooleanField;
    cdsFormsDESC_FORM: TStringField;
    cdsFormsTITLE: TStringField;
    cdsFormsFL_INITIALIZE: TBooleanField;
    cdsFormsFL_FORM_FILE_KIND: TStringField;
    btnSelectDir: TButton;
    llblNotification: TLinkLabel;
    cbShowExportedFiles: TCheckBox;
    procedure btnExportClick(Sender: TObject);
    procedure btnSelectDirClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure grFormsKeyPress(Sender: TObject; var Key: Char);
    procedure grFormsCellClick(Column: TColumn);
    procedure cdsFormsFL_EXPORTGetText(Sender: TField; var Text: string;
      DisplayText: Boolean);
    procedure grFormsColEnter(Sender: TObject);
    procedure cdsFormsFL_INITIALIZEGetText(Sender: TField; var Text: string;
      DisplayText: Boolean);
    procedure grFormsTitleClick(Column: TColumn);
    procedure grFormsDrawColumnCell(Sender: TObject; const Rect: TRect;
      DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure llblNotificationLinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
  public
    function Execute(const AModel: TExportFormsDesignModel): boolean;
  end;

var
  FormsExportDialog: TFormsExportDialog;

implementation

uses
  System.Generics.Collections, System.Math,
  CommCtrl, UxTheme,
  ShellApi,
  Winapi.Windows,
  Vcl.Graphics,
  PythonTools.Common;

{$R *.dfm}

procedure DrawCheckBox(const ADBGrid: TDBGrid; const AColumn: TColumn; ARect: TRect; const AChecked: boolean);
const
  IS_CHECKED: array[boolean] of integer = (DFCS_BUTTONCHECK, DFCS_BUTTONCHECK or DFCS_CHECKED);
var
  LhTheme: Cardinal;
  LSize: TSize;
begin
  ADBGrid.Canvas.FillRect(ARect);
  if UseThemes then begin
    LhTheme := OpenThemeData(ADBGrid.Handle, 'BUTTON');
    if LhTheme <> 0 then
      try
        GetThemePartSize(LhTheme, ADBGrid.Canvas.Handle, BP_CHECKBOX, CBS_CHECKEDNORMAL, nil, TS_DRAW, LSize);
        DrawThemeBackground(LhTheme, ADBGrid.Canvas.Handle, BP_CHECKBOX,
          IfThen(AChecked, CBS_CHECKEDNORMAL, CBS_UNCHECKEDNORMAL),
          ARect, nil);
      finally
        CloseThemeData(LhTheme);
      end;
  end else
    DrawFrameControl(ADBGrid.Canvas.Handle, ARect, DFC_BUTTON, IS_CHECKED[AChecked]);
end;

procedure TFormsExportDialog.btnExportClick(Sender: TObject);
var
  LMark: TArray<Byte>;
  LHasSelection: boolean;
begin
  //Make some validations
  if Trim(edtDirectory.Text) = String.Empty then
    raise Exception.Create('Select the Directory.');

  cdsForms.DisableControls();
  try
    LMark := cdsForms.Bookmark;
    try
      cdsForms.Filter := 'FL_EXPORT = True';
      cdsForms.Filtered := true;
      LHasSelection := not cdsForms.IsEmpty();
      cdsForms.Filtered := false;
    finally
      if cdsForms.BookmarkValid(LMark) then
        cdsForms.Bookmark := LMark;
    end;
  finally
    cdsForms.EnableControls();
  end;

  if not LHasSelection then
    raise Exception.Create('Select one form at least.');

  ModalResult := mrOk;
end;

procedure TFormsExportDialog.btnSelectDirClick(Sender: TObject);
begin
  with FileOpenDialog1 do begin
    DefaultFolder := edtDirectory.Text;
    FileName := edtDirectory.Text;
    if Execute then
      edtDirectory.Text := FileName
    else
      edtDirectory.Text := String.Empty;
  end;
end;

procedure TFormsExportDialog.cdsFormsFL_EXPORTGetText(Sender: TField;
  var Text: string; DisplayText: Boolean);
begin
 Text := ' ';
end;

procedure TFormsExportDialog.cdsFormsFL_INITIALIZEGetText(Sender: TField;
  var Text: string; DisplayText: Boolean);
begin
 Text := ' ';
end;

procedure TFormsExportDialog.grFormsCellClick(Column: TColumn);
begin
  if Column.Field.DataType = ftBoolean then begin
    cdsForms.Edit();
    Column.Field.AsBoolean := not Column.Field.AsBoolean;
    cdsForms.Post();
  end;
end;

procedure TFormsExportDialog.grFormsColEnter(Sender: TObject);
begin
  with Sender as TDBGrid do
    if (SelectedField.DataType = ftBoolean) then
      Options := Options - [dgEditing]
    else
      Options := Options + [dgEditing];
end;

procedure TFormsExportDialog.grFormsDrawColumnCell(Sender: TObject;
  const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
begin
  inherited;
  if Column.Field.DataType = ftBoolean then
    DrawCheckBox(TDBGrid(Sender), Column, Rect, Column.Field.AsBoolean);
end;

procedure TFormsExportDialog.grFormsKeyPress(Sender: TObject; var Key: Char);
begin
  if (key = Chr(9)) then
    Exit;

  with Sender as TDBGrid do
    if Assigned(SelectedField) and (Ord(Key) in [VK_RETURN, VK_SPACE]) then begin
      cdsForms.Edit();
      SelectedField.AsBoolean := not SelectedField.AsBoolean;
      cdsForms.Post();
    end;
end;

procedure TFormsExportDialog.grFormsTitleClick(Column: TColumn);
var
  LMark: TArray<Byte>;
begin
  if Column.Field.DataType = ftBoolean then begin
    Column.Field.Tag := Integer(not Boolean(Column.Field.Tag));

    cdsForms.DisableControls();
    try
      LMark := cdsForms.Bookmark;
      try
        cdsForms.First();
        while not cdsForms.Eof do begin
          cdsForms.Edit();
          Column.Field.AsBoolean := Boolean(Column.Field.Tag);
          cdsForms.Post();
          cdsForms.Next();
        end;
      finally
        if cdsForms.BookmarkValid(LMark) then
          cdsForms.Bookmark := LMark;
      end;
    finally
      cdsForms.EnableControls();
    end;
  end;
end;

procedure TFormsExportDialog.llblNotificationLinkClick(Sender: TObject;
  const Link: string; LinkType: TSysLinkType);
begin
  ShellExecute(0, 'open', pchar(Link), nil, nil, SW_NORMAL);
end;

function TFormsExportDialog.Execute(const AModel: TExportFormsDesignModel): boolean;
var
  LInput: TInputForm;
  LOutput: TList<TOutputForm>;
begin
  edtDirectory.Text := AModel.Directory;
  cbShowExportedFiles.Checked := AModel.ShowInExplorer;

  cdsForms.EmptyDataSet();
  for LInput in AModel.InputForms do begin
    cdsForms.AppendRecord([
      true,
      LInput.Form.CombineFileAndFormName(),
      LInput.Title,
      True,
      TFormFileKind.ffkText.ToString()
    ]);
  end;
  cdsForms.First();

  with grForms do
    if SelectedField.DataType = ftBoolean then
      Options := Options - [dgEditing];

  Result := ShowModal() = mrOk;

  if not Result then
    Exit();

  AModel.Directory := edtDirectory.Text;
  Amodel.ShowInExplorer := cbShowExportedFiles.Checked;

  LOutput := TList<TOutputForm>.Create();
  try
    cdsForms.DisableControls();
    try
      cdsForms.First();
      for LInput in AModel.InputForms do begin
        if cdsForms.Locate('DESC_FORM', LInput.Form.CombineFileAndFormName(), []) then begin
          if not cdsFormsFL_EXPORT.AsBoolean then
            Continue;
          LOutput.Add(TOutputForm.Create(
            LInput.Form,
            cdsFormsFL_INITIALIZE.AsBoolean,
            cdsFormsTITLE.AsString,
            TFormFileKind.FromString(cdsFormsFL_FORM_FILE_KIND.AsString)
          ));
        end;
      end;
    finally
      cdsForms.EnableControls();
    end;
    AModel.OutputForms := LOutput.ToArray();
  finally
    LOutput.Free();
  end;
end;

procedure TFormsExportDialog.FormCreate(Sender: TObject);
begin
  inherited;
  cdsForms.CreateDataSet();
end;

{ TDBGrid }

procedure TDBGrid.DrawCell(ACol, ARow: Longint; ARect: TRect;
  AState: TGridDrawState);
var
  LRect: TRect;
  LChecked: Boolean;
begin
  inherited;
  Dec(ARow);
  if ARow < 0 then
    if Columns[ACol].Field.DataType = ftBoolean then begin
      LRect := ARect;
      LRect.Right := LRect.Right - Canvas.TextWidth(Columns[ACol].Title.Caption) - 25;
      LChecked := Boolean(Columns[ACol].Field.Tag);
      DrawCheckBox(Self, Columns[ACol], LRect, LChecked);
    end;
end;

end.
