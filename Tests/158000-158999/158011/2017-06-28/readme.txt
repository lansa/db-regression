1. From "O:\CCS Tests\Test-Materials\" directory, import "VT_CVL", "BIF Field". (if required).
2. Compile VT_CVL process and its Functions. (if required).
=> Ignore all FFC errors.
3. Check-In / compile all the imported objects. (if required).

4. Import the provided package from the CCS's test directory, with the <File Library> option set to "Partition Data Library".
5. Compile all the imported objects.
=> The compilation should complete successfully.

PS: This test case requires access to "//syd1/docs" server. Failure having that setup will result in execution errors.

6. Select and execute the Process (as Windows application) with the prefix "VT" and following with the CCS number.
7. Select and execute the CCS <Test Case Driver> Function.
=> The execution should be completed successfully, without any Fatal Error.
=> Resolve any errors / warnings in the Verifier_Test_Report.txt.

PS: The VTL158011C File definition will be modified during execution, and the test environment (including the File definition) will be preserved in case of execution error. Therefore, steps (4) & (5) are required to be repeated again in case of any error.

PS: Because this test case simulate MSI Installation, it will not be executed under any Super-Server configuration. Tester is required to test it on all supported database types on Windows.

9. Test and ensure user provided test case in the CCS (if any) is working correctly.

The test result can also be checked in <LANSA_Root>/Verifier_Test_Report.txt for the support of both Windows 32-bit and 64-bit.

