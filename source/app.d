import dlangui;
import ui.main_window;

mixin APP_ENTRY_POINT;

/// Entry point for dlangui application
extern (C) int UIAppMain(string[] args) {
    // create window
    Window window = Platform.instance.createWindow("CrystalDiskMark D"d, null, WindowFlag.Resizable, 800, 600);
    
    // add some widget to window
    window.mainWidget = new MainView();
    
    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
