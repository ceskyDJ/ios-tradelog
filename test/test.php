<?php

declare(strict_types=1);

/**
 * PHP console file for running test for Shell scripts
 *
 * @author Michal ŠMAHEL <admin@ceskydj.cz>
 * @date March 2021
 */

mb_internal_encoding("UTF-8");

// Script input params
// test.php -c          Activate extended color mode (with background color)
$args = getopt("c", ["ext-color"]);

// Colors for terminal outputs
if (key_exists("c", $args) || key_exists("ext-color", $args)) {
    define("GREEN", "\e[0;32;40m");
    define("YELLOW", "\e[0;33;40m");
    define("RED", "\e[0;31;40m");
    define("WHITE", "\e[0m");
} else {
    define("GREEN", "\e[0;32m");
    define("YELLOW", "\e[0;33m");
    define("RED", "\e[0;31m");
    define("WHITE", "\e[0m");
}

const OUTPUT_ERROR = 1;
const EXIT_CODE_ERROR = 2;

$successCallback = function (int $number) {
    echo GREEN."[Test {$number}]: The test was successful.".WHITE.PHP_EOL;
};
$failCallback = function (int $number, int $error, string $command) {
    $type = $error === OUTPUT_ERROR ? "Output error" : "Exit code error";
    echo RED."[Test {$number}]: {$type}".WHITE.PHP_EOL;
    echo RED."\t{$command}".WHITE.PHP_EOL;
};


// TESTS
// =====
$tests = [];

$tests[] = [
    'command' => "echo 'It works!'",
    'exp-output-f' => "test0.txt",
];

// Test 1
$tests[] = [
    'command' => "cat stock-2.log | head -n 5 | ./tradelog",
    'exp-output-f' => "test1.txt",
];

// Test 2
$tests[] = [
    'command' => "./tradelog -t TSLA -t V stock-2.log",
    'exp-output-f' => "test2.txt",
];

// Test 3
$tests[] = [
    'command' => "./tradelog -t CVX stock-4.log.gz | head -n 3",
    'exp-output-f' => "test3.txt",
];

// Test 4
$tests[] = [
    'command' => "./tradelog list-tick stock-2.log",
    'exp-output-f' => "test4.txt",
];

// Test 5
$tests[] = [
    'command' => "./tradelog profit stock-2.log",
    'exp-output-f' => "test5.txt",
];

// Test 6
$tests[] = [
    'command' => "./tradelog -t TSM -t PYPL profit stock-2.log",
    'exp-output-f' => "test6.txt",
];

// Test 7
$tests[] = [
    'command' => "./tradelog pos stock-2.log",
    'exp-output-f' => "test7.txt",
];

// Test 8
$tests[] = [
    'command' => "./tradelog -t TSM -t PYPL -t AAPL pos stock-2.log",
    'exp-output-f' => "test8.txt",
];

// Test 9
$tests[] = [
    'command' => "./tradelog last-price stock-2.log",
    'exp-output-f' => "test9.txt",
];

// Test 10
$tests[] = [
    'command' => "./tradelog hist-ord stock-2.log",
    'exp-output-f' => "test10.txt",
];

// Test 11
$tests[] = [
    'command' => "./tradelog -w 100 graph-pos stock-6.log",
    'exp-output-f' => "test11.txt",
];

// Test 12
$tests[] = [
    'command' => "./tradelog -w 10 -t FB -t JNJ -t WMT graph-pos stock-6.log",
    'exp-output-f' => "test12.txt",
];

// Test 13
$tests[] = [
    'command' => "cat /dev/null | ./tradelog profit",
    'exp-output-f' => "test13.txt",
];

// Get data
ob_start();

$successful = 0;
$failed = 0;
$sum = count($tests);
foreach($tests as $index => $test) {
    $output = [];
    $exitCode = 0;
    exec("cd ../src; {$test['command']}", $output, $exitCode);

    $outputAsString = implode("\n", $output);
    $validOutput = file_get_contents("files/{$test['exp-output-f']}");
    if($outputAsString === $validOutput) {
        if($exitCode === 0) {
            $successful++;
            $successCallback($index);
        } else {
            $failed++;
            $failCallback($index , EXIT_CODE_ERROR, $test['command']);
        }
    } else {
        $failed++;
        $failCallback($index, OUTPUT_ERROR, $test['command']);
    }
}

$testResults = ob_get_clean();
$successRate = (int)round(($successful / $sum) * 100);
$failRate = (int)round(($failed / $sum) * 100);

$testerName = "Tradelog - Tester";

$successRow = sprintf("Successful tests:\t%d / %d (%d %%)", $successful, $sum, $successRate);
$failRow = sprintf(   "Failed tests:    \t%d / %d (%d %%)", $failed, $sum, $failRate);

// Print report
echo GREEN."+".str_repeat("-", strlen($testerName) + 2)."+".WHITE.PHP_EOL;
echo GREEN."+ ".$testerName." +".WHITE.PHP_EOL;
echo GREEN."+".str_repeat("-", strlen($testerName) + 2)."+".WHITE.PHP_EOL.PHP_EOL;

echo $testResults.PHP_EOL;

echo GREEN.$successRow.WHITE.PHP_EOL;
echo RED.$failRow.WHITE.PHP_EOL;

// Exit code for Gitlab
exit($successRate === 100 ? 0 : 1);
