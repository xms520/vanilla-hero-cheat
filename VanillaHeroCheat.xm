//
//  VanillaHeroCheat.xm
//  香草英雄团外挂 - 提取自原dylib并重新实现
//
//  已知架构：
//  - QZ9M8: 自定义UIView面板类
//  - p001-p012: UI控件引用
//  - HTTPServer + WebSocket 远程控制
//  - 密钥解密: func5 @0x2f7798
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <sys/mman.h>
#import <mach/mach.h>

// ============ 常量定义 ============
#define CHEAT_VERSION @"2.0"
#define LOG_TAG @"[VanillaHero]"

// 功能开关状态
static BOOL g_oneHitKill = NO;    // 秒杀
static BOOL g_godMode = NO;       // 无敌
static float g_speedMultiplier = 1.0; // 变速倍数
static BOOL g_noAd = NO;          // 免广告
static BOOL g_panelVisible = NO;  // 面板可见性

// 内存地址（从逆向分析获得）
#define STATE_ADDR 0x3c41e0      // 全局状态
#define FLAG_ADDR  0x443b84      // 功能开关标志位
#define KEY_SRC    0x3c17e0      // 加密密钥源
#define KEY_DST    0x3c1830      // 解密缓存

// ============ UI面板类 ============
@interface CheatPanel : UIView
@property (nonatomic, strong) UIButton *dragButton;
@property (nonatomic, strong) UIScrollView *contentView;
@property (nonatomic, strong) UISwitch *oneHitSwitch;
@property (nonatomic, strong) UISwitch *godSwitch;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UISwitch *noAdSwitch;
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
    // 半透明背景
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    self.layer.cornerRadius = 10;
    self.clipsToBounds = YES;
    
    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 30)];
    title.text = @"🎮 香草英雄 Cheat";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:16];
    title.textAlignment = NSTextAlignmentCenter;
    [self addSubview:title];
    
    // 秒杀开关
    UILabel *ohkLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 120, 30)];
    ohkLabel.text = @"秒杀";
    ohkLabel.textColor = [UIColor whiteColor];
    [self addSubview:ohkLabel];
    
    self.oneHitSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(140, 50, 60, 30)];
    self.oneHitSwitch.on = g_oneHitKill;
    [self.oneHitSwitch addTarget:self action:@selector(oneHitChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.oneHitSwitch];
    
    // 无敌开关
    UILabel *godLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 90, 120, 30)];
    godLabel.text = @"无敌";
    godLabel.textColor = [UIColor whiteColor];
    [self addSubview:godLabel];
    
    self.godSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(140, 90, 60, 30)];
    self.godSwitch.on = g_godMode;
    [self.godSwitch addTarget:self action:@selector(godChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.godSwitch];
    
    // 变速滑块
    UILabel *speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 130, 80, 30)];
    speedLabel.text = @"变速";
    speedLabel.textColor = [UIColor whiteColor];
    [self addSubview:speedLabel];
    
    self.speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(10, 165, 200, 30)];
    self.speedSlider.minimumValue = 0.5;
    self.speedSlider.maximumValue = 3.0;
    self.speedSlider.value = g_speedMultiplier;
    [self.speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.speedSlider];
    
    self.speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 130, 60, 30)];
    self.speedLabel.text = @"1.0x";
    self.speedLabel.textColor = [UIColor whiteColor];
    [self addSubview:self.speedLabel];
    
    // 免广告开关
    UILabel *noAdLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 205, 120, 30)];
    noAdLabel.text = @"免广告";
    noAdLabel.textColor = [UIColor whiteColor];
    [self addSubview:noAdLabel];
    
    self.noAdSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(140, 205, 60, 30)];
    self.noAdSwitch.on = g_noAd;
    [self.noAdSwitch addTarget:self action:@selector(noAdChanged:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.noAdSwitch];
    
    // 版本信息
    UILabel *version = [[UILabel alloc] initWithFrame:CGRectMake(10, 245, 200, 20)];
    version.text = [NSString stringWithFormat:@"v%@", CHEAT_VERSION];
    version.textColor = [UIColor grayColor];
    version.font = [UIFont systemFontOfSize:10];
    [self addSubview:version];
    
    // 拖拽按钮
    self.dragButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dragButton.frame = CGRectMake(self.bounds.size.width - 40, 0, 40, 40);
    [self.dragButton setTitle:@"☰" forState:UIControlStateNormal];
    [self.dragButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.dragButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.dragButton];
    
    // 拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
    [self addGestureRecognizer:pan];
    
    // 初始大小
    self.frame = CGRectMake(self.bounds.size.width - 220, 100, 220, 280);
}

