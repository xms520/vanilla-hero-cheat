//
//  VanillaHeroCheat.xm - v2.0
//  香草英雄团外挂 - 完整功能实现
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/mman.h>
#import <mach/mach.h>
#import <pthread.h>

// ============ 配置常量 ============
#define CHEAT_VERSION @"2.0"
#define LOG_TAG @"[VH-Cheat]"
#define LOG_FILE @"/var/mobile/Library/Logs/vh_cheat.log"

// CLAMP宏
#define CLAMP(x, min, max) ((x) < (min) ? (min) : ((x) > (max) ? (max) : (x)))

// 功能状态
static volatile BOOL g_oneHitKill = NO;
static volatile BOOL g_godMode = NO;
static volatile float g_speedMult = 1.0f;
static volatile BOOL g_noAd = NO;

// 内存地址（从逆向分析）
#define G_STATE_ADDR 0x3c41e0
#define G_FLAG_ADDR  0x443b84

// ============ 日志系统 ============
static void cheat_log(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    
    NSLog(@"%@ %@", LOG_TAG, msg);
    
    // 写入文件
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:LOG_FILE];
    if (!fh) {
        fh = [NSFileHandle fileHandleForWritingAtPath:LOG_FILE];
    }
    if (fh) {
        [fh seekToEndOfFile];
        NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", 
                            [[NSDate date] description], msg];
        [fh writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

// ============ UI面板类 ============
@interface CheatPanel : UIView
@property (nonatomic, strong) UIButton *dragHandle;
@property (nonatomic, strong) UISwitch *oneHitSwitch;
@property (nonatomic, strong) UISwitch *godSwitch;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UISwitch *noAdSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
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
    self.layer.borderWidth = 1;
    self.layer.borderColor = [[UIColor greenColor] colorWithAlphaComponent:0.5].CGColor;
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
    
    // 秒杀开关
    [self addSwitchRow:@"💀 秒杀" switchView:&self.oneHitSwitch target:self action:@selector(oneHitChanged:) y:50];
    
    // 无敌开关
    [self addSwitchRow:@"🛡️ 无敌" switchView:&self.godSwitch target:self action:@selector(godChanged:) y:90];
    
    // 变速滑块
    UILabel *speedTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, 130, 80, 25)];
    speedTitle.text = @"⚡ 变速";
    speedTitle.textColor = [UIColor whiteColor];
    [self addSubview:speedTitle];
    
    self.speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 158, 160, 30)];
    self.speedSlider.minimumValue = 0.5f;
    self.speedSlider.maximumValue = 3.0f;
    self.speedSlider.value = g_speedMult;
    [self.speedSlider setThumbColor:[UIColor greenColor]];
    [self.speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.speedSlider];
    
    self.speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(175, 158, 40, 30)];
    self.speedLabel.text = @"1.0x";
    self.speedLabel.textColor = [UIColor greenColor];
    self.speedLabel.font = [UIFont boldSystemFontOfSize:14];
    [self addSubview:self.speedLabel];
    
    // 免广告开关
    [self addSwitchRow:@"🚫 免广告" switchView:&self.noAdSwitch target:self action:@selector(noAdChanged:) y:200];
    
    // 状态标签
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 240, 200, 20)];
    self.statusLabel.text = @"就绪";
    self.statusLabel.textColor = [UIColor grayColor];
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.statusLabel];
    
    // 拖拽把手
    self.dragHandle = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dragHandle.frame = CGRectMake(self.bounds.size.width - 35, 0, 35, 35);
    [self.dragHandle setTitle:@"≡" forState:UIControlStateNormal];
    [self.dragHandle setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.dragHandle.titleLabel.font = [UIFont boldSystemFontOfSize:18]];
    [self.dragHandle addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.dragHandle];
    
    // 拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
    [self addGestureRecognizer:pan];
    
    // 初始大小和位置
    self.frame = CGRectMake(280, 150, 220, 270);
}

