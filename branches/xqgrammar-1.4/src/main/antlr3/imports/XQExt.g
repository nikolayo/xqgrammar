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

                            XQuery Extensions Grammar
                            
=============================================================================*/
parser grammar XQExt;

// start of ext:update specific rules
revalidationDecl
    : DECLARE REVALIDATION (STRICT | LAX | SKIP)
    ;
insertExprTargetChoice
    : ((AS (FIRST | LAST))? INTO)
    | AFTER
    | BEFORE
    ;
insertExpr
    : INSERT (NODE | NODES) sourceExpr insertExprTargetChoice targetExpr
    ;
deleteExpr
    : DELETE (NODE | NODES) targetExpr
    ;
replaceExpr
    : REPLACE (VALUE OF)? NODE targetExpr WITH exprSingle
    ;
renameExpr
    : RENAME NODE targetExpr AS newNameExpr
    ;
sourceExpr
    : exprSingle
    ;
targetExpr
    : exprSingle
    ;
newNameExpr
    : exprSingle
    ;
transformExpr
    : COPY '$' varName ':=' exprSingle 
      (',' '$' varName ':=' exprSingle)* 
      MODIFY exprSingle RETURN exprSingle
    ;
// end   of ext:update    specific rules
// start of ext:scripting specific rules
assignmentExpr
    : '$' varName ':=' exprSingle
    ;
blockExpr
    : BLOCK block
    ;
block
    : LCurly blockDecls blockBody RCurly
    ;
blockDecls
    : (blockVarDecl ';')*
    ;
blockVarDecl
    : DECLARE '$' varName typeDeclaration? (':=' exprSingle)? 
         (',' '$' varName typeDeclaration? (':=' exprSingle)? )*
    ;
blockBody
    : expr
    ;
exitExpr
    : EXIT RETURNING exprSingle
    ;
whileExpr
    : WHILE '(' exprSingle ')' whileBody
    ;
whileBody
    : block
    ;
// end   of ext:scripting specific rules
// start of ext:fulltext  specific rules
ftSelection
    : ftOr ftPosFilter*
    ;
ftOr
    : ftAnd (FTOR ftAnd)*
    ;
ftAnd
    : ftMildNot (FTAND ftMildNot)*
    ;
ftMildNot
    : ftUnaryNot (NOT IN ftUnaryNot)*
    ;
ftUnaryNot
    : FTNOT? ftPrimaryWithOptions
    ;
ftPrimaryWithOptions
    : ftPrimary (USING ftMatchOption)* ftWeight?
    ;
ftWeight
    : WEIGHT LCurly rangeExpr RCurly
    ;
ftPrimary
    : ftWords ftTimes?
    | '(' ftSelection ')'
    | ftExtensionSelection
    ;
ftWords
    : ftWordsValue ftAnyAllOption?
    ;
ftWordsValue
    : StringLiteral
    | LCurly expr RCurly
    ;
ftExtensionSelection
    : (Pragma { parsePragma(); })+ LCurly ftSelection? RCurly
    ;
ftAnyAllOption
    : ANY WORD?
    | ALL WORDS?
    | PHRASE
    ;
ftTimes
    : OCCURS ftRange TIMES
    ;
ftRange
    : EXACTLY  additiveExpr
    | AT LEAST additiveExpr
    | AT MOST  additiveExpr
    | FROM     additiveExpr TO additiveExpr
    ;
ftPosFilter
    : ftOrder
    | ftWindow
    | ftDistance
    | ftScope
    | ftContent
    ;
ftOrder
    : ORDERED
    ;
ftWindow
    : WINDOW additiveExpr ftUnit
    ;
ftDistance
    : DISTANCE ftRange ftUnit
    ;
ftUnit
    : WORDS
    | SENTENCES
    | PARAGRAPHS
    ;
ftScope
    : (SAME | DIFFERENT) ftBigUnit
    ;
ftBigUnit
    : SENTENCE
    | PARAGRAPH
    ;
