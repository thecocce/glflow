object GLFlowForm: TGLFlowForm
  Left = 329
  Top = 82
  Caption = 'GLFlow - Powered by Delphi XE2 and GLScene'
  ClientHeight = 592
  ClientWidth = 958
  Color = clBlack
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Arial'
  Font.Style = []
  OldCreateOrder = False
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 14
  object GLSceneViewer: TGLSceneViewer
    Left = 0
    Top = 0
    Width = 958
    Height = 557
    Camera = GLCamera1
    VSync = vsmSync
    Buffer.BackgroundColor = clBlack
    Buffer.Lighting = False
    Buffer.AntiAliasing = aaNone
    Buffer.DepthPrecision = dp16bits
    Buffer.ColorDepth = cd24bits
    FieldOfView = 171.784912109375000000
    Align = alClient
    OnMouseDown = GLSceneViewerMouseDown
    ExplicitTop = -3
  end
  object Panel1: TPanel
    AlignWithMargins = True
    Left = 50
    Top = 557
    Width = 858
    Height = 35
    Margins.Left = 50
    Margins.Top = 0
    Margins.Right = 50
    Margins.Bottom = 0
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object TrackBar: TTrackBar
      Left = 95
      Top = 0
      Width = 763
      Height = 35
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Margins.Bottom = 0
      Align = alClient
      Ctl3D = True
      ParentCtl3D = False
      PageSize = 1
      TabOrder = 0
      TabStop = False
      ThumbLength = 15
      TickMarks = tmBoth
    end
    object BUSelect: TButton
      AlignWithMargins = True
      Left = 0
      Top = 5
      Width = 75
      Height = 25
      Margins.Left = 0
      Margins.Top = 5
      Margins.Right = 20
      Margins.Bottom = 5
      Align = alLeft
      Caption = 'Select...'
      TabOrder = 1
      OnClick = BUSelectClick
    end
  end
  object GLScene1: TGLScene
    VisibilityCulling = vcObjectBased
    Left = 32
    Top = 32
    object DCPics: TGLDummyCube
      CubeSize = 1.000000000000000000
    end
    object GLCamera1: TGLCamera
      DepthOfView = 100.000000000000000000
      FocalLength = 20.000000000000000000
      SceneScale = 19.000000000000000000
      TargetObject = DCPics
      Position.Coordinates = {0000000000000000000010410000803F}
    end
  end
  object GLMaterialLibrary: TGLMaterialLibrary
    Left = 120
    Top = 32
  end
  object GLCadencer1: TGLCadencer
    Scene = GLScene1
    SleepLength = 10
    OnProgress = GLCadencer1Progress
    Left = 32
    Top = 80
  end
  object OpenDialog1: TOpenDialog
    Filter = 'JPEg images (*.jpg)|*.jpg'
    Left = 88
    Top = 144
  end
end
