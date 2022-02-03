unit PythonTools.Menu.ExportProject;

interface

uses
  DesignIntf, ToolsAPI, System.Classes, Vcl.ActnList, Vcl.Menus,
  PythonTools.Producer, PythonTools.Exceptions, Vcl.Dialogs;

type
  TPythonToolsExportProjectMenuAction = class(TCustomAction)
  private
    procedure DoExportProject(Sender: TObject);
    function FindComponents(const ADesigner: IDesigner): TArray<TComponent>;
    function RequestDirectory(var ADir: string): boolean;
    function BuildModel(const AProject: IOTAProject;
      const AModuleInfo: IOTAModuleInfo;
      const AFormDesigner: IDesigner): TFormProducerModel;
    procedure ExportForm(const ADir: string; const AProject: IOTAProject;
      const AModuleInfo: IOTAModuleInfo);
  public
    constructor Create(AOwner: TComponent); override;

    function Update: boolean; override;
  end;

  TPythonToolsExportProjectMenuItem = class(TMenuItem)
  public
    procedure AfterConstruction(); override;
  end;

implementation

uses
  System.SysUtils, System.StrUtils,
  PythonTools.IOTAUtils, PythonTools.Producer.SimpleFactory;

{ TPythonToolsExportProjectMenuAction }

constructor TPythonToolsExportProjectMenuAction.Create(AOwner: TComponent);
begin
  inherited;
  Name := 'PythonToolsExportProjectAction';
  Caption := 'Export Current Project';
  OnExecute := DoExportProject;
end;

function TPythonToolsExportProjectMenuAction.Update: boolean;
begin
  Enabled := Assigned(GetActiveProject());
  Result := inherited;
end;

function TPythonToolsExportProjectMenuAction.FindComponents(
  const ADesigner: IDesigner): TArray<TComponent>;
begin
  var LIOTAUtils := TIOTAUtils.Create();
  try
    Result := LIOTAUtils.FindComponents(ADesigner);
  finally
    LIOTAUtils.Free();
  end;
end;

function TPythonToolsExportProjectMenuAction.RequestDirectory(
  var ADir: string): boolean;
begin
  with TFileOpenDialog.Create(nil) do
    try
      Title := 'Select Directory';
      Options := [fdoPickFolders, fdoPathMustExist, fdoForceFileSystem];
      OkButtonLabel := 'Select';
      DefaultFolder := ADir;
      FileName := ADir;
      Result := Execute;
      if Result then
        ADir := FileName;
    finally
      Free();
    end
end;

function TPythonToolsExportProjectMenuAction.BuildModel(
  const AProject: IOTAProject; const AModuleInfo: IOTAModuleInfo;
  const AFormDesigner: IDesigner): TFormProducerModel;
begin
  Result := TFormProducerModel.Create();
  try
    with Result do begin
      FormName := AModuleInfo.FormName;
      FormParentName := System.Copy(
        AFormDesigner.Root.ClassParent.ClassName,
        2,
        AFormDesigner.Root.ClassParent.ClassName.Length);
      FileName := ChangeFileExt(ExtractFileName(AModuleInfo.FileName), '');
      ExportedComponents := FindComponents(AFormDesigner);
      with ModelInitialization do begin
        GenerateInitialization := false;
      end;
    end;
  except
    on E: Exception do begin
      FreeAndNil(Result);
      raise;
    end;
  end;
end;

procedure TPythonToolsExportProjectMenuAction.DoExportProject(Sender: TObject);
begin
  //Get the current project
  var LProject := GetActiveProject();
  //Request the directory where files will be saved
  var LDir := ExtractFileDir(LProject.FileName);
  if not RequestDirectory(LDir) then
    Exit;
  //Navigate through all forms
  for var I := 0 to LProject.GetModuleCount() - 1 do begin
    var LModuleInfo := LProject.GetModule(I);
    if (LModuleInfo.ModuleType = omtForm) then begin
      if not LModuleInfo.FormName.Trim().IsEmpty() then begin
        ExportForm(LDir, LProject, LModuleInfo);
      end;
    end;
  end;
end;

procedure TPythonToolsExportProjectMenuAction.ExportForm(const ADir: string;
  const AProject: IOTAProject; const AModuleInfo: IOTAModuleInfo);
begin
  var LModule := AModuleInfo.OpenModule();
  var LFormEditor := TIOTAUtils.GetFormEditorFromModule(LModule);
  var LFormDesigner := (LFormEditor as INTAFormEditor).FormDesigner;
  if Assigned(LFormDesigner) then begin
    var LProducer := TProducerSimpleFactory.CreateProducer(AProject.FrameworkType);
    if not LProducer.IsValidFormInheritance(LFormDesigner.Root.ClassParent) then
      raise EFormInheritanceNotSupported.CreateFmt(
        '%s TForm direct inheritance only', [AProject.FrameworkType]);

    var LProducerModel := BuildModel(AProject, AModuleInfo, LFormDesigner);
    try
      LProducerModel.Directory := ADir;
      LProducer.SavePyFile(LProducerModel);
    finally
      LProducerModel.Free();
    end;
  end else
    raise EUnableToObtainFormDesigner.CreateFmt(
      'Unable to obtain the form designer for type %s.', [AModuleInfo.FormName]);
end;

{ TPythonToolsExportProjectMenuItem }

procedure TPythonToolsExportProjectMenuItem.AfterConstruction;
begin
  inherited;
  Name := 'PythonToolsExportProjectMenu';
end;

end.
