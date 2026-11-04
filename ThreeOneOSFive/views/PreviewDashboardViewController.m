#import "PreviewDashboardViewController.h"

@interface PreviewDashboardViewController ()
@property (nonatomic, assign) BOOL aimbotMode;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, assign) NSInteger selectedGame;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *toggleValues;
@property (nonatomic, strong) NSMutableArray<UIButton *> *gameButtons;
@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong) UIColor *cardColor;
@end

@implementation PreviewDashboardViewController

- (instancetype)initWithAimbotMode:(BOOL)aimbotMode {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _aimbotMode = aimbotMode;
        _selectedGame = 0;
        _toggleValues = aimbotMode
            ? [@[@NO, @NO, @NO, @NO, @NO, @YES] mutableCopy]
            : [@[@NO, @YES, @YES, @NO, @NO] mutableCopy];
        _gameButtons = [NSMutableArray array];
        _accentColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.19 alpha:1.0];
        _cardColor = [UIColor colorWithRed:0.075 green:0.075 blue:0.085 alpha:1.0];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.025 green:0.025 blue:0.03 alpha:1.0];
    [self buildInterface];
}

- (void)buildInterface {
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];
    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];

    self.contentStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.spacing = 17.0;
    [self.scrollView addSubview:self.contentStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:self.aimbotMode ? 22.0 : 8.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:16.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-16.0],
        [self.contentStack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32.0]
    ]];

    if (!self.aimbotMode) {
        [self.contentStack addArrangedSubview:[self heroView]];
    }
    [self.contentStack addArrangedSubview:[self gameSelectorView]];
    [self.contentStack addArrangedSubview:[self featureSectionView]];
    if (!self.aimbotMode) {
        UILabel *vipLabel = [self sectionLabel:@"VIP MODS"];
        [self.contentStack addArrangedSubview:vipLabel];
    }
}

- (UIView *)heroView {
    UIView *hero = [[UIView alloc] initWithFrame:CGRectZero];
    hero.translatesAutoresizingMaskIntoConstraints = NO;
    hero.clipsToBounds = YES;
    hero.layer.cornerRadius = 21.0;

    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"LiveHeroBackground"]];
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    [hero addSubview:imageView];
    UIView *shade = [[UIView alloc] initWithFrame:CGRectZero];
    shade.translatesAutoresizingMaskIntoConstraints = NO;
    shade.backgroundColor = [UIColor colorWithWhite:0 alpha:0.43];
    [hero addSubview:shade];

    UIStackView *textStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    textStack.translatesAutoresizingMaskIntoConstraints = NO;
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.alignment = UIStackViewAlignmentLeading;
    textStack.distribution = UIStackViewDistributionEqualSpacing;
    [hero addSubview:textStack];

    UIView *livePill = [[UIView alloc] initWithFrame:CGRectZero];
    livePill.translatesAutoresizingMaskIntoConstraints = NO;
    livePill.backgroundColor = self.accentColor;
    livePill.layer.cornerRadius = 15.0;
    UIView *dot = [[UIView alloc] initWithFrame:CGRectZero];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = UIColor.whiteColor;
    dot.layer.cornerRadius = 3.5;
    UILabel *live = [self whiteLabel:@"LIVE" size:11 weight:UIFontWeightHeavy];
    [livePill addSubview:dot];
    [livePill addSubview:live];
    [NSLayoutConstraint activateConstraints:@[
        [livePill.heightAnchor constraintEqualToConstant:30],
        [dot.leadingAnchor constraintEqualToAnchor:livePill.leadingAnchor constant:12],
        [dot.centerYAnchor constraintEqualToAnchor:livePill.centerYAnchor],
        [dot.widthAnchor constraintEqualToConstant:7],
        [dot.heightAnchor constraintEqualToConstant:7],
        [live.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:6],
        [live.trailingAnchor constraintEqualToAnchor:livePill.trailingAnchor constant:-12],
        [live.centerYAnchor constraintEqualToAnchor:livePill.centerYAnchor]
    ]];

    UILabel *title = [self whiteLabel:@"ROBOT EXTERNAL" size:22 weight:UIFontWeightHeavy];
    title.adjustsFontSizeToFitWidth = YES;
    title.minimumScaleFactor = 0.8;
    [textStack addArrangedSubview:livePill];
    [textStack addArrangedSubview:title];
    [NSLayoutConstraint activateConstraints:@[
        [hero.heightAnchor constraintEqualToConstant:150],
        [imageView.topAnchor constraintEqualToAnchor:hero.topAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor],
        [shade.topAnchor constraintEqualToAnchor:hero.topAnchor],
        [shade.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor],
        [shade.trailingAnchor constraintEqualToAnchor:hero.trailingAnchor],
        [shade.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor],
        [textStack.topAnchor constraintEqualToAnchor:hero.topAnchor constant:16],
        [textStack.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor constant:16],
        [textStack.trailingAnchor constraintLessThanOrEqualToAnchor:hero.trailingAnchor constant:-16],
        [textStack.bottomAnchor constraintEqualToAnchor:hero.bottomAnchor constant:-16]
    ]];
    return hero;
}

