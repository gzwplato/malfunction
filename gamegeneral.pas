{
  Copyright 2003-2005 Michalis Kamburelis.

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
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit GameGeneral;

{ some general things, consts and funcs for "Malfunction" game.

  Ten modul NIE MOZE zalezec od jakiegokolwiek modulu ktory odwoluje
  sie do obiektu glw w swoim initialization (np. aby zrobic
  glw.OnInitList.AppendItem()). To dlatego ze glw jest tworzony w
  initialization niniejszego modulu i jezeli tamten modul bedzie zalezal
  od GameGeneral a GameGeneral od niego to nie jest pewne ktore
  initialization zostanie wykonane jako pierwsze - a przeciez
  obiekt glw musi byc utworzony zanim sie do niego odwolasz.
}

interface

uses SysUtils, GLWindow, TimeMessages;

{$define read_interface}

const
  Version = '1.2.3';
  DisplayProgramName = 'malfunction';

type
  TGLWindow_malfunc = TGLWindowDemo;

var
  { Whole program uses glw window of class TGLWindow_malfunc.
    Every unit may add some callbacks to glw.OnInitList and glw.OnCloseList.
    This is created and destroyed in init/fini of this module. }
  glw: TGLWindow_malfunc;

{ Game modes.

  At every time, the program is in some "mode".
  Each mode has a specific callbacks to control GLWindow_malfunc
  window, each mode can also init some OpenGL state for itself.

  Events OnInit, OnClose, OnCloseQuery are defined in this unit
  and cannot be redefined by modes. Other events are initialized to nil
  before calling GameModeEnter (so you don't have to set them to nil
  in every gameModeExit), and every gameModeEnter[] can set them
  to some mode-specific callbacks.

  As for OnResize : RasizeAllowed = raOnlyAtInit. So we don't have to do
  anything in OnResize. So we register no OnResize callback.
  @bold(Every mode must) define some projection inside modeEnter.

  modeNone is a very specific mode : this is the initial mode
  when program starts. Never do SetGameMode(modeNone).

  SetGameMode raises @link(BreakGLWinEvent) at the end. }

type
  TGameMode = (modeNone, modeMenu, modeGame);

function GameMode: TGameMode;
procedure SetGameMode(value: TGameMode);

var
  { gameModeEnter i Exit - inicjowana w initialization odpowiednich modulow
    mode*Unit, wszedzie indziej readonly. W czasie dzialania tych procedur
    GameMode bedzie ciagle rowne staremu mode'owi. }
  gameModeEnter, gameModeExit: array[TGameMode]of TProcedure;

{ game data directories ------------------------------------------------------ }

const
  imagesDir = 'images' +PathDelim;
  vrmlsDir = 'vrmls' +PathDelim;
  skiesDir = 'skies' +PathDelim;

{ ----------------------------------------------------------------------------
  zainicjowane w niszczone w tym module. Wyswietlane i Idle'owane w ModeGameUnit.
  Moze byc uzywane z kazdego miejsca. }

var TimeMsg: TTimeMessagesManager;

implementation

{$define read_implementation}

uses KambiGLUtils, KambiUtils, GLWinMessages, GL, GLU, GLExt, ProgressUnit,
  ProgressGL, OpenGLBmpFonts, BFNT_BitstreamVeraSansMono_m18_Unit;

var fGameMode: TGameMode = modeNone;

function GameMode: TGameMode;
begin result := fGameMode end;

procedure SetGameMode(value: TGameMode);
begin
 Check(value <> modeNone, 'Can''t SetGameMode to modeNone');

 if gameModeExit[fGameMode] <> nil then gameModeExit[fGameMode];

 glw.OnDraw := nil;
 glw.OnKeyDown := nil;
 glw.OnKeyUp := nil;
 glw.OnIdle := nil;

 if gameModeEnter[value] <> nil then gameModeEnter[value];
 fGameMode := value;

 glw.PostRedisplay;

 raise BreakGLWinEvent.Create;
end;

{ glw general events handling ----------------------------------------------- }

procedure CloseQuery(glwin: TGLWindow);
begin
 if MessageYesNo(glwin, 'Are you sure you want to quit ?') then glwin.Close;
end;

procedure Init(glwin: TGLWindow);
begin
 GLWinMessagesTheme.Font := TGLBitmapFont.Create(@BFNT_BitstreamVeraSansMono_m18);

 TimeMsg := TTimeMessagesManager.Create(glwin, hpMiddle, vpUp, glwin.width);
 ProgressGLInterface.Window := glwin;
 Progress.UserInterface := ProgressGLInterface;

 SetGameMode(modeMenu);
end;

procedure Close(glwin: TGLWindow);
begin
 if (fGameMode <> modeNone) and
    (gameModeExit[fGameMode] <> nil) then gameModeExit[fGameMode];
 fGameMode := modeNone;

 FreeAndNil(GLWinMessagesTheme.Font);

 FreeAndNil(TimeMsg);
end;

initialization
 glw := TGLWindow_malfunc.Create;
 glw.SetDemoOptions(K_None, #0, true);
 glw.OnCloseQuery := @CloseQuery;
 glw.OnInit := @Init;
 glw.OnClose := @Close;

 {leave OnResize to nil - dont set default projection matrix
  (we will set it in modeEnter, and because we can't be resized -
  we will never have to set it in OnResize)}

 glw.ResizeAllowed := raOnlyAtInit;
finalization
 FreeAndNil(glw);
end.
