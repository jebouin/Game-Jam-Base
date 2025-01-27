package ;

import hxd.System;
import hxd.Key;
import Controller;

@:native("")
extern class External {
    static function updateProgress(p:Int):Void;
    static function onGameLoaded():Void;
}

@:build(Macros.buildTemplate())
class Main extends hxd.App {
    public static inline var WIDTH = 320;
    public static inline var HEIGHT = 180;
    public static inline var SIM_FPS = 60;
    public static inline var SIM_TICK_TIME = 1. / SIM_FPS;
    public static inline var MAX_TICKS_PER_FRAME = 2;
    public static var inst : Main;
    public var controller : Controller;
    public var hasFocus : Bool = true;
    public var renderer : Renderer;
    var timeToSimulate : Float = 0;
    var timeToSimulateConstantRate : Float = 0.;
    var started : Bool = false;
    var maxDrawCalls : Int = 0;

    override function init() {
        renderer = new Renderer(s2d);
        Assets.init();
        engine.fullScreen = false;
        engine.autoResize = true;
        var window = hxd.Window.getInstance();
        window.title = GAME_NAME;
        window.addEventTarget(onEvent);
        SceneManager.init();
        initController();
        started = true;
    }
    function onEvent(event:hxd.Event) {
        if(!started) return;
        if(event.kind == EFocus) {
            hasFocus = true;
        } else if(event.kind == EFocusLost) {
            hasFocus = false;
        }
    }
    public function setVSync(v:Bool) {
        var window = hxd.Window.getInstance();
        if(window.vsync == v) return;
        window.vsync = v;
    }
    override function onResize() {
        hxd.Timer.skip();
        renderer.updateScale();
        tickConstantRate();
    }
    function initController() {
        controller = new Controller();
    }
    function tick() {
        try {
            SceneManager.update(SIM_TICK_TIME);
        } catch(e) {
            trace(e.details());
            System.exit();
        }
    }
    function tickConstantRate() {
        SceneManager.updateConstantRate(SIM_TICK_TIME);
    }
    override function update(dt:Float) {
        if(!started) return;
        controller.update(dt);
        #if debug
        hasFocus = true;
        #end
        if(hasFocus) {
            updateSimulation(dt);
        }
        #if debug
        updateDebug();
        #end
    }
    inline function updateSimulation(dt:Float) {
        timeToSimulateConstantRate += dt;
        timeToSimulate += dt;
        if(timeToSimulate > 1.) {
            timeToSimulate = 1.;
        }
        var ticks = MAX_TICKS_PER_FRAME;
        while(timeToSimulate >= SIM_TICK_TIME && ticks > 0) {
            timeToSimulate -= SIM_TICK_TIME;
            tick();
            if(SceneManager.scenes.length == 0) {
                System.exit();
            }
            controller.afterUpdate();
            ticks--;
        }
        ticks = 5;
        while(timeToSimulateConstantRate >= SIM_TICK_TIME && ticks > 0) {
            timeToSimulateConstantRate -= SIM_TICK_TIME;
            tickConstantRate();
            ticks--;
        }
        SceneManager.updateAfter(dt);
    }
    #if debug
    function updateDebug() {
        if(engine.drawCalls > maxDrawCalls) {
            maxDrawCalls = engine.drawCalls;
            trace("Draw calls: " + maxDrawCalls);
        }
        if(Key.isPressed(Key.G)) {
            engine.fullScreen = !engine.fullScreen;
        }
    }
    #end

    override function render(e:h3d.Engine) {
        renderer.render(e);
    }

    static function main() {
        #if js
        var loader = new hxd.net.BinaryLoader("res.pak");
        loader.load();
        loader.onProgress = function(cur:Int, max:Int) {
            var p = Math.floor(100 * cur / max);
            External.updateProgress(p);
        }
        loader.onLoaded = function(bytes:haxe.io.Bytes) {
            var fs = new hxd.fmt.pak.FileSystem();
            fs.addPak(new hxd.fmt.pak.FileSystem.FileInput(bytes));
            hxd.Res.loader = new hxd.res.Loader(fs);
            External.onGameLoaded();
            onPAKLoaded();
        }
        #elseif debug
        var loader = hxd.Res.initLocal();
        onPAKLoaded();
        #else
        var loader = hxd.Res.initPak();
        onPAKLoaded();
        #end
    }

    static function onPAKLoaded() {
        hxd.Timer.reset();
        inst = new Main();
    }
}