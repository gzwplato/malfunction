{
  Copyright 2003-2017 Michalis Kamburelis.

  This file is part of "malfunction".

  "malfunction" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "malfunction" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "malfunction"; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA

  ----------------------------------------------------------------------------
}

unit ShipsAndRockets;

{ Ten modul gromadzi stan mobilnych rzeczy w przestrzeni (ale nie statku gracza)
  czyli wrogich statkow i rakiet.

  W implementacji ten modul zarzadza tez ladowaniem i uzywaniem VRMLi modeli.
  Konwencje VRMLi modeli :
    Caly model musi byc zbudowany rownomiernie wokolo punktu 0, 0, 0
    (ShipPos bedzie punktem 0, 0, 0 dla modelu).
    Cos co jest uwazane za "przod" modelu (tam gdzie ma wskazywac ShipDir)
    musi byc skierowane w strone +Z.
    Cos co jest uwazane za "up" modelu musi byc skierowane w strone +X.
}

{$I castleconf.inc}

interface

uses SysUtils, Classes, Generics.Collections,
  CastleWindow, CastleGLUtils, CastleVectors, CastleUtils,
  CastleClassUtils, CastleTimeUtils, CastleScene, Castle3D;

type
  TEnemyShipKind = (skHedgehog, skTieFighter, skDestroyer);
  TRocket = class;
  TEnemyShip = class;

  TRocketList = specialize TObjectList<TRocket>;

  TSpaceShip = class
  private
    {rakiety tego statku jakie kraza w przestrzeni.
     Zeby nie przeciazac programu kazdy statek moze miec ich maksymalnie
      maxFiredRocketsCount (nie bedzie mogl wystrzelic nowej rakiety jezeli
      spowodowaloby to przekroczenie tej liczby). Ponadto, musimy przechowywac
      sobie wskazniki na wszystkie utworzone rakiety zeby jezeli statek
      zostanie zniszczony to ustawic im wskazniki motherShip na nil
      (zeby torpedy wiedzialy ze kiedy one zostane zniszczone to nie musza
      o tym powiadamiac zadnego statku). }
    firedRockets: TRocketList;
    FMaxShipLife, FShipLife: TGLfloat;
  protected
    { mozesz zwiekszyc wartosc tego pola dla jakiejs bardzo istotnej podklasy
      TSpaceShip (np. dla TPlayerShip) }
    MaxFiredRocketsCount: integer; { =10 }
  public
    { dlugosc shipDir jak zwykle odpowiedzialna jest za szybkosc poruszania sie
      (chociaz niektore podklasy TEnemyShip moga byc tu wyjatkiem -
      np. CircleMoving ma wlasna mechanike poruszania sie i ustawia shipDir
      (aby byla ladna wizualizacja statku) ale go nie uzywa do wlasnych obliczen).

      ShipUp POWINNO byc prostopadle do ShipDir ale nie musi.
      Nie jest zdefiniowane jak shipUp bedzie zmienione na potrzeby wyswietlania
      modelu ale okreslam sobie ze shipDir ma priorytet nad shipUp, wiec jesli
      Dir z Up nie beda prostopadle to postaram sie zeby dziob statku NA PEWNO
      wskazywal na shipDir, a potem zastanowie sie jak ulozyc model zeby wyswietlane
      shipUp bylo mozliwie bliskie zadanemu.

      Koniecznie zadbaj o zainicjowanie tych trzech wektorow w podklasie !}
    shipPos, shipDir, shipUp: TVector3Single;

    { ShipLife MAxShipLife = pelna sprawnosc, 0 lub mniej => statek zniszczony.
      Player Ship ma MaxShipLife = 100 zeby byl jakis punkt odniesienia. }
    property ShipLife: TGLfloat read FShipLife write FShipLife; { =MaxShipLife }
    property MaxShipLife: TGLfloat read FMaxShipLife;

    { zostanie zignorowane jezeli za duzo rakiet wystrzelonych przez ten
      statek juz jest w przestrzeni. Dlugosc rocketDir nie ma wplywu
      na szybkosc rakiety podobnie jak w TRocket.Create. }
    procedure FireRocket(const rocketDir: TVector3Single; rocketSpeed: Single);

    {kolizje statek/rakieta - level sa robione przy pomocy drzewa osemkowego ale
     kolizje statek - statek i statek - rakieta sa robione "recznie" tzn.
     kazdy z kazdym i to uzywajac najprostrzego modelu : statek to sfera
     o promieniu shipRadius wokol shipPos. }
    function shipRadius: Single; virtual; abstract;

    {w tej klasie HitByRocket powoduje tylko ze shipLife spada.
     NIE wywoluje Destroy. Mozesz pokryc ta metode w podklasach
     (tylko pamietaj wywolac na poczatku inherited) wlasnie aby dodac destroy
     i/lub wyswietlic jakies Notification lub zrobic FadeOut graczowi.}
    procedure HitByRocket; virtual;

    {sprawdza czy gdybysmy stali na pozycji pos to kolidowalibysmy z jakims
     statkiem na liscie enemyShips (ale nie z samymi soba, naturalnie).
     Jezeli nie ma kolizji to zwraca nil. }
    function CollisionWithOtherEnemyShip(const pos: TVector3Single): TEnemyShip;

    constructor Create(const AMaxShipLife: TGLfloat);
    destructor Destroy; override;
  end;

  TEnemyShip = class(TSpaceShip)
  private
    FKind: TEnemyShipKind;
  public
    property Kind: TEnemyShipKind read FKind;
    function ShipName: string;

    constructor Create(AKind: TEnemyShipKind; const AShipPos: TVector3Single);
    destructor Destroy; override;

    {render yourself to OpenGL at the right position and direction.
     You should use glPush/PopMatrix mechanism to save current matrix.
     Zawsze wywoluj inherited w podklasach. }
    procedure Render(const Params: TRenderParams); virtual;
    procedure Update; virtual;

    procedure HitByRocket; override;
    function ShipRadius: Single; override;

    { sprawdz czy nowa pozycja jest dobra (a wiec takze czy droga z shipPos
      na newShipPos jest dobra), jesli true - zmien shipPos na newShipPos.
      Nie przeprowadza tak dokladnego testu na kolizje jaki trzeba robic
      dla playerShip, ale dla enemyShips jest dobre. }
    function TryShipMove(const newShipPos: TVector3Single): boolean;
  end;

  TEnemyShipList = specialize TObjectList<TEnemyShip>;

  {statki tej klasy wywoluja w Update FireRocket co jakis czas, zalezny od
   FireDelay dla tego shipKind. Pamietaj wywolac inherited w Update; }
  TFiringRocketsEnemyShip = class(TEnemyShip)
  private
    LastFiredRocketTime: TTimerResult;
    NextFireRocketDelay: TFloatTime;
    RocketFiringInited: boolean;
  protected
    {uzywaj tego w podklasach aby sterowac tym kiedy statek strzela
     rakietami (bo ZAWSZE powinienes wywolywac Update.inherited !).
     Domyslnie jest true.}
    FiringRocketsAllowed: boolean;
  public
    constructor Create(AKind: TEnemyShipKind; const AShipPos: TVector3Single);
    procedure Update; override;
  end;

  TNotMovingEnemyShip = class(TFiringRocketsEnemyShip)
  end;

  TCircleMovingEnemyShip = class(TFiringRocketsEnemyShip)
  private
    AngleRad: Single; { aktualny kat na kole (w radianach) }
    AngleRadChange: Single; { zmiana kata co Update (moze byc ujemna) }
    FCircleCenter: TVector3Single;
    FCircleRadius: Single;
    FUniqueCircleMovingSpeed: Single;
    procedure SetUniqueCircleMovingSpeed(const value: Single);
  public
    { wlasciwa dla statku szybkosc poruszania sie po kole. 1 = jakis default. }
    property UniqueCircleMovingSpeed: Single read FUniqueCircleMovingSpeed
      write SetUniqueCircleMovingSpeed;
    { promien i srodek kola po ktorym sie porusza w plaszczyznie XY statek }
    property CircleCenter: TVector3Single read FCircleCenter;
    property CircleRadius: Single read FCircleRadius;

    { zwroc uwage ze jako drugi parametr podajesz nie shipPos ale circleCenter.
      Poczatkowe ShipPos bedzie wyliczone (jako pozycja na zadanym kole
      dla AngleRad = 0 a wiec w [ CircleCenter[0]+CircleRadius,
       CircleCenter[1], CircleCenter[2] ] }
    constructor Create(AKind: TEnemyShipKind; const ACircleCenter: TVector3Single;
      const ACircleRadius, AUniqueCircleMovingSpeed: Single);

    procedure Update; override;
  end;

  THuntingEnemyShip = class(TFiringRocketsEnemyShip)
  private
    { Random* - uzywane do modyfikowania ShipDir.
        Sa losowane w Randomize uzywanym z Create i zapamietywane w tych polach
        obiektu zeby zawsze uzywac tego samego wektora losowego i kata dla
        jednego statku (zeby statki nie poruszaly sie w takiej "trzesawce"
        na skutek ciaglego losowania nowego RandomVectora).
      Moga byc relosowane tylko raz na jakis czas - zeby nie spowodowac
        tego "trzesacego sie ruchu".}
    RandomVector: TVector3Single;
    RandomAngleDeg: Single;
    procedure Randomize;
  private
    FHuntingAttack: boolean;
    procedure SetHuntingAttack(value: boolean);
    property HuntingAttack: boolean read FHuntingAttack write SetHuntingAttack;
  public
    constructor Create(AKind: TEnemyShipKind; const AShipPos: TVector3Single);
    procedure Update; override;
  end;

  TRocket = class
  private
    FMotherShip: TSpaceShip;
  public
    rocPos, rocDir: TVector3Single;
    { MotherShip = statek ktory wystrzelil ta rakiete. Gdy rakieta
      zostanie zniszczona (bo zderzyla sie z czyms lub wyleciala za level)
      powiadomi o tym swoj MotherShip usuwajac sie z jego listy firedRockets.
      Z drugiej strony, jezeli to motherShip zostanie zniszczony pierwszy
      to musi on powiadomic o tym wszystkie swoje rakiety ustawiajac im
      motherShip na nil. }
    property MotherShip: TSpaceShip read FMotherShip;
    { inaczej niz zazwyczaj, dlugosc ArocDir nie ma tu znaczenia -
      tak jakby ten wektor byl zawsze normalizowany na poczatku tego
      konstruktora. Szybkosc lotu rakiety bedzie nastepnie ustalana na
      podstawie speed (speed = 1 oznacza "standardowa szybkosc rakiety"). }
    constructor Create(const ArocPos, ArocDir: TVector3Single; const speed: TGLfloat; AmotherShip: TSpaceShip);
    destructor Destroy; override;

    class function rocRadius: Single;

    {render yourself to OpenGL at the right position and direction.
     You should use glPush/PopMatrix mechanism to save current matrix.}
    procedure Render(const Params: TRenderParams);
    procedure Update;
  end;

var
  {wszystkie rakiety i statki wroga jakie istnieja w przestrzeni.

   Te listy POSIADAJA swoje elementy, to znaczy te listy sa niszczone przez
   FreeWithContents. Tworzone i niszczone w LevelUnit przy LoadLevel/FreeLevel.

   Na obydwu listach moga wystepowac elementy = nil. To dlatego ze elementy
   TEnemyShip i TRocket kiedy sa niszczone zmieniaja wszystkie swoje
   wystapienia na odpowiednich listach na nil. NIE moga sie z nich usuwac
   bo byc moze beda musialy to zrobic kiedy jakis kod iteruje po tych listach.
   (np. w ShipsAndRocketsUpdate jest robione
    for i := 0 to rockets.Count-1 do rockets[i].Update;
    a przeciez rakieta moze zostac zniszczona w czasie swojego Update.
    Statki chwilowo nie moga zostac zniszczone w czasie wlasnego Update
    ale z pewnoscia myslac przyszlosciowo nalezy dopuscic taka mozliwosc
    (statki - kamikadze na przyklad).
   Listy sa czyszczone z nil'i na koncu ShipsAndRocketsUpdate kiedy jest to
     bezpieczne (wiadomo ze nic nie iteruje wtedy po listach) i nie powinny
     byc czyszczone z nil'i nigdzie indziej (uzywamy wyniku DeleteAll(nil)
     aby ew. wypisac komunikat "All enemy ships destroyed") }
  rockets: TRocketList;
  enemyShips: TEnemyShipList;

{ funcs below should be called from ModeGameUnit at appropriate times.
  They don't modify current matrix. }
procedure ShipsRender(const Params: TRenderParams);
procedure RocketsRender(const Params: TRenderParams);
procedure ShipsAndRocketsUpdate;

{ inne funkcje }

function NameShcutToEnemyShipKind(const ANameShcut: string): TEnemyShipKind;

implementation

uses CastleBoxes, GameGeneral, X3DNodes, LevelUnit, Math, PlayerShipUnit,
  CastleRenderingCamera, CastleUIControls, CastleGL, CastleFilesUtils,
  CastleApplicationProperties;

type
  TEnemyShipKindInfo = record
    MaxLife: integer;

    { Skrotowa nazwa do uzytku wewnetrznego (w tej chwili w
      node'ach "DEF Enemy Info" w VRML'ach levelu), 1 wyraz bez bialych
      spacji pisany malymi literami. }
    NameShcut: string;

    { Ladna nazwa dla usera, pisana z duzych liter i byc moze
      wielowyrazowa. }
    Name: string;

    { Nazwa pliku z ktorego zaladowac VRML statku. }
    VrmlFName: string;

    { Determinuje jak czesto statek bedzie strzelal rakiety,
      istotne tylko jesli statek jest TFiringRocketsEnemyShip. }
    FireDelay: TFloatTime;

    { Okreslaja jaka jest szybkosc statku przy danym stanie
      HuntingAttack, w skali gdzie wartosc 1.0 oznacza pewna domyslna
      sensowna szybkosc. }
    HuntingSpeed: array[boolean]of Single;

    { Jaka jest szybkosc poruszania sie po kole. 1.0 oznacza domyslna szybkosc. }
    CircleMovingSpeed: Single;
  end;

const
  EnemyShipKindsInfos : array[TEnemyShipKind]of TEnemyShipKindInfo =
  (( MaxLife: 30; NameShcut: 'hedgehog'; Name: 'Black Hedgehog';
     VrmlFname:'black_hedgehog.wrl'; FireDelay: 8.000;
     HuntingSpeed: (0.5, 0.5); CircleMovingSpeed: 1.0),
   ( MaxLife: 15; NameShcut: 'tieftr'; Name: 'Tie Fighter';
     VrmlFname: 'tie_fighter.wrl'; FireDelay: 8.000;
     HuntingSpeed: (1, 1); CircleMovingSpeed: 1.0),
   ( MaxLife: 50; NameShcut:'destroyer'; Name: 'Destroyer';
     VrmlFname: 'destroyer.wrl'; FireDelay: 4.000;
     HuntingSpeed: (1, 1); CircleMovingSpeed: 0.5)
  );

const
  modelDir3d: TVector3Single = (Data: (0, 0, 1));

var
  { modeliki; ladowane w Window.Open, niszczone w Window.Close  }
  rocketVRML: TCastleScene;
  enemyShipVRMLs: array[TEnemyShipKind]of TCastleScene;

{ TSpaceShip ----------------------------------------------------------------- }

constructor TSpaceShip.Create(const AMaxShipLife: TGLfloat);
begin
 inherited Create;
 MaxFiredRocketsCount := 10;
 FMaxShipLife := AMaxShipLife;
 FShipLife := MaxShipLife;
 firedRockets := TRocketList.Create(false);
end;

destructor TSpaceShip.Destroy;
var i: integer;
begin
 if firedRockets <> nil then
 begin
  for i := 0 to firedRockets.Count-1 do firedRockets[i].FMotherShip := nil;
  FreeAndNil(firedRockets);
 end;
 inherited;
end;

procedure TSpaceShip.FireRocket(const rocketDir: TVector3Single; rocketSpeed: Single);
var rocket: TRocket;
begin
 if firedRockets.Count < maxFiredRocketsCount then
 begin
  rocket := TRocket.Create(shipPos, rocketDir, rocketSpeed, Self);
  rockets.Add(rocket);
  firedRockets.Add(rocket);
 end;
end;

procedure TSpaceShip.HitByRocket;
begin
 fshipLife := fshipLife - (Random(15)+5);
end;

function TSpaceShip.CollisionWithOtherEnemyShip(const pos: TVector3Single): TEnemyShip;
var i: integer;
begin
 {jak widac, sprawdzamy powyzej czy enemyShips[i] <> Self zeby gdy wywolamy
  ta procedure z klasy TEnemySpaceShip nie otrzymac kolizji z samym
  soba.}
 for i := 0 to enemyShips.Count-1 do
  if (enemyShips[i] <> nil) and
    IsSpheresCollision(pos, shipRadius,
                       enemyShips[i].shipPos, enemyShips[i].shipRadius) and
    (enemyShips[i] <> Self) then
   exit(enemyShips[i]);
 result := nil;
end;

{ TEnemyShip ---------------------------------------------------------------- }

constructor TEnemyShip.Create(AKind: TEnemyShipKind; const AShipPos: TVector3Single);
begin
 inherited Create(EnemyShipKindsInfos[AKind].MaxLife);
 FKind := AKind;
 ShipPos := AShipPos;
 ShipUp := Vector3Single(0, 0, 1);
 ShipDir := Vector3Single(1, 0, 0);
end;

destructor TEnemyShip.Destroy;
var
  Index: Integer;
begin
  if enemyShips <> nil then
  begin
    Index := enemyShips.IndexOf(Self);
    if Index <> -1 then
      enemyShips[Index] := nil;
  end;
  inherited;
end;

function TEnemyShip.ShipName: string;
begin
 result := EnemyShipKindsInfos[Kind].Name;
end;

procedure TEnemyShip.HitByRocket;
begin
 inherited;
 Notifications.Show('"'+ShipName+'" was hit by the rocket.');
 if ShipLife <= 0 then
 begin
  Notifications.Show('"'+ShipName+'" was destroyed.');
  Self.Destroy;
 end;
end;

function TEnemyShip.ShipRadius: Single;
begin
 result := EnemyShipVRMLs[Kind].BoundingBox.AverageSize * Sqrt2/2;
end;

procedure TEnemyShip.Render(const Params: TRenderParams);
var GoodShipUp: TVector3Single;
begin
 glPushMatrix;

   GoodShipUp := ShipUp;
   MakeVectorsOrthoOnTheirPlane(GoodShipUp, ShipDir);
   glMultMatrix(TransformToCoordsNoScaleMatrix(
     ShipPos, GoodShipUp, VectorProduct(ShipDir, GoodShipUp), ShipDir));

   { TODO: RenderingCamera.Frustum is actually invalid, it's not transformed
     by matrix. But we pass TestShapeVisibility = nil, and we don't use
     VisibilitySensor inside these models, so frustum value isn't really used.
     We should remake ships as Castle3D.T3DOrient, then this whole
     unit can be trivial. }

   EnemyShipVRMLs[Kind].Render(nil, RenderingCamera.Frustum, Params);
 glPopMatrix;
end;

procedure TEnemyShip.Update;
{ w klasie TEnemyShip Update nie robi nic; ale nie jest zdefiniowane
  jako abstrakcyjne zeby mozna bylo bezproblemowo ZAWSZE zrobic inherited
  w podklasach (i nie martwic sie tym samym czy klasa dziedziczy posrednio
  czy bezposrednio od TEnemyShip) }
begin
end;

function TEnemyShip.TryShipMove(const newShipPos: TVector3Single): boolean;
begin
 {jezeli mozna sie przesunac, to rusz sie; uwaga - nie uwzgledniamy tu
  ze statek moze tu przeleciec przez torpede lub przez statek gracza.
  Wszystko to dla prostoty i szybkosci.}

 result :=
   (not levelScene.InternalOctreeCollisions.IsSegmentCollision(ShipPos, newShipPos,
     nil, false, nil)) and
   (CollisionWithOtherEnemyShip(newShipPos) = nil) and
   MoveLimit.Contains(newShipPos);
 if result then ShipPos := newShipPos;
end;

{ TFiringRocketsEnemyShip ------------------------------------------------- }

constructor TFiringRocketsEnemyShip.Create(AKind: TEnemyShipKind; const AShipPos: TVector3Single);
begin
 inherited;
 RocketFiringInited := false;
 FiringRocketsAllowed := true;
end;

procedure TFiringRocketsEnemyShip.Update;
begin
 inherited;
 if RocketFiringInited then
 begin
  if TimerSeconds(Timer, LastFiredRocketTime) >= NextFireRocketDelay then
  begin
   if FiringRocketsAllowed then
    FireRocket(VectorSubtract(playerShip.shipPos, shipPos), 1);
   {w ten sposob statki beda strzelaly w dosc zroznicowanych odstepach czasu}
   LastFiredRocketTime := Timer;
   with EnemyShipKindsInfos[Kind] do
    NextFireRocketDelay := (FireDelay / 2) + Random * (FireDelay / 2);
  end;
 end else
 begin
  {ustalamy czas wystrzelenia pierwszej rakiety dopiero tutaj, naszym Update,
   zamiast w naszym konstruktorze bo po skonstruowaniu obiektu enemyShip
   w LoadLevel moze minac duzo czasu do poczatku gry - np. czas na ten MessageOK
   w ModeGameUnit.modeGameEnter; }
  LastFiredRocketTime := Timer;
  with EnemyShipKindsInfos[Kind] do
   NextFireRocketDelay := (FireDelay / 2) + Random * (FireDelay / 2);
  RocketFiringInited := true;
 end;
end;

{ TCircleMovingEnemyShip ------------------------------------------------------ }

procedure TCircleMovingEnemyShip.SetUniqueCircleMovingSpeed(const value: Single);
begin
 FUniqueCircleMovingSpeed := value;
 AngleRadChange:=
   10 {standardowa zmiana kata} *
   (1/CircleRadius) {obwod kola rosnie liniowo razem z promieniem;
      wiec jezeli np. zwiekszymy promien 2 razy to zwiekszymy tez
      obwod dwa razy a wiec statek musi sie poruszac 2 razy wolniej
      zeby miec taka sama szubkosc.} *
   EnemyShipKindsInfos[Kind].CircleMovingSpeed {zmodyfikuj szybkosc w
      zaleznosci od Kind} *
   UniqueCircleMovingSpeed {zmodyfikuj szybkosc w sposob szczegolny dla
      tego wlasnie statku};
end;

constructor TCircleMovingEnemyShip.Create(AKind: TEnemyShipKind;
  const ACircleCenter: TVector3Single;
  const ACircleRadius, AUniqueCircleMovingSpeed: Single);
begin
 inherited Create(AKind, Vector3Single(ACircleCenter[0]+ACircleRadius,
   ACircleCenter[1], ACircleCenter[2]));

 FCircleRadius := ACircleRadius;
 FCircleCenter := ACircleCenter;
 AngleRad := 0;

 {ustawianie UniqueCircleMovingSpeed zainicjuje AngleRadChange od razu}
 UniqueCircleMovingSpeed := AUniqueCircleMovingSpeed;
end;

procedure TCircleMovingEnemyShip.Update;
var newAngleRad: Double;
    newShipPos, newShipDir: TVector3Single;
begin
 inherited;

 newAngleRad := AngleRad + AngleRadChange * Window.Fps.UpdateSecondsPassed * 50;
 newShipPos[0] := cos(newAngleRad)*CircleRadius + CircleCenter[0];
 newShipPos[1] := sin(newAngleRad)*CircleRadius + CircleCenter[1];
 newShipPos[2] := CircleCenter[2];

 newShipDir := VectorSubtract(newShipPos, shipPos);

 if TryShipMove(newShipPos) then
 begin
  ShipDir := newShipDir;
  AngleRad := newAngleRad;
 end else
  AngleRadChange := -AngleRadChange;
end;

{ THuntingEnemyShip ---------------------------------------------------------- }

procedure THuntingEnemyShip.SetHuntingAttack(value: boolean);
begin
 FHuntingAttack := value;
 { bylo tu FiringRocketsAllowed := value; ale niech jednak ZAWSZE strzela,
   nawet gdy ucieka - inaczej gracz bedzie mogl "przyprzec statek dpo muru"
   i spokojnie strzelac w nieruchomy statek. }
end;

procedure THuntingEnemyShip.Randomize;
begin
 RandomVector := Vector3Single(Random, Random, Random);
 RandomAngleDeg := 15+Random(15);
end;

constructor THuntingEnemyShip.Create(AKind: TEnemyShipKind; const AShipPos: TVector3Single);
begin
 inherited;
 HuntingAttack := Boolean(Random(2));
 Randomize;
end;

procedure THuntingEnemyShip.Update;
begin
 inherited;

 if ( HuntingAttack and
      ( PointsDistanceSqr(ShipPos, PlayerShip.ShipPos)<=
        Sqr((ShipRadius+PlayerShip.ShipRadius)*10) )
    ) or
    ( (not HuntingAttack) and
      (PointsDistanceSqr(ShipPos, PlayerShip.ShipPos) > Sqr(10000.0))
    ) then
  HuntingAttack := not HuntingAttack;

 {ustal ShipDir: dla HuntingAttack, shipDir kieruje sie w strone gracza,
  potem jest nieznacznie zmodyfikowany o maly obrot wokol losowej osi
   (zeby statek nie lecial DOKLADNIE na/od gracza, bo wtedy latwo
   go trafic ! Statek ma leciec tylko tak mniej-wiecej po torze w poblizu
   kolizyjnego !)
  ma dlugosc wzieta z PlayerShipDirLength o naszego HuntingSpeed,
  dla not HuntingAttack jest skierowany po prostu w druga strone.}
 ShipDir := VectorSubtract(PlayerShip.ShipPos, ShipPos);
 ShipDir := RotatePointAroundAxisDeg(RandomAngleDeg, ShipDir, RandomVector);
 ShipDir := VectorAdjustToLength(ShipDir, 20 *
   EnemyShipKindsInfos[Kind].HuntingSpeed[HuntingAttack]);
 if not HuntingAttack then
  ShipDir := -ShipDir;

 if not TryShipMove(ShipPos + ShipDir * (Window.Fps.UpdateSecondsPassed * 50)) then
 begin
  Randomize;
  HuntingAttack := not HuntingAttack
 end;
end;

{ TRocket ---------------------------------------------------------------- }

constructor TRocket.Create(const ArocPos, ArocDir: TVector3Single;
  const speed: TGLfloat; AmotherShip: TSpaceShip);
begin
 inherited Create;
 rocPos := ArocPos;
 rocDir := ArocDir.AdjustToLength(speed * 50);
 FMotherShip := AMotherShip;
end;

destructor TRocket.Destroy;
var
  Index: Integer;
begin
  if MotherShip <> nil then MotherShip.firedRockets.Remove(Self);
  if rockets <> nil then
  begin
    Index := rockets.IndexOf(Self);
    if Index <> -1 then
      rockets[Index] := nil;
  end;
  inherited;
end;

procedure TRocket.Render(const Params: TRenderParams);
var axis: TVector3Single;
begin
 glPushMatrix;
   glTranslated(rocPos[0], rocPos[1], rocPos[2]);
   axis := VectorProduct(modelDir3d, rocDir);
   glRotated(RadToDeg(AngleRadBetweenVectors(modelDir3d, rocDir)), axis[0], axis[1], axis[2]);

   { TODO: RenderingCamera.Frustum is actually invalid, it's not transformed
     by matrix. But we pass TestShapeVisibility = nil, and we don't use
     VisibilitySensor inside these models, so frustum value isn't really used.
     We should remake rockets as Castle3D.T3DTransform, then this whole
     unit can be trivial. }

   rocketVRML.Render(nil, RenderingCamera.Frustum, Params);
 glPopMatrix;
end;

procedure TRocket.Update;
var newRocPos: TVector3Single;

  function CollidesWith(ship: TSpaceShip): boolean;
  begin
   result := IsTunnelSphereCollision(rocPos, newRocPos, rocRadius,
     ship.shipPos, ship.shipRadius);
  end;

var i: integer;
begin
 newRocPos := rocPos + rocDir * (Window.Fps.UpdateSecondsPassed * 50);
 if (levelScene.InternalOctreeCollisions.IsSegmentCollision(rocPos,
       newRocPos, nil, false, nil)) or
    (not MoveLimit.Contains(rocPos)) then
  {rakieta zderzyla sie z czescia levelu lub wyleciala poza MoveLimit}
  Self.Destroy else
 begin
  {sprawdzamy czy rakieta zderzyla sie z jakims statkiem, naszym lub wroga.
   Uzywamy testowania kolizji na kulach. Jak widac rakieta nie moze
   uderzyc w swoj wlasny MotherShip - to dlatego ze na poczatku, gdy
   statek strzela, rakieta wylatuje zawsze ze statku i zawsze bylaby
   kolizja. Moglibysmy wysunac rakiete duzo do przodu i dac jej taka
   szybkosc zeby statek nie mogl jej dogonic ale to byloby skomplikowane.}
  for i := 0 to enemyShips.Count-1 do
   if (enemyShips[i] <> nil) and
     CollidesWith(enemyShips[i]) and (enemyShips[i] <> motherShip) then
   begin
    enemyShips[i].HitByRocket;
    Self.Destroy;
    exit;
   end;

  if CollidesWith(playerShip) and (playerShip <> motherShip) then
  begin
   playerShip.HitByRocket;
   Self.Destroy;
   exit
  end;

  {nie bylo zderzenia ? to lec dalej.}
  rocPos := newRocPos;
 end;
end;

class function TRocket.rocRadius: Single;
begin
 result := rocketVRML.BoundingBox.AverageSize / 2;
end;

{ global funcs ----------------------------------------------------------- }

procedure ShipsRender(const Params: TRenderParams);
var i: integer;
begin
 for i := 0 to enemyShips.Count-1 do
  if enemyShips[i] <> nil then enemyShips[i].Render(Params);
end;

procedure RocketsRender(const Params: TRenderParams);
var i: integer;
begin
 for i := 0 to rockets.Count-1 do
  if rockets[i] <> nil then rockets[i].Render(Params);
end;

procedure ShipsAndRocketsUpdate;
var
  i: integer;
  removedSomeEnemy: boolean;
begin
  for i := 0 to rockets.Count-1 do
    if rockets[i] <> nil then
      rockets[i].Update;

  for i := 0 to enemyShips.Count-1 do
    if enemyShips[i] <> nil then
      enemyShips[i].Update;

  // remove nils
  I := 0;
  while I < rockets.Count do
    if rockets[I] <> nil then
      Inc(I)
    else
      rockets.Delete(I);

  // remove nils
  I := 0;
  removedSomeEnemy := false;
  while I < enemyShips.Count do
    if enemyShips[I] <> nil then
      Inc(I)
    else
    begin
      removedSomeEnemy := true;
      enemyShips.Delete(I);
    end;

  if removedSomeEnemy and (enemyShips.Count = 0) then
    Notifications.Show('ALL ENEMY SHIPS DESTROYED.');
end;

function NameShcutToEnemyShipKind(const ANameShcut: string): TEnemyShipKind;
begin
 for result := Low(result) to High(result) do
  if EnemyShipKindsInfos[result].NameShcut = ANameShcut then exit;
 raise Exception.Create('NameShcut ' +ANameShcut+
   ' doesn''t specify any EnemyShipKind');
end;

{ glw callbacks ------------------------------------------------------------- }

procedure ContextOpen;
var sk: TEnemyShipKind;
begin
 rocketVRML := TCastleScene.Create(nil);
 rocketVRML.Load(ApplicationData('vrmls/rocket.wrl'));
 rocketVRML.Attributes.Lighting := false;

 for sk := Low(sk) to High(sk) do
 begin
  EnemyShipVRMLs[sk] := TCastleScene.Create(nil);
  EnemyShipVRMLs[sk].Load(ApplicationData('vrmls/' + EnemyShipKindsInfos[sk].VrmlFname));
 end;
end;

procedure ContextClose;
var sk: TEnemyShipKind;
begin
 FreeAndNil(rocketVRML);
 for sk := Low(sk) to High(sk) do FreeAndNil(EnemyShipVRMLs[sk]);
end;

initialization
 ApplicationProperties.OnGLContextOpen.Add(@ContextOpen);
 ApplicationProperties.OnGLContextClose.Add(@ContextClose);
end.
