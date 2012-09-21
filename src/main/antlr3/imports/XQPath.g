/*=============================================================================

    Copyright 2009, 2010, 2011 Nikolay Ognyanov

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

                         XQuery Path Expression Grammar
                         
=============================================================================*/

parser grammar XQPath;

pathExpr                                              // xgs:leading-lone-slash
    : ('/'  relativePathExpr) => '/'  relativePathExpr
    | ('/'        '*'       ) => '/' '*'
    | '/'
    | '//' relativePathExpr
    | relativePathExpr
    ;
relativePathExpr
    : // stepExpr (('/' | '//'      ) stepExpr)*     // XQuery 1.0
         stepExpr (('/' | '//' | '!') stepExpr)*     // XQuery 3.0
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
    : eQName
    | wildcard
    ;
wildcard                                                         // ws:explicit
    : '*'
    | ncName Colon {noSpaceBefore();} '*'    {noSpaceBefore();}
    | '*'    Colon {noSpaceBefore();} ncName {noSpaceBefore();}
    ;
filterExpr
    : primaryExpr filterExprSuffix*
    ;
filterExprSuffix
    : predicate
    | {xqVersion==XQUERY_3_0}? => dynamicFunctionInvocation
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
    | {xqVersion==XQUERY_3_0}? => functionItemExpr
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
    : eQName
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
      qName   {noSpaceBefore(); 
               pushElemName (); }
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
//W3C grammar :
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
    | {xqVersion==XQUERY_3_0}? => compNamespaceConstructor        // XQuery 3.0
    ;
compDocConstructor
    : DOCUMENT LCurly expr RCurly
    ;
compElemConstructor
    : ELEMENT (eQName | (LCurly expr RCurly)) LCurly contentExpr? RCurly
    ;
contentExpr
    : expr
    ;
compAttrConstructor
    : ATTRIBUTE (eQName | (LCurly expr RCurly)) LCurly expr? RCurly;
compTextConstructor
    : TEXT LCurly expr RCurly
    ;
compCommentConstructor
    : COMMENT LCurly expr RCurly
    ;
compPIConstructor
    : PROCESSING_INSTRUCTION (ncName | (LCurly expr RCurly)) LCurly expr? RCurly
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
    | {xqVersion==XQUERY_3_0}? => functionTest
    | {xqVersion==XQUERY_3_0}? => parenthesizedItemType
    ;
atomicType
    : eQName
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
    | {xqVersion==XQUERY_3_0}? => namespaceNodeTest               // XQuery 3.0
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
    : eQName
    ;
elementName
    : eQName
    ;
typeName
    : eQName
    ;
