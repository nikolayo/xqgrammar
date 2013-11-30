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
            int nameLength = 0;
            for (String s : arg) {
                if (s.length() > nameLength) {
                    nameLength = s.length();
                }
            }
            StringBuffer sb = new StringBuffer();

            for (String fileName : arg) {
                if (!(new File(fileName).exists())) {
                    System.out.print(fileName);
                    for (int i = 0; i < nameLength - fileName.length(); i++) {
                        sb.append(' ');
                    }
                    System.out.print(sb + " : ");
                    sb.delete(0, sb.length());
                    System.out.println("Not Found");
                }
                else {
                    try {
                        System.out.print(fileName);
                        for (int i = 0; i < nameLength - fileName.length(); i++) {
                            sb.append(' ');
                        }
                        System.out.print(sb + " : ");
                        sb.delete(0, sb.length());
                        ANTLRFileStream input = new ANTLRFileStream(fileName);
                        XQLexer lexer = new XQLexer(input);
                        XQTokenStream tokenStream = new XQTokenStream(lexer);
                        XQParser parser = new XQParser(tokenStream);
                        parser.module();
                        System.out.println("OK");
                    }
                    catch (Exception e) {
                    }
                }
            }
        }
    }
}
