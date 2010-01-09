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

                              Test Suite Results
                              ==================

I. XQuery : 100% pass with the following remarks:

1. One test which is expected to pass generates syntax error if run "out of
   the box" with this runner due to encoding issues :
   
   Queries/XQuery/Expressions/PrologExpr/VersionProlog/prolog-version-2.xq
   
   Handling of encoding does not belong to parser proper and if converted
   manually to appropriate encoding, this test passes too.

2. One test is expected to and does generate syntax error under XQuery 1.0 
   due to multiple where clauses in FLWOR expression. XQuery 1.1 grammar 
   though allows multiple where clauses, so no syntax error is generated. 
   The test is:

   Queries/XQuery/Expressions/FLWORExpr/WhereExpr/WhereExpr020.xq

II.  XQuery Update    : 100% pass.

III. XQuery Free Text : 100% pass.

===============================================================================

                                   Remarks
                                   =======
   Test suites are not part of the project, so this test is disabled by 
   default. For access to W3C test suites see the following URLs: 

       http://www.w3.org/XML/Query/test-suite/
       http://dev.w3.org/2007/xquery-update-10-test-suite/
       http://dev.w3.org/2007/xpath-full-text-10-test-suite/
    
   Two formats of test catalogs are supported :  W3C standard xml catalogs 
   and custom catalogs consisting of test file paths relative to base test 
   suite path with files expected to generate syntax error marked by leading
   '@'. This custom format is easier to maintain for custom test suites. 
   Custom catalog overrides xml catalog if both are present.


===============================================================================

                                   Credits
                                   =======
   Test suite xml catalog scan code is based on ideas of Dimitriy Shabanov
   (shabanovd@gmail.com)

=============================================================================*/

package xqgrammar;

import static org.junit.Assert.assertTrue;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.ThreadMXBean;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;
import javax.xml.parsers.SAXParserFactory;

import org.antlr.runtime.ANTLRStringStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.Token;
import org.junit.Before;
import org.junit.Ignore;
import org.junit.Test;
import org.xml.sax.Attributes;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;
import org.xml.sax.XMLReader;
import org.xml.sax.helpers.DefaultHandler;

public class TestSuiteRunner
{
    private static final String CUSTOM_CATALOG_NAME = "tests.txt";
    private static final String ERROR_EXPECTED_MARK = "@";

    private static final String W3C_CATALOG_NAME    = "Catalog.xml";
    private static final String QUERIES_BASE        = "Queries/XQuery";
    private static final String QUERY_SUFFIX        = ".xq";
    private static final String TEST_CASE           = "test-case";
    private static final String QUERY               = "query";
    private static final String PARSE_ERROR         = "parse-error";
    private static final String NAME_ATTRIBUTE      = "name";
    private static final String SCENARIO_ATTRIBUTE  = "scenario";
    private static final String FILE_PATH_ATTRIBUTE = "FilePath";

    // Absolute base paths of test suites.
    // Change these to your specific paths.
    private static final String XQTS_BASE           = "/home/nikolay/Work/XQTS";
    private static final String XQUTS_BASE          =
                                                        "/home/nikolay/Work/xquery-update-10-test-suite";
    private static final String XQFTTS_BASE         =
                                                        "/home/nikolay/Work/XQFTTS";
    private static final String XQGTS_BASE          =
                                                        "/home/nikolay/Work/XQGTS";
    // List of base paths for all test suites to be run.
    private final List<String>  testSuitesBasePaths = new ArrayList<String>();

    // Tests which are expected to pass according to catalog 
    // but fail with syntax error for good reason.
    private final Set<String>   failOK              = new HashSet<String>();
    // Tests which are expected to fail with syntax error according to catalog 
    // but pass for good reason.
    private final Set<String>   passOK              = new HashSet<String>();