ftContent
    : AT START
    | AT END
    | ENTIRE CONTENT
    ;
//W3C grammar :
//ftMatchOptions
//  : (ftMatchOption)+
//  ;
ftMatchOption
    : ftLanguageOption
    | ftWildCardOption
    | ftThesaurusOption
    | ftStemOption
    | ftCaseOption
    | ftDiacriticsOption
    | ftStopWordOption
    | ftExtensionOption
    ;
ftCaseOption
    : CASE INSENSITIVE
    | CASE SENSITIVE
    | LOWERCASE
    | UPPERCASE
    ;
ftDiacriticsOption
    : DIACRITICS INSENSITIVE
    | DIACRITICS SENSITIVE
    ;
ftStemOption
    :    STEMMING
    | NO STEMMING
    ;
ftThesaurusOption
    :    THESAURUS     (ftThesaurusID | DEFAULT) 
    |    THESAURUS '(' (ftThesaurusID | DEFAULT) (',' ftThesaurusID)* ')'
    | NO THESAURUS
    ;
ftThesaurusID
    : AT uriLiteral (RELATIONSHIP StringLiteral)? (ftRange LEVELS)?
    ;
ftStopWordOption
    :      STOP WORDS ftStopWords ftStopWordsInclExcl*
    | NO   STOP WORDS
    | STOP WORDS DEFAULT ftStopWordsInclExcl*
    ;
ftStopWords
    : AT uriLiteral
    | '(' StringLiteral (',' StringLiteral)* ')'
    ;
ftStopWordsInclExcl
    : (UNION | EXCEPT) ftStopWords
    ;
ftLanguageOption
    : LANGUAGE StringLiteral
    ;
ftWildCardOption
    :    WILDCARDS
    | NO WILDCARDS
    ;
ftExtensionOption
    : OPTION eQName StringLiteral
    ;
ftIgnoreOption
    : WITHOUT CONTENT unionExpr
    ;
// end of ext:fulltext specific rules
// start of Xquery 1.1 specific rules
contextItemDecl
    : {xqVersion==XQUERY_3_0}? =>
      DECLARE CONTEXT ITEM (AS itemType)? 
      ((':=' varValue) | (EXTERNAL (':=' varDefaultValue)?))
    ;
functionItemExpr
    : literalFunctionItem
    | inlineFunction
    ;
literalFunctionItem
    : eQName '#' IntegerLiteral
    ;
inlineFunction
    : FUNCTION '(' paramList? ')' (AS sequenceType)? enclosedExpr
    ;
dynamicFunctionInvocation
    : '(' (exprSingle (',' exprSingle)*)? ')'
    ;
switchExpr
    : SWITCH '(' expr ')' switchCaseClause+ DEFAULT RETURN exprSingle
    ;
switchCaseClause
    : ( CASE switchCaseOperand)+ RETURN exprSingle
    ;
switchCaseOperand
    : exprSingle
    ;
tryCatchExpr
    : tryClause catchClause+
    ;
tryClause
    : TRY LCurly tryTargetExpr RCurly
    ;
tryTargetExpr
    : expr
    ;
catchClause
    : CATCH catchErrorList LCurly expr RCurly
    ;
catchErrorList
    : nameTest ('|' nameTest)*
    ;
compNamespaceConstructor
    : NAMESPACE (prefix | (LCurly prefixExpr RCurly)) LCurly uriExpr? RCurly
    ;
prefix
    : ncName
    ;
prefixExpr
    : expr
    ;
uriExpr
    : expr
    ;
namespaceNodeTest
    : NAMESPACE_NODE '(' ')'
    ;
functionTest
    : anyFunctionTest
    | typedFunctionTest
    ;
anyFunctionTest
    : FUNCTION '(' '*' ')'
    ;
typedFunctionTest
    : FUNCTION '(' (sequenceType (',' sequenceType)*)? ')' AS sequenceType
    ;
parenthesizedItemType
    : '(' itemType ')'
    ;
// end of XQuery 1.1 specific rules
