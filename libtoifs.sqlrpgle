**free

// ***************************************************************//
// Program:      
// Description:
//
// Author:
// Date:
//
// Change Log:
//
//****************************************************************//

Ctl-Opt 
 Option(*NoDebugIO:*SrcStmt:*NoUnref)
 AlwNull( *UsrCtl )
 Copyright('Free to use | V1.0.0 your date | your program name')
 BndDir( 'QC2LE' );

Dcl-Pr thisPgm  extpgm('LIBTOIFS');
  library char(10);             
  path char(500) Options(*Nopass);                      
End-Pr;                               

Dcl-Pi thisPgm;                      
  library char(10);             
  path char(500) Options(*Nopass);                        
End-Pi;                               

// Named Constants
Dcl-C TRUE '1' ;
Dcl-C FALSE '0' ;
Dcl-C QUOTE '''' ;
Dcl-C OK 0;
Dcl-C EOF 100;
Dcl-C NOAPIERROR 0;
Dcl-C CRLF x'0d25';
Dcl-C ENTER x'F1';
Dcl-C HEXZEROS x'00';
Dcl-C DEFAULTPATH '/QOpenSys/source';

// Global Definitions
Dcl-S toDir char(200);
Dcl-S nbrOfRows Packed(5);
Dcl-S rowsFetched Int(5);
Dcl-S directoryPath char(256);
Dcl-S isOk Ind;

Dcl-Ds sourceDS qualified dim(10000);
  sourceType char(10);
  systemTableSchema char(10);
  systemTableName char(10);
  systemTableMember char(10);
  partiotionText char(100);
End-Ds;

// DataAreas
Dcl-Ds pgm_Status PSDS qualified;
  Status *Status ;
  Routine *Routine ;
  Library Char(10) Pos(81) ;
End-ds;


// Mainline

// Set SQL Options
  Exec Sql
    Set Option DatFmt = *Iso,
    Commit = *None,
    CloSqlCsr = *EndMod;

  isOk = init();
  getData();
  createDirAndFiles();

  *InLr = TRUE;
  Return;

// ***************************************************************//
// getData - Get the data from the source table and put it in the
//           sourceDS data structure.
// ***************************************************************//
Dcl-Proc getData;

  Exec Sql
    SELECT count(*) 
    INTO :nbrOfRows
    FROM QSYS2/SYSPARTITIONSTAT 
    WHERE               
    system_table_SCHEMA = :library AND system_table_NAME IN ( 
        SELECT TABLE_NAME 
        FROM QSYS2/SYSTABLES 
        WHERE table_schema = :library
        and table_type = 'P' and file_type ='S');

  Exec Sql
    declare c1 cursor for
    SELECT IFNULL(SOURCE_TYPE, ''), IFNULL(system_table_SCHEMA, ''), IFNULL(system_table_NAME, ''),         
    IFNULL(system_table_MEMBER,''), IFNULL(PARTITION_TEXT, '') 
    FROM QSYS2/SYSPARTITIONSTAT 
    WHERE               
    system_table_SCHEMA = :library AND system_table_NAME IN ( 
        SELECT TABLE_NAME 
        FROM QSYS2/SYSTABLES 
        WHERE table_schema = :library
        and table_type = 'P' and file_type ='S' ) 
    ORDER BY TABLE_NAME;

  Exec Sql
    open c1;

  Exec sql 
    fetch c1 for :nbrOfRows rows into :sourceDS;

  Exec sql 
    GET DIAGNOSTICS :RowsFetched = ROW_COUNT ;

  Exec sql
    close c1;

End-Proc;  

// ***************************************************************//
// createDirAndFiles - Create the directory and files if 
//                     it doesn't exist.
// ***************************************************************//

Dcl-Proc createDirAndFiles;
  Dcl-Pi *n;
  End-Pi;   

  Dcl-S loopCount Packed(5);
  Dcl-S isOk Ind;
  Dcl-S newSourceFile Ind Inz( '1' );
  Dcl-S sourceMemberQualifiedPath char(256);
  Dcl-S nativeSourcePath char(256);
  Dcl-S previousTable Char(10) Inz( ' ' );
  Dcl-s ifsSourceFilePath char(256);

    For loopCount = 1 to RowsFetched;
      // Each source mebmber will be a directory inside the library named directory
      If previousTable <> sourceDS(loopCount).systemTableName;
        ifsSourceFilePath = %trim(todir) 
                            + '/' 
                            + %trim(sourceDS(loopCount).systemTableSchema) + '/'
                            + %trim(sourceDS(loopCount).systemTableName);

        newSourceFile = createDirectory(ifsSourceFilePath);
        previousTable = sourceDS(loopCount).systemTableName;
      EndIf;

      nativeSourcePath = '/QSYS.LIB/'
                        + %trim(sourceDS(loopCount).systemTableSchema) + '.LIB/'
                        + %trim(sourceDS(loopCount).systemTableName) + '.FILE/'
                        + %trim(sourceDS(loopCount).systemTableMember) + '.MBR';

      sourceMemberQualifiedPath = %trim(todir) + '/'
                                  + %trim(sourceDS(loopCount).systemTableSchema) + '/'
                                  + %trim(sourceDS(loopCount).systemTableName) + '/'
                                  + %trim(sourceDS(loopCount).systemTableMember) + '.'
                                  + %trim(sourceDS(loopCount).sourceType);

      isOk = copyFile(nativeSourcePath:sourceMemberQualifiedPath);
    EndFor;

End-Proc;

// ***************************************************************//
// createDirectory - Copy the file from the native source path to the
//            ifs source path.
// ***************************************************************//

Dcl-Proc createDirectory;
  Dcl-Pi *n Ind;
    qualifiedPath char(256);
  End-Pi;

  Dcl-S Command char(1000);
  Dcl-C Quote Const(X'7D');

    Command = 'MKDIR DIR(' + Quote + %trim(qualifiedPath) + Quote +')'; 

    Return executeCommand(command);

End-Proc;

// ***************************************************************//
// copyFile - Copy the file from the native source path to the
//            ifs source path.
// ***************************************************************//

Dcl-Proc copyFile;
  Dcl-Pi *n Ind;
    fromPath Char(256);
    toPath Char(256);
  End-Pi;

  Dcl-S Command Char(1000);
  Dcl-C Quote Const(X'7D');
  Dcl-S Status Ind;
 
    Command = 'CPYTOSTMF FROMMBR(' + Quote + %trim(fromPath) + Quote + ') ' +
              'TOSTMF(' + Quote + %trim(toPath) + Quote + ') ' +
              'STMFOPT(*REPLACE) ' +
              'STMFCCSID(*PCASCII)';
    
    Return executeCommand(Command);

End-Proc;

// ***************************************************************//
// executeCommand - Execute the command and return the status.
// ***************************************************************//

Dcl-Proc executeCommand;
  Dcl-Pi *n Ind;
    command Char(1000);
  End-Pi;

    Exec Sql CALL QSYS2.QCMDEXC(:command);
    If sqlcode <> OK and SQLSTATE = '38501';
      // source already exists
      Return FALSE;
    EndIf;

    Return TRUE;

End-Proc;

// ***************************************************************//
// init - Initialize the program.
// ***************************************************************//

Dcl-Proc Init;
  Dcl-Pi *n Ind;
  End-Pi;

  Dcl-S Command Char(1000);

    If %Parms() = 2;
      toDir = path + '/source';
    Else;
      toDir = DEFAULTPATH; 
    EndIf;

    Command = 'DSPLNK OBJ(' + QUOTE + %trim(toDir) + '/qsys' + QUOTE + ')';
    If executeCommand(Command);

    Else;
      isOk = gitSyncSetup();
    EndIf;

    // Library directory
    Clear directoryPath;
    directoryPath = %trim(%subst(todir : 1 : %scan(' ' : todir : 1))) + '/' + %trim(library);
    Return isOk = createDirectory(directoryPath);

End-Proc;

// ***************************************************************//
// gitSyncSetup 
// ***************************************************************//

Dcl-Proc gitSyncSetup;
  Dcl-Pi *n Ind;
  End-Pi;

  Dcl-S Command Char(1000);
  Dcl-C QSYSGITPATH CONST('/qsys.git');
  Dcl-C GITINITBARECOMMAND CONST('/QOpenSys/pkgs/bin/git  init --bare');
  Dcl-C GITCLONECOMMAND CONST('/QOpenSys/pkgs/bin/git clone qsys.git');

//  create default directory first time

    // source directory 
    Clear directoryPath;
    directoryPath = toDir;
    isOk = createDirectory(directoryPath);

    // qsys.git directory
    Clear directoryPath;
    directoryPath =  %trim(toDir) + %trim(QSYSGITPATH);
    isOk = createDirectory(directoryPath);

    // git init --bare qsys.git
    Command = 'strqsh  cmd(' + QUOTE + 'cd ' + %trim(directoryPath) + '; ' +
              GITINITBARECOMMAND + QUOTE + ')';
    isOk = executeCommand(Command);

    // git clone qsys.git qsys
    Command = 'strqsh  cmd(' + QUOTE + 'cd ' + %trim(toDir) + '; ' +
              GITCLONECOMMAND + QUOTE + ')';
    Return executeCommand(Command);

End-Proc;
