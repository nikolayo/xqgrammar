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

                  XQuery Expression Grammar (less path expressions)
                  
=============================================================================*/

parser grammar XQExpr;

expr
    : { scripting}? => applyExpr
    | {!scripting}? => concatExpr
    ;
applyExpr
    : concatExpr (';' (concatExpr ';')*)?
    ;
concatExpr
    : exprSingle (',' exprSingle)*
    ;
exprSingle
    : flworExpr
    | quantifiedExpr
    | typeswitchExpr
    | ifExpr
    | orExpr
    | {update}?                => insertExpr                      // ext:update 
    | {update}?                => deleteExpr                      // ext:update
    | {update}?                => renameExpr                      // ext:update
    | {update}?                => replaceExpr                     // ext:update
    | {update}?                => transformExpr                   // ext:update
    | {scripting}?             => blockExpr                    // ext:scripting
    | {scripting}?             => assignmentExpr               // ext:scripting
    | {scripting}?             => exitExpr                     // ext:scripting
    | {scripting}?             => whileExpr                    // ext:scripting
    | {xqVersion==XQUERY_3_0}? => switchExpr                      // XQuery 3.0
    | {xqVersion==XQUERY_3_0}? => tryCatchExpr                    // XQuery 3.0
    ;
flworExpr
    : {xqVersion==XQUERY_1_0}? =>
      (forClause | letClause)+ whereClause? orderByClause? RETURN exprSingle
    | {xqVersion==XQUERY_3_0}? =>
      initalClause intermediateClause* returnClause               // XQuery 3.0
    ;
initalClause                                                      // XQuery 3.0
    : forClause
    | letClause
    | {xqVersion==XQUERY_3_0}? => windowClause
    ;
intermediateClause                                                // XQuery 3.0
    : initalClause
    | whereClause
    | {xqVersion==XQUERY_3_0}? => groupByClause
    | orderByClause
    | {xqVersion==XQUERY_3_0}? => countClause
    ;
forClause
    : FOR  forBinding (',' forBinding)*
    ;
forBinding
    : '$' varName typeDeclaration? allowingEmpty? positionalVar? ftScoreVar? 
      IN exprSingle
    ;
allowingEmpty                                                     // XQuery 3.0
    : {xqVersion==XQUERY_3_0}? => ALLOWING EMPTY
    ;
positionalVar
    : AT '$' varName
    ;
ftScoreVar                                                      // ext:fulltext
    : {fullText}? => SCORE '$' varName
    ;
letClause
    : LET letBinding (',' letBinding)*
    ;
letBinding
    : (('$' varName typeDeclaration?) | ftScoreVar) ':=' exprSingle
    ;
windowClause                                                      // XQuery 3.0
    : FOR (tumblingWindowClause | slidingWindowClause)
    ;
tumblingWindowClause                                              // XQuery 3.0
    : TUMBLING WINDOW '$' varName typeDeclaration? IN exprSingle 
      windowStartCondition windowEndCondition?
    ;
slidingWindowClause                                               // XQuery 3.0
    : SLIDING WINDOW  '$' varName typeDeclaration? IN exprSingle 
      windowStartCondition windowEndCondition
    ;
windowStartCondition                                              // XQuery 3.0
    : START windowVars WHEN exprSingle
    ;
windowEndCondition                                                // XQuery 3.0
    : ONLY? END windowVars WHEN exprSingle
    ;
windowVars                                                        // XQuery 3.0
    : ('$' currentItem)? positionalVar? 
      (PREVIOUS '$' previousItem)? (NEXT '$' nextItem)?
    ;
currentItem                                                       // XQuery 3.0
    : eQName
    ;
previousItem                                                      // XQuery 3.0
    : eQName
    ;
nextItem                                                          // XQuery 3.0
    : eQName
    ;
countClause                                                       // XQuery 3.0
    : COUNT '$' varName
    ;
whereClause
    : WHERE exprSingle
    ;
groupByClause                                                     // XQuery 3.0
    : GROUP BY groupingSpecList
    ;
groupingSpecList                                                  // XQuery 3.0
    : groupingSpec (',' groupingSpec)*
    ;
groupingSpec                                                      // XQuery 3.0
    : '$' varName (COLLATION uriLiteral)?
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
returnClause                                                      // XQuery 3.0
    : RETURN exprSingle
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
orExpr
    : andExpr ( OR andExpr )*
    ;
andExpr
    : comparisonExpr ( AND comparisonExpr )*
    ;
comparisonExpr
    : //XQuery 1.0 :
      //rangeExpr ( (valueComp | generalComp | nodeComp) rangeExpr )?
                                                                // ext:fulltext
      ftContainsExpr ( (valueComp | generalComp | nodeComp) ftContainsExpr )?
    ;
ftContainsExpr                                                  // ext:fulltext
    : stringConcatExpr ftContainsClause?
    ;
stringConcatExpr
    : //rangeExpr                      // XQuery 1.0
        rangeExpr ('||' rangeExpr)*      // XQuery 3.0
    ;
ftContainsClause
    :  {fullText}? => CONTAINS TEXT ftSelection ftIgnoreOption?
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
//W3C grammar :
//pragma                                                         // ws:explicit
//  : '(#' S? eQName (S PragmaContents)? '#)'
//  ;
