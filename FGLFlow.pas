unit FGLFlow;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  GLCrossPlatform, GLMisc, GLScene, GLWin32Viewer, IOUtils, Types,
  JPeg, GLTexture, GLGraphics, VectorGeometry, GLUtils, GLCadencer,
  GLMesh, GLColor, ComCtrls, GLObjects, Dialogs, StdCtrls, ExtCtrls;

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
    procedure GLSceneViewerMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure GLCadencer1Progress(Sender: TObject; const deltaTime,
      newTime: Double);
    procedure BUSelectClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FPosition : Single;
    FLoader : TThread;
    procedure LoadFolder(const folder : String);
    procedure UpdateCoversPositions;
  end;

var
  GLFlowForm: TGLFlowForm;

implementation

{$R *.dfm}

const
   cTargetSize = 400;

type
   TBackgroundLoader = class(TThread)
      FPics : TStringDynArray;
      FJPGImage : TJPEGImage;
      FBitmap : TBitmap;
      FDestination : TGLBaseSceneObject;
      FMaterialLibrary : TGLMaterialLibrary;
      FOnAfterAddMesh, FOnTerminate : TProc;
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

   FPics:=TDirectory.GetFiles(folder, '*.jpg');

   FJPGImage:=TJPEGImage.Create;
   FJPGImage.Performance:=jpBestSpeed;

   FBitmap:=TBitmap.Create;
   FBitmap.Canvas.Brush.Color:=clBlack;
   FBitmap.PixelFormat:=pf32bit;
end;

destructor TBackgroundLoader.Destroy;
begin
   // custom event as we can't use OnTerminated reliably (design issue in RTL)
   if Assigned(FOnTerminate) then
      FOnTerminate();
   FJPGImage.Free;
   FBitmap.Free;
   inherited;
end;

procedure TBackgroundLoader.Execute;
begin
   while (not Terminated) and LoadNext do
      Synchronize(AddMesh);
   FreeOnTerminate:=not Terminated;
end;

function TBackgroundLoader.LoadNext : Boolean;
begin
   if FDestination.Count>High(FPics) then Exit(False);

   // Load the JPEG image
   FJPGImage.LoadFromFile(FPics[FDestination.Count]);

   FCurrentWidth:=FJPGImage.Width;
   FCurrentHeight:=FJPGImage.Height;

   // Use built-in JPEG ability to downsize large bitmaps to what we need
   case MinInteger(FCurrentWidth div cTargetSize, FCurrentHeight div cTargetSize) of
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

   // prepare texture bitmap (with 1 pixel margin at borders, prettier)
   FBitmap.Height:=RoundUpToPowerOf2(FCurrentHeight+2);
   FBitmap.Width:=RoundUpToPowerOf2(FCurrentWidth+2);

   // manual lock necessary to workaround TJPEGImage.Draw() ages-old bug
   FBitmap.Canvas.Lock;
   TJPEGImageCracker(FJPGImage).Bitmap.Canvas.Lock;
   try
      FBitmap.Canvas.FillRect(FBitmap.Canvas.ClipRect);
      FBitmap.Canvas.StretchDraw(Rect(1, FBitmap.Height-FCurrentHeight-2,
                                      FCurrentWidth+1, FBitmap.Height-1),
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
   material.Name:=IntToStr(FDestination.Count);
   material.TextureScale.X:=(FCurrentWidth+2)/FBitmap.Width;
   material.TextureScale.Y:=(FCurrentHeight+2)/FBitmap.Height;

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
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5,  0.5 , 0), ZVector, clrWhite,  XYTexPoint);
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5,  0.5 , 0), ZVector, clrWhite,  YTexPoint);
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5, -0.16, 0), ZVector, clrWhite,  XTexPoint);
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.16, 0), ZVector, clrWhite,  NullTexPoint);
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.16, 0), ZVector, clrWhite,  NullTexPoint); // degenerate triangle
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.16, 0), ZVector, clrGray70, NullTexPoint);
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5, -0.16, 0), ZVector, clrGray70, XTexPoint);
   mesh.Vertices.AddVertex(AffineVectorMake(-0.5, -0.6 , 0), ZVector, clrTransparent, TexPointMake(0, 0.66));
   mesh.Vertices.AddVertex(AffineVectorMake( 0.5, -0.6 , 0), ZVector, clrTransparent, TexPointMake(1, 0.66));
   mesh.Material.MaterialLibrary:=FMaterialLibrary;
   mesh.Material.LibMaterialName:=material.Name;
   mesh.Tag:=FDestination.Count-1;

   if Assigned(FOnAfterAddMesh) then
      FOnAfterAddMesh();
end;

procedure TBackgroundLoader.Abort;
begin
   if Self=nil then Exit;
   Terminate;
   WaitFor;
   Free;
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
   loader.FOnTerminate:=procedure
                        begin
                           FLoader:=nil;
                        end;

   TrackBar.Position:=0;
   TrackBar.Max:=High(loader.FPics);
   FPosition:=0;

   FLoader.Start;
end;

procedure TGLFlowForm.BUSelectClick(Sender: TObject);
begin
   if OpenDialog1.Execute then begin
      TBackgroundLoader(FLoader).Abort;
      DCPics.DeleteChildren;
      GLMaterialLibrary.Materials.Clear;
      LoadFolder( ExtractFilePath(OpenDialog1.FileName) );
   end;
end;

procedure TGLFlowForm.UpdateCoversPositions;
var
   i : Integer;
   delta : Single;
   obj : TGLBaseSceneObject;
begin
   for i:=0 to DCPics.Count-1 do begin
      obj:=DCPics.Children[i];
      delta:=i-FPosition;
      obj.TurnAngle  := -65 * ClampValue(delta, -1, 1);
      obj.Position.X := Sqrt(Abs(delta)) * Sign(delta);
      obj.Position.Z := 8/(Sqr(obj.position.X)+1) - 6;
   end;
end;

procedure TGLFlowForm.GLCadencer1Progress(Sender: TObject; const deltaTime,
  newTime: Double);
begin
   if Abs(FPosition-TrackBar.Position) > 1e-5 then begin
      FPosition:=Lerp(FPosition, TrackBar.Position,
                      ClampValue(0.3/Abs(TrackBar.Position-FPosition), 0.1, 0.5));
      UpdateCoversPositions;
      GLSceneViewer.Repaint;
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

end.
