{$M 20000,0,30000}
Program Xwing_Cheat_Utility;  { Version 2.0 par D. MORCELLET }

uses Dos,Crt,Drivers,XUtils,Menus,Windows,Desktop,Config,Misc,TxtFonts;

CONST
   { Nombre maximal de pilotes g‚r‚s }
   MaxPilot=30;
   { Nombre de missions pour chaque StarFighter }
   NbMissions : ARRAY[0..3] of Byte = (6,6,6,6);
   { Correspondances entre les num‚ros et indices de missions }
   C : ARRAY[0..4,0..24] of Byte = (
   (0,1,2,3,4,5,6,7,8,9,10,11,12,12,12,12,12,12,12,12,12,12,12,12,12),
   (0,1,2,3,4,5,6,7,8,9,10,11,12,12,12,12,12,12,12,12,12,12,12,12,14),
   (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,14,14,14,14,14,14,14,14,14,14),
   (0,1,2,3,4,5,5,6,7,7,8,9,10,11,11,12,13,14,15,15,16,17,18,19,20),
   (0,1,2,3,4,5,6,7,8,9,10,10,11,12,13,13,14,15,16,16,17,18,19,19,20));
VAR
   { Nombre de StarFighters diff‚rents : Xwing,Awing,Bwing,Ywing }
   StarFighters : Byte;
   { Nombre de tours install‚s : Tour I,II,III,IV ... }
   NbTours : Byte;
   { Variable File associ‚e au fichier pilote }
   PilotFile : FILE OF Byte;
   { Chemin d'accŠs des fichiers pilote }
   XWingPATH : DirStr;
   { Nom du fichier pilote sans l'extension .PLT }
   PilotName : NameStr;
   { Nom d'accŠs complet du fichier pilote }
   PilotFilePATH : PathStr;
   { Indique la pr‚sence de modules suppl‚mentaires }
   BwingModule,ImperialPursuitModule : Boolean;
   { Indique la pr‚sence d'un pilote en m‚moire }
   aPilotIsLoaded : Boolean;
   { Indique si le pilote a ‚t‚ modifi‚ ou non }
   Modified : Boolean;
   { Variables utilis‚e dans les fenˆtres }
     { Indique un vaisseau : 0=Xwing,1=Ywing,2=Awing,3=Bwing }
     Craft : Byte;
     { Indique un niveau : entre 0 et 8 (pour l'entraŒnement)}
     Level : Byte;
     { Indique un Tour : 0=Tour I,1=Tour II,... }
     Tour : Byte;
     { Indique un num‚ro de mission }
     Mission : Byte;
   { Liste des pilotes du r‚pertoire XWingPATH }
     Pilots : ARRAY[1..MaxPilot] of NameStr;
   { Liste des descriptifs de pilote, ex : Commander X (Flight Officer) }
     PilotStrs : ARRAY[1..MaxPilot] of String[40];
   { Nombre de pilotes dans le r‚pertoire XWingPATH }
     NbrOfPilots : Byte;
   DestroyedCrafts,CapturedCrafts : LongInt;

{ Indique le score pour la mission d‚sign‚e par Mission,Craft
  et si elle a ‚t‚ remplie ou non ... }
procedure MissionScoreWindowContent;  FAR;
VAR WhereCompleted : Word;
    Where : Value;
    Score : LongInt;
begin
   { Calcul de l'adresse voulue... }
   WhereCompleted:=SuccessfulHistoricMissions+Mission+Craft*16;
   { Calcul du score }
   Where:=HistoricScores;Where.Offset:=Where.Offset+Mission*4+Craft*64;
   Score:=ReadFromMemory(Where);
   { Affichage : Mission (not) completed ; xxxx points }
   Write(' Mission ');IF NOT (T[WhereCompleted]=1) THEN Write('not ');
   Write('completed ; ',Score,' points');
end;

procedure TODVictoriesContent; FAR;
VAR C : ARRAY[0..20] of String[25];
    Victories : ARRAY[0..20,KindOfVictories] of Word;
    i,j : Byte;
    Where : Value;
Begin
     j:=0;
     for i:=0 to 23 do
         if CraftsNames[i+1]<>'' THEN BEGIN
            C[j]:=CraftsNames[i+1];
            Where:=TODCraftsDestroyed;Where.Offset:=Where.Offset+i*2;
            Victories[j,Destroyed]:=ReadFromMemory(Where);
            Where:=TODCraftsCaptured;Where.Offset:=Where.Offset+i*2;
            Victories[j,Captured]:=ReadFromMemory(Where);
            Inc(j);
         END;
     for i:=0 to 20 do begin
         gotoxy(2,i+1);Write(C[i]);gotoxy(30,i+1);Write(Victories[i,Destroyed]);
         gotoxy(40,i+1);Write(Victories[i,Captured]);
     end;
end;

PROCEDURE PrintTODVictories;
VAR
   WhereDestroyed,WhereCaptured : Value;
   i : Byte;

BEGIN
   DestroyedCrafts:=0;CapturedCrafts:=0;
   for i:=0 to 23 do begin
       TextColor(LightCyan);Gotoxy(5+35*(i div 12),3+(i mod 12));
       WhereDestroyed:=TODCraftsDestroyed;WhereCaptured:=TODCraftsCaptured;
       WhereDestroyed.offset:=WhereDestroyed.offset+2*i;
       WhereCaptured.Offset:=WhereCaptured.offset+2*i;
       DestroyedCrafts:=DestroyedCrafts+ReadFromMemory(WhereDestroyed);
       CapturedCrafts:=CapturedCrafts+REadFromMemory(WhereCaptured);
       IF CraftsNames[i+1]<>'' THEN BEGIN
         Write(CraftsNames[i+1]);TextColor(White);
         WriteLn(' : ',ReadFromMemory(WhereDestroyed),' (',ReadFromMemory(WhereCaptured),')');
       END;
   end;
END;

procedure OperationScoreWindowContent; FAR;
VAR Where : Value;
begin
     { Calcul d'adresse }
     Where:=TODScores;Where.Offset:=Where.Offset+Tour*100+Mission*4;
     { Affichage du score }
     TextColor(White);Write(' Current score : ',ReadFromMemory(Where));
end;

{ Renvoie une chaŒne d‚crivant le tour en cours (None,Tour I,Tour II...) }
FUNCTION CurrentTour : STRING;
BEGIN
     IF T[CurrentTOD]<NbTours THEN CurrentTour:=TourName[T[CurrentTOD]]
                              ELSE CurrentTour:='None';
END;

{ Affiche les caract‚ristiques du pilote en m‚moire }
procedure PilotContent; FAR;
begin
     { Fixe la couleur White, mˆme si la fenˆtre est en arriŠre plan }
     TextColor(White);
     { Nom et grade du pilote }
     WriteLn(' ',Ranks[T[Rank]],' ',PilotName,' (',StatusNames[T[Status]],')');
     { Exp‚rience en Tour of Duty }
     WriteLn(' TOD Points : ',ReadFromMemory(TODXP));
     { Exp‚rience en Missions Historiques }
     WriteLn(' Historic Missions : ',ReadFromMemory(HistoricXP),' (',GetHistoricRank,')');
     { Indique le Tour en cours }
     Write(' Current Tour of Duty : ',CurrentTour);
end;

procedure PilotLogContent; FAR;
VAR i,j : Integer;
    Where : Value;
    Key : Char;
begin
   { Page 1 : Proving Grounds }
   WriteLn;
   TextColor(LightRed);WriteLn(' Proving Ground ...');TextColor(White);
   for i:=0 to StarFighters-1 do begin
       Write('   '+StarFightersNames[i+1]+' : you have completed level ',T[$86+i]);
       Where:=TrainingScores;Where.Offset:=Where.Offset+i*4;
       WriteLn(' with a (best) score of ',ReadFromMemory(Where));
   end;
   Key:=ReadKey;ClrScr;
   { Page 2 : Historic Combat Missions }
   WriteLn;TextColor(LightRed);WriteLn(' Historic Combat Missions');
   for i:=0 to StarFighters-1 do begin
       TextColor(LightCyan);gotoxy(4,4+i*3);
       Write(StarFightersNames[i+1],' ( Completed : ');
       for j:=0 to NbMissions[i]-1 do if T[$220+i*16+j]=1 THEN Write(j+1,' ');
       WriteLn(')');TextColor(White);
       for j:=0 to NbMissions[i]-1 do begin
           Where:=HistoricScores;Where.Offset:=Where.Offset+i*64+j*4;
           gotoxy((j mod 3)*23+5,5+i*3+(j div 3));;
           write('   Mission ',j+1,' : ',ReadFromMemory(Where));
       end;
   end;
   Key:=readKey;ClrScr;
   { Page 3 : TOD Victories }
   PrintTODVictories;
   gotoxy(3,2);TextColor(LightRed);Write('TOD Crafts Destroyed (Captured) : ');
   TextColor(White);Writeln(destroyedCrafts,' (',capturedCrafts,')');
   gotoxy(3,16);TextColor(LightRed);Write('TOD Surface Victories : ');
   TextColor(White);Write(ReadFromMemory(TODSurfaceVictories));
   Key:=ReadKey;ClrScr;
   TextColor(LightRed);gotoxy(2,2);Write('TOD Laser Fired : ');
   TextColor(White);Write(ReadFromMemory(TODLaserFired));
   TextColor(LightCyan);gotoxy(5,3);Write('TOD Laser Craft Hits : ');
   TextColor(White);Write(ReadFromMemory(TODLaserCraftHits),' (');
   IF ReadFromMemory(TODLaserFired)>0 THEN
      Write(Trunc(ReadFromMemory(TODLaserCraftHits)/ReadFromMemory(TODLaserFired)*100),'%)')
      ELSE Write('Undefined %)');
   TextColor(LightCyan);gotoxy(5,4);Write('TOD Laser Ground Hits : ');
   TextColor(White);Write(ReadFromMemory(TODLaserGroundHits),' (');
   IF ReadFromMemory(TODLaserFired)>0 THEN
      Write(Trunc(ReadFromMemory(TODLaserGroundHits)/ReadFromMemory(TODLaserFired)*100),'%)')
      ELSE Write('Undefined %)');
   TextColor(LightRed);gotoxy(2,6);Write('TOD Homing Projectiles Fired : ');
   TextColor(White);Write(ReadFromMemory(TODHomingProjFired));
   TextColor(LightCyan);gotoxy(5,7);Write('TOD Homing Projectiles Craft Hits : ');
   TextColor(White);Write(ReadFromMemory(TODHPCraftHits),' (');
   IF ReadFromMemory(TODHomingProjFired)>0 THEN
      Write(Trunc(ReadFromMemory(TODHPCraftHits)/ReadFromMemory(TODHomingProjFired)*100),'%)')
      ELSE Write('Undefined %)');
   TextColor(LightCyan);gotoxy(5,8);Write('TOD Homing Projectiles Ground Hits : ');
   TextColor(White);Write(ReadFromMemory(TODHPGroundHits),' (');
   IF ReadFromMemory(TODHomingProjFired)>0 THEN
      Write(Trunc(ReadFromMemory(TODHPGroundHits)/ReadFromMemory(TODHomingProjFired)*100),'%)')
      ELSE Write('Undefined %)');
   TextColor(LightRed);gotoxy(2,10);Write('TOD Crafts Lost : ');
   TextColor(White);Write(ReadFromMemory(TODCraftsLost));
   FOR i:=0 to NbTours-1 do begin
       gotoxy(2,12+i);
       IF (i<3) OR ((i=3) AND ImperialPursuitModule)
                OR ((i=4) AND BwingModule) THEN BEGIN
          if T[TourOperation+i]=0 THEN Write('No operation completed for ',TourName[i])
          else write('You completed ',T[TourOperation+i],' operation(s) in ',TourName[i]);
       END
       ELSE write(TourName[i],' not available');
   END;
   Key:=ReadKey;
end;

PROCEDURE RecognizeConfig;
BEGIN
   { Valeurs standard de NbTours et Starfighters pour Xwing seul }
     NbTours:= 3;
     StarFighters:=3;
   { Reconnaissance des modules suppl‚mentaires ... }
     { B-wing }
       BwingModule:=NOT (FSearch('TOUR5.XID',XwingPath)='');
     { Imperial Pursuit - Tour IV }
       ImperialPursuitModule:=NOT (FSearch('TOUR4.XID',XwingPath)='');
   { Modification des valeurs standard en fonction des modules ... }
     { Imperial Pursuit }
       IF ImperialPursuitModule THEN NbTours:=4;
     { B-wing }
       IF BwingModule THEN BEGIN
                           NbTours:=5;Inc(StarFighters);
       END;
   { Et c'est tout ... }
END;

FUNCTION PilotStr(aPilotName : String ) : String;
VAR Rank,Status : Byte;
BEGIN
     Assign(PilotFile,XWingPATH+'\'+aPilotName+'.PLT');Reset(PilotFile);
     Read(PilotFile,Rank,Rank,Status,Rank);
     Close(PilotFile);
     PilotStr:=Ranks[Rank]+' '+aPilotName+' ('+StatusNames[status]+')';
END;

PROCEDURE ReadPilots;
VAR DirInfo : SearchRec;
BEGIN
     EmptyMenu('pilotsmenu');
     NbrOfPilots:=0;
     FindFirst(XWingPATH+'\*.PLT',AnyFile,DirInfo);
     IF DosError>0 THEN Erreur('No pilot found... Create one with X-wing !');
     WHILE DosError=0 DO BEGIN
           Delete(DirInfo.Name,Pos('.PLT',DirInfo.Name),4);
           Inc(NbrOfPilots);Pilots[NbrOfPilots]:=DirInfo.Name;
           AddArticle(GetMenu('pilotsmenu')^,PilotStr(DirInfo.Name),White,True,' ');
           FindNext(DirInfo);
     END;
END;

procedure Init;
VAR aFile : TEXT;
    aStr : STRING;

begin
   { Loads the CONFIG file XWCU.CFG ... }
     UseConfigFile('XWCU.CFG');
     REPEAT
           aStr:=FindNextInfo;
           IF aStr>'' THEN BEGIN
              IF Variable(aStr)='XWINGPATH' THEN XWingPath:=Valeur(aStr);
           END;
     UNTIL aStr='';
     CloseConfigFile;
     IF FSearch('XWING.EXE',XWingPATH)='' THEN
        Erreur('The X-wing program path set by the Config file is invalid');
   { ReconnaŒt la pr‚sence de modules suppl‚mentaires }
     RecognizeConfig;
   { Inits variables }
     aPilotIsLoaded:=False;Modified:=False;
   { Inits Text Mode }
     InitTextMode(CO80,Magenta);
end;

procedure LoadData;
VAR aMenu : Menu; aWindow : WindowType;
    i : Byte;
    aFile : TEXT;
begin
     { Reads MENUS.DOC menus definitions }
     Assign(aFile,'MENUS.DOC');
     IF FSearch('MENUS.DOC',GetCurrentPath)=''
        THEN Erreur('Unable to find Menus definition file MENUS.DOC...');
     Reset(aFile);
     FOR i:=1 to NbrOfMenus DO BEGIN
         ReadMenuFromFile(aFile,aMenu);NewMenu(aMenu);
     END;
     Close(aFile);
     { Reads WINDOWS.DOC windows defintions }
     Assign(aFile,'WINDOWS.DOC');
     IF FSearch('WINDOWS.DOC',GetCurrentPath)=''
        THEN Erreur('Unable to find Windows definition file WINDOWS.DOC...');
     Reset(aFile);
     FOR i:=1 to NbrOfWindows DO BEGIN
         ReadWindowFromFile(aFile,aWindow);NewWindow(aWindow);
     END;
     Close(aFile);
     SetContentProc('Pilot',PilotContent);
     SetContentProc('PilotLog',PilotLogContent);
     SetContentProc('Score1',MissionScoreWindowContent);
     SetContentProc('Score2',OperationScoreWindowContent);
     SetContentProc('Kills',TODVictoriesContent);
     IF ImperialPursuitModule THEN BEGIN
        EnableArticle('tours',4);
     END;
     IF BwingModule THEN BEGIN
        EnableArticle('tours',5);
        EnableArticle('crafts',4);
     END;
end;

procedure DisplayPilot;
BEGIN
     IF Modified THEN SetWindowTitle('Pilot','Pilot in memory (modified)')
                 ELSE SetWindowTitle('Pilot','Pilot in memory');
     Show('Pilot');
END;

procedure WritePilot;
VAR i : Integer;
begin
     Rewrite(PilotFile);
     for i:=0 to FileLength do write(PilotFile,T[i]);
     Close(PilotFile);
     Modified:=False;
end;

FUNCTION AskForSave : Boolean;
VAR anAnswer : Char;
BEGIN
     Show('AskSave');
     REPEAT
           Write(' Save your modified pilot before closing (y/n) ? ');
           anAnswer:=ReadKey;anAnswer:=UPCASE(anAnswer);WriteLn(anAnswer);
     UNTIL (anAnswer='Y') OR (anAnswer='N');
     IF anAnswer='Y' then AskForSave:=True ELSE AskForSave:=False;
     Hide('AskSave');
END;

PROCEDURE ClosePilot;
VAR i : Byte;
BEGIN
     IF aPilotIsLoaded THEN BEGIN
        IF Modified=True THEN IF AskForSave=True THEN WritePilot;
        Hide('Pilot');
        for i:=2 to 4 do DisableArticle('main',i);
        SetArticleIntitule('main',1,'Load a pilot {.PLT file)');
     END;
     Modified:=False;
END;

FUNCTION AskForAPilot : String;
VAR aChoice : Integer;
BEGIN
     Show('pilotsmenu');aChoice:=Choice;
     IF aChoice>0 THEN BEGIN
        PilotName:=Pilots[aChoice];
        AskForAPilot:=XWingPATH+'\'+PilotName+'.PLT';
     END
     ELSE AskForAPilot:='';
     Hide('pilotsmenu');
END;

FUNCTION AskForANumber : LongInt;
VAR aLongInt : LongInt;
    i,j : Byte;
    E : TEvent;
    LastHelpLine : String;
BEGIN
     LastHelpLine:=HelpLineContent;
     HelpLine(EnterNumber);Show('AskNumber');aLongInt:=0;i:=3;
     REPEAT
           gotoxy(i,1);REPEAT GetKeyEvent(E) UNTIL E.What=evKeyDown;
           for j:=0 to 9 do
            if (E.KeyCode=Touches09[1,j]) OR (E.KeyCode=Touches09[2,j]) THEN
            BEGIN
                 aLongInt:=aLongInt*10+j;Write(j);Inc(i);
            END;
           CASE E.KeyCode OF
           kbEsc : aLongInt:=-1;
           kbDel,kbBack : IF (i>3) THEN BEGIN
                      aLongInt:=aLongInt DIV 10;
                      Dec(i);gotoxy(i,1);write(' ');
                   END;
           END;
     UNTIL (E.KeyCode=kbEnter) OR (E.KeyCode=kbEsc);
     AskForANumber:=aLongInt;
     Hide('AskNumber');HelpLine(LastHelpLine);
END;

PROCEDURE MenuLoad;
VAR i : Integer;
begin
     ClosePilot;ReadPilots;PilotFilePATH:=AskForAPilot;
     IF PilotFilePATH<>'' THEN BEGIN
        Assign(PilotFile,PilotFilePATH);Reset(PilotFile);Seek(PilotFile,0);
        FOR i:=0 to FileLength DO READ(PilotFile,T[i]);
        Close(PilotFile);
        aPilotIsLoaded:=True;
        for i:=2 to 4 do EnableArticle('main',i);
        DisplayPilot;
        SetArticleIntitule('main',1,'Load another pilot...');
     END;
END;

PROCEDURE MenuAbout;
VAR aStr : String;
    LastHelpLine : String;
    Key : Char;
    aFile : TEXT;
BEGIN
     LastHelpLine:=HelpLineContent;
     HelpLine(KeyToExit);
     Show('About');
     TextColor(White);
     Assign(aFile,'XWCU.DOC');
     IF FSearch('XWCU.DOC',GetCUrrentPath)=''
        THEN Erreur('Unable to find About file XWCU.DOC !');
     Reset(aFile);
     REPEAT ReadLn(aFile,aStr);WriteLn(aStr); UNTIL EOF(aFile);
     Close(aFile);Key:=ReadKey;Hide('About');
     HelpLine(LastHelpLine);
     IF aPilotIsLoaded THEN DisplayPilot;
END;

PROCEDURE StatusMenu;
VAR i : Integer;
    aChoice,aChoice2,aChoice3 : Byte;
    aNumber : LongInt;
BEGIN
   Show('pilotstatus');
   REPEAT
     aChoice:=Choice;
     CASE aChoice OF
     1 : BEGIN   { Change Pilot Status : Alive,Captured,Killed }
         ClearMarks('kindofstatus');
         SetArticleMark('kindofstatus',T[Status]+1,'x');
         Show('kindofstatus');
         aChoice2:=Choice;
         IF aChoice2>0 THEN BEGIN
            T[Status]:=aChoice2-1;UpDateWindow('Pilot');
         END;
         Hide('kindofstatus');
     END;
     2 : BEGIN   { Change Pilot Rank : Flight Cadet ... General }
         ClearMarks('kindofrank');
         SetArticleMark('kindofrank',T[Rank]+1,'x');
         Show('kindofrank');aChoice2:=Choice;
         IF aChoice2>0 THEN BEGIN
            T[Rank]:=aChoice2-1;UpDateWindow('Pilot');
         END;
         Hide('kindofrank');
     END;
     3 : BEGIN   { Change medals }
         for i:=0 to 4 do
           IF T[CorellianCross+i]=1 THEN SetArticleMark('medals',i+2,'x')
                                    ELSE SetArticleMark('medals',i+2,' ');
         REPEAT
           Show('medals');aChoice2:=Choice;
           CASE aChoice2 OF
           1 : BEGIN
             for i:=1 to 7 do SetArticleMark('kalidor',i,' ');
             SetArticleMark('kalidor',T[KalidorCrescent]+1,'x');
             Show('kalidor');
             aChoice3:=Choice;
             IF aChoice3>0 THEN BEGIN
                T[KalidorCrescent]:=aChoice3-1;
                ClearMarks('kalidor');SetArticleMark('kalidor',aChoice,'x');
             END;
             Hide('kalidor');
             END;
           2 : IF T[CorellianCross]=1 THEN T[CorellianCross]:=0 ELSE T[CorellianCross]:=1;
           3 : IF T[MantooineMedallion]=1 THEN T[MantooineMedallion]:=0 ELSE T[MantooineMedallion]:=1;
           4 : IF T[StarOfAlderaan]=1 THEN T[StarOfAlderaan]:=0 ELSE T[StarOfAlderaan]:=1;
           5 : If T[YavinShield]=1 THEN T[YavinShield]:=0 ELSE T[YavinShield]:=1;
           6 : If T[TalonsOfHoth]=1 THEN T[TalonsOfHoth]:=0 ELSE T[TalonsOfHoth]:=1;
           END;
           for i:=0 to 4 do
           IF T[CorellianCross+i]=1 THEN SetArticleMark('medals',i+2,'x')
                                    ELSE SetArticleMark('medals',i+2,' ');
        UNTIL (aChoice2=0);
        Hide('medals');
     END;
     4 : { Change Historic Missions Experience }
         BEGIN
         aNumber:=AskForANumber;
         IF aNumber>=0 THEN BEGIN
            WriteInBytes(HistoricXP,aNumber);
            UpdateWindow('Pilot');
            END;
         END;
     5 : { Change Tour Of Duty Experience }
       BEGIN
         aNumber:=AskForANumber;
         IF aNumber>=0 THEN BEGIN
            WriteInBytes(TODXP,aNumber);
            UpdateWindow('Pilot');
            END;
         END;
     END;
   UNTIL (aChoice=0);
   Hide('pilotstatus');
END;

PROCEDURE HistoricMissionsMenu;
VAR i : Byte;
    MenuName : NickName;
    WhereCompleted : Integer;
    Completed : Boolean;Where:Value;
    aChoice1,aChoice2,aChoice3 : Byte;
    aNumber : Longint;
BEGIN
   Show('crafts');
   REPEAT
     aChoice1:=Choice;
     IF aChoice1>0 THEN BEGIN
        Craft:=aChoice1-1;
        CASE Craft OF
             0 : MenuName:='xwingmissions';
             1 : MenuName:='ywingmissions';
             2 : MenuName:='awingmissions';
             3 : MenuName:='bwingmissions';
        END;
        ClearMarks(MenuName);
        for i:=1 to 6 do
            IF T[SuccessfulHistoricMissions+i-1+Craft*16]=1 THEN
               SetArticleMark(MenuName,i,'x');
        REPEAT
          Show(MenuName);aChoice2:=Choice;
          IF aChoice2>0 THEN BEGIN
            Mission:=aChoice2-1;
            SetWindowTitle('Score1',CraftsNames[Craft+1]+' '+GetArticle(MenuName,Mission+1));
            Show('Score1');
            WhereCompleted:=SuccessfulHistoricMissions+Mission+Craft*16;
            Where:=HistoricScores;Where.Offset:=Where.Offset+Mission*4+Craft*64;
            Completed:=(T[WhereCompleted]=1);
            IF Completed THEN SetArticleIntitule('historicmenu',1,'Set mission to ''Not completed'' ')
                         ELSE SetArticleIntitule('historicmenu',1,'Set mission to ''Completed'' ');
            REPEAT
              Show('historicmenu');aChoice3:=Choice;
              CASE aChoice3 OF
              1 : BEGIN
                IF Completed THEN BEGIN
                   T[WhereCompleted]:=0;Completed:=False;
                   SetArticleIntitule('historicmenu',1,'Set mission to ''Completed'' ');
                   SetArticleMark(MenuName,Mission+1,' ');
                   END
                ELSE BEGIN
                   T[WhereCompleted]:=1;Completed:=True;
                   SetArticleIntitule('historicmenu',1,'Set mission to ''Not completed'' ');
                   SetArticleMark(MenuName,Mission+1,'x');
                END;
                Hide('historicmenu');
                END;
              2 : BEGIN
                  aNumber:=AskForANumber;
                  IF aNumber>=0 THEN WriteInBytes(Where,aNumber);
                  UpdateWindow('Score1');
                  END;
              END;
            UNTIL aChoice3=0;
            Hide('historicmenu');Hide('Score1');
          END;
        UNTIL aChoice2=0;
        Hide(MenuName);
     END;
   UNTIL aChoice1=0;
   Hide('crafts');
END;

PROCEDURE ProvingGroundMenu;
VAR Where : Value;
    aNumber : LongInt;
    aChoice,aChoice2,aChoice3 : Byte;
BEGIN
   Show('crafts');
   REPEAT
     aChoice:=Choice;
     IF aChoice>0 THEN BEGIN
        Craft:=aChoice-1;
        Show('pgroundmenu');
        REPEAT
          aChoice2:=Choice;
          CASE aChoice2 OF
          1 : BEGIN
              ClearMarks('pilotlevels');
              SetArticleMark('pilotlevels',T[TrainingLevels+Craft]+1,'x');
              Show('pilotlevels');
              aChoice3:=Choice;
              IF aChoice3>0 THEN T[TrainingLevels+Craft]:=aChoice3-1;
              Hide('pilotlevels');
           END;
          2 : BEGIN
              Where:=TrainingScores;Where.Offset:=Where.Offset+Craft*4;
              aNumber:=AskForANumber;
              IF aNumber>=0 THEN WriteInBytes(Where,aNumber);
              END;
          END;
        UNTIL aChoice2=0;
        Hide('pgroundmenu');
     END;
   UNTIL aChoice=0;
   Hide('crafts');
END;

PROCEDURE TODVictories;
VAR E : TEvent;
    H : ARRAY[0..20] of Byte;
    DC : KindOfVictories;
    i,j : ShortInt;
    Where : Value;
    aNumber : LongInt;

  PROCEDURE WriteIndex(i : Integer; DC : KindOfVictories ; Trace : Boolean);
  BEGIN
       IF DC=Destroyed THEN gotoxy(28,i+1) ELSE gotoxy(38,i+1);
       IF Trace THEN TextColor(Yellow) ELSE TextColor(Blue);
       Write('¯');
  END;

BEGIN
   j:=0;
   for i:=0 to 23 do if CraftsNames[i+1]<>'' THEN BEGIN
       H[j]:=i;Inc(j);
   END;
   j:=0;DC:=Destroyed;
   REPEAT
     Show('Kills');WriteIndex(j,DC,True);
     REPEAT
      REPEAT GetKeyEvent(E) UNTIL E.What=evKeyDown;
      WriteIndex(j,DC,False);
      CASE E.KeyCode OF
        kbDown : BEGIN    { FlŠche basse }
               Inc(j);IF j>20 THEN j:=0;
               END;
        kbUp : BEGIN      { FlŠche haute }
               Dec(j);IF j<0 THEN j:=20;
               END;
        kbLeft,kbRight: IF DC=Destroyed THEN DC:=Captured ELSE DC:=Destroyed;
        END;
        WriteIndex(j,DC,True);
     UNTIL (E.KeyCode=kbEnter) OR (E.KeyCode=kbEsc);
     IF E.KeyCode=kbEnter THEN BEGIN
        IF DC=Destroyed THEN Where:=TODCraftsDestroyed
                        ELSE Where:=TODCraftsCaptured;
        Where.Offset:=Where.Offset+H[j]*2;
        aNumber:=AskForANumber;
        IF aNumber>=0 THEN WriteInBytes(Where,aNumber);
        END
   UNTIL E.KeyCode=kbEsc;
   Hide('Kills');
end;

PROCEDURE TOD;
VAR i : Integer;
    Where : Value;
    aChoice1,aChoice2,aChoice3 : Byte;
    aNumber : LongInt;

PROCEDURE ShowMarks(aTour : Byte ; aMission : Byte);
VAR i : Integer;
BEGIN
    SetArticleMark(TourName[aTour],MenuLength(TourName[aTour]),' ');
    for i:=1 to MenuLength(TourName[aTour])-1 DO
        IF C[aTour,i-1]=aMission THEN SetArticleMark(TourName[aTour],i,'x')
                                 ELSE SetArticleMark(TourName[aTour],i,' ');
    if T[TourStatus+aTour]=3 THEN SetArticleMark(TourName[aTour],MenuLength(TourName[aTour]),'x');
end;

BEGIN
  Show('todmenu');
  REPEAT
    aChoice1:=Choice;
    CASE aChoice1 OF
    1 : BEGIN   { Play Mission... }
        Show('tours');
        REPEAT
          aChoice2:=Choice;
          IF aChoice2>0 THEN BEGIN
            Tour:=aChoice2-1;
            REPEAT
            ShowMarks(Tour,T[TourOperation+Tour]);
            Show(TourName[Tour]);
              aChoice3:=Choice;
              IF aChoice3>0 THEN BEGIN
                 Mission:=aChoice3-1;
                 T[CurrentTOD]:=Tour;T[$282]:=Mission;
                 T[$283]:=C[Tour,Mission];T[$287]:=Mission;T[$288]:=$FF;
                 IF Mission<MenuLength(TourName[Tour])-1 THEN
                 IF C[Tour,Mission]=C[Tour,Mission+1] THEN T[$288]:=Mission+1;
                 IF Mission>1 THEN
                 IF C[Tour,Mission]=C[Tour,Mission-1] THEN BEGIN
                    T[$287]:=Mission-1;T[$288]:=Mission;
                 END;
                 T[TourOperation+Tour]:=C[Tour,Mission];
                 for i:=TourStatus TO TourStatus+4 DO
                     IF T[i]<>3 THEN T[i]:=2;  { Incomplete }
                 T[TourStatus+Tour]:=1; { Active }
                 IF (Mission+1=MenuLength(TourName[Tour])) THEN T[TourStatus+Tour]:=3;
                 { Operations available in the Historic Missions }
                 IF Mission=0 THEN T[$2E8+Tour]:=$FF ELSE T[$2E8+Tour]:=C[Tour,Mission-1];
              END;
            UNTIL aChoice3=0;
            Hide(TourName[Tour]);
          END;
        UNTIL aChoice2=0;
        Hide('tours');
    END;
    2 : BEGIN   { Change scores }
         Show('tours');
         REPEAT
           aChoice2:=Choice;
           IF aChoice2>0 THEN BEGIN
             Tour:=aChoice2-1;
             DisableArticle(TourName[Tour],MenuLength(TourName[Tour]));
             REPEAT
               Show(TourName[Tour]);
               aChoice3:=Choice;
               IF aChoice3>0 THEN BEGIN
                  Mission:=aChoice3-1;
                  Where:=TODScores;Where.Offset:=Where.Offset+Tour*100+Mission*4;
                  SetWindowTitle('Score2',TourName[Tour]+' '+GetArticle(TourName[Tour],Mission+1));
                  Show('Score2');aNumber:=AskForANumber;
                  IF aNumber>=0 THEN WriteInBytes(Where,aNumber);
                  Hide('Score2');
               END;
             UNTIL aChoice3=0;
             EnableArticle(TourName[Tour],MenuLength(TourName[Tour]));
             Hide(TourName[Tour]);
           END;
         UNTIL aChoice2=0;
         Hide('tours');
    END;
    3 : TODVictories;
    4 : BEGIN { TOD Statistics }
         Show('statistics');
         REPEAT
           aChoice2:=Choice;
           IF aChoice2>0 THEN aNumber:=AskForANumber;
           IF aNumber>=0 THEN
           CASE aChoice2 OF
           1 : WriteInBytes(TODSurfaceVictories,aNumber);
           2 : WriteInBytes(TODLaserFired,aNumber);
           3 : WriteInBytes(TODLaserCraftHits,aNumber);
           4 : WriteInBytes(TODLaserGroundHits,aNumber);
           5 : WriteInBytes(TODHomingProjFired,aNumber);
           6 : WriteInBytes(TODHPCraftHits,aNumber);
           7 : WriteInBytes(TODHPGroundHits,aNumber);
           8 : WriteInBytes(TODCraftsLost,aNumber);
           END;
         UNTIL aChoice2=0;
         Hide('statistics');
    END;
    END;
  UNTIL aChoice1=0;
  Hide('todmenu');
END;

PROCEDURE EditMenu;
VAR aChoice : Byte;
BEGIN
     Show('edit');
     REPEAT
           aChoice:=Choice;
           CASE aChoice OF
                1 : StatusMenu;
                2 : ProvingGroundMenu;
                3 : HistoricMissionsMenu;
                4 : TOD;
           END;
           Modified:=True;
     UNTIL aChoice=0;  { ESC }
     Hide('edit');
END;

PROCEDURE Quit;
BEGIN
     ClosePilot;
     TextBackGround(Black);TextColor(White);SetWindow(MaxWindow);ClrScr;
     WriteLn('Leaving X-Wing Cheat Utility... Back to DOS !');
END;

PROCEDURE Utilities;
VAR aChoice,i,Alive : Byte;
    aFile : FILE of Byte;
BEGIN
     Show('utilities');
     aChoice:=Choice;Alive:=0;ReadPilots;
     CASE aChoice OF
     1 : for i:=1 to NbrOfPilots do begin
             Assign(aFile,XwingPATH+'/'+Pilots[i]+'.PLT');Reset(aFile);
             Seek(aFile,Status);Write(aFile,Alive);
             Close(aFile);
         END;
     END;
     Hide('utilities');
END;

PROCEDURE MainMenu;
VAR aChoice : Byte;
BEGIN
   HelpLine(HelpLine1);HeadLine(MainHeadLine);
   REPEAT
     Show('main');aChoice:=Choice;
     CASE aChoice OF
          1 : MenuLoad;
          2 : EditMenu;
          3 : BEGIN
              HelpLine(KeyToContinue);Show('PilotLog');Hide('PilotLog');
              HelpLine(HelpLine1);
              END;
          4 : WritePilot;
          5 : Utilities;
          6 : MenuAbout;
     END;
   UNTIL (aChoice=7) OR (aChoice=0);  { User wants to quit }
   Quit;
END;

BEGIN
     Init;InstallFont('t.fnt');
     LoadData;
     MainMenu;
END.