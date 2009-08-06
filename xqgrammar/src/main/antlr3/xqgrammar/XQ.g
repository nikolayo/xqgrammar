/*=============================================================================

    Copyright 2009 Nikolay Ognyanov

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

=============================================================================*/
/*=============================================================================
            
            XQGrammar : An NTLR 3 XQuery Grammar, Version 1.0.0
            
            Supported W3C grammars:
            
            1. XQuery 1.0 
               Recommendation / 23 January 2007
               http://www.w3.org/TR/xquery/
               
            2. XQuery Update Facility 1.0
               Candidate Recommendation / 09 June 2009
               http://www.w3.org/TR/xquery-update-10/
               
            3. XQuery Scripting Extension 1.0
               Working Draft / 3 December 2008 with added fix
               for bug #6852 from W3C public Bugzilla 
               ("exit returning" instead of "exit with")
               http://www.w3.org/TR/xquery-sx-10/
               
            4. XQuery 1.1
               Partial support of Working Draft / 3 December 2008
               http://www.w3.org/TR/xquery-11/
               The features not supported are windows and decimal formats.
          
=============================================================================*/

grammar XQ;

// Tokens shared with the direct XML lexer
tokens {
    LAngle;
    RAngle;
    LCurly;
    RCurly;
    LClose;
    RClose;
    SymEq;
    Colon;
    Quot;
    Apos;
    EscapeQuot;
    EscapeApos;
    EscapeLCurly;
    EscapeRClurly;
    ElementContentChar;
    PredefinedEntityRef;
    QuotAttrContentChar;
    AposAttrContentChar;
}

@header {
    package xqgrammar;
}
@lexer::header {
    package xqgrammar;
}
@members {
    // small trick to pass token codes 
    // to super class at creation time
    boolean dummy = setTokenCodes(NCName, Colon);
}

module
    : versionDecl? (libraryModule | mainModule)
    ;    
versionDecl
    : //XQUERY VERSION StringLiteral (ENCODING StringLiteral)? ';' //XQuery 1.0
      XQUERY  ((ENCODING StringLiteral {checkEncoding();}) |       //XQuery 1.1
      (VERSION StringLiteral (ENCODING StringLiteral {checkEncoding();})?)) ';'
    ;
mainModule
    : prolog queryBody
    ;
libraryModule
    : moduleDecl prolog
    ;
moduleDecl
    : MODULE NAMESPACE ncName SymEq uriLiteral ';'
    ;
prolog
    :                                                             // XQuery 1.0
      //((defaultNamespaceDecl | setter | namespaceDecl | importDecl) ';')* 
      //((varDecl | functionDecl | optionDecl) ';')*
                                                                  // XQuery 1.1
      ((defaultNamespaceDecl | setter | namespaceDecl | importDecl) ';')* 
      ((varDecl | functionDecl | optionDecl | contextItemDecl) ';')*
    ;
setter
    : boundarySpaceDecl 
    | defaultCollationDecl 
    | baseURIDecl
    | constructionDecl  
    | orderingModeDecl     
    | emptyOrderDecl 
    | revalidationDecl                                            // ext:update
    | copyNamespacesDecl
    ;
importDecl
    : schemaImport
    | moduleImport
    ;
namespaceDecl
    : DECLARE NAMESPACE ncName SymEq uriLiteral
    ;
boundarySpaceDecl
    : DECLARE BOUNDARY_SPACE (PRESERVE | STRIP)
    ;
defaultNamespaceDecl
    : DECLARE DEFAULT (ELEMENT | FUNCTION) NAMESPACE uriLiteral
    ;
optionDecl
    : DECLARE OPTION qName StringLiteral
    ;
orderingModeDecl
    : DECLARE ORDERING (ORDERED | UNORDERED)
    ;
emptyOrderDecl
 	: DECLARE DEFAULT ORDER EMPTY (GREATEST | LEAST)
 	;
copyNamespacesDecl
    : DECLARE COPY_NAMESPACES preserveMode ',' inheritMode
    ;
preserveMode
    : PRESERVE | NO_PRESERVE
    ;
inheritMode
    : INHERIT  | NO_INHERIT
    ;
defaultCollationDecl
    : DECLARE DEFAULT COLLATION uriLiteral;
baseURIDecl
    : DECLARE BASE_URI uriLiteral
    ;
schemaImport
    : IMPORT SCHEMA schemaPrefix? uriLiteral 
       (AT uriLiteral (',' uriLiteral)*)?
    ;
schemaPrefix
    : (NAMESPACE ncName SymEq)
    | DEFAULT ELEMENT NAMESPACE
    ;
moduleImport
    : IMPORT MODULE (NAMESPACE ncName SymEq)? uriLiteral
      (AT uriLiteral (',' uriLiteral)*)?
    ;
varDecl
    : //DECLARE VARIABLE '$' qName typeDeclaration?
      DECLARE (VARIABLE | CONSTANT) '$' qName typeDeclaration? // ext:scripting
      //((':=' exprSingle) | EXTERNAL)
      ((':=' varValue) | EXTERNAL (':=' varDefaultValue)?)        // XQuery 1.1
    ;
varValue                                                          // XQuery 1.1
    : exprSingle
    ;
varDefaultValue                                                   // XQuery 1.1
    : exprSingle
    ;
constructionDecl
    : DECLARE CONSTRUCTION (STRIP | PRESERVE)
    ;
contextItemDecl                                                   // XQuery 1.1
    : DECLARE CONTEXT ITEM (AS itemType)? 
      ((':=' varValue) | (EXTERNAL (':=' varDefaultValue)?))
    ;
functionDecl
    : //  DECLARE FUNCTION fqName '(' paramList? ')'              // XQuery 1.0
      /*
          DECLARE UPDATING? FUNCTION fqName '('  paramList? ')'   // ext:update
              (AS sequenceType)? (enclosedExpr | EXTERNAL)
      */
           DECLARE (DETERMINISTIC | NONDETERMINISTIC)?            // Xquery 1.1
              (SIMPLE? | UPDATING)                             // ext:scripting
              FUNCTION fqName '(' paramList? ')' 
              (AS sequenceType)? (enclosedExpr | EXTERNAL)
         | DECLARE (DETERMINISTIC | NONDETERMINISTIC)?            // Xquery 1.1
              SEQUENTIAL             FUNCTION fqName '(' paramList? ')'
              (AS sequenceType)? (block        | EXTERNAL)
    ;
paramList
    : param (',' param)*
    ;
param
    : '$' qName typeDeclaration?
    ;
enclosedExpr
    : LCurly expr RCurly
    ;
queryBody
    : expr
    ;
expr  // Some hand crafted  parsing since                      // ext:scripting
      // original W3C grammar is not LL(*)
      @init
      {
        boolean seqStarted = false;
        boolean seqEnded   = false;
      }
      @after {
        if(seqStarted && !seqEnded) {
            raiseError("Sequential expression not terminated by ';'.");
        }
      }
    : exprSingle ((',' | ';' { seqStarted = true; }) exprSingle )* 
      (';' { seqEnded = true; })?
    ;    
/*
// W3C grammar:
expr 
    : applyExpr                                                // ext:scripting
    | concatExpr
    ;
applyExpr                                                      // ext:scripting
    : (concatExpr ';')+
    ;
concatExpr                                                     // ext:scripting
    : exprSingle (',' exprSingle)*
    ;
*/
exprSingle
    : flworExpr
    | quantifiedExpr
    | typeswitchExpr
    | ifExpr
    | tryCatchExpr                                                // XQuery 1.1
    | orExpr
    | insertExpr                                                  // ext:update 
    | deleteExpr                                                  // ext:update
    | renameExpr                                                  // ext:update
    | replaceExpr                                                 // ext:update
    | transformExpr                                               // ext:update
    | blockExpr                                                // ext:scripting
    | assignmentExpr                                           // ext:scripting
    | exitExpr                                                 // ext:scripting
    | whileExpr                                                // ext:scripting
    ;
flworExpr
    : (forClause | letClause)+ whereClause? orderByClause? RETURN exprSingle
    ;
forClause
    : FOR  '$' varName typeDeclaration? positionalVar? IN exprSingle 
      (',' '$' varName typeDeclaration? positionalVar? IN exprSingle)*
    ;
positionalVar
    : AT '$' varName
    ;
letClause
    : LET '$' varName typeDeclaration? ':=' exprSingle 
     (',' '$' varName typeDeclaration? ':=' exprSingle)*
    ;
whereClause
    : WHERE exprSingle
    ;
orderByClause
    : ((ORDER BY) | (STABLE ORDER BY)) orderSpecList
    ;
orderSpecList
    : orderSpec (',' orderSpec)*
    ;
orderSpec
    : exprSingle orderModifier
    ;
orderModifier
    : (ASCENDING | DESCENDING)? 
      (EMPTY (GREATEST | LEAST))? 
      (COLLATION uriLiteral)?
    ;
quantifiedExpr
    : (SOME | EVERY) '$' varName typeDeclaration? IN exprSingle 
                (',' '$' varName typeDeclaration? IN exprSingle)* 
      SATISFIES exprSingle
    ;
typeswitchExpr
    : TYPESWITCH '(' expr ')' 
      caseClause+ 
      DEFAULT ('$' varName)? RETURN exprSingle
    ;
caseClause
    : CASE ('$' varName AS)? sequenceType RETURN exprSingle
    ;
ifExpr
    : IF '(' expr ')' THEN exprSingle ELSE exprSingle
    ;
tryCatchExpr                                                      // XQuery 1.1
    : tryClause catchClause+
    ;
tryClause                                                         // XQuery 1.1
    : TRY LCurly tryTargetExpr RCurly
    ;
tryTargetExpr                                                     // XQuery 1.1
    : expr
    ;
catchClause                                                       // XQuery 1.1
    : CATCH catchErrorList catchVars? LCurly expr RCurly
    ;
catchErrorList                                                    // XQuery 1.1
    : nameTest ('|' nameTest)*
    ;
catchVars                                                         // XQuery 1.1
    : '(' catchErrorCode (',' catchErrorDesc (',' catchErrorVal)?)? ')'
    ;
catchErrorCode                                                    // XQuery 1.1
    : '$' varName
    ;
catchErrorDesc                                                    // XQuery 1.1
    : '$' varName
    ;
catchErrorVal                                                     // XQuery 1.1
    : '$' varName
    ;
orExpr
    : andExpr ( OR andExpr )*
    ;
andExpr
    : comparisonExpr ( AND comparisonExpr )*
    ;
comparisonExpr
    : rangeExpr ( (valueComp | generalComp | nodeComp) rangeExpr )?
    ;
rangeExpr
    : additiveExpr ( TO additiveExpr )?
    ;
additiveExpr
    : multiplicativeExpr ( ('+' | '-') multiplicativeExpr )*
    ;
multiplicativeExpr
    : unionExpr ( 
       (  '*' 
        | DIV  {needSpaceBetween(IntegerLiteral);}
               {needSpaceBetween(DecimalLiteral);}
               {needSpaceBetween(DoubleLiteral );}
        | IDIV {needSpaceBetween(IntegerLiteral);}
               {needSpaceBetween(DecimalLiteral);}
               {needSpaceBetween(DoubleLiteral );}
        | MOD  {needSpaceBetween(IntegerLiteral);}
               {needSpaceBetween(DecimalLiteral);}
               {needSpaceBetween(DoubleLiteral );}
        ) 
        unionExpr 
       )*
    ;
unionExpr
    : intersectExceptExpr ( (UNION | '|') intersectExceptExpr )*
    ;
intersectExceptExpr
    : instanceofExpr ( (INTERSECT | EXCEPT) instanceofExpr )*
    ;
instanceofExpr
    : treatExpr ( INSTANCE OF sequenceType )?
    ;
treatExpr
    : castableExpr ( TREAT AS sequenceType )?
    ;
castableExpr
    : castExpr ( CASTABLE AS singleType )?
    ;
castExpr
    : unaryExpr ( CAST AS singleType )?
    ;
unaryExpr
    : ('-' | '+')* valueExpr
    ;
valueExpr
    : validateExpr
    | pathExpr
    | extensionExpr
    ;
generalComp
    : SymEq  | '!=' | LAngle  | '<=' | RAngle  | '>='
    ;
valueComp
    : EQ | NE | LT | LE | GT | GE
    ;
nodeComp
    : IS | '<<' | '>>'
    ;
validateExpr
    : VALIDATE validationMode? LCurly expr RCurly
    ;
validationMode
 	: LAX | STRICT
 	;
extensionExpr
    : (Pragma { parsePragma(); })+ LCurly expr? RCurly
    ;
//pragma                                                         // ws:explicit
//  : '(#' S? qName (S PragmaContents)? '#)'
//  ;
pathExpr                                              // xgs:leading-lone-slash
    : ('/'  relativePathExpr) => '/'  relativePathExpr
    | ('/'        '*'       ) => '/' '*'
    | '/'
    | '//' relativePathExpr
    | relativePathExpr
    ;
relativePathExpr
    : stepExpr (('/' | '//') stepExpr)*
    ;
stepExpr
    : filterExpr
    | axisStep
    ;
axisStep
    : (reverseStep | forwardStep) predicateList
    ;
forwardStep
    : (forwardAxis nodeTest)
    | abbrevForwardStep
    ;
forwardAxis
    : CHILD '::'
    | DESCENDANT '::'
    | ATTRIBUTE '::'
    | SELF '::'
    | DESCENDANT_OR_SELF '::' 
    | FOLLOWING_SIBLING '::'
    | FOLLOWING '::'
    ;
abbrevForwardStep
    : '@'? nodeTest
    ;
reverseStep
    : (reverseAxis nodeTest)
    | abbrevReverseStep
    ;
reverseAxis
    : PARENT '::'
    | ANCESTOR '::'
    | PRECEDING_SIBLING '::'
    | PRECEDING '::'
    | ANCESTOR_OR_SELF '::'
    ;
abbrevReverseStep
    : '..'
    ;
nodeTest
    : kindTest
    | nameTest
    ;
nameTest
    : qName
    | wildcard
    ;
wildcard                                                         // ws:explicit
    : '*'
    | ncName Colon '*'
    | '*' Colon ncName
    ;
filterExpr
    : primaryExpr predicateList
    ;
predicateList
    : predicate*
    ;
predicate
    : '[' expr ']'
    ;
primaryExpr
    : literal
    | varRef
    | parenthesizedExpr
    | contextItemExpr 
    | functionCall
    | orderedExpr
    | unorderedExpr
    | constructor
    ;
literal
    : numericLiteral
    | StringLiteral
    ;
numericLiteral
    : IntegerLiteral
    | DecimalLiteral
    | DoubleLiteral
    ;
varRef
    : '$' varName
    ;
varName
    : qName
    ;
parenthesizedExpr
    : '(' expr? ')'
    ;
contextItemExpr
    : '.'
    ;
orderedExpr
    : ORDERED LCurly expr RCurly
    ;
unorderedExpr
    : UNORDERED LCurly expr RCurly
    ;
functionCall                        // xgs:reserved-function-names // gn:parens
    : fqName '(' (exprSingle (',' exprSingle)*)? ')'
    ;
constructor
    : directConstructor
    | computedConstructor
    ;
directConstructor
    : dirElemConstructor
    | DirCommentConstructor { parseDirComment(); }
    | DirPIConstructor      { parseDirPI();      }
    ;
dirElemConstructor                                               // ws:explicit
    : LAngle  { enterDirXml (); } 
      qName   { pushElemName(); }
      dirAttributeList 
      (RClose { popElemName (); }
        | (RAngle dirElemContent* LClose qName {matchElemName();} S? RAngle)
      )       { leaveDirXml (); }
    ;
dirAttributeList                                                 // ws:explicit
    : (S (qName S? SymEq S? dirAttributeValue)?)*
    ;
dirAttributeValue                                                // ws:explicit
    : Quot (EscapeQuot | quotAttrValueContent)* Quot
    | Apos (EscapeApos | aposAttrValueContent)* Apos
    ;
quotAttrValueContent
    : QuotAttrContentChar
    | commonContent
    ;
aposAttrValueContent
    : AposAttrContentChar
    | commonContent
    ;
dirElemContent
    : directConstructor
    | CDataSection
    | commonContent
    | ElementContentChar
    ;
commonContent
    : PredefinedEntityRef
    | CharRef
    | EscapeLCurly
    | EscapeRCurly
    | dirEnclosedExpr
    ;
dirEnclosedExpr
    : LCurly { enterXQuery(); } expr RCurly { leaveXQuery(); }
    ;
//dirCommentConstructor                                          // ws:explicit
//    : '<!--' DirCommentContents '-->'
//    ;
//dirPIConstructor                                               // ws:explicit
//    : '<?' PiTarget (S DirPIContents)? '?>'
//    ;
//cDataSection                                                   // ws:explicit
//    : '<![CDATA[' CDataSectionContents ']]>'
//    ;
computedConstructor
    : compDocConstructor
    | compElemConstructor
    | compAttrConstructor
    | compTextConstructor
    | compCommentConstructor
    | compPIConstructor
    | compNamespaceConstructor                                    // XQuery 1.1
    ;
compDocConstructor
    : DOCUMENT LCurly expr RCurly
    ;
compElemConstructor
    : ELEMENT (qName | (LCurly expr RCurly)) LCurly contentExpr? RCurly
    ;
contentExpr
    : expr
    ;
compAttrConstructor
    : ATTRIBUTE (qName | (LCurly expr RCurly)) LCurly expr? RCurly;
compTextConstructor
    : TEXT LCurly expr RCurly
    ;
compCommentConstructor
    : COMMENT LCurly expr RCurly
    ;
compPIConstructor
    : PROCESSING_INSTRUCTION (ncName | (LCurly expr RCurly)) LCurly expr? RCurly
    ;
compNamespaceConstructor                                          // XQuery 1.1
    : NAMESPACE (prefix | (LCurly prefixExpr RCurly)) LCurly uriExpr? RCurly
    ;
prefix                                                            // XQuery 1.1
    : ncName
    ;
prefixExpr                                                        // XQuery 1.1
    : expr
    ;
uriExpr                                                           // XQuery 1.1
    : expr
    ;
singleType
    : atomicType '?'?
    ;
typeDeclaration
    : AS sequenceType
    ;
sequenceType
    : (EMPTY_SEQUENCE '(' ')')
    | (itemType ((occurrenceIndicator) => occurrenceIndicator)?)
    ;
occurrenceIndicator                                 // xgs:occurance-indicators
    : '?'
    | '*'
    | '+'
    ;
itemType
    : kindTest
    | (ITEM '(' ')')
    | atomicType
    ;
atomicType
    : qName
    ;
kindTest
    : documentTest
    | elementTest
    | attributeTest
    | schemaElementTest
    | schemaAttributeTest
    | piTest
    | commentTest
    | textTest
    | anyKindTest
    | namespaceNodeTest                                           // XQuery 1.1
    ;
anyKindTest
    : NODE '(' ')'
    ;
documentTest
    : DOCUMENT_NODE '(' (elementTest | schemaElementTest)? ')'
    ;
textTest
    : TEXT '(' ')'
    ;
commentTest
    : COMMENT '(' ')'
    ;
namespaceNodeTest                                                 // XQuery 1.1
    : NAMESPACE_NODE '(' ')'
    ;
piTest
    : PROCESSING_INSTRUCTION '(' (ncName | StringLiteral)? ')'
    ;
attributeTest
    : ATTRIBUTE '(' (attribNameOrWildcard (',' typeName)?)? ')'
    ;
attribNameOrWildcard
    : attributeName
    | '*'
    ;
schemaAttributeTest
    : SCHEMA_ATTRIBUTE '(' attributeDeclaration ')'
    ;
attributeDeclaration
    : attributeName
    ;
elementTest
    : ELEMENT '(' (elementNameOrWildcard (',' typeName '?'?)?)? ')'
    ;
elementNameOrWildcard
    : elementName
    | '*'
    ;
schemaElementTest
    : SCHEMA_ELEMENT '(' elementDeclaration ')'
    ;
elementDeclaration
    : elementName
    ;
attributeName
    : qName
    ;
elementName
    : qName
    ;
typeName
    : qName
    ;
uriLiteral
    : StringLiteral
    ;
revalidationDecl                                                  // ext:update
    : DECLARE REVALIDATION (STRICT | LAX | SKIP)
    ;
insertExprTargetChoice                                            // ext:update
    : ((AS (FIRST | LAST))? INTO)
    | AFTER
    | BEFORE
    ;
insertExpr                                                        // ext:update
    : INSERT (NODE | NODES) sourceExpr insertExprTargetChoice targetExpr
    ;
deleteExpr                                                        // ext:update
    : DELETE (NODE | NODES) targetExpr
    ;
replaceExpr                                                       // ext:update
    : REPLACE (VALUE OF)? NODE targetExpr WITH exprSingle
    ;
renameExpr                                                        // ext:update
    : RENAME NODE targetExpr AS newNameExpr
    ;
sourceExpr                                                        // ext:update
    : exprSingle
    ;
targetExpr                                                        // ext:update
    : exprSingle
    ;
newNameExpr                                                       // ext:update
    : exprSingle
    ;
transformExpr                                                     // ext:update
    : COPY '$' varName ':=' exprSingle 
      (',' '$' varName ':=' exprSingle)* 
      MODIFY exprSingle RETURN exprSingle
    ;
assignmentExpr                                                 // ext:scripting
    : SET '$' varName ':=' exprSingle
    ;
blockExpr
    : BLOCK block
    ;
block                                                          // ext:scripting
    : '{' blockDecls blockBody '}'
    ;
blockDecls                                                     // ext:scripting
    : (blockVarDecl ';')*
    ;
blockVarDecl                                                   // ext:scripting
   : DECLARE '$' varName typeDeclaration? (':=' exprSingle)? 
        (',' '$' varName typeDeclaration? (':=' exprSingle)? )*
    ;
blockBody                                                      // ext:scripting
    : expr
    ;
exitExpr                                                       // ext:scripting
    : EXIT RETURNING exprSingle
    ;
whileExpr                                                      // ext:scripting
    : WHILE '(' exprSingle ')' whileBody
    ;
whileBody
    : block
    ;
// End of W3C grammar.

qName
    : ncName  (Colon {noSpaceBefore();} ncName{noSpaceBefore();})?
    ;
fqName
    : fncName (Colon {noSpaceBefore();}fncName{noSpaceBefore();})?
    ;
ncName
    : fncName
    // reserved function names
    | ATTRIBUTE
    | COMMENT
    | DOCUMENT_NODE
    | ELEMENT
    | EMPTY_SEQUENCE
    | IF
    | ITEM
    | NODE
    | PROCESSING_INSTRUCTION
    | SCHEMA_ATTRIBUTE
    | SCHEMA_ELEMENT
    | TEXT
    | TYPESWITCH
    | NAMESPACE_NODE                                              // XQuery 1.1
    | WHILE                                                       // ext:update
    ;
fncName
    : NCName
    | ANCESTOR
    | ANCESTOR_OR_SELF
    | AND
    | AS
    | ASCENDING
    | AT
    | BASE_URI
    | BOUNDARY_SPACE
    | BY
    | CASE
    | CASTABLE
    | CAST
    | CHILD
    | COLLATION
    | CONSTRUCTION
    | COPY
    | COPY_NAMESPACES
    | DECLARE
    | DEFAULT
    | DESCENDANT
    | DESCENDANT_OR_SELF
    | DESCENDING
    | DIV
    | DOCUMENT
    | ELSE
    | EMPTY
    | ENCODING
    | EQ
    | EVERY
    | EXCEPT
    | EXTERNAL
    | FOLLOWING
    | FOLLOWING_SIBLING
    | FOR
    | FUNCTION
    | GE
    | GREATEST
    | GT
    | IDIV
    | IMPORT                  
    | INHERIT
    | IN
    | INSTANCE
    | INTERSECT
    | IS
    | LAX
    | LEAST
    | LE
    | LET
    | LT
    | MOD
    | MODULE
    | NAMESPACE
    | NE
    | NO_INHERIT
    | NO_PRESERVE
    | OF
    | OPTION
    | ORDERED
    | ORDERING
    | ORDER
    | OR
    | PARENT
    | PRECEDING
    | PRECEDING_SIBLING
    | PRESERVE
    | RETURN
    | SATISFIES
    | SCHEMA
    | SELF
    | SIMPLE
    | SOME
    | STABLE
    | STRIP
    | THEN
    | TO
    | TREAT
    | UNION
    | UNORDERED
    | VALIDATE                
    | VARIABLE
    | VERSION
    | WHERE
    | XQUERY
    | STRICT
    // ext:update tokens
    | AFTER
    | BEFORE
    | DELETE
    | FIRST
    | INSERT
    | INTO
    | LAST
    | MODIFY
    | NODES
    | RENAME
    | REPLACE
    | REVALIDATION
    | SKIP
    | UPDATING
    | VALUE
    | WITH
    // end of ext:update tokens
    // ext:scripting tokens
    | BLOCK
    | CONSTANT
    | EXIT
    | RETURNING
    | SEQUENTIAL
    | SET
    // WHILE
    // XQuery 1.1 tokens
    | CATCH
    | CONTEXT
    | DETERMINISTIC
  //| NAMESPACE_NODE
    | NONDETERMINISTIC
    | TRY
    // end of XQUery 1.1 tokens
    ;
LAngle                  : '<';
RAngle                  : '>';
LCurly                  : '{';
RCurly                  : '}';
SymEq                   : '=';
Colon                   : ':';
LClose                  : '</';
RClose                  : '/>';
Quot                    : '"';
Apos                    : '\'';
fragment
EscapeQuot              : '""';
fragment
EscapeApos              : '\'\'';
fragment
EscapeLCurly            : '{{';
fragment
EscapeRCurly            : '}}';

ANCESTOR                : 'ancestor';
ANCESTOR_OR_SELF        : 'ancestor-or-self';
AND                     : 'and';
AS                      : 'as';
ASCENDING               : 'ascending';
AT                      : 'at';
ATTRIBUTE               : 'attribute';
BASE_URI                : 'base-uri';
BOUNDARY_SPACE          : 'boundary-space';
BY                      : 'by';
CASE                    : 'case';
CASTABLE                : 'castable';
CAST                    : 'cast';
CHILD                   : 'child';
COLLATION               : 'collation';
COMMENT                 : 'comment';
CONSTRUCTION            : 'construction';
COPY                    : 'copy';
COPY_NAMESPACES         : 'copy-namespaces';
DECLARE                 : 'declare';
DEFAULT                 : 'default';
DESCENDANT              : 'descendant';
DESCENDANT_OR_SELF      : 'descendant-or-self';
DESCENDING              : 'descending';
DIV                     : 'div';
DOCUMENT                : 'document';
DOCUMENT_NODE           : 'document-node';
ELEMENT                 : 'element';
ELSE                    : 'else';
EMPTY                   : 'empty';
EMPTY_SEQUENCE          : 'empty-sequence';
ENCODING                : 'encoding';
EQ                      : 'eq';
EVERY                   : 'every';
EXCEPT                  : 'except';
EXTERNAL                : 'external';
FOLLOWING               : 'following';
FOLLOWING_SIBLING       : 'following-sibling';
FOR                     : 'for';
FUNCTION                : 'function';
GE                      : 'ge';
GREATEST                : 'greatest';
GT                      : 'gt';
IDIV                    : 'idiv';
IF                      : 'if';
IMPORT                  : 'import';
INHERIT                 : 'inherit';
IN                      : 'in';
INSTANCE                : 'instance';
INTERSECT               : 'intersect';
IS                      : 'is';
ITEM                    : 'item';
LAX                     : 'lax';
LEAST                   : 'least';
LE                      : 'le';
LET                     : 'let';
LT                      : 'lt';
MOD                     : 'mod';
MODULE                  : 'module';
NAMESPACE               : 'namespace';
NE                      : 'ne';
NODE                    : 'node';
NO_INHERIT              : 'no-inherit';
NO_PRESERVE             : 'no-preserve';
OF                      : 'of';
OPTION                  : 'option';
ORDERED                 : 'ordered';
ORDERING                : 'ordering';
ORDER                   : 'order';
OR                      : 'or';
PARENT                  : 'parent';
PRECEDING               : 'preceding';
PRECEDING_SIBLING       : 'preceding-sibling';
PRESERVE                : 'preserve';
PROCESSING_INSTRUCTION  : 'processing-instruction';
RETURN                  : 'return';
SATISFIES               : 'satisfies';
SCHEMA_ATTRIBUTE        : 'schema-attribute';
SCHEMA_ELEMENT          : 'schema-element';
SCHEMA                  : 'schema';
SELF                    : 'self';
SIMPLE                  : 'simple';
SOME                    : 'some';
STABLE                  : 'stable';
STRICT                  : 'strict';
STRIP                   : 'strip';
TEXT                    : 'text';
THEN                    : 'then';
TO                      : 'to';
TREAT                   : 'treat';
TYPESWITCH              : 'typeswitch';
UNION                   : 'union';
UNORDERED               : 'unordered';
VALIDATE                : 'validate';
VARIABLE                : 'variable';
VERSION                 : 'version';
WHERE                   : 'where';
XQUERY                  : 'xquery';
// ext:update tokens
AFTER                   : 'after';
BEFORE                  : 'before';
DELETE                  : 'delete';
FIRST                   : 'first';
INSERT                  : 'insert';
INTO                    : 'into';
LAST                    : 'last';
MODIFY                  : 'modify';
NODES                   : 'nodes';
RENAME                  : 'rename';
REPLACE                 : 'replace';
REVALIDATION            : 'revalidation';
SKIP                    : 'skip';
UPDATING                : 'updating';
VALUE                   : 'value';
WITH                    : 'with';
// end of ext:update tokens
// xq:scripting tokens
BLOCK                   : 'block';
CONSTANT                : 'constant';
EXIT                    : 'exit';
SEQUENTIAL              : 'sequential';
RETURNING               : 'returning';
SET                     : 'set';
WHILE                   : 'while';
// end of ext:scripting tokens
// XQuery 1.1 tokens
CATCH                   : 'catch';
CONTEXT                 : 'context';
DETERMINISTIC           : 'deterministic';
NAMESPACE_NODE          : 'namespace-node';
NONDETERMINISTIC        : 'nondeterministic';
TRY                     : 'try';
// end of XQuery 1.1 tokens

DirCommentConstructor                                            // ws:explicit
    : '<!--' (options {greedy=false;} : . )* '-->'   
    ;
DirPIConstructor    
    : '<?' VS? NCName (VS (options {greedy=false;} : . )*)? '?>' // ws:explicit
    ;
/*
// Only allowed within direct XML and hence - parsed by XMLexer
CDataSection
    : '<![CDATA[' (options {greedy=false;} : . )* ']]>'          // ws:explicit  
    ;
*/
Pragma
    : '(#' VS? NCName (Colon NCName)? (VS (options {greedy=false;} : .)*)? '#)'
    ;
/*
// W3C grammar :
DirCommentContents                                               // ws:explicit  
    : ((Char - '-') | ('-' (Char - '-')))*
    ;
PiTarget
    : Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
    ;
Name
    : NameStartChar (NameChar)*
    ;
DirPIContents                                                    // ws:explicit 
    : (Char* - (Char* '?>' Char*))
    ;
CDataSectionContents                                             // ws:explicit
    : (Char* - (Char* ']]>' Char*))
    ;
PragmaContents
    : (Char - (Char* '#)' Char*))
    ;
*/
IntegerLiteral
    : Digits
    ;
