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

I. XQTS : 100% pass with the following remarks:

1. Some files are physically present in the suite but not present  in the 
   catalog (XQTSCatalog.xml):

   Queries/XQuery/Expressions/Construct/DirectConElem/DirectConElemAttr
       /Constr-attr-enclexpr-8.xq  
   Queries/XQuery/Expressions/Construct/DirectConElem/DirectConElemAttr
       /Constr-attr-enclexpr-9.xq
   Queries/XQuery/Expressions/Operators/CompExpr/ValComp/DurationDateTimeOp
       /DayTimeDurationLT/op-dayTimeDuration-less-than-2.xq
   Queries/XQuery/Expressions/PrologExpr/DefaultOrderingProlog/orderDecl-19.xq

   These all generate syntax errors for good reasons.

2. One test which is expected to pass generates syntax error if run "out of
   the box" with this runner due to encoding issues :
   
   Queries/XQuery/Expressions/PrologExpr/VersionProlog/prolog-version-2.xq
   
   Handling of encoding does not belong to parser propper and if converted
   manually to appropriate encoding, this test passes too.


II.XQUTS : 100% pass.

=============================================================================*/

package xqgrammar;

import static org.junit.Assert.assertTrue;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.ThreadMXBean;
import java.util.ArrayList;
import java.util.List;

import org.antlr.runtime.ANTLRStringStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.Token;
import org.junit.Ignore;
import org.junit.Test;

public class TestSuiteRunner
{
    private static String XQTS_BASE  = "/home/nikolay/Work/XQTS";
    private static String XQUTS_BASE =
                                         "/home/nikolay/Work/xquery-update-10-test-suite";
    private static String XQGTS_BASE = "/home/nikolay/Work/XQGTS";

    // Test suites are not part of the project, 
    // so this test is disabled by default. 
    //
    // See
    // http://www.w3.org/XML/Query/test-suite/
    // http://dev.w3.org/2007/xquery-update-10-test-suite/
    // 
    @Ignore
    @Test
    public void runTestSuites()
        throws IOException
    {
        assertTrue(runTests(XQTS_BASE));
        assertTrue(runTests(XQUTS_BASE));
        assertTrue(runTests(XQGTS_BASE));
    }

    private boolean runTests(String testListPath)
        throws IOException
    {
        int numTests = 0;
        int numErrors = 0;
        ThreadMXBean threadMXBean = ManagementFactory.getThreadMXBean();
        List<XQTest> tests = loadTests(testListPath);

        long cpuStart = threadMXBean.getCurrentThreadCpuTime();
        for (XQTest xqTest : tests) {
            boolean failureExpected = xqTest.isFailureExpected();
            try {
                numTests++;
                parse(xqTest.getQuery(), xqTest.getLength());
                if (failureExpected) {
                    System.out.println("Failed to register error in file "
                            + xqTest.getFileName());
                    ++numErrors;
                }
            }
            catch (Throwable e) {
                if (!failureExpected) {
                    System.out.println(e.getMessage());
                    numErrors++;
                    System.out.println();
                    System.out.println("Failed to parse file "
                            + xqTest.getFileName());
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

    private List<XQTest> loadTests(String testListPath)
        throws IOException
    {
        // load tests to memory in order to factor 
        // out load time in cpu time measurements
        List<XQTest> tests = new ArrayList<XQTest>();

        File basePath = new File(testListPath);
        File testList = new File(basePath, "tests.txt");
        BufferedReader testListReader =
            new BufferedReader(new FileReader(testList));
        System.out.println("Loading tests ...");
        System.out.println("Parsing tests ...");
        while (true) {
            String testPath = testListReader.readLine();
            if (testPath == null) {
                break;
            }
            XQTest test = new XQTest();
            if (testPath.contains("@")) {
                test.setFailureExpected(true);
                testPath = testPath.substring(1);
            }
            test.setFileName(testPath);
            File queryFile = new File(basePath, testPath);
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
        private String fileName;
        private char[] query;
        private int    length;
        boolean        failureExpected;

        public String getFileName()
        {
            return fileName;
        }

        public void setFileName(String fileName)
        {
            this.fileName = fileName;
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
}
