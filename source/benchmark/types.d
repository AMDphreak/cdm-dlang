module benchmark.types;

enum TestMode {
    Sequential,
    Random4K
}

struct TestParams {
    TestMode mode;
    uint queueDepth;
    uint threads;
    size_t blockSize; // in bytes
}

struct TestResult {
    double readMBs;  // MB/s
    double writeMBs; // MB/s
    double readIOPS;
    double writeIOPS;
}