DecimalLiteral
    : ('.' Digits) | (Digits '.' '0'..'9'*)
    ;
DoubleLiteral
    : (('.' Digits) | (Digits ('.' '0'..'9'*)?)) ('e' | 'E') ('+'|'-')? Digits
    ;
StringLiteral
    : Quot (
          options {greedy=false;}:
          (PredefinedEntityRef | CharRef | EscapeQuot | ~('"'  | '&'))*
      )
      Quot  
    | Apos (
          options {greedy=false;}:
          (PredefinedEntityRef | CharRef | EscapeApos | ~('\'' | '&'))*
      )
      Apos
    ;
PredefinedEntityRef
    : '&' ('lt' | 'gt' | 'apos' | 'quot' | 'amp' ) ';'
    ;
CharRef
    : '&#'  Digits    ';' {checkCharRef();}
    | '&#x' HexDigits ';' {checkCharRef();}
    ;
Comment
    : '(:' (options {greedy=false;}: Comment | . )* ':)' { $channel = HIDDEN; }
    ;
NCName
    : NCNameStartChar NCNameChar*
    ;
S
    : ('\u0009' | '\u000A' | '\u000D' | '\u0020')+ { $channel = HIDDEN; }
    ;
fragment
VS
    : ('\u0009' | '\u000A' | '\u000D' | '\u0020')+
    ;
fragment
Digits
    : '0'..'9'+
    ;
fragment
HexDigits
    : ('0'..'9' | 'a'..'f' | 'A'..'F')+
    ;
fragment
Char
    : '\u0009'           | '\u000A'           | '\u000D' 
    | '\u0020'..'\uD7FF' | '\uE000'..'\uFFFD' // | '\u10000'..'\u10FFFF'
    ; 
fragment
NCNameStartChar
    : Letter | '_'
    ;
fragment
NCNameChar  // NameChar - ':'  http://www.w3.org/TR/REC-xml-names/#NT-NCName
    : 'A'..'Z'           | 'a'..'z'           | '_' 
    | '\u00C0'..'\u00D6' | '\u00D8'..'\u00F6' | '\u00F8'..'\u02FF' 
    | '\u0370'..'\u037D' | '\u037F'..'\u1FFF' | '\u200C'..'\u200D' 
    | '\u2070'..'\u218F' | '\u2C00'..'\u2FEF' | '\u3001'..'\uD7FF' 
    | '\uF900'..'\uFDCF' | '\uFDF0'..'\uFFFD' 
  //| ':'                | '\u10000..'\uEFFFF] // end of NameStartChar
    | '-'                | '.'                | '0'..'9' 
    | '\u00B7'           | '\u0300'..'\u036F' | '\u203F'..'\u2040'
    ;