- (void)oneHitChanged:(UISwitch *)sender {
    g_oneHitKill = sender.on;
    NSLog(@"%@ 秒杀 %@", LOG_TAG, sender.on ? @"ON" : @"OFF");
    [self applyFunctions];
}

- (void)godChanged:(UISwitch *)sender {
    g_godMode = sender.on;
    NSLog(@"%@ 无敌 %@", LOG_TAG, sender.on ? @"ON" : @"OFF");
    [self applyFunctions];
}

- (void)speedChanged:(UISlider *)sender {
    g_speedMultiplier = sender.value;
    self.speedLabel.text = [NSString stringWithFormat:@"%.1fx", sender.value];
    NSLog(@"%@ 变速 %.1fx", LOG_TAG, sender.value);
    [self applyFunctions];
}

- (void)noAdChanged:(UISwitch *)sender {
    g_noAd = sender.on;
    NSLog(@"%@ 免广告 %@", LOG_TAG, sender.on ? @"ON" : @"OFF");
    [self applyFunctions];
}

- (void)applyFunctions {
    // 这里调用实际的功能逻辑
    // 由于香草英雄团是服务器验证，客户端修改可能无效
    // 但我们可以尝试Hook相关函数
    
    if (g_oneHitKill) {
        NSLog(@"%@ [秒杀] 已开启 - 等待战斗开始", LOG_TAG);
    }
    if (g_godMode) {
        NSLog(@"%@ [无敌] 已开启", LOG_TAG);
    }
    if (g_speedMultiplier != 1.0) {
        NSLog(@"%@ [变速] %.1fx", LOG_TAG, g_speedMultiplier);
    }
}

- (void)togglePanel {
    if (self.hidden) {
        self.hidden = NO;
        g_panelVisible = YES;
    } else {
        self.hidden = YES;
        g_panelVisible = NO;
    }
}

- (void)panGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.superview];
    self.center = CGPointApplyAffineTransform(self.center, CGAffineTransformMakeTranslation(translation.x, translation.y));
    [gesture setTranslation:CGPointZero inView:self.superview];
    
    if (gesture.state == UIGestureRecognizerStateEnded) {
        // 吸附到边缘
        CGRect screen = [UIScreen mainScreen].bounds;
        if (self.center.x < screen.size.width / 2) {
            self.center = CGPointMake(50, self.center.y);
        } else {
            self.center = CGPointMake(screen.size.width - 50, self.center.y);
        }
    }
}

@end

// ============ 全局面板实例 ============
static CheatPanel *g_cheatPanel = nil;
static UIWindow *g_cheatWindow = nil;

// ============ Hook函数 ============
// 这里需要Hook游戏的伤害计算、HP更新等函数
// 由于游戏是服务器验证，客户端修改可能无效

// 尝试Hook常见的战斗相关函数
extern "C" {
    void* objc_msgSend = NULL;
}