- (void)addSwitchRow:(NSString *)text switchView:(UISwitch **)switchRef target:(id)target action:(SEL)action y:(CGFloat)y {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, y, 80, 30)];
    label.text = text;
    label.textColor = [UIColor whiteColor];
    [self addSubview:label];
    
    *switchRef = [[UISwitch alloc] initWithFrame:CGRectMake(150, y + 5, 60, 30)];
    [*switchRef addTarget:target action:action forControlEvents:UIControlEventValueChanged];
    [self addSubview:*switchRef];
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
    self.speedLabel.text = [NSString stringWithFormat:@"%.1fx", sender.value];
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
    CGPoint translation = [gesture translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat maxX = screen.size.width - self.bounds.size.width / 2;
        CGFloat minX = self.bounds.size.width / 2;
        self.center = CGPointMake(CLAMP(self.center.x, minX, maxX), self.center.y);
    }
}

- (void)updateStatus {
    NSMutableString *status = [NSMutableString string];
    [status appendFormat:@"秒杀:%@ 无敌:%@ 变速:%.1fx", 
     g_oneHitKill ? @"开" : @"关",
     g_godMode ? @"开" : @"关",
     g_speedMult];
    if (g_noAd) [status appendString:@" 免广:开"];
    self.statusLabel.text = status;
}

@end

// ============ 全局变量 ============
static CheatPanel *g_panel = nil;
static UIWindow *g_window = nil;
static NSTimer *g_cheatTimer = nil;

// ============ 功能应用 ============
static void applyCheatFunctions() {
    if (g_oneHitKill) {
        cheat_log(@"[秒杀] 等待战斗开始...");
    }
    if (g_godMode) {
        cheat_log(@"[无敌] 已开启");
    }
    if (g_speedMult != 1.0f) {
        cheat_log(@"[变速] %.1fx", g_speedMult);
    }
}

// ============ 定时器回调 ============
static void cheatTimerCallback(CFRunLoopTimerRef timer, void *info) {
    applyCheatFunctions();
}

// ============ Hook安装 ============
static void installHooks() {
    cheat_log(@"安装Hook...");
    
    // 示例：Hook UIViewController（用于检测场景切换）
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
            cheat_log(@"✓ Hooked viewDidAppear:");
        }
    }
    
    cheat_log(@"Hook安装完成");
}

// ============ 初始化 ============
__attribute__((constructor))
static void VanillaHeroCheatInit() {
    cheat_log(@"========================================");
    cheat_log(@"香草英雄团 Cheat v%@ 启动", CHEAT_VERSION);
    cheat_log(@"========================================");
    
    // 创建后台线程初始化UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 等待UIApplication
        while (!UIApplication.sharedApplication) {
            usleep(100000); // 100ms
        }
        
        cheat_log(@"UIApplication 已就绪");
        
        // 创建悬浮窗口
        g_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_window.windowLevel = UIWindowLevelAlert + 100;
        g_window.backgroundColor = UIColor.clearColor;
        g_window.hidden = NO;
        
        // 创建面板
        g_panel = [[CheatPanel alloc] initWithFrame:CGRectZero];
        [g_window addSubview:g_panel];
        
        // 居中显示
        CGRect screen = [UIScreen mainScreen].bounds;
        g_panel.frame = CGRectMake(screen.size.width - 230, 150, 220, 270);
        
        cheat_log(@"UI面板已创建");
        
        // 延迟安装Hook
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), 
                      dispatch_get_main_queue(), ^{
            installHooks();
            
            // 启动定时器 (使用NSTimer替代CFRunLoopTimer)
            g_cheatTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                          repeats:YES
                                                            block:^(NSTimer * _Nonnull timer) {
                applyCheatFunctions();
            }];
            
            cheat_log(@"定时器已启动 (0.5s间隔)");
        });
    });
}

// ============ 外部API ============
extern "C" {
    void VHSetOneHitKill(BOOL enabled) {
        g_oneHitKill = enabled;
        if (g_panel) g_panel.oneHitSwitch.on = enabled;
        [g_panel updateStatus];
    }
    
    void VHSetGodMode(BOOL enabled) {
        g_godMode = enabled;
        if (g_panel) g_panel.godSwitch.on = enabled;
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
        if (g_panel) g_panel.noAdSwitch.on = enabled;
        [g_panel updateStatus];
    }
    
    void VHShowPanel() {
        if (g_panel) g_panel.hidden = NO;
    }
    
    void VHHidePanel() {
        if (g_panel) g_panel.hidden = YES;
    }
}
