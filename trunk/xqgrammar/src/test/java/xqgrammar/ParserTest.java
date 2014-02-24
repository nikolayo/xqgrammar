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

package xqgrammar;

import static org.junit.Assert.assertTrue;

import org.antlr.runtime.ANTLRStringStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.Token;
import org.junit.Test;

public class ParserTest
{
    private static String queries[] =
                                        {
            "for $a in b return for $c in d return $c",
            "<проба b='{$проба}'>проба</проба>",
            "for $a in $b/c/d[@e = 123] return $c",
            "let $a:=$b+$c-123 return $a mod $b",
            "copy $t:s := $target modify rename node $t as 'something' return $t",
            "declare variable $a:=123;<abc>{<x>{/a/b/c}</x>}</abc>",
            "<elem>&#x7b;</elem>",
            "(# ns:pragma blah#) (#pragma1 blahblah #) {whatever}", "\na;b,c;" };

    @Test
    public void test()
        throws RecognitionException
    {
        for (int i = 0; i < queries.length; i++) {
            ANTLRStringStream input = new ANTLRStringStream(queries[i]);
            XQLexer lexer = new XQLexer(input);
            XQTokenStream tokens = new XQTokenStream(lexer);
            XQParser parser = new XQParser(tokens);
            tokens.setTokenNames(parser.getTokenNames());
            parser.module();
            assertTrue(tokens.LT(1).getType() == Token.EOF);
            assertTrue(lexer.getNumberOfSyntaxErrors() == 0);
            assertTrue(parser.getNumberOfSyntaxErrors() == 0);
        }
    }
}
