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

dcl-pr thisPgm  extpgm('TEST');  
  library char(10);             
  todir char(200);              
  dirLength packed(3);           
end-pr;                               
                 
dcl-pi thisPgm ;                      
  library char(10);             
  todir char(200);              
  dirLength packed(3);        
end-pi;                               

// Named Constants
Dcl-C TRUE '1' ;
Dcl-C FALSE '0' ;
Dcl-C QUOTE '''' ;
Dcl-C OK 0 ;
Dcl-C EOF 100 ;
Dcl-C NOAPIERROR 0 ;
Dcl-C CRLF x'0d25' ;
Dcl-C ENTER x'F1' ;
Dcl-C HEXZEROS x'00' ;

// Global Definitions
Dcl-Ds dsGlobal;
  SQLStatement VarChar( 4096 ) ;
  w_Command VarChar( 4096 ) ;
  Error Ind Inz( '0' ) ;
  Today Date Inz( *Sys ) ;
  SysMsgF Char(20) Inz( 'QCPFMSG   *LIBL' ) ;
  File Char( 10 ) ;
  Object Char( 10 ) ;
  Member Char( 10 ) ;
  ErrCode Int(10) Inz( 0 ) ;
  CurrentUser Char(10) Inz( *User ) ;
End-ds;

Dcl-S nbrOfRows Packed(5);
Dcl-S rowsFetched Int(5);
Dcl-S directoryPath char(256);
Dcl-S isOk Ind;

Dcl-Ds sourceDS qualified dim(100);
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
    CloSqlCsr = *EndMod ;

  directoryPath = %trim(%subst(todir : 1 : dirLength)) + '/' + %trim(library);
  isOk = createDirectory(directoryPath);
  getData();
  createDirAndFiles();

*InLr = '1';
Return;


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

Dcl-Proc createDirAndFiles;
  Dcl-Pi *n;
  End-Pi;   

  Dcl-S loopCount Packed(5);
  Dcl-S newSourceFile Ind Inz( '1' );
  Dcl-S sourceMemberQualifiedPath char(256);
  Dcl-S nativeSourcePath char(256);
  Dcl-S previousTable Char(10) Inz( ' ' );
  Dcl-s ifsSourceFilePath char(256);

    For loopCount = 1 to RowsFetched;
      If previousTable <> sourceDS(loopCount).systemTableName;
        ifsSourceFilePath = %trim(todir) 
                            + '/' 
                            + %trim(sourceDS(loopCount).systemTableSchema) + '/'
                            + %trim(sourceDS(loopCount).systemTableName);

        newSourceFile =createDirectory(ifsSourceFilePath);
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

      copyFile(nativeSourcePath:sourceMemberQualifiedPath);
    EndFor;

End-Proc;

Dcl-Proc createDirectory;
  Dcl-Pi *n Ind;
    qualifiedPath char(256);
  End-Pi;

  Dcl-S Command char(300);
  Dcl-C Quote Const(X'7D');

    Command = 'MKDIR DIR(' + Quote + %trim(qualifiedPath) + Quote +')'; 
    Exec Sql CALL QSYS2.QCMDEXC(:Command);
    If sqlcode <> 0 and SQLSTATE = '38501';
      // error
      // directory already exists or wrong path
      Return '0';
    EndIf;

    Return '1';

End-Proc;

Dcl-Proc copyFile;
  Dcl-Pi *n;
    fromPath Char(256);
    toPath Char(256);
  End-Pi;

  Dcl-S Command Char(300);
  Dcl-C Quote Const(X'7D');
 
    Command = 'CPYTOSTMF FROMMBR(' + Quote + %trim(fromPath) + Quote + ') ' +
              'TOSTMF(' + Quote + %trim(toPath) + Quote + ') ' +
              'STMFOPT(*REPLACE) ' +
              'STMFCCSID(*PCASCII)';

    Exec Sql CALL QSYS2.QCMDEXC(:Command);
    If sqlcode <> 0 and SQLSTATE = '38501';
      // error
      // directory already exists or wrong path
    EndIf;

    Return;

End-Proc;
