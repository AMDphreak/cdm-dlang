module ui.main_window;

import dlangui;

class MainView : VerticalLayout {
    this() {
        super();
        
        // Define a layout
        layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        
        // Header
        auto header = new HorizontalLayout();
        header.layoutWidth(FILL_PARENT).layoutHeight(60).backgroundColor(0x1F1F1F);
        auto title = new TextWidget();
        title.text("CRYSTALDISKMARK D"d);
        title.fontSize(24).textColor(0xFFFFFF).padding(Rect(10, 20, 10, 20));
        header.addChild(title);
        
        this.addChild(header);
        
        // Main content area
        auto mainArea = new HorizontalLayout();
        mainArea.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
        
        // Sidebar
        auto sidebar = new VerticalLayout();
        sidebar.layoutWidth(250).layoutHeight(FILL_PARENT).backgroundColor(0x2D2D2D);
        sidebar.padding(Rect(10, 10, 10, 10));
        
        // Drive Selection
        sidebar.addChild(new TextWidget().text("Select Drive:"d).textColor(0xCCCCCC));
        auto driveCombo = new ComboBox(null, ["C: (SSD)"d, "D: (HDD)"d]);
        driveCombo.layoutWidth(FILL_PARENT).margins(Rect(5, 5, 5, 5));
        sidebar.addChild(driveCombo);
        
        // Test Size
        sidebar.addChild(new TextWidget().text("Select Test Size:"d).textColor(0xCCCCCC));
        auto sizeCombo = new ComboBox(null, ["512 MiB"d, "1 GiB"d, "2 GiB"d, "4 GiB"d]);
        sizeCombo.selectedItemIndex = 1;
        sizeCombo.layoutWidth(FILL_PARENT).margins(Rect(5, 5, 5, 5));
        sidebar.addChild(sizeCombo);
        
        // Test Count
        sidebar.addChild(new TextWidget().text("Select Test Count:"d).textColor(0xCCCCCC));
        auto countCombo = new ComboBox(null, ["1"d, "3"d, "5"d, "9"d]);
        countCombo.selectedItemIndex = 2;
        countCombo.layoutWidth(FILL_PARENT).margins(Rect(5, 5, 5, 5));
        sidebar.addChild(countCombo);
        
        sidebar.addChild(new VSpacer());
        
        // Start Buttons
        auto btnAll = new Button().text("ALL TESTS"d);
        btnAll.layoutWidth(FILL_PARENT).padding(Rect(10, 10, 10, 10)).margins(Rect(5, 5, 5, 5)).backgroundColor(0x0078D7).textColor(0xFFFFFF);
        btnAll.click = delegate(Widget source) {
            runBenchmarks();
            return true;
        };
        sidebar.addChild(btnAll);
        
        statusLabel = new TextWidget();
        statusLabel.text("Ready"d).textColor(0xAAAAAA).padding(Rect(5, 5, 5, 5));
        sidebar.addChild(statusLabel);
        
        mainArea.addChild(sidebar);
        
        // Benchmarks Table
        auto benchArea = new VerticalLayout();
        benchArea.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT).padding(Rect(20, 20, 20, 20)).backgroundColor(0x121212);
        
        auto table = new VerticalLayout();
        table.layoutWidth(FILL_PARENT);
        
        // Column Headers
        auto headers = new HorizontalLayout();
        headers.layoutWidth(FILL_PARENT).padding(Rect(5, 5, 5, 5));
        headers.addChild(new TextWidget().text("Test Mode"d).layoutWidth(200).textColor(0x888888));
        headers.addChild(new TextWidget().text("Read (MB/s)"d).layoutWidth(150).textColor(0x888888));
        headers.addChild(new TextWidget().text("Write (MB/s)"d).layoutWidth(150).textColor(0x888888));
        table.addChild(headers);
        
        // Add benchmark rows
        testRows["SEQ Q8T1"] = createBenchRow("SEQ Q8T1", "---", "---");
        testRows["SEQ Q1T1"] = createBenchRow("SEQ Q1T1", "---", "---");
        testRows["RND4K Q32T1"] = createBenchRow("RND4K Q32T1", "---", "---");
        testRows["RND4K Q1T1"] = createBenchRow("RND4K Q1T1", "---", "---");
        
        table.addChild(testRows["SEQ Q8T1"]);
        table.addChild(testRows["SEQ Q1T1"]);
        table.addChild(testRows["RND4K Q32T1"]);
        table.addChild(testRows["RND4K Q1T1"]);
        
        benchArea.addChild(table);
        mainArea.addChild(benchArea);
        
        this.addChild(mainArea);
    }
    
    private TextWidget statusLabel;
    private HorizontalLayout[string] testRows;
    private TextWidget[string] readValues;
    private TextWidget[string] writeValues;

    private void runBenchmarks() {
        import core.thread : Thread;
        import benchmark.engine;
        import benchmark.types;
        import std.format;
        import std.conv : to;

        auto thr = new Thread(() {
            executeInUiThread(() {
                statusLabel.text = "Preparing..."d;
            });
            
            auto engine = new BenchmarkEngine("cdm_test.tmp", 128); // 128 MiB for test
            if (!engine.prepare()) {
                executeInUiThread(() {
                    statusLabel.text = "Error: Preparation failed"d;
                });
                return;
            }
            
            // Run tests
            struct TestInfo { string name; bool isRandom; }
            TestInfo[] tests = [
                {"SEQ Q8T1", false}, {"SEQ Q1T1", false},
                {"RND4K Q32T1", true}, {"RND4K Q1T1", true}
            ];
            foreach (test; tests) {
                executeInUiThread(() {
                    statusLabel.text = ("Running " ~ test.name).to!dstring;
                    readValues[test.name].text = "..."d;
                    writeValues[test.name].text = "..."d;
                });
                
                auto res = test.isRandom ? engine.runRandom4K(1, 1) : engine.runSequential(1, 1);
                
                executeInUiThread(() {
                    readValues[test.name].text = format("%.2f", res.readMBs).to!dstring;
                    writeValues[test.name].text = format("%.2f", res.writeMBs).to!dstring;
                });
            }
            
            executeInUiThread(() {
                statusLabel.text = "Finished"d;
            });
        });
        thr.start();
    }
    
    private HorizontalLayout createBenchRow(string label, string read, string write) {
        import std.conv : to;
        auto row = new HorizontalLayout();
        row.layoutWidth(FILL_PARENT).padding(Rect(10, 10, 10, 10)).backgroundColor(0x1E1E1E).margins(Rect(2, 2, 2, 2));
        
        auto lbl = new TextWidget();
        lbl.text = label.to!dstring;
        lbl.layoutWidth(200).fontSize(16).textColor(0xFFFFFF);
        row.addChild(lbl);
        
        auto rVal = new TextWidget();
        rVal.text = read.to!dstring;
        rVal.layoutWidth(150).fontSize(20).textColor(0x00FF00);
        row.addChild(rVal);
        readValues[label] = rVal;
        
        auto wVal = new TextWidget();
        wVal.text = write.to!dstring;
        wVal.layoutWidth(150).fontSize(20).textColor(0xFF00FF);
        row.addChild(wVal);
        writeValues[label] = wVal;
        
        return row;
    }
}
