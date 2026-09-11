//
//  VanillaHeroCheat.xm - v2.0
//  香草英雄团外挂
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============ 配置 ============
#define CHEAT_VERSION @"2.0"
#define LOG_TAG @"[VH-Cheat]"
#define LOG_FILE @"/var/mobile/Library/Logs/vh_cheat.log"

#define CLAMP(x, min, max) ((x) < (min) ? (min) : ((x) > (max) ? (max) : (x)))

// ============ 全局状态 ============
static BOOL g_oneHitKill = NO;
static BOOL g_godMode = NO;
static float g_speedMult = 1.0f;
static BOOL g_noAd = NO;

// ============ 日志 ============
static void cheat_log(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"%@ %@", LOG_TAG, msg);
    
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:LOG_FILE];
    if (!fh) fh = [NSFileHandle fileHandleForWritingAtPath:LOG_FILE];
    if (fh) {
        [fh seekToEndOfFile];
        [fh writeData:[NSString stringWithFormat:@"[%@] %@\n", [[NSDate date] description], msg] dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

// ============ UI面板 ============
@interface CheatPanel : UIView
@property (nonatomic, strong) UIButton *dragBtn;
@property (nonatomic, strong) UISwitch *oneHitSw;
@property (nonatomic, strong) UISwitch *godSw;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLbl;
@property (nonatomic, strong) UISwitch *noAdSw;
@property (nonatomic, strong) UILabel *statusLbl;
@end

@implementation CheatPanel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.layer.cornerRadius = 12;
    self.clipsToBounds = YES;
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 200, 28)];
    title.text = @"🎮 香草英雄 v2.0";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:14];
    title.textAlignment = NSTextAlignmentCenter;
    [self addSubview:title];
    
    // 分隔线
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(10, 38, self.bounds.size.width - 20, 1)];
    line.backgroundColor = [UIColor grayColor];
    [self addSubview:line];
    
    // 秒杀
    UILabel *ohkL = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 80, 30)];
    ohkL.text = @"💀 秒杀";
    ohkL.textColor = [UIColor whiteColor];
    [self addSubview:ohkL];
    
    UISwitch *ohkS = [[UISwitch alloc] initWithFrame:CGRectMake(150, 55, 60, 30)];
    ohkS.on = g_oneHitKill;
    [ohkS addTarget:self action:@selector(oneHitChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:ohkS];
    _oneHitSw = ohkS;
    
    // 无敌
    UILabel *godL = [[UILabel alloc] initWithFrame:CGRectMake(10, 90, 80, 30)];
    godL.text = @"🛡️ 无敌";
    godL.textColor = [UIColor whiteColor];
    [self addSubview:godL];
    
    UISwitch *godS = [[UISwitch alloc] initWithFrame:CGRectMake(150, 95, 60, 30)];
    godS.on = g_godMode;
    [godS addTarget:self action:@selector(godChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:godS];
    _godSw = godS;
    
    // 变速
    UILabel *spdL = [[UILabel alloc] initWithFrame:CGRectMake(10, 130, 80, 25)];
    spdL.text = @"⚡ 变速";
    spdL.textColor = [UIColor whiteColor];
    [self addSubview:spdL];
    
    UISlider *spdSl = [[UISlider alloc] initWithFrame:CGRectMake(10, 158, 160, 30)];
    spdSl.minimumValue = 0.5f;
    spdSl.maximumValue = 3.0f;
    spdSl.value = g_speedMult;
    [spdSl addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:spdSl];
    _speedSlider = spdSl;
    
    UILabel *spdLbl = [[UILabel alloc] initWithFrame:CGRectMake(175, 158, 40, 30)];
    spdLbl.text = @"1.0x";
    spdLbl.textColor = [UIColor greenColor];
    spdLbl.font = [UIFont boldSystemFontOfSize:14];
    [self addSubview:spdLbl];
    _speedLbl = spdLbl;
    
    // 免广告
    UILabel *adL = [[UILabel alloc] initWithFrame:CGRectMake(10, 200, 80, 30)];
    adL.text = @"🚫 免广告";
    adL.textColor = [UIColor whiteColor];
    [self addSubview:adL];
    
    UISwitch *adS = [[UISwitch alloc] initWithFrame:CGRectMake(150, 205, 60, 30)];
    adS.on = g_noAd;
    [adS addTarget:self action:@selector(noAdChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:adS];
    _noAdSw = adS;
    
    // 状态
    UILabel *stL = [[UILabel alloc] initWithFrame:CGRectMake(10, 240, 200, 20)];
    stL.text = @"就绪";
    stL.textColor = [UIColor grayColor];
    stL.font = [UIFont systemFontOfSize:10];
    stL.textAlignment = NSTextAlignmentCenter;
    [self addSubview:stL];
    _statusLbl = stL;
    
    // 拖拽按钮
    UIButton *drag = [UIButton buttonWithType:UIButtonTypeSystem];
    drag.frame = CGRectMake(self.bounds.size.width - 35, 0, 35, 35);
    [drag setTitle:@"≡" forState:UIControlStateNormal];
    [drag setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [drag.titleLabel setFont:[UIFont boldSystemFontOfSize:18]];
    [drag addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:drag];
    _dragBtn = drag;
    
    // 拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
    [self addGestureRecognizer:pan];
    
    self.frame = CGRectMake(280, 150, 220, 270);
}

- (void)oneHitChanged:(UISwitch *)sender {
    g_oneHitKill = sender.on;
    cheat_log(@"秒杀 %@", sender.on ? @"ON" : @"OFF");
    [self updateStatus];
}

- (void)godChanged:(UISwitch *)sender {
    g_godMode = sender.on;
    cheat_log(@"无敌 %@", sender.on ? @"ON" : @"OFF");
    [self updateStatus];
}

- (void)speedChanged:(UISlider *)sender {
    g_speedMult = sender.value;
    _speedLbl.text = [NSString stringWithFormat:@"%.1fx", sender.value];
    cheat_log(@"变速 %.1fx", sender.value);
    [self updateStatus];
}

- (void)noAdChanged:(UISwitch *)sender {
    g_noAd = sender.on;
    cheat_log(@"免广告 %@", sender.on ? @"ON" : @"OFF");
    [self updateStatus];
}

- (void)togglePanel {
    self.hidden = !self.hidden;
}

- (void)panGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint t = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat maxX = screen.size.width - self.bounds.size.width / 2;
        CGFloat minX = self.bounds.size.width / 2;
        self.center = CGPointMake(CLAMP(self.center.x, minX, maxX), self.center.y);
    }
}

- (void)updateStatus {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"秒杀:%@ 无敌:%@ 变速:%.1fx", 
     g_oneHitKill ? @"开" : @"关",
     g_godMode ? @"开" : @"关",
     g_speedMult];
    if (g_noAd) [s appendString:@" 免广:开"];
    _statusLbl.text = s;
}

