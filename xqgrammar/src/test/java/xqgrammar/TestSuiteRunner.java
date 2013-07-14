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

I.   XQuery 1.0 : 100% pass with the following remarks:

1.   One test which is expected to pass generates syntax error if run "out of
     the box" with this runner due to encoding issues :
   
     Queries/XQuery/Expressions/PrologExpr/VersionProlog/prolog-version-2.xq
   
     Handling of encoding does not belong to parser proper and if converted
     manually to appropriate encoding, this test passes too.

2.   One test is expected to and does generate syntax error under XQuery 1.0 
     due to multiple where clauses in FLWOR expression. XQuery 1.1 grammar 
     though allows multiple where clauses, so no syntax error is generated. 
     The test is:

     Queries/XQuery/Expressions/FLWORExpr/WhereExpr/WhereExpr020.xq

II.  XQuery Update    1.0 : 100% pass

III. XQuery Free Text 1.0 : 100% pass.

IV.  XQuery 3.0 :
     99.95 percent of the relevant tests which are supposed to be parsed
     without error are parsed successfully. The failing 13 tests are mostly
     lexical.
     For some 1000+ tests the parser fails to register an error which is
     expected according to the test specifications. The XQuery 3.0 suite
     does not distinguish between purely syntax errors and errors which can
     only be discovered based on the compile time semantic context or based
     on the runtime context. Therefore it is not clear what part of these
     tests are passed by the parser.