    @Before
    public void init()
    {
        testSuitesBasePaths.add(XQTS_BASE);
        testSuitesBasePaths.add(XQUTS_BASE);
        testSuitesBasePaths.add(XQFTTS_BASE);
        testSuitesBasePaths.add(XQGTS_BASE);

        failOK.add("Expressions/PrologExpr/VersionProlog/prolog-version-2.xq");
        passOK.add("Expressions/FLWORExpr/WhereExpr/WhereExpr020.xq");
    }

    @Ignore
    @Test
    public void runTestSuites()
        throws IOException, ParserConfigurationException, SAXException
    {
        for (String testSuiteBasePath : testSuitesBasePaths) {
            assertTrue(runTests(testSuiteBasePath));
        }
    }

    private boolean runTests(String testSuiteBasePath)
        throws IOException, ParserConfigurationException, SAXException
    {
        int numTests = 0;
        int numErrors = 0;
        ThreadMXBean threadMXBean = ManagementFactory.getThreadMXBean();

        System.out.println("Loading tests ...");
        List<XQTest> tests = loadTests(testSuiteBasePath);
        System.out.println("Running tests ...");
        long cpuStart = threadMXBean.getCurrentThreadCpuTime();
        for (XQTest xqTest : tests) {
            boolean failureExpected = xqTest.isFailureExpected();
            try {
                numTests++;
                parse(xqTest.getQuery(), xqTest.getLength());
                if (failureExpected && !passOK.contains(xqTest.getPath())) {
                    System.out.println("Failed to register error in file "
                            + xqTest.getPath());
                    ++numErrors;
                }
            }
            catch (Throwable e) {
                if (!failureExpected && !failOK.contains(xqTest.getPath())) {
                    System.out.println(e.getMessage());
                    numErrors++;
                    System.out.println();
                    System.out.println("Failed to parse file "
                            + xqTest.getPath());
                }
            }
        }
        long cpuTime =
            (threadMXBean.getCurrentThreadCpuTime() - cpuStart) / 1000000;

        System.out.println("Number of tests : " + numTests);
        System.out.println("Number of errors: " + numErrors);
        System.out.println("CPU Time        : " + cpuTime + "ms");
        System.out.println();

        return numErrors == 0;
    }

    private List<XQTest> loadTests(String testSuiteBasePath)
        throws IOException, ParserConfigurationException, SAXException

    {
        File basePathFile = new File(testSuiteBasePath);
        File customCatalogFile = new File(basePathFile, CUSTOM_CATALOG_NAME);

        if (customCatalogFile.exists()) {
            return scanCustomCatalog(basePathFile, customCatalogFile);
        }
        else {
            return scanW3cCatalog(basePathFile);
        }
    }

    private List<XQTest> scanCustomCatalog(File basePathFile,
                                           File customCatalogFile)
        throws IOException

    {
        List<XQTest> tests = new ArrayList<XQTest>();

        BufferedReader testListReader =
            new BufferedReader(new FileReader(customCatalogFile));
        while (true) {
            String testPath = testListReader.readLine();
            if (testPath == null) {
                break;
            }
            XQTest test = new XQTest();
            if (testPath.contains(ERROR_EXPECTED_MARK)) {
                test.setFailureExpected(true);
                testPath = testPath.substring(1);
            }
            test.setPath(testPath);
            File queryFile = new File(basePathFile, testPath);
            char[] query = new char[(int) queryFile.length()];
            BufferedReader testReader =
                new BufferedReader(new FileReader(queryFile));
            int len = testReader.read(query, 0, query.length);
            testReader.close();
            test.setQuery(query);
            test.setLength(len);
            tests.add(test);
        }
        testListReader.close();
        return tests;

    }

    private List<XQTest> scanW3cCatalog(File basePathFile)
        throws ParserConfigurationException, SAXException, IOException

    {
        File catalog = null;
        String[] fileList = basePathFile.list();

        for (String fileName : fileList) {
            if (fileName.endsWith(W3C_CATALOG_NAME)) {
                catalog = new File(basePathFile, fileName);
                break;
            }
        }
        if (catalog == null) {
            throw new IOException("Failed to locate catalog.");
        }

        FileInputStream is = new FileInputStream(catalog);
        InputSource src = new InputSource(is);

        CatalogContentHandler catalogContentHandler =
            new CatalogContentHandler(basePathFile);
        SAXParserFactory factory = SAXParserFactory.newInstance();
        factory.setNamespaceAware(true);
        SAXParser parser = factory.newSAXParser();
        XMLReader reader = parser.getXMLReader();
        reader.setEntityResolver(catalogContentHandler);
        reader.setContentHandler(catalogContentHandler);
        reader.parse(src);

        return catalogContentHandler.getTests();
    }

    private void parse(char[] query, int length)
        throws IOException, RecognitionException
    {
        ANTLRStringStream source = new ANTLRStringStream(query, length);
        XQLexer lexer = new XQLexer(source);
        XQTokenStream tokenStream = new XQTokenStream(lexer);
        XQParser parser = new XQParser(tokenStream);
        parser.module();
        if (tokenStream.LT(1) != Token.EOF_TOKEN) {
            throw new RuntimeException("Extra input after end of expression.");
        }
    }

    private static class XQTest
    {
        private String  path;
        private char[]  query;
        private int     length;
        private boolean failureExpected;

        public String getPath()
        {
            return path;
        }

        public void setPath(String path)
        {
            this.path = path;
        }

        public char[] getQuery()
        {
            return query;
        }

        public void setQuery(char[] query)
        {
            this.query = query;
        }

        public int getLength()
        {
            return length;
        }

        public void setLength(int length)
        {
            this.length = length;
        }

        public boolean isFailureExpected()
        {
            return failureExpected;
        }

        public void setFailureExpected(boolean failureExpected)
        {
            this.failureExpected = failureExpected;
        }
    }

    private static class CatalogContentHandler
        extends DefaultHandler
    {
        private final File         basePathFile;
        private final List<XQTest> tests = new ArrayList<XQTest>();
        private XQTest             test;

        public CatalogContentHandler(File basePathFile)
        {
            this.basePathFile = basePathFile;
        }

        public List<XQTest> getTests()
        {
            return tests;
        }

        @Override
        public void startElement(String uri, String localName, String qName,
                                 Attributes atts)
            throws SAXException
        {
            if (localName.equals(TEST_CASE)) {
                test = new XQTest();
                test.setPath(atts.getValue(FILE_PATH_ATTRIBUTE));
                test.setFailureExpected(PARSE_ERROR.equals(atts
                    .getValue(SCENARIO_ATTRIBUTE)));

            }
            else if (localName.equals(QUERY)) {
                if (test == null)
                    return;

                File queryFile =
                    new File(new File(new File(basePathFile, QUERIES_BASE),
                                      test.getPath()), atts
                        .getValue(NAME_ATTRIBUTE)
                            + QUERY_SUFFIX);
                test.setPath(test.getPath() + queryFile.getName());

                char[] query = new char[(int) queryFile.length()];
                try {
                    BufferedReader testReader =
                        new BufferedReader(new FileReader(queryFile));
                    int len = testReader.read(query, 0, query.length);
                    testReader.close();
                    test.setQuery(query);
                    test.setLength(len);
                }
                catch (FileNotFoundException e) {
                    // If your want to see missing test files:
                    // System.out.println("Missing test file: " + test.getPath());
                    test = null;
                    // The following throw statement is disabled because
                    // it does happen at least while test suite is under 
                    // development that some tests described in the catalog 
                    // do not really exist.
                    // throw new SAXException(e);
                }
                catch (IOException e) {
                    test = null;
                    throw new SAXException(e);
                }
            }
        }

        @Override
        public void endElement(String uri, String localName, String qName)
            throws SAXException
        {
            if (localName.equals(TEST_CASE)) {
                if (test != null) {
                    tests.add(test);
                }
            }
        }
    }
}