fragment
Letter // http://www.w3.org/TR/REC-xml/#NT-Letter
    : '\u0041'..'\u005A' | '\u0061'..'\u007A' | '\u00C0'..'\u00D6' 
    | '\u00D8'..'\u00F6' | '\u00F8'..'\u00FF' | '\u0100'..'\u0131'
    | '\u0134'..'\u013E' | '\u0141'..'\u0148' | '\u014A'..'\u017E'
    | '\u0180'..'\u01C3' | '\u01CD'..'\u01F0' | '\u01F4'..'\u01F5' 
    | '\u01FA'..'\u0217' | '\u0250'..'\u02A8' | '\u02BB'..'\u02C1'
    | '\u0386'           | '\u0388'..'\u038A' | '\u038C'
    | '\u038E'..'\u03A1' | '\u03A3'..'\u03CE' | '\u03D0'..'\u03D6' 
    | '\u03DA'           | '\u03DC'           | '\u03DE'
    | '\u03E0'           | '\u03E2'..'\u03F3' | '\u0401'..'\u040C' 
    | '\u040E'..'\u044F' | '\u0451'..'\u045C' | '\u045E'..'\u0481' 
    | '\u0490'..'\u04C4' | '\u04C7'..'\u04C8' | '\u04CB'..'\u04CC' 
    | '\u04D0'..'\u04EB' | '\u04EE'..'\u04F5' | '\u04F8'..'\u04F9' 
    | '\u0531'..'\u0556' | '\u0559'           | '\u0561'..'\u0586' 
    | '\u05D0'..'\u05EA' | '\u05F0'..'\u05F2' | '\u0621'..'\u063A' 
    | '\u0641'..'\u064A' | '\u0671'..'\u06B7' | '\u06BA'..'\u06BE' 
    | '\u06C0'..'\u06CE' | '\u06D0'..'\u06D3' | '\u06D5'
    | '\u06E5'..'\u06E6' | '\u0905'..'\u0939' | '\u093D'
    | '\u0958'..'\u0961' | '\u0985'..'\u098C' | '\u098F'..'\u0990'
    | '\u0993'..'\u09A8' | '\u09AA'..'\u09B0' | '\u09B2'
    | '\u09B6'..'\u09B9' | '\u09DC'..'\u09DD' | '\u09DF'..'\u09E1' 
    | '\u09F0'..'\u09F1' | '\u0A05'..'\u0A0A' | '\u0A0F'..'\u0A10' 
    | '\u0A13'..'\u0A28' | '\u0A2A'..'\u0A30' | '\u0A32'..'\u0A33' 
    | '\u0A35'..'\u0A36' | '\u0A38'..'\u0A39' | '\u0A59'..'\u0A5C' 
    | '\u0A5E'           | '\u0A72'..'\u0A74' | '\u0A85'..'\u0A8B' 
    | '\u0A8D'           | '\u0A8F'..'\u0A91' | '\u0A93'..'\u0AA8' 
    | '\u0AAA'..'\u0AB0' | '\u0AB2'..'\u0AB3' | '\u0AB5'..'\u0AB9'
    | '\u0ABD'           | '\u0AE0'           | '\u0B05'..'\u0B0C'
    | '\u0B0F'..'\u0B10' | '\u0B13'..'\u0B28' | '\u0B2A'..'\u0B30'
    | '\u0B32'..'\u0B33' | '\u0B36'..'\u0B39' | '\u0B3D'
    | '\u0B5C'..'\u0B5D' | '\u0B5F'..'\u0B61' | '\u0B85'..'\u0B8A'
    | '\u0B8E'..'\u0B90' | '\u0B92'..'\u0B95' | '\u0B99'..'\u0B9A'
    | '\u0B9C'           | '\u0B9E'..'\u0B9F' | '\u0BA3'..'\u0BA4'
    | '\u0BA8'..'\u0BAA' | '\u0BAE'..'\u0BB5' | '\u0BB7'..'\u0BB9'
    | '\u0C05'..'\u0C0C' | '\u0C0E'..'\u0C10' | '\u0C12'..'\u0C28'
    | '\u0C2A'..'\u0C33' | '\u0C35'..'\u0C39' | '\u0C60'..'\u0C61'
    | '\u0C85'..'\u0C8C' | '\u0C8E'..'\u0C90' | '\u0C92'..'\u0CA8'
    | '\u0CAA'..'\u0CB3' | '\u0CB5'..'\u0CB9' | '\u0CDE'
    | '\u0CE0'..'\u0CE1' | '\u0D05'..'\u0D0C' | '\u0D0E'..'\u0D10'
    | '\u0D12'..'\u0D28' | '\u0D2A'..'\u0D39' | '\u0D60'..'\u0D61'
    | '\u0E01'..'\u0E2E' | '\u0E30'           | '\u0E32'..'\u0E33'
    | '\u0E40'..'\u0E45' | '\u0E81'..'\u0E82' | '\u0E84'
    | '\u0E87'..'\u0E88' | '\u0E8A'           | '\u0E8D'
    | '\u0E94'..'\u0E97' | '\u0E99'..'\u0E9F' | '\u0EA1'..'\u0EA3'
    | '\u0EA5'           | '\u0EA7'           | '\u0EAA'..'\u0EAB'
    | '\u0EAD'..'\u0EAE' | '\u0EB0'           | '\u0EB2'..'\u0EB3'
    | '\u0EBD'           | '\u0EC0'..'\u0EC4' | '\u0F40'..'\u0F47'
    | '\u0F49'..'\u0F69' | '\u10A0'..'\u10C5' | '\u10D0'..'\u10F6'
    | '\u1100'           | '\u1102'..'\u1103' | '\u1105'..'\u1107'
    | '\u1109'           | '\u110B'..'\u110C' | '\u110E'..'\u1112'
    | '\u113C'           | '\u113E'           | '\u1140'
    | '\u114C'           | '\u114E'           | '\u1150'
    | '\u1154'..'\u1155' | '\u1159'           | '\u115F'..'\u1161'
    | '\u1163'           | '\u1165'           | '\u1167'
    | '\u1169'           | '\u116D'..'\u116E' | '\u1172'..'\u1173'
    | '\u1175'           | '\u119E'           | '\u11A8'
    | '\u11AB'           | '\u11AE'..'\u11AF' | '\u11B7'..'\u11B8'
    | '\u11BA'           | '\u11BC'..'\u11C2' | '\u11EB'
    | '\u11F0'           | '\u11F9'           | '\u1E00'..'\u1E9B'
    | '\u1EA0'..'\u1EF9' | '\u1F00'..'\u1F15' | '\u1F18'..'\u1F1D'
    | '\u1F20'..'\u1F45' | '\u1F48'..'\u1F4D' | '\u1F50'..'\u1F57'
    | '\u1F59'           | '\u1F5B'           | '\u1F5D'
    | '\u1F5F'..'\u1F7D' | '\u1F80'..'\u1FB4' | '\u1FB6'..'\u1FBC'
    | '\u1FBE'           | '\u1FC2'..'\u1FC4' | '\u1FC6'..'\u1FCC'
    | '\u1FD0'..'\u1FD3' | '\u1FD6'..'\u1FDB' | '\u1FE0'..'\u1FEC'
    | '\u1FF2'..'\u1FF4' | '\u1FF6'..'\u1FFC' | '\u2126'
    | '\u212A'..'\u212B' | '\u212E'           | '\u2180'..'\u2182'
    | '\u3041'..'\u3094' | '\u30A1'..'\u30FA' | '\u3105'..'\u312C'
    | '\uAC00'..'\uD7A3' | '\u4E00'..'\u9FA5' | '\u3007'
    | '\u3021'..'\u3029'
;
