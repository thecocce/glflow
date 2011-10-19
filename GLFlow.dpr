program GLFlow;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

uses
  Forms,
  FGLFlow in 'FGLFlow.pas' {GLFlowForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
//  TStyleManager.TrySetStyle('Ruby Graphite');
  Application.CreateForm(TGLFlowForm, GLFlowForm);
  Application.Run;
end.
