unit FGLFlow;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, GLCrossPlatform, GLMisc, GLScene, GLWin32Viewer, dwsXPlatform,
  JPeg, GLTexture, GLGraphics, VectorGeometry, GLUtils, GLCadencer,
  GLMesh, GLColor, ComCtrls, GLObjects, ExtCtrls, StdCtrls;

type

  TGLFlowForm = class(TForm)
    GLScene1: TGLScene;
    GLSceneViewer: TGLSceneViewer;
    GLMaterialLibrary: TGLMaterialLibrary;
    DCPics: TGLDummyCube;
    GLCamera1: TGLCamera;
    GLCadencer1: TGLCadencer;
    Panel1: TPanel;
    TrackBar: TTrackBar;
    BUSelect: TButton;
    OpenDialog1: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure GLSceneViewerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLCadencer1Progress(Sender: TObject; const deltaTime,
      newTime: Double);
    procedure TrackBarChange(Sender: TObject);
    procedure BUSelectClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    { Private declarations }
    FTargetPosition, FPosition : Double;
    FLoader : TThread;
    procedure LoadFolder(const folder : String);
    procedure LoaderTerminated;
  public
    { Public declarations }
    procedure UpdateCoversPositions;
  end;

var
  GLFlowForm: TGLFlowForm;

implementation

{$R *.dfm}

const
   cTargetWidth = 400;
   cTargetHeight = 270;

type
   TMethod = procedure of object;

   TBackgroundLoader = class(TThread)
      FPics : TStringList;
      FJPGImage : TJPEGImage;
      FBitmap : TBitmap;
      FCurrent : Integer;
      FDestination : TGLBaseSceneObject;
      FMaterialLibrary : TGLMaterialLibrary;
      FOnAfterAddMesh : TMethod;
      FOnTerminate : TMethod;
      FCurrentWidth, FCurrentHeight : Integer;

      constructor Create(const folder : String; destination : TGLBaseSceneObject;
                         materialLibray : TGLMaterialLibrary);
      destructor Destroy; override;

      function LoadNext : Boolean;
      procedure AddMesh;
      procedure Abort;

      procedure Execute; override;
   end;

type
   TJPEGImageCracker = class (TJPEGImage); // see TBackgroundLoader.LoadNext

constructor TBackgroundLoader.Create(const folder : String; destination : TGLBaseSceneObject;
                                     materialLibray : TGLMaterialLibrary);
begin
   inherited Create(True);

   FDestination:=destination;
   FMaterialLibrary:=materialLibray;

   FPics:=TStringList.Create;
   CollectFiles(folder, '*.jpg', FPics);

   FJPGImage:=TJPEGImage.Create;
   FJPGImage.Performance:=jpBestSpeed;

   FBitmap:=TBitmap.Create;
   FBitmap.Canvas.Brush.Color:=clBlack;
   FBitmap.PixelFormat:=pf32bit;
end;

destructor TBackgroundLoader.Destroy;
begin
   inherited;
   FPics.Free;
   FJPGImage.Free;
   FBitmap.Free;
   if Assigned(FOnTerminate) then
      FOnTerminate();
end;

procedure TBackgroundLoader.Execute;
begin
   while LoadNext do
      Synchronize(AddMesh);
   FreeOnTerminate:=not Terminated;
end;

function TBackgroundLoader.LoadNext : Boolean;
var
   fileName : String;
begin
   if Terminated or (FCurrent>=FPics.Count) then
      Exit(False);

   fileName:=FPics[FCurrent];
   Inc(FCurrent);

   // Load the JPEG image
   FJPGImage.LoadFromFile(fileName);
   FCurrentWidth:=FJPGImage.Width;
   FCurrentHeight:=FJPGImage.Height;

   // Use built-in JPEG ability to downsize large bitmaps to what we need
   case MaxInteger(FCurrentWidth div cTargetWidth, FCurrentHeight div cTargetHeight) of
      0..1 :
         FJPGImage.Scale:=jsFullSize;
      2..3 : begin
         FCurrentWidth:=FCurrentWidth div 2;
         FCurrentHeight:=FCurrentHeight div 2;
         FJPGImage.Scale:=jsHalf;
      end;
      4..7 : begin
         FCurrentWidth:=FCurrentWidth div 4;
         FCurrentHeight:=FCurrentHeight div 4;
         FJPGImage.Scale:=jsQuarter;
      end;
   else
      FCurrentWidth:=FCurrentWidth div 8;
      FCurrentHeight:=FCurrentHeight div 8;
      FJPGImage.Scale:=jsEighth;
   end;

   // reserve 1 pixel margin at borders (prettier)
   Inc(FCurrentWidth, 2);
   Inc(FCurrentHeight, 2);

   // prepare texture bitmap
   FBitmap.Height:=RoundUpToPowerOf2(FCurrentHeight);
   FBitmap.Width:=RoundUpToPowerOf2(FCurrentWidth);

   // manual lock necessary to workaround TJPEGImage.Draw() ages-old bug
   FBitmap.Canvas.Lock;
   TJPEGImageCracker(FJPGImage).Bitmap.Canvas.Lock;
   try
      FBitmap.Canvas.FillRect(FBitmap.Canvas.ClipRect);
      FBitmap.Canvas.StretchDraw(Rect(1, FBitmap.Height-FCurrentHeight,
                                      FCurrentWidth-1, FBitmap.Height-1),
                                 FJPGImage);
   finally
      TJPEGImageCracker(FJPGImage).Bitmap.Canvas.Unlock;
      FBitmap.Canvas.Unlock;
   end;

   Result:=True;