- (UIView *)gameSelectorView {
    UIView *selector = [[UIView alloc] initWithFrame:CGRectZero];
    selector.translatesAutoresizingMaskIntoConstraints = NO;
    selector.backgroundColor = self.cardColor;
    selector.layer.cornerRadius = 16.0;
    selector.clipsToBounds = YES;

    UIStackView *buttons = [[UIStackView alloc] initWithFrame:CGRectZero];
    buttons.translatesAutoresizingMaskIntoConstraints = NO;
    buttons.axis = UILayoutConstraintAxisHorizontal;
    buttons.distribution = UIStackViewDistributionFillEqually;
    [selector addSubview:buttons];
    [self.gameButtons removeAllObjects];
    NSArray<NSString *> *titles = @[@"Free Fire", @"Free Fire MAX"];
    for (NSInteger index = 0; index < titles.count; index++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = index;
        button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        [button setTitle:titles[index] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(gameSelected:) forControlEvents:UIControlEventTouchUpInside];
        [buttons addArrangedSubview:button];
        [self.gameButtons addObject:button];
        if (index == 0) {
            UIView *separator = [[UIView alloc] initWithFrame:CGRectZero];
            separator.translatesAutoresizingMaskIntoConstraints = NO;
            separator.backgroundColor = [UIColor colorWithWhite:1 alpha:0.045];
            [selector addSubview:separator];
            [NSLayoutConstraint activateConstraints:@[
                [separator.widthAnchor constraintEqualToConstant:1],
                [separator.heightAnchor constraintEqualToConstant:34],
                [separator.centerXAnchor constraintEqualToAnchor:selector.centerXAnchor],
                [separator.centerYAnchor constraintEqualToAnchor:selector.centerYAnchor]
            ]];
        }
    }
    [NSLayoutConstraint activateConstraints:@[
        [selector.heightAnchor constraintEqualToConstant:48],
        [buttons.topAnchor constraintEqualToAnchor:selector.topAnchor],
        [buttons.leadingAnchor constraintEqualToAnchor:selector.leadingAnchor],
        [buttons.trailingAnchor constraintEqualToAnchor:selector.trailingAnchor],
        [buttons.bottomAnchor constraintEqualToAnchor:selector.bottomAnchor]
    ]];
    [self updateGameButtons];
    return selector;
}

- (void)gameSelected:(UIButton *)sender {
    self.selectedGame = sender.tag;
    [self updateGameButtons];
}

- (void)updateGameButtons {
    [self.gameButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop) {
        UIColor *color = (NSInteger)idx == self.selectedGame ? self.accentColor : [UIColor colorWithWhite:0.62 alpha:1];
        [button setTitleColor:color forState:UIControlStateNormal];
        button.accessibilityTraits = (NSInteger)idx == self.selectedGame ? UIAccessibilityTraitSelected : UIAccessibilityTraitButton;
    }];
}