===============================================================================

                                   Remarks
                                   =======
   Test suites are not part of the project, so this test is disabled by 
   default. For access to W3C test suites see the following URLs: 

       http://www.w3.org/XML/Query/test-suite/
       http://dev.w3.org/2007/xquery-update-10-test-suite/
       http://dev.w3.org/2007/xpath-full-text-10-test-suite/
       http://dev.w3.org/2011/QT3-test-suite/
    
   Three formats of test catalogs are supported : the 2 types of W3C standard 
   xml catalogs and custom catalogs consisting of test file paths relative to 
   base test suite path with files expected to generate syntax error marked by
   a leading '@'. This custom format is easier to maintain for custom test 
   suites.


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
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
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
    private static final String ERROR_EXPECTED_MARK = "@";

    private static final String QUERIES_BASE        = "Queries/XQuery";
    private static final String QUERY_SUFFIX        = ".xq";
    private static final String TEST_SET            = "test-set";
    private static final String TEST_CASE           = "test-case";
    private static final String TEST                = "test";
    private static final String DEPENDENCY          = "dependency";
    private static final String ERROR               = "error";
    private static final String QUERY               = "query";
    private static final String PARSE_ERROR         = "parse-error";
    private static final String NAME_ATTRIBUTE      = "name";
    private static final String SCENARIO_ATTRIBUTE  = "scenario";
    private static final String FILE_PATH_ATTRIBUTE = "FilePath";
    private static final String FILE_ATTRIBUTE      = "file";
    private static final String CODE_ATTRIBUTE      = "code";
    private static final String TYPE_ATTRIBUTE      = "type";
    private static final String VALUE_ATTRIBUTE     = "value";

    private static enum CatalogType
    {
        OLD_XML, NEW_XML, TEXT
    };

    // Absolute base paths of test suites.
    // Change these to your specific paths.
    private static final String                   XQTS_BASE           = "/home/nikolay/Work/XQTS";
    private static final String                   XQ3TS_BASE          = "/home/nikolay/Work/QT3_1_0";
    private static final String                   XQUTS_BASE          =
                                                                          "/home/nikolay/Work/xquery-update-10-test-suite";
    private static final String                   XQFTTS_BASE         =
                                                                          "/home/nikolay/Work/XQFTTS";
    private static final String                   XQGTS_BASE          =
                                                                          "/home/nikolay/Work/XQGTS";
    private static final String                   ZQTS_BASE           =
                                                                          "/home/nikolay/Projects/tribe_head/"
                                                                                  + "zulu/src/main/resources/";
    // List of base paths for all test suites to be run.
    private static final List<String>             testSuitesBasePaths = new ArrayList<String>();
    // Tests which are expected to pass according to catalog 
    // but fail with syntax error for good reason.
    private static final Set<String>              failOK              = new HashSet<String>();
    // Tests which are expected to fail with syntax error according to catalog 
    // but pass for good reason.
    private static final Set<String>              passOK              = new HashSet<String>();
    // Test suites which must be skipped. For example - because they contain
    // features so far not supported by the official grammar - such as maps.
    private static final Set<String>              skipSuite           = new HashSet<String>();

    private static final Map<String, CatalogType> catalogTypes        = new HashMap<String, CatalogType>();
    private static final Map<String, String>      catalogNames        = new HashMap<String, String>();
    private static final Set<String>              unsupportedSpecs    = new HashSet<String>();
    private static final Set<String>              unsupportedFeatures = new HashSet<String>();
    private static final Set<String>              unsupportedErrors   = new HashSet<String>();

    static {
        catalogTypes.put(XQTS_BASE, CatalogType.OLD_XML);
        catalogTypes.put(XQ3TS_BASE, CatalogType.NEW_XML);
        catalogTypes.put(XQUTS_BASE, CatalogType.OLD_XML);
        catalogTypes.put(XQFTTS_BASE, CatalogType.OLD_XML);
        catalogTypes.put(XQGTS_BASE, CatalogType.TEXT);
        catalogTypes.put(ZQTS_BASE, CatalogType.TEXT);

        catalogNames.put(XQTS_BASE, "XQTSCatalog.xml");
        catalogNames.put(XQ3TS_BASE, "catalog.xml");
        catalogNames.put(XQUTS_BASE, "XQUTSCatalog.xml");
        catalogNames.put(XQFTTS_BASE, "XQFTTSCatalog.xml");
        catalogNames.put(XQGTS_BASE, "tests.txt");
        catalogNames.put(ZQTS_BASE, "tests.txt");

        unsupportedSpecs.add("XQ10");
        unsupportedSpecs.add("XT30+");
        unsupportedFeatures.add("namespace-axis");

        /*
        unsupportedErrors.add("XPST0001");
        unsupportedErrors.add("XPST0005");
        unsupportedErrors.add("XPST0017");
        unsupportedErrors.add("XQST0016");
        unsupportedErrors.add("XQST0032"); // ??????
        unsupportedErrors.add("XQST0033"); // ??????
        unsupportedErrors.add("XQST0034"); // ??????
        unsupportedErrors.add("XQST0035"); // ??????
        unsupportedErrors.add("XQST0045"); // !!!!!!
        unsupportedErrors.add("XPST0080");
        */

        testSuitesBasePaths.add(XQTS_BASE);
        testSuitesBasePaths.add(XQ3TS_BASE);
        testSuitesBasePaths.add(XQUTS_BASE);
        testSuitesBasePaths.add(XQFTTS_BASE);
        //testSuitesBasePaths.add(XQGTS_BASE);
        //testSuitesBasePaths.add(ZQTS_BASE);

        failOK.add("Expressions/PrologExpr/VersionProlog/prolog-version-2.xq");
        passOK.add("Expressions/FLWORExpr/WhereExpr/WhereExpr020.xq");

        // XQuery 3.0 failing tests
        failOK.add("fn/serialize.xml:serialize-xml-012");
        failOK.add("misc/XMLEdition.xml:XML10-4ed-Excluded-char-1-new");
        failOK.add("misc/XMLEdition.xml:XML11-c0-001");
        failOK.add("prod/StepExpr.xml:Steps-leading-lone-slash-12");
        failOK.add("prod/DirAttributeList.xml:K2-DirectConElemAttr-40");
        failOK.add("prod/EQName.xml:eqname-003");
        failOK.add("prod/EQName.xml:eqname-006");
        failOK.add("prod/Literal.xml:K-Literals-31a");
        failOK.add("prod/PathExpr.xml:PathExpr-6");
        failOK.add("xml:Steps-leading-lone-slash-12");
        failOK.add("xs/anyURI.xml:cbcl-anyURI-004b");
        failOK.add("xs/anyURI.xml:cbcl-anyURI-006b");
        failOK.add("xs/anyURI.xml:cbcl-anyURI-009b");
        failOK.add("xs/anyURI.xml:cbcl-anyURI-012b");
    }

    @Before
    public void init()
    {
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
        CatalogType catalogType = catalogTypes.get(testSuiteBasePath);
        int numTests = 0;
        int numErrors = 0;
        ThreadMXBean threadMXBean = ManagementFactory.getThreadMXBean();

        System.out.println("Loading tests ...");
        Collection<XQTest> tests = loadTests(testSuiteBasePath);
        System.out.println("Running tests ...");
        long cpuStart = threadMXBean.getCurrentThreadCpuTime();
        for (XQTest xqTest : tests) {
            String spec = xqTest.getDependency("spec");
            String feature = xqTest.getDependency("feature");
            if (unsupportedSpecs.contains(spec) ||
                    unsupportedFeatures.contains(feature)) {
                continue;
            }
            boolean failureExpected = xqTest.isFailureExpected();
            try {
                parse(xqTest.getQuery(), xqTest.getLength());
                if (!CatalogType.NEW_XML.equals(catalogType)) {
                    numTests++;
                    if (failureExpected
                            && !passOK.contains(xqTest.getPath())) {
                        ++numErrors;
                        System.out.println("Failed to register error in test "
                                + xqTest.getPath());
                    }
                }
                else {
                    if (failureExpected
                            && !passOK.contains(xqTest.getPath())) {
                        System.out.println("Failed to register error in test "
                                + xqTest.getPath());
                    }
                    else {
                        numTests++;
                    }
                }
            }
            catch (Throwable e) {
                if (!failureExpected && !failOK.contains(xqTest.getPath())) {
                    numErrors++;
                    System.out.println();
                    System.out.println("Failed to parse test "
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

    private Collection<XQTest> loadTests(String testSuiteBasePath)
        throws IOException, ParserConfigurationException, SAXException

    {
        CatalogType catalogType = catalogTypes.get(testSuiteBasePath);
        String catalogName = catalogNames.get(testSuiteBasePath);

        File basePathFile = new File(testSuiteBasePath);
        File catalogFile = new File(basePathFile, catalogName);

        if (catalogType.equals(CatalogType.TEXT)) {
            return scanCustomCatalog(basePathFile, catalogFile);
        }
        else {
            return scanW3cCatalog(basePathFile, catalogFile);
        }
    }

    private Set<XQTest> scanW3cCatalog(File basePathFile, File catalog)
        throws ParserConfigurationException, SAXException, IOException

    {
        CatalogType catalogType = catalogTypes.get(
            basePathFile.getPath());
        FileInputStream is = new FileInputStream(catalog);
        InputSource src = new InputSource(is);

        TestContentHandler catalogContentHandler = null;
        if (catalogType == CatalogType.OLD_XML) {
            catalogContentHandler = new OldCatalogContentHandler(basePathFile);
        }
        else {
            catalogContentHandler = new NewCatalogContentHandler(basePathFile);
        }
        SAXParserFactory factory = SAXParserFactory.newInstance();
        factory.setNamespaceAware(true);
        SAXParser parser = factory.newSAXParser();
        XMLReader reader = parser.getXMLReader();
        reader.setEntityResolver(catalogContentHandler);
        reader.setContentHandler(catalogContentHandler);
        reader.parse(src);

        return catalogContentHandler.getTests();
    }

    private Collection<XQTest> scanCustomCatalog(File basePathFile,
                                                 File customCatalogFile)
        throws IOException

    {
        Set<XQTest> tests = new LinkedHashSet<XQTest>();

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
        private String              path;
        private char[]              query;
        private int                 length;
        private boolean             failureExpected;
        private Map<String, String> dependencies = new HashMap<String, String>();

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

        public String getDependency(String type)
        {
            return dependencies.get(type);
        }

        public void putDependency(String type, String value)
        {
            dependencies.put(type, value);
        }
    }

    private static class TestContentHandler
        extends DefaultHandler
    {
        protected File        basePathFile;
        protected Set<XQTest> tests           = new LinkedHashSet<XQTest>();
        protected boolean     failureExpected = false;
        protected String      path            = null;

        public Set<XQTest> getTests()
        {
            return tests;
        }

    }

    private static class OldCatalogContentHandler
        extends TestContentHandler
    {
        public OldCatalogContentHandler(File basePathFile)
        {
            this.basePathFile = basePathFile;
        }

        @Override
        public void startElement(String uri, String localName, String qName,
                                 Attributes atts)
            throws SAXException
        {
            if (localName.equals(TEST_CASE)) {
                path = atts.getValue(FILE_PATH_ATTRIBUTE);
                failureExpected =
                    PARSE_ERROR.equals(atts.getValue(SCENARIO_ATTRIBUTE));
            }
            else if (localName.equals(QUERY)) {
                if (path == null)
                    return;
                XQTest test = new XQTest();
                test.setPath(path);
                test.setFailureExpected(failureExpected);
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
                    tests.add(test);
                }
                catch (FileNotFoundException e) {
                    // If your want to see missing test files:
                    //System.out.println("Missing test file: " + test.getPath());
                    test = null;
                    // The following throw statement is disabled because
                    // it does happen at least while test suite is under 
                    // development that some tests described in the catalog 
                    // do not really exist.
                    // throw new SAXException(e);
                }
                catch (IOException e) {
                    path = null;
                    throw new SAXException(e);
                }
            }
        }

        @Override
        public void endElement(String uri, String localName, String qName)
            throws SAXException
        {
            if (localName.equals(TEST_CASE)) {
                path = null;
            }
        }
    }

    private static class NewCatalogContentHandler
        extends TestContentHandler
    {
        public NewCatalogContentHandler(File basePathFile)
        {
            this.basePathFile = basePathFile;
        }

        @Override
        public void startElement(String uri, String localName, String qName,
                                 Attributes atts)
            throws SAXException
        {
            if (localName.equals(TEST_SET)) {
                try {
                    String testSetFileName = atts.getValue(FILE_ATTRIBUTE);
                    if (!skipSuite.contains(testSetFileName)) {
                        File testSet = new File(basePathFile, testSetFileName);
                        FileInputStream is;
                        is = new FileInputStream(testSet);
                        InputSource src = new InputSource(is);
                        TestContentHandler testSetContentHandler =
                            new TestSetContentHandler(basePathFile,
                                                      testSetFileName);
                        SAXParserFactory factory = SAXParserFactory
                            .newInstance();
                        factory.setNamespaceAware(true);
                        SAXParser parser = factory.newSAXParser();
                        XMLReader reader = parser.getXMLReader();
                        reader.setEntityResolver(testSetContentHandler);
                        reader.setContentHandler(testSetContentHandler);
                        reader.parse(src);

                        tests.addAll(testSetContentHandler.getTests());
                    }
                }
                catch (Exception e) {
                    throw new RuntimeException(e);
                }
            }
        }

        @Override
        public void endElement(String uri, String localName, String qName)
            throws SAXException
        {
        }
    }

    private static class TestSetContentHandler
        extends TestContentHandler
    {
        /*
            Test dependency types:
            spec
            feature
            xml-version
            xsd-version
            language
            default-language
            limits
            calendar
            unicode-normalization-form
            format-integer-sequence
         */
        private String              testSetName;
        private String              testSetRelPath;
        private boolean             inTestCase;
        private boolean             inTest;
        private boolean             skip;
        private XQTest              test;
        private char[]              query;
        private int                 length;
        private Map<String, String> dependencies = new HashMap<String, String>();

        public TestSetContentHandler(File basePathFile, String testSetName)
        {
            this.testSetName = testSetName;
            this.basePathFile = basePathFile;
            testSetRelPath = testSetName.substring(0,
                testSetName.lastIndexOf('/'));
        }

        @Override
        public void startElement(String uri, String localName, String qName,
                                 Attributes atts)
            throws SAXException
        {
            if (localName.equals(TEST_CASE)) {
                inTestCase = true;
                test = new XQTest();
                query = new char[64];
                length = 0;
                skip = false;
                String name = atts.getValue(NAME_ATTRIBUTE);
                String fullName = testSetName + ":" + name;
                test.setPath(fullName);
            }
            if (localName.equals(TEST)) {
                String file = atts.getValue(FILE_ATTRIBUTE);
                if (file != null && file.length() > 0) {
                    File queryFile = new File(basePathFile, testSetRelPath
                            + "/" + file);
                    query = new char[(int) queryFile.length()];
                    try {
                        BufferedReader testReader =
                            new BufferedReader(new FileReader(queryFile));
                        length = testReader.read(query, 0, query.length);
                        testReader.close();
                    }
                    catch (Exception e) {
                        e.printStackTrace();
                        throw new RuntimeException(e);
                    }
                }
                inTest = true;
            }
            else if (localName.equals(DEPENDENCY)) {
                String type = atts.getValue(TYPE_ATTRIBUTE);
                String value = atts.getValue(VALUE_ATTRIBUTE);
                if (inTestCase) {
                    test.putDependency(type, value);
                }
                else {
                    dependencies.put(type, value);
                }
            }
            else if (localName.equals(ERROR)) {
                String code = atts.getValue(CODE_ATTRIBUTE);
                if (code != null &&
                        !unsupportedErrors.contains(code) && (
                        code.startsWith("XPS") ||
                        code.startsWith("XQS"))) {
                    test.setFailureExpected(true);
                }
            }
        }

        @Override
        public void endElement(String uri, String localName, String qName)
            throws SAXException
        {
            if (localName.equals(TEST_CASE)) {
                inTestCase = false;
                test.setQuery(query);
                test.setLength(length);
                Set<String> depNames = dependencies.keySet();
                for (String name : depNames) {
                    if (test.getDependency(name) == null) {
                        test.putDependency(name, dependencies.get(name));
                    }
                }
                if (!skip) { // !!!!!!
                    tests.add(test);
                }
                test = null;
                query = null;
                length = 0;
            }
            else if (localName.equals(TEST)) {
                inTest = false;
            }
        }

        @Override
        public void characters(char[] ch,
                               int start,
                               int len)
        {
            if (inTest) {
                int lengthNeeded = length + len;
                if (query.length < lengthNeeded) {
                    char[] newQuery = new char[2 * lengthNeeded];
                    System.arraycopy(query, 0, newQuery, 0, length);
                    query = newQuery;
                }
                System.arraycopy(ch, start, query, length, len);
                length = lengthNeeded;
            }
        }
    }
}
