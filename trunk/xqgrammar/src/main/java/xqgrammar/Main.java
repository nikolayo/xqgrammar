/*=============================================================================

    Copyright 2013 Nikolay Ognyanov

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

import java.io.File;

import org.antlr.runtime.ANTLRFileStream;
import org.antlr.runtime.TokenStream;

/**
 * A simple driver program for the XQuery parser.
 */
public class Main
{
    public static void main(String[] arg)
    {
        if (arg.length == 0) {
            System.out.println("Usage : java -jar xqgrammar file ...");
        }
        else {
            for (String fileName : arg) {
                if (!(new File(fileName).exists())) {
                    System.out.println(fileName);
                    System.out.println("\tfile not found");
                }
                else {
                    try {
                        System.out.println(fileName);
                        ANTLRFileStream input = new ANTLRFileStream(fileName);
                        XQLexer lexer = new XQLexer(input);
                        XQTokenStream tokenStream = new XQTokenStream(lexer);
                        XQParser parser = new MyParser(tokenStream);
                        parser.setBreakOnError(false);
                        parser.module();
                    }
                    catch (Exception e) {
                        System.out.println(e.getMessage());
                    }
                }
            }
        }
    }

    private static class MyParser
        extends XQParser
    {

        public MyParser(TokenStream input)
        {
            super(input);
        }

        @Override
        public void emitErrorMessage(String message)
        {
            System.err.println("\t" + message);
        }
    }
}