end;

procedure TBackgroundLoader.AddMesh;
var
   material : TGLLibMaterial;
   picImage : TGLPersistentImage;
   texture : TGLTexture;
   mesh : TGLMesh;
begin
   if Terminated then Exit;

   // prepare material
   material:=FMaterialLibrary.Materials.Add;
   material.Name:=IntToStr(FCurrent);
   material.TextureScale.X:=FCurrentWidth/FBitmap.Width;
   material.TextureScale.Y:=FCurrentHeight/FBitmap.Height;

   texture:=material.Material.Texture;

   texture.FilteringQuality:=tfAnisotropic;
   texture.Enabled:=True;
   texture.TextureWrap:=twNone;
   texture.TextureMode:=tmModulate;
   texture.TextureFormat:=tfRGB;

   picImage:=texture.Image as TGLPersistentImage;
   picImage.Picture.Bitmap:=FBitmap;

   // prepare mesh for each picture
   // fully lit at the top, mirrored and modulated away at the bottom
   mesh:=TGLMesh(FDestination.AddNewChild(TGLMesh));
   mesh.Mode:=mmTriangleStrip;
   mesh.Vertices.Clear;
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5,  0.5, 0), ZVector, clrWhite, TexPointMake(1, 1));
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5,  0.5, 0), ZVector, clrWhite, TexPointMake(0, 1));
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5, -0.16, 0), ZVector, clrWhite, TexPointMake(1, 0));
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.16, 0), ZVector, clrWhite, TexPointMake(0, 0));
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.16, 0), ZVector, clrWhite, TexPointMake(0, 0)); // degenerate triangle
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.16, 0), ZVector, clrGray70, TexPointMake(0, 0));
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5, -0.16, 0), ZVector, clrGray70, TexPointMake(1, 0));
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.6, 0), ZVector, clrTransparent, TexPointMake(0, 0.66));
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5, -0.6, 0), ZVector, clrTransparent, TexPointMake(1, 0.66));
   mesh.Material.MaterialLibrary:=FMaterialLibrary;
   mesh.Material.LibMaterialName:=material.Name;
   mesh.Tag:=FCurrent-1;

   if Assigned(FOnAfterAddMesh) then
      FOnAfterAddMesh();
end;

// Abort
//
procedure TBackgroundLoader.Abort;
begin
   if Self=nil then Exit;
   Terminate;
   WaitFor;
   Free;
end;

procedure TGLFlowForm.FormCreate(Sender: TObject);
begin
   // default to samples FPics from the FireMonkey sample
   LoadFolder('C:\Users\Public\Documents\RAD Studio\9.0\Samples\FireMonkey\FireFlow\Demo Photos\');
end;

procedure TGLFlowForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
   TBackgroundLoader(FLoader).Abort;
end;

procedure TGLFlowForm.LoadFolder(const folder : String);
var
   loader : TBackgroundLoader;
begin
   loader:=TBackgroundLoader.Create(folder, DCPics, GLMaterialLibrary);
   FLoader:=loader;
   loader.FOnAfterAddMesh:=UpdateCoversPositions;
   loader.FOnTerminate:=LoaderTerminated;

   TrackBar.Position:=0;
   TrackBar.Max:=loader.FPics.Count-1;
   FPosition:=FTargetPosition;

   FLoader.Start;
end;

procedure TGLFlowForm.LoaderTerminated;
begin
   FLoader:=nil;
end;

procedure TGLFlowForm.BUSelectClick(Sender: TObject);
begin
   if OpenDialog1.Execute then begin
      TBackgroundLoader(FLoader).Abort;
      DCPics.DeleteChildren;
      GLMaterialLibrary.Materials.Clear;
      LoadFolder(ExtractFilePath(OpenDialog1.FileName));
   end;
end;

procedure TGLFlowForm.UpdateCoversPositions;
var
   i : Integer;
   delta : Single;
   obj : TGLBaseSceneObject;
begin
   for i:=0 to DCPics.Count-1 do begin
      delta:=i-FPosition;
      obj:=DCPics.Children[i];
      obj.TurnAngle:=-65*ClampValue(delta, -1, 1);
      obj.Position.X:=Sqrt(Abs(delta))*Sign(delta);
      obj.Position.Z:=8/(Sqr(obj.position.X)+1)-6;
   end;
end;

procedure TGLFlowForm.GLCadencer1Progress(Sender: TObject; const deltaTime,
  newTime: Double);
begin
   if Abs(FPosition-FTargetPosition)>1e-5 then begin
      FPosition:=Lerp(FPosition, FTargetPosition,
                      ClampValue(0.3/Abs(FTargetPosition-FPosition), 0.02, 0.5));
      UpdateCoversPositions;
   end;
end;

procedure TGLFlowForm.GLSceneViewerMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
   pick : TGLBaseSceneObject;
begin
   pick:=GLSceneViewer.Buffer.GetPickedObject(x, y);
   if pick<>nil then
      TrackBar.Position:=pick.Tag;
end;

procedure TGLFlowForm.TrackBarChange(Sender: TObject);
begin
   FTargetPosition:=TrackBar.Position;
end;

end.
