1. From "\\syd6\CCS\Tests\Test-Materials\" directory, import "VT_CVL", "BIF Field". (if required).
2. Compile VT_CVL process and its Functions. (if required).
=> Ignore all FFC errors on Functions with "Template" in the function description.

3. Import the provided package from the CCS's test directory, with the <File Library> option setting to "Partition Data Library".
=> The import should complete successfully.

4. Compile all the imported objects.
=> The compilation should complete successfully.

5. Select and execute the Process (as Windows application) with the prefix "VT" and following with the CCS number.
6. Select and execute the CCS <Test Case Driver> Function.
=> The execution should be completed successfully, without any Fatal Error.
=> Resolve any errors / warnings in the Verifier_Test_Report.txt.

7. Test and ensure user provided test case in the CCS (if any) is working correctly.

The test result can also be checked in <LANSA_Root>/Verifier_Test_Report.txt for the support of both Windows 32-bit and 64-bit.

PS: Because this test case simulate MSI Installation, it will not be executed under any Super-Server configuration. Tester is required to test it on all supported database types on Windows.