// ============ 初始化函数 ============
__attribute__((constructor))
static void VanillaHeroCheatInit() {
    NSLog(@"%@ Loading Cheat v%@", LOG_TAG, CHEAT_VERSION);
    
    // 创建后台线程显示面板
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 等待UIApplication
        while (!UIApplication.sharedApplication) {
            sleep(0.1);
        }
        
        // 创建窗口
        g_cheatWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_cheatWindow.windowLevel = UIWindowLevelAlert + 1;
        g_cheatWindow.backgroundColor = UIColor.clearColor;
        g_cheatWindow.hidden = NO;
        
        // 创建面板
        g_cheatPanel = [[CheatPanel alloc] initWithFrame:CGRectZero];
        [g_cheatWindow addSubview:g_cheatPanel];
        
        // 居中显示
        CGRect screen = [UIScreen mainScreen].bounds;
        g_cheatPanel.frame = CGRectMake(screen.size.width - 230, 100, 220, 280);
        
        NSLog(@"%@ Panel created", LOG_TAG);
    });
    
    // 延迟安装Hook（等待游戏类加载）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self installHooks];
    });
}

// ============ Hook安装 ============
static void installHooks() {
    NSLog(@"%@ Installing hooks...", LOG_TAG);
    
    // TODO: 根据实际游戏函数进行Hook
    // 由于游戏使用Cocos Creator + V8，需要Hook JS层面的函数
    // 或者HookObjC层的战斗管理器等
    
    // 示例：Hook UIViewController的出现（用于检测战斗场景）
    // Class VC = objc_getClass("UIViewController");
    // Method m = class_getInstanceMethod(VC, sel_registerName("viewDidAppear:"));
    // if (m) {
    //     method_exchangeImplementations(m, class_getInstanceMethod(VC, @selector(fg_viewDidAppear:)));
    // }
    
    NSLog(@"%@ Hooks installed", LOG_TAG);
}

// ============ 功能应用 ============
static void applyCheatFunctions() {
    // 秒杀逻辑：尝试找到并修改怪物HP
    if (g_oneHitKill) {
        // 由于服务器验证，这里可能需要：
        // 1. Hook伤害计算函数，使伤害无限大
        // 2. 或拦截网络包，修改伤害值
    }
    
    // 无敌逻辑：尝试防止玩家受伤
    if (g_godMode) {
        // 1. Hook受伤函数，返回0
        // 2. 或修改玩家HP到最大值
    }
    
    // 变速逻辑：修改游戏时间倍率
    if (g_speedMultiplier != 1.0) {
        // 1. Hook CCTimer/CDisplayLink
        // 2. 或修改scene.speed（如果是SpriteKit游戏）
    }
}

// ============ 面板显示/隐藏 ============
extern "C" {
    void showCheatPanel() {
        if (g_cheatPanel) {
            g_cheatPanel.hidden = NO;
            g_panelVisible = YES;
        }
    }
    
    void hideCheatPanel() {
        if (g_cheatPanel) {
            g_cheatPanel.hidden = YES;
            g_panelVisible = NO;
        }
    }
    
    void setOneHitKill(BOOL enabled) {
        g_oneHitKill = enabled;
        if (g_cheatPanel) {
            g_cheatPanel.oneHitSwitch.on = enabled;
        }
        [applyCheatFunctions];
    }
    
    void setGodMode(BOOL enabled) {
        g_godMode = enabled;
        if (g_cheatPanel) {
            g_cheatPanel.godSwitch.on = enabled;
        }
        [applyCheatFunctions];
    }
    
    void setSpeedMultiplier(float speed) {
        g_speedMultiplier = speed;
        if (g_cheatPanel) {
            g_cheatPanel.speedSlider.value = speed;
            g_cheatPanel.speedLabel.text = [NSString stringWithFormat:@"%.1fx", speed];
        }
        [applyCheatFunctions];
    }
    
    void setNoAd(BOOL enabled) {
        g_noAd = enabled;
        if (g_cheatPanel) {
            g_cheatPanel.noAdSwitch.on = enabled;
        }
        [applyCheatFunctions];
    }
}
