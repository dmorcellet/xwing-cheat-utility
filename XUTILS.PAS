UNIT XUTILS;

INTERFACE

USES DeskTop;

TYPE
     Value = RECORD
         Offset : Word;
         Length : Word;
     END;
     KindOfVictories=(Destroyed,Captured);

CONST FileLength=1705;Status=2;Rank=3;NbrOfMenus=25;NbrOfWindows=8;
      Ranks:ARRAY[0..5] of STRING[15] =
      ('Flight Cadet','Flight Officer','Lieutenant','Captain','Commander','General');
      StatusNames: ARRAY[0..2] of STRING[8] = ('Alive','Captured','Killed');
      TrainingLevels=$86;SuccessfulHistoricMissions=$220;
      KalidorCrescent=$11;CorellianCross=$0A;YavinShield=$D;
      MantooineMedallion=$0B;StarOfAlderaan=$0C;TalonsOfHoth=$E;
      CurrentTOD=$280;TourStatus=$2E0;TourOperation=$2F0;
      StarFightersNames:ARRAY[1..4] of String[7] =
      ('X-Wing','Y-Wing','A-Wing','B-Wing');
      CraftsNames:ARRAY[1..24] of STRING[25] =
      ( 'X-Wing','Y-Wing','A-Wing','TIE Fighter','TIE Interceptor',
        'TIE Bomber','Assault Gunboat','Transport','Shuttle','Tug',
        'Container','Freighter','Calamari Cruiser','Nebulon B Fregate',
        'Corellian Corvette','Star Destroyer','TIE Advanced','B-Wing','','',
        'Mines','','Communication Satellites','Space Probe');
      TourName:ARRAY[0..4] of String[8] = ('Tour I','Tour II','Tour III','Tour IV','Tour V');
      HelpLine1='Make your choice with Up & Down Arrows ; Enter = OK ; ESC = Go back';
      KeyToExit='Press a key to exit...';
      KeyToContinue='Press a key to continue...';
      MainHeadLine=' X-wing Cheat Utility v2.0                        Copyright (1994) D.MORCELLET';
      EnterNumber='Please enter a number or type ESC to go back...';
      Touches09 : ARRAY[1..2,0..9] of Word =
         ( (21040,20273,20530,20787,19252,19509,19766,18231,18488,18745),
           (2864,561,818,1075,1332,1589,1846,2103,2360,2617));

VAR HistoricXP,TODXP,TrainingScores,HistoricScores,
    TODScores,TODCraftsDestroyed,TODCraftsCaptured,TODSurfaceVictories,
    TODLaserFired,TODLaserCraftHits,TODLaserGroundHits,TODHomingProjFired,
    TODHPCraftHits,TODHPGroundHits,TODCraftsLost : Value;
    T : ARRAY[0..FileLength] of Byte;

FUNCTION ReadFromMemory (aValue : Value): LONGINT;
function GetHistoricRank : String;
PROCEDURE WriteInBytes(Where : Value ; What : LongInt);

IMPLEMENTATION

PROCEDURE FillValue(VAR aValue : Value ; aOffset,aLength : Word);
BEGIN
     aValue.Offset:=aOffset;aValue.Length:=aLength;
END;

PROCEDURE InitConstants;
BEGIN
   FillValue(HistoricXP,8,2);FillValue(TODXP,4,4);
   FillValue(TrainingScores,$26,4);FillValue(HistoricScores,$A0,4);
   FillValue(TODScores,$2F8,4);
   FillValue(TODCraftsDestroyed,$636,2);FillValue(TODCraftsCaptured,$666,2);
   FillValue(TODSurfaceVictories,$634,2);
   FillValue(TODLaserFired,$696,4);FillValue(TODLaserCraftHits,$69A,4);
   FillValue(TODLaserGroundHits,$69E,4);FillValue(TODHomingProjFired,$6A2,2);
   FillValue(TODHPCraftHits,$6A4,2);FillValue(TODHPGroundHits,$6A6,2);
   FillValue(TODCraftsLost,$6A8,2);
END;

FUNCTION ReadFromMemory (aValue : Value): LONGINT;
VAR Somme,Puissance : LongInt;
    i : Integer;
BEGIN
     Somme:=0;Puissance:=1;
     for i:=0 to aValue.Length-1 do begin
         Somme:=Somme+T[aValue.Offset+i]*Puissance;
         Puissance:=Puissance*256;
     end;
     ReadFromMemory:=Somme;
END;

function GetHistoricRank : String;
VAR XP : LongInt;
    S : String;
begin
     XP:=ReadFromMemory(HistoricXP);S:='Top Ace';
     IF Xp<65535 THEN S:='Ace';IF XP<49152 THEN S:='Veteran';
     IF XP<32768 THEN S:='Officer';IF Xp<16384 THEN S:='Rookie';
     GetHistoricRank:=S;
end;

PROCEDURE WriteInBytes(Where : Value ; What : LongInt);
VAR aByte : Byte;
    Sum : LongInt;
    i : Integer;
BEGIN
     Sum:=What;
     for i:=1 to Where.Length DO BEGIN
         aByte:=Sum MOD 256;
         Sum:=Sum DIV 256;T[Where.Offset-1+i]:=aByte;
     END;
END;

BEGIN
     InitConstants;
END.