@end

// ============ 全局 ============
static CheatPanel *g_panel = nil;
static UIWindow *g_window = nil;

// ============ 功能 ============
static void applyCheatFunctions() {
    if (g_oneHitKill) cheat_log(@"[秒杀] 激活");
    if (g_godMode) cheat_log(@"[无敌] 激活");
    if (g_speedMult != 1.0f) cheat_log(@"[变速] %.1fx", g_speedMult);
}

// ============ Hook ============
static void installHooks() {
    cheat_log(@"安装Hook...");
    
    Class VC = objc_getClass("UIViewController");
    if (VC) {
        Method m = class_getInstanceMethod(VC, sel_registerName("viewDidAppear:"));
        if (m) {
            IMP orig = method_getImplementation(m);
            IMP new_imp = imp_implementationWithBlock(^(id self, SEL _cmd, BOOL animated) {
                cheat_log(@"[VC] viewDidAppear: %@", NSStringFromClass([self class]));
                ((void(*)(id, SEL, BOOL))orig)(self, _cmd, animated);
            });
            method_setImplementation(m, new_imp);
        }
    }
    cheat_log(@"Hook完成");
}

// ============ 初始化 ============
__attribute__((constructor))
static void VanillaHeroCheatInit() {
    cheat_log(@"========================================");
    cheat_log(@"香草英雄团 Cheat v%@ 启动", CHEAT_VERSION);
    cheat_log(@"========================================");
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (!UIApplication.sharedApplication) {
            usleep(100000);
        }
        
        g_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_window.windowLevel = UIWindowLevelAlert + 100;
        g_window.backgroundColor = UIColor.clearColor;
        g_window.hidden = NO;
        
        g_panel = [[CheatPanel alloc] initWithFrame:CGRectZero];
        [g_window addSubview:g_panel];
        
        CGRect screen = [UIScreen mainScreen].bounds;
        g_panel.frame = CGRectMake(screen.size.width - 230, 150, 220, 270);
        
        cheat_log(@"UI面板已创建");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), 
                      dispatch_get_main_queue(), ^{
            installHooks();
            
            [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
                applyCheatFunctions();
            }];
            
            cheat_log(@"定时器已启动");
        });
    });
}

// ============ API ============
extern "C" {
    void VHSetOneHitKill(BOOL enabled) {
        g_oneHitKill = enabled;
        if (g_panel) g_panel.oneHitSw.on = enabled;
        [g_panel updateStatus];
    }
    void VHSetGodMode(BOOL enabled) {
        g_godMode = enabled;
        if (g_panel) g_panel.godSw.on = enabled;
        [g_panel updateStatus];
    }
    void VHSetSpeed(float speed) {
        g_speedMult = speed;
        if (g_panel) {
            g_panel.speedSlider.value = speed;
            [g_panel updateStatus];
        }
    }
    void VHSetNoAd(BOOL enabled) {
        g_noAd = enabled;
        if (g_panel) g_panel.noAdSw.on = enabled;
        [g_panel updateStatus];
    }
    void VHShowPanel() {
        if (g_panel) g_panel.hidden = NO;
    }
    void VHHidePanel() {
        if (g_panel) g_panel.hidden = YES;
    }
}
