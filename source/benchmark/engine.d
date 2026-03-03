module benchmark.engine;

import core.sys.windows.windows;
import std.datetime.stopwatch;
import std.stdio;
import std.conv : to;
import std.string : toStringz;
import benchmark.types;

class BenchmarkEngine {
    private HANDLE hFile;
    private string testFilePath;
    private size_t testFileSize;

    this(string path, size_t sizeMiB) {
        testFilePath = path;
        testFileSize = sizeMiB * 1024 * 1024;
    }

    bool prepare() {
        // Create test file with no buffering
        hFile = CreateFileA(
            testFilePath.toStringz,
            GENERIC_READ | GENERIC_WRITE,
            0,
            NULL,
            CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_SEQUENTIAL_SCAN,
            NULL
        );

        if (hFile == INVALID_HANDLE_VALUE) {
            writeln("Failed to create test file: ", GetLastError());
            return false;
        }

        // Set file size
        LARGE_INTEGER liSize;
        liSize.QuadPart = testFileSize;
        if (!SetFilePointerEx(hFile, liSize, NULL, FILE_BEGIN) || !SetEndOfFile(hFile)) {
            writeln("Failed to set file size: ", GetLastError());
            CloseHandle(hFile);
            return false;
        }

        // Pre-fill with random or 0x00
        // (Ignoring pre-fill for brevity in first version, but CDM usually fills it)
        
        CloseHandle(hFile); // Re-open as needed for specific tests
        return true;
    }

    TestResult runSequential(uint threads, uint queueDepth) {
        TestResult result;
        result.readMBs = performSeqRead(1024 * 1024); // 1 MiB blocks
        result.writeMBs = performSeqWrite(1024 * 1024);
        return result;
    }

    TestResult runRandom4K(uint threads, uint queueDepth) {
        TestResult result;
        result.readMBs = performRndRead(4096); // 4 KiB blocks
        result.writeMBs = performRndWrite(4096);
        result.readIOPS = result.readMBs * 1024 * 1024 / 4096;
        result.writeIOPS = result.writeMBs * 1024 * 1024 / 4096;
        return result;
    }

    private double performSeqRead(size_t blockSize) {
        hFile = CreateFileA(
            testFilePath.toStringz,
            GENERIC_READ,
            0,
            NULL,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_SEQUENTIAL_SCAN,
            NULL
        );
        if (hFile == INVALID_HANDLE_VALUE) return 0.0;

        void* buffer = VirtualAlloc(NULL, blockSize, MEM_COMMIT, PAGE_READWRITE);
        DWORD bytesRead;
        auto sw = StopWatch(AutoStart.yes);
        
        for (size_t i = 0; i < testFileSize; i += blockSize) {
            ReadFile(hFile, buffer, cast(DWORD)blockSize, &bytesRead, NULL);
        }
        
        sw.stop();
        VirtualFree(buffer, 0, MEM_RELEASE);
        CloseHandle(hFile);
        
        double seconds = sw.peek().total!"hnsecs" / 10_000_000.0;
        return (testFileSize / (1024.0 * 1024.0)) / seconds;
    }

    private double performSeqWrite(size_t blockSize) {
        hFile = CreateFileA(
            testFilePath.toStringz,
            GENERIC_WRITE,
            0,
            NULL,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_SEQUENTIAL_SCAN,
            NULL
        );
        if (hFile == INVALID_HANDLE_VALUE) return 0.0;

        void* buffer = VirtualAlloc(NULL, blockSize, MEM_COMMIT, PAGE_READWRITE);
        DWORD bytesWritten;
        auto sw = StopWatch(AutoStart.yes);
        
        for (size_t i = 0; i < testFileSize; i += blockSize) {
            WriteFile(hFile, buffer, cast(DWORD)blockSize, &bytesWritten, NULL);
        }
        
        sw.stop();
        VirtualFree(buffer, 0, MEM_RELEASE);
        CloseHandle(hFile);
        
        double seconds = sw.peek().total!"hnsecs" / 10_000_000.0;
        return (testFileSize / (1024.0 * 1024.0)) / seconds;
    }

    private double performRndRead(size_t blockSize) {
        import std.random : uniform;
        hFile = CreateFileA(
            testFilePath.toStringz,
            GENERIC_READ,
            0,
            NULL,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_RANDOM_ACCESS,
            NULL
        );
        if (hFile == INVALID_HANDLE_VALUE) return 0.0;

        void* buffer = VirtualAlloc(NULL, blockSize, MEM_COMMIT, PAGE_READWRITE);
        DWORD bytesRead;
        auto sw = StopWatch(AutoStart.yes);
        
        size_t totalBlocks = testFileSize / blockSize;
        size_t iterations = 1000; // Sample for speed
        
        for (size_t i = 0; i < iterations; i++) {
            size_t blockIndex = uniform(0, totalBlocks);
            LARGE_INTEGER liOffset;
            liOffset.QuadPart = blockIndex * blockSize;
            SetFilePointerEx(hFile, liOffset, NULL, FILE_BEGIN);
            ReadFile(hFile, buffer, cast(DWORD)blockSize, &bytesRead, NULL);
        }
        
        sw.stop();
        VirtualFree(buffer, 0, MEM_RELEASE);
        CloseHandle(hFile);
        
        double seconds = sw.peek().total!"hnsecs" / 10_000_000.0;
        return (iterations * blockSize / (1024.0 * 1024.0)) / seconds;
    }

    private double performRndWrite(size_t blockSize) {
        import std.random : uniform;
        hFile = CreateFileA(
            testFilePath.toStringz,
            GENERIC_WRITE,
            0,
            NULL,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_NO_BUFFERING | FILE_FLAG_RANDOM_ACCESS,
            NULL
        );
        if (hFile == INVALID_HANDLE_VALUE) return 0.0;

        void* buffer = VirtualAlloc(NULL, blockSize, MEM_COMMIT, PAGE_READWRITE);
        DWORD bytesWritten;
        auto sw = StopWatch(AutoStart.yes);
        
        size_t totalBlocks = testFileSize / blockSize;
        size_t iterations = 1000; // Sample for speed
        
        for (size_t i = 0; i < iterations; i++) {
            size_t blockIndex = uniform(0, totalBlocks);
            LARGE_INTEGER liOffset;
            liOffset.QuadPart = blockIndex * blockSize;
            SetFilePointerEx(hFile, liOffset, NULL, FILE_BEGIN);
            WriteFile(hFile, buffer, cast(DWORD)blockSize, &bytesWritten, NULL);
        }
        
        sw.stop();
        VirtualFree(buffer, 0, MEM_RELEASE);
        CloseHandle(hFile);
        
        double seconds = sw.peek().total!"hnsecs" / 10_000_000.0;
        return (iterations * blockSize / (1024.0 * 1024.0)) / seconds;
    }
}
