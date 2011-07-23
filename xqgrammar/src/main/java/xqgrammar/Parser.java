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

import java.util.Stack;

import org.antlr.runtime.BitSet;
import org.antlr.runtime.CharStream;
import org.antlr.runtime.CommonToken;
import org.antlr.runtime.IntStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.RecognizerSharedState;
import org.antlr.runtime.Token;
import org.antlr.runtime.TokenSource;
import org.antlr.runtime.TokenStream;

/**
 * Base class for generated XQuery parser. Has the following roles:
 * <ol>
 * <li> Produce tokens of custom type.</li>
 * <li> Provide control over behavior upon errors.</li>
 * <li> Switch between XQuery and direct XML lexers.</li>
 * <li> Provide utilities for "add-on" parsing of details which 
 *      can not or should better not be handled in the generated parser.
 * </li>
 * </ol>
 */
public class Parser
    extends org.antlr.runtime.Parser
{
    private CharStream         source;
    private Stack<TokenSource> lexerStack   = new Stack<TokenSource>();
    private Stack<Integer>     elemStack    = new Stack<Integer>();
    private boolean            breakOnError = true;
    @SuppressWarnings("all")
    private static int                NCName;
    private static int                Colon;

    
    public static final int XQUERY_1_0 = 0;
    public static final int XQUERY_1_1 = 1;

    // Flags enabling XQuery extensions
    protected static boolean update    = true;
    protected static boolean scripting = true;
    protected static boolean fullText  = true;

    // XQuery version - must be one of XQUERY_1_0 or XQUERY_1_1 
    // If strict XQuery 1.0 is needed then see also comments to flworExpr.
    protected static int     xqVersion = XQUERY_1_1;

    public static boolean getUpdate   () {return update   ;}
    public static boolean getScripting() {return scripting;}
    public static boolean getFullText () {return fullText ;}
    public static int     getXqVersion() {return xqVersion;}

    public static void setUpdate   (boolean value) {update    = value;}
    public static void setScripting(boolean value) {scripting = value;}
    public static void setFullText (boolean value) {fullText  = value;}
    public static void setXqVersion(int     value) {
        if(value != XQUERY_1_0 && value != XQUERY_1_1)
            throw new IllegalArgumentException("Unknown XQuery version.");
        xqVersion = value;
    }

    public Parser(XQTokenStream input)
    {
        this(input, new RecognizerSharedState());
    }

    public Parser(TokenStream input, RecognizerSharedState state)
    {
        super(input, state);
        source = ((Lexer) input.getTokenSource()).getCharStream();
    }

    /**
     * Set a flag which determines error handling behavior. If the flag is
     * true then a runtime exception is thrown upon error. Default value
     * is "true"
     * 
     * @param breakOnError the value to be set
     */
    public void setBreakOnError(boolean breakOnError)
    {
        this.breakOnError = breakOnError;
    }

    /**
     * Retrieves the value of the error handling flag.
     * 
     * @return value of the flag
     */
    public boolean getBreakOnError()
    {
        return breakOnError;
    }

    /**
     * A placeholder for implementation of custom error message handling.
     */
    @Override
    public void emitErrorMessage(String message)
    {
        super.emitErrorMessage(message);
    }

    /**
     * Overriden in order to provide control of error handling through
     * {@link setBreakOnError}.
     */
    @Override
    public void reportError(RecognitionException e)
    {
        super.reportError(e);
        if (breakOnError) {
            throw new RuntimeException(getErrorHeader(e) + " "
                    + getErrorMessage(e, getTokenNames()), e);
        }
    }

    /**
     * Overriden in order to produce XQToken instead of CommonToken.
     */
    @Override
    protected Object getMissingSymbol(IntStream input, RecognitionException e,
                                      int expectedTokenType, BitSet follow)
    {
        String tokenText = null;
        if (expectedTokenType == Token.EOF)
            tokenText = "<missing EOF>";
        else
            tokenText = "<missing " + getTokenNames()[expectedTokenType] + ">";
        CommonToken t = new XQToken(expectedTokenType, tokenText);
        Token current = ((TokenStream) input).LT(1);
        if (current.getType() == Token.EOF) {
            current = ((TokenStream) input).LT(-1);
        }
        t.setLine(current.getLine());
        t.setCharPositionInLine(current.getCharPositionInLine());
        t.setChannel(DEFAULT_TOKEN_CHANNEL);
        return t;
    }

    /**
     * Convinience method for throwing XQRecognitionException.
     */
    protected void raiseError(String message)
        throws RecognitionException
    {
        throw new XQRecognitionException(input, message);
    }

    /**
     * Notifies the base parser that generated parser enters a direct
     * XML element declaration. The action taken is to instantiate and
     * start using a new XMLexer.
     */
    protected void enterDirXml()
    {
        lexerStack.push(input.getTokenSource());
        XMLexer XMLexer = new XMLexer(source);
        ((XQTokenStream) input).setTokenSource(XMLexer);
    }

    /**
     * Notifies the base parser that generated parser leaves a direct
     * XML element definition. The action taken is to discard current
     * XMLexer in use and switch back to the lexer used before it was
     * instantiated.
     */
    protected void leaveDirXml()
    {
        popLexer();
    }

    /**
     * Notifies base parser that generated parser enters section of 
     * computed xquery code embedded within direct XML. The action
     * taken is to instantiate and start using a new instance of
     * XQLexer.
     */
    protected void enterXQuery()
    {
        lexerStack.push(input.getTokenSource());
        XQLexer xqueryLexer = new XQLexer(source);
        ((XQTokenStream) input).setTokenSource(xqueryLexer);
    }

    /**
     * Notifies base parser that generated parser leaves section of 
     * computed xquery code embedded within direct XML. The action
     * taken is to discard current XQLexer and switch back to the lexer
     * used befeore it was instantiated.
     */
    protected void leaveXQuery()
    {
        popLexer();
    }

    private void popLexer()
    {
        TokenSource tokenSource = lexerStack.pop();
        ((XQTokenStream) input).setTokenSource(tokenSource);
    }

    /**
     * An empty hook. Called when generated parser encounters encoding
     * declaration. According to W3C recommendation handling of such
     * declaration is implementation dependent, so here it is left to
     * language prpcessor designers...
     */
    protected void checkEncoding()
    {
        // String encoding = input.get(input.index()).getText();
        // System.out.println("Encoding: " + encoding);
    }

    /**
     * Check that current token is not preceded by blank space and throw
     * error if it is.
     * 
     * @throws RecognitionException
     */
    protected void noSpaceBefore()
        throws RecognitionException
    {
        if (((XQToken) input.get(input.index())).spaceBefore) {
            raiseError("Space not allowed before '"
                    + input.get(input.index()).getText() + "'.");
        }
    }

    /**
     * Check that current token, if preceded by specified other token, is 
     * separated from it by blank space and throw error if it is not.
     * 
     * @param previous the kind of preceding token for which the check is
     *                 to be made
     */
    protected void needSpaceBetween(int previous)
        throws RecognitionException
    {
        if ((input.LA(-1) == previous)
                && !((XQToken) input.get(input.index())).spaceBefore) {
            raiseError("Space required before "
                    + input.get(input.index()).getText() + "'.");
        }
    }

    /**
     * Push direct xml element on stack, so that later its name can be compared
     * to name of the closing tag (if any). 
     */
    protected void pushElemName()
    {
        elemStack.push(input.index());
    }

    /**
     * Pop direct xml element from stack. Called if element is terminated
     * immediately by '/>'
     */
    protected void popElemName()
    {
        elemStack.pop();
    }

    /**
     * Check whether name of closing direct xml element tag matches name 
     * of opening tag. Throw error if names do not match.
     * 
     * @throws RecognitionException
     */
    protected void matchElemName()
        throws RecognitionException
    {
        String opening = getQName(elemStack.pop());
        String closing = getQName(input.index());
        if (!opening.equals(closing)) {
            raiseError("Closing tag name '" + closing
                    + " must match opening tag name '" + opening + "'.");
        }
    }

    private String getQName(int index)
        throws RecognitionException
    {
        if ((index < 2) || input.get(index - 1).getType() != Colon) {
            return input.get(index).getText();
        }
        else {
            //if(input.get(index - 2).getType() != NCName) {
            //    raiseError("Parser internal error.");
            //}
            return input.get(index - 2).getText()
                    + input.get(index - 1).getText()
                    + input.get(index).getText();
        }
    }

    /**
     * Set values of some token codes needed by "add-on" parsing methods.
     * 
     * @param NCName code of the NCName token
     * @param Colon  code of the Colon token
     * @return
     */
    protected boolean setTokenCodes(int NCName, int Colon)
    {
        this.NCName = NCName;
        this.Colon = Colon;
        return false;
    }

    /**
     * Extract content of direct xml comment constructor parsed by generated
     * parser. Throws error if contenct contains the forbidden sequence '--'.
     * 
     * @return comment content
     * @throws RecognitionException
     */
    protected String parseDirComment()
        throws RecognitionException
    {
        String content = input.get(input.index()).getText().substring(4);
        content = content.substring(0, content.length() - 3);
        int length = content.length();
        if (length > 0
                && (content.contains("--") || content.charAt(length - 1) == '-')) {
            raiseError("String '--' not allowed in xml comment.");
        }

        return content;
    }

    /**
     * Extract content of direct xml CDATA section constructor parsed by the
     * generated parser.
     * 
     * @return CDATA section content.
     * 
     * @throws RecognitionException
     */
    protected String parseCData()
        throws RecognitionException
    {
        String content = input.get(input.index()).getText().substring(9);
        content = content.substring(0, content.length() - 3);

        return content;
    }

    /**
     * Extract target and content of direct xml processing instruction parsed
     * by the generated parser. Throws excetion if procesing instruction 
     * target is invalid (equal to 'xml' ignoring case).
     * 
     * @return pair of strings containing processing instruction target and
     *         content.
     *         
     * @throws RecognitionException
     */
    protected Pair<String, String> parseDirPI()
        throws RecognitionException
    {
        String text = input.get(input.index()).getText();
        if (text.charAt(2) <= '\u0020') {
            raiseError("Procesing instruction may not start with wihte space.");
        }
        int limit = text.length() - 2;
        int i = 2;
        while ((i < limit) && (text.charAt(i) > '\u0020')) {
            ++i;
        }
        String target = text.substring(2, i);
        if (target.equalsIgnoreCase("xml")) {
            raiseError(target + " is not a valid processing instruction name.");
        }
        while (text.charAt(i) <= '\u0020') {
            ++i;
        }
        String content = text.substring(i, limit);

        return new Pair<String, String>(target, content);
    }

    /**
     * Extract name and content of direct xml pragma constructor parsed by
     * the generated parser.
     * 
     * @return a pair where the first element is pair of prefix and name 
     *         constituting a QName and second element is pragma text content.
     *
     * @throws RecognitionException
     */
    protected Pair<Pair<String, String>, String> parsePragma()
        throws RecognitionException
    {
        String text = input.get(input.index()).getText();
        int start = 2;
        while (text.charAt(start) <= '\u0020') {
            ++start;
        }
        int limit = text.length() - 2;
        int i = start;
        while ((i < limit) && (text.charAt(i) > '\u0020')) {
            ++i;
        }
        String prefix = "";
        String target = text.substring(start, i);
        if (text.charAt(i) == ':') {
            while ((i < limit) && (text.charAt(i) > '\u0020')) {
                ++i;
            }
            prefix = target;
            target = text.substring(2, i);
        }
        while (text.charAt(i) <= '\u0020') {
            ++i;
        }
        String content = text.substring(i, limit);

        return new Pair<Pair<String, String>, String>(
                                                      new Pair<String, String>(
                                                                               prefix,
                                                                               target),
                                                      content);
    }
}