- (UIView *)featureSectionView {
    UIStackView *section = [[UIStackView alloc] initWithFrame:CGRectZero];
    section.axis = UILayoutConstraintAxisVertical;
    section.alignment = UIStackViewAlignmentFill;
    section.spacing = self.aimbotMode ? 10.0 : 9.0;

    UILabel *heading = [self sectionLabel:self.aimbotMode ? @"ESP" : @"BRUTAL FEATURES"];
    heading.layoutMargins = UIEdgeInsetsMake(0, 4, 1, 4);
    [section addArrangedSubview:heading];

    NSArray<NSString *> *titles = self.aimbotMode
        ? @[@"MENU", @"ONLY ESP", @"VIP MOD MENU", @"AIM SILENT + ESP", @"AIMBOT+ESP ALL +144 FPS", @"AIMBOT"]
        : @[@"BODY HS", @"NECK HS", @"DRAG HS", @"CHEST HS", @"MAGIC BULLET"];
    for (NSUInteger index = 0; index < titles.count; index++) {
        [section addArrangedSubview:[self featureRow:titles[index] index:index]];
    }
    return section;
}

- (UIView *)featureRow:(NSString *)title index:(NSUInteger)index {
    UIView *row = [[UIView alloc] initWithFrame:CGRectZero];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.backgroundColor = self.cardColor;
    row.layer.cornerRadius = 16.0;

    UILabel *label = [self whiteLabel:title size:15 weight:UIFontWeightSemibold];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.8;
    label.numberOfLines = 1;
    [row addSubview:label];

    UIButton *toggle = [UIButton buttonWithType:UIButtonTypeCustom];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.tag = (NSInteger)index;
    toggle.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:1];
    toggle.layer.cornerRadius = 15.0;
    toggle.clipsToBounds = YES;
    toggle.accessibilityLabel = title;
    toggle.accessibilityHint = @"Controle apenas visual de prévia";
    [toggle addTarget:self action:@selector(togglePressed:) forControlEvents:UIControlEventTouchUpInside];
    [row addSubview:toggle];

    UIView *knob = [[UIView alloc] initWithFrame:CGRectZero];
    knob.translatesAutoresizingMaskIntoConstraints = NO;
    knob.tag = 728;
    knob.backgroundColor = [self.toggleValues[index] boolValue] ? UIColor.whiteColor : [UIColor colorWithWhite:0.61 alpha:1];
    knob.layer.cornerRadius = 12.0;
    [toggle addSubview:knob];

    NSLayoutConstraint *knobLeft = [knob.leadingAnchor constraintEqualToAnchor:toggle.leadingAnchor constant:3];
    NSLayoutConstraint *knobRight = [knob.trailingAnchor constraintEqualToAnchor:toggle.trailingAnchor constant:-3];
    knobLeft.identifier = @"previewKnobLeft";
    knobRight.identifier = @"previewKnobRight";
    knobLeft.active = ![self.toggleValues[index] boolValue];
    knobRight.active = [self.toggleValues[index] boolValue];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:62],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:16],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [label.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-12],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-16],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [toggle.widthAnchor constraintEqualToConstant:48],
        [toggle.heightAnchor constraintEqualToConstant:30],
        [knob.widthAnchor constraintEqualToConstant:24],
        [knob.heightAnchor constraintEqualToConstant:24],
        [knob.centerYAnchor constraintEqualToAnchor:toggle.centerYAnchor]
    ]];
    return row;
}

- (void)togglePressed:(UIButton *)sender {
    NSUInteger index = (NSUInteger)sender.tag;
    if (index >= self.toggleValues.count) { return; }
    BOOL enabled = ![self.toggleValues[index] boolValue];
    self.toggleValues[index] = @(enabled);
    UIView *knob = [sender viewWithTag:728];
    NSLayoutConstraint *left = nil;
    NSLayoutConstraint *right = nil;
    for (NSLayoutConstraint *constraint in sender.constraints) {
        if ([constraint.identifier isEqualToString:@"previewKnobLeft"]) { left = constraint; }
        if ([constraint.identifier isEqualToString:@"previewKnobRight"]) { right = constraint; }
    }
    // Constraints are owned by the button's layout context; update by replacing the active edge.
    if (left && right) {
        left.active = !enabled;
        right.active = enabled;
    }
    knob.backgroundColor = enabled ? UIColor.whiteColor : [UIColor colorWithWhite:0.61 alpha:1];
    sender.accessibilityValue = enabled ? @"Ligado" : @"Desligado";
    [UIView animateWithDuration:0.18 animations:^{ [sender layoutIfNeeded]; }];
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.font = [UIFont systemFontOfSize:11 weight:UIFontWeightHeavy];
    label.textColor = self.accentColor;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UILabel *)whiteLabel:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

@end
