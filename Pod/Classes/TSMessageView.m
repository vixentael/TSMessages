//
//  TSMessageView.m
//  Felix Krause
//
//  Created by Felix Krause on 24.08.12.
//  Copyright (c) 2012 Felix Krause. All rights reserved.
//

#import "TSMessageView.h"
#import "HexColors.h"
#import "TSBlurView.h"
#import "TSMessage.h"
#import "TSMessageContentView.h"

#define TSMessageViewMinimumPadding 15.0

#define TSDesignFileName @"TSMessagesDefaultDesign"

static NSMutableDictionary *_notificationDesign;

@interface TSMessage (TSMessageView)
- (void)fadeOutNotification:(TSMessageView *)currentView; // private method of TSMessage, but called by TSMessageView in -[fadeMeOut]
@end

@interface TSMessageView () <UIGestureRecognizerDelegate>

/** The displayed title of this message */
@property (nonatomic, strong) NSString *title;

/** The displayed subtitle of this message view */
@property (nonatomic, strong) NSString *subtitle;

/** The title of the added button */
@property (nonatomic, strong) NSString *buttonTitle;

/** The view controller this message is displayed in */
@property (nonatomic, strong) UIViewController *viewController;


/** Internal properties needed to resize the view on device rotation properly */
@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) TSMessageContentView * contentView;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIImage *buttonImage;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) TSBlurView *backgroundBlurView; // Only used in iOS 7

@property (nonatomic, assign) BOOL iconOnTheRight;

@property (copy) void (^callback)();
@property (copy) void (^buttonCallback)();

- (CGFloat)updateHeightOfMessageView;
- (void)layoutSubviews;

@end


@implementation TSMessageView{
    TSMessageNotificationType notificationType;
}

- (TSMessageNotificationType *)messageViewNotificationType {
    return notificationType;
}


-(void) setContentFont:(UIFont *)contentFont{
    _contentFont = contentFont;
    [self.contentView setContentFont:contentFont];
}

-(void) setContentTextColor:(UIColor *)contentTextColor{
    _contentTextColor = contentTextColor;
    [self.contentView setContentTextColor:_contentTextColor];
}

-(void) setTitleFont:(UIFont *)aTitleFont{
    _titleFont = aTitleFont;
    [self.titleLabel setFont:_titleFont];
}

-(void)setTitleTextColor:(UIColor *)aTextColor{
    _titleTextColor = aTextColor;
    [self.titleLabel setTextColor:_titleTextColor];
}

-(void) setMessageIcon:(UIImage *)messageIcon{
    _messageIcon = messageIcon;
    [self updateCurrentIcon];
}

-(void) setErrorIcon:(UIImage *)errorIcon{
    _errorIcon = errorIcon;
    [self updateCurrentIcon];
}

-(void) setSuccessIcon:(UIImage *)successIcon{
    _successIcon = successIcon;
    [self updateCurrentIcon];
}

-(void) setWarningIcon:(UIImage *)warningIcon{
    _warningIcon = warningIcon;
    [self updateCurrentIcon];
}

-(void) updateCurrentIcon{
    UIImage *image = nil;
    switch (notificationType)
    {
        case TSMessageNotificationTypeMessage:
        {
            image = _messageIcon;
            self.iconImageView.image = _messageIcon;
            break;
        }
        case TSMessageNotificationTypeError:
        {
            image = _errorIcon;
            self.iconImageView.image = _errorIcon;
            break;
        }
        case TSMessageNotificationTypeSuccess:
        {
            image = _successIcon;
            self.iconImageView.image = _successIcon;
            break;
        }
        case TSMessageNotificationTypeWarning:
        {
            image = _warningIcon;
            self.iconImageView.image = _warningIcon;
            break;
        }
        default:
            break;
    }
    self.iconImageView.frame = CGRectMake(self.padding * 2,
                                          self.padding,
                                          image.size.width,
                                          image.size.height);
}




+ (NSMutableDictionary *)notificationDesign
{
    if (!_notificationDesign)
    {
        NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:TSDesignFileName ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSAssert(data != nil, @"Could not read TSMessages config file from main bundle with name %@.json", TSDesignFileName);

        _notificationDesign = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization JSONObjectWithData:data
                                                                                                            options:kNilOptions
                                                                                                              error:nil]];
    }

    return _notificationDesign;
}


+ (void)addNotificationDesignFromFile:(NSString *)filename
{
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        NSDictionary *design = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                                               options:kNilOptions
                                                                 error:nil];

        [[TSMessageView notificationDesign] addEntriesFromDictionary:design];
    }
    else
    {
        NSAssert(NO, @"Error loading design file with name %@", filename);
    }
}

- (CGFloat)padding
{
    // Adds 10 padding to to cover navigation bar
    return self.messagePosition == TSMessageNotificationPositionNavBarOverlay ? TSMessageViewMinimumPadding + 10.0f : TSMessageViewMinimumPadding;
}

- (id)initWithTitle:(NSString *)title
           subtitle:(NSString *)subtitle
              image:(UIImage *)image
               type:(TSMessageNotificationType)aNotificationType
           duration:(CGFloat)duration
   inViewController:(UIViewController *)viewController
           callback:(void (^)())callback
        buttonTitle:(NSString *)buttonTitle
        buttonImage:(UIImage *)buttonImage
     buttonCallback:(void (^)())buttonCallback
         atPosition:(TSMessageNotificationPosition)position
canBeDismissedByUser:(BOOL)dismissingEnabled
{
    NSDictionary *notificationDesign = [TSMessageView notificationDesign];

    if ((self = [self init]))
    {
        _title = title;
        _subtitle = subtitle;
        _buttonTitle = buttonTitle;
        _duration = duration;
        _viewController = viewController;
        _messagePosition = position;
        _buttonImage = buttonImage;
        self.callback = callback;
        self.buttonCallback = buttonCallback;

        CGFloat screenWidth = self.viewController.view.bounds.size.width;
        CGFloat padding = [self padding];

        NSDictionary *current;
        NSString *currentString;
        notificationType = aNotificationType;
        switch (notificationType)
        {
            case TSMessageNotificationTypeMessage:
            {
                currentString = @"message";
                break;
            }
            case TSMessageNotificationTypeError:
            {
                currentString = @"error";
                break;
            }
            case TSMessageNotificationTypeSuccess:
            {
                currentString = @"success";
                break;
            }
            case TSMessageNotificationTypeWarning:
            {
                currentString = @"warning";
                break;
            }

            default:
                break;
        }

        current = [notificationDesign valueForKey:currentString];
        self.iconOnTheRight = [current[@"iconOnRight"] boolValue];

        if (!buttonImage && !image && [[current valueForKey:@"imageName"] length])
        {
            image = [self bundledImageNamed:[current valueForKey:@"imageName"]];
        }
        if (!buttonImage && !image && [[current valueForKey:@"imageName"] length])
        {
            image = [UIImage imageNamed:[current valueForKey:@"imageName"]];
        }

        if (![TSMessage iOS7StyleEnabled] || [TSMessage useBackgroundImageInsteadOfBlur])
        {
            self.alpha = [TSMessage useBackgroundImageInsteadOfBlur] ? 1.0 : 0.0;
            
            // add background image here
            UIImage *backgroundImage = [self bundledImageNamed:[current valueForKey:@"backgroundImageName"]];
            backgroundImage = [backgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 10, 0)];
            
            _backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
            self.backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:self.backgroundImageView];
        }
        else
        {
            // On iOS 7 and above use a blur layer instead (not yet finished)
            _backgroundBlurView = [[TSBlurView alloc] init];
            self.backgroundBlurView.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
            self.backgroundBlurView.blurTintColor = [UIColor hx_colorWithHexString:current[@"backgroundColor"]];
            [self addSubview:self.backgroundBlurView];
        }

        UIColor *fontColor = [UIColor hx_colorWithHexString:[current valueForKey:@"textColor"]];

        

        self.textSpaceLeft = padding;

        if (image) {
            if (self.iconOnTheRight) {
                self.textSpaceRight = image.size.width + 2 * padding;
            } else {
                self.textSpaceLeft = image.size.width + 2 * padding;
            }
        }

        // Set up title label
        _titleLabel = [[UILabel alloc] init];
        [self.titleLabel setText:title];
        [self.titleLabel setTextColor:fontColor];
        [self.titleLabel setBackgroundColor:[UIColor clearColor]];
        CGFloat fontSize = [[current valueForKey:@"titleFontSize"] floatValue];
        NSString *fontName = [current valueForKey:@"titleFontName"];
        if (fontName != nil) {
            [self.titleLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
        } else {
            [self.titleLabel setFont:[UIFont boldSystemFontOfSize:fontSize]];
        }
        [self.titleLabel setShadowColor:[UIColor hx_colorWithHexString:[current valueForKey:@"shadowColor"]]];
        [self.titleLabel setShadowOffset:CGSizeMake([[current valueForKey:@"shadowOffsetX"] floatValue],
                                                    [[current valueForKey:@"shadowOffsetY"] floatValue])];

        self.titleLabel.numberOfLines = 0;
        self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:self.titleLabel];

        if (image)
        {
            _iconImageView = [[UIImageView alloc] initWithImage:image];
            self.iconImageView.frame = CGRectMake(0,
                                                  0,
                                                  image.size.width,
                                                  image.size.height);
            [self addSubview:self.iconImageView];
        }

        // Set up button (if set)
        if ([buttonTitle length] || buttonImage)
        {
            _button = [UIButton buttonWithType:UIButtonTypeCustom];

            if ( buttonImage && buttonTitle.length == 0 ) {
                [self.button setImage:buttonImage forState:UIControlStateNormal];
            } else {
                UIImage *buttonBackgroundImage = [self bundledImageNamed:[current valueForKey:@"buttonBackgroundImageName"]];

                buttonBackgroundImage = [buttonBackgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(15.0, 12.0, 15.0, 11.0)];

                if (!buttonBackgroundImage)
                {
                    buttonBackgroundImage = [self bundledImageNamed:[current valueForKey:@"NotificationButtonBackground"]];
                    buttonBackgroundImage = [buttonBackgroundImage resizableImageWithCapInsets:UIEdgeInsetsMake(15.0, 12.0, 15.0, 11.0)];
                }

                [self.button setBackgroundImage:buttonBackgroundImage forState:UIControlStateNormal];
                [self.button setTitle:self.buttonTitle forState:UIControlStateNormal];

                UIColor *buttonTitleShadowColor = [UIColor hx_colorWithHexString:[current valueForKey:@"buttonTitleShadowColor"]];
                if (!buttonTitleShadowColor)
                {
                    buttonTitleShadowColor = self.titleLabel.shadowColor;
                }

                [self.button setTitleShadowColor:buttonTitleShadowColor forState:UIControlStateNormal];

                UIColor *buttonTitleTextColor = [UIColor hx_colorWithHexString:[current valueForKey:@"buttonTitleTextColor"]];
                if (!buttonTitleTextColor)
                {
                    buttonTitleTextColor = fontColor;
                }

                [self.button setTitleColor:buttonTitleTextColor forState:UIControlStateNormal];
                self.button.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
                self.button.titleLabel.shadowOffset = CGSizeMake([[current valueForKey:@"buttonTitleShadowOffsetX"] floatValue],
                        [[current valueForKey:@"buttonTitleShadowOffsetY"] floatValue]);

            }

            [self.button addTarget:self
                            action:@selector(buttonTapped:)
                  forControlEvents:UIControlEventTouchUpInside];

            self.button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 5.0, 0.0, 5.0);
            [self.button sizeToFit];
            self.button.frame = CGRectMake(screenWidth - padding - self.button.frame.size.width,
                                           0.0,
                                           self.button.frame.size.width,
                                           31.0);

            [self addSubview:self.button];

            self.textSpaceRight = self.button.frame.size.width + padding;
        }


        // Set up content label (if set)
        if ([subtitle length])
        {
            _contentView = [[TSMessageContentView alloc] init];
            [_contentView setText:subtitle];


            UIColor *contentTextColor = [UIColor hx_colorWithHexString:[current valueForKey:@"contentTextColor"]];
            if (!contentTextColor)
            {
                contentTextColor = fontColor;
            }
            [_contentView setContentTextColor:contentTextColor];
            [_contentView setBackgroundColor:[UIColor clearColor]];
            CGFloat fontSize = [[current valueForKey:@"contentFontSize"] floatValue];
            NSString *fontName = [current valueForKey:@"contentFontName"];
            if (fontName != nil) {
                [_contentView setContentFont:[UIFont fontWithName:fontName size:fontSize]];
            } else {
                [_contentView setContentFont:[UIFont systemFontOfSize:fontSize]];
            }
            [_contentView.contentLabel setShadowColor:self.titleLabel.shadowColor];
            [_contentView.contentLabel setShadowOffset:self.titleLabel.shadowOffset];
            _contentView.contentLabel.lineBreakMode = self.titleLabel.lineBreakMode;

            [self setCustomContentView:_contentView];
        }
        // Add a border on the bottom (or on the top, depending on the view's postion)
        if (![TSMessage iOS7StyleEnabled])
        {
            _borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0,
                                                                   0.0, // will be set later
                                                                   screenWidth,
                                                                   [[current valueForKey:@"borderHeight"] floatValue])];
            self.borderView.backgroundColor = [UIColor hx_colorWithHexString:[current valueForKey:@"borderColor"]];
            self.borderView.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
            [self addSubview:self.borderView];
        }


        CGFloat actualHeight = [self updateHeightOfMessageView]; // this call also takes care of positioning the labels
        CGFloat topPosition = -actualHeight;

        if (self.messagePosition == TSMessageNotificationPositionBottom)
        {
            topPosition = self.viewController.view.bounds.size.height;
        }

        self.frame = CGRectMake(0.0, topPosition, screenWidth, actualHeight);

        if (self.messagePosition == TSMessageNotificationPositionTop)
        {
            self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        }
        else
        {
            self.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        }

        if (dismissingEnabled)
        {
            UISwipeGestureRecognizer *gestureRec = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                             action:@selector(fadeMeOut)];
            [gestureRec setDirection:(self.messagePosition == TSMessageNotificationPositionTop ?
                                      UISwipeGestureRecognizerDirectionUp :
                                      UISwipeGestureRecognizerDirectionDown)];
            [self addGestureRecognizer:gestureRec];

            UITapGestureRecognizer *tapRec = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(fadeMeOut)];
            [self addGestureRecognizer:tapRec];
        }

        if (self.callback) {
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            tapGesture.delegate = self;
            [self addGestureRecognizer:tapGesture];
        }
    }
    return self;
}


- (CGFloat)updateHeightOfMessageView
{
    CGFloat currentHeight;
    CGFloat screenWidth = self.viewController.view.bounds.size.width;
    CGFloat padding = [self padding];

    self.titleLabel.frame = CGRectMake(self.textSpaceLeft,
                                       padding,
                                       screenWidth - padding - self.textSpaceLeft - self.textSpaceRight,
                                       0.0);
    [self.titleLabel sizeToFit];

    if ([self.subtitle length])
    {
        self.contentView.frame = CGRectMake(self.textSpaceLeft,
                                             self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + 5.0,
                                             screenWidth - padding - self.textSpaceLeft - self.textSpaceRight,
                                             0.0);
        [self.contentView sizeToFit];

        currentHeight = self.contentView.frame.origin.y + self.contentView.frame.size.height;
    }
    else
    {
        // only the title was set
        currentHeight = self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height;
    }

    currentHeight += padding;

    if (self.iconImageView)
    {
        CGFloat leftOffset = (self.iconOnTheRight) ? screenWidth - padding - self.iconImageView.frame.size.width : padding;
        self.iconImageView.frame = CGRectMake(leftOffset,
                                              self.iconImageView.frame.origin.y,
                                              self.iconImageView.frame.size.width,
                                              self.iconImageView.frame.size.height);
        
        // Check if that makes the popup larger (height)
        if (self.iconImageView.frame.origin.y + self.iconImageView.frame.size.height + padding > currentHeight)
        {
            currentHeight = self.iconImageView.frame.origin.y + self.iconImageView.frame.size.height + padding;
        }
        else
        {
            // z-align
            self.iconImageView.center = CGPointMake([self.iconImageView center].x,
                                                    round(currentHeight / 2.0));
        }
    }

    // z-align button
    self.button.center = CGPointMake([self.button center].x,
                                     round(currentHeight / 2.0));

    if (self.messagePosition == TSMessageNotificationPositionTop)
    {
        // Correct the border position
        CGRect borderFrame = self.borderView.frame;
        borderFrame.origin.y = currentHeight;
        self.borderView.frame = borderFrame;
    }

    currentHeight += self.borderView.frame.size.height;

    self.frame = CGRectMake(0.0, self.frame.origin.y, self.frame.size.width, currentHeight);


    if (self.button)
    {
        self.button.frame = CGRectMake(self.frame.size.width - self.textSpaceRight,
                                       round((self.frame.size.height / 2.0) - self.button.frame.size.height / 2.0),
                                       self.button.frame.size.width,
                                       self.button.frame.size.height);
    }


    CGRect backgroundFrame = CGRectMake(self.backgroundImageView.frame.origin.x,
                                        self.backgroundImageView.frame.origin.y,
                                        screenWidth,
                                        currentHeight);

    // increase frame of background view because of the spring animation
    if ([TSMessage iOS7StyleEnabled] && ![TSMessage useBackgroundImageInsteadOfBlur])
    {
        if (self.messagePosition == TSMessageNotificationPositionTop)
        {
            float topOffset = 0.f;

            UINavigationController *navigationController = self.viewController.navigationController;
            if (!navigationController && [self.viewController isKindOfClass:[UINavigationController class]]) {
                navigationController = (UINavigationController *)self.viewController;
            }
            BOOL isNavBarIsHidden = !navigationController || [TSMessage isNavigationBarInNavigationControllerHidden:navigationController];
            BOOL isNavBarIsOpaque = !navigationController.navigationBar.isTranslucent && navigationController.navigationBar.alpha == 1;

            if (isNavBarIsHidden || isNavBarIsOpaque) {
                topOffset = -30.f;
            }
            backgroundFrame = UIEdgeInsetsInsetRect(backgroundFrame, UIEdgeInsetsMake(topOffset, 0.f, 0.f, 0.f));
        }
        else if (self.messagePosition == TSMessageNotificationPositionBottom)
        {
            backgroundFrame = UIEdgeInsetsInsetRect(backgroundFrame, UIEdgeInsetsMake(0.f, 0.f, -30.f, 0.f));
        }
    }

    self.backgroundImageView.frame = backgroundFrame;
    self.backgroundBlurView.frame = backgroundFrame;

    return currentHeight;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateHeightOfMessageView];
}

- (void)setCustomContentView:(TSMessageContentView *)contentView {
    if ( contentView == nil || ![contentView isKindOfClass:[TSMessageContentView class]] ) {
        return;
    }

    if ( self.contentView ) {
        [self.contentView removeFromSuperview];
    }

    _contentView = contentView;

    [self addSubview:_contentView];

    [self setNeedsLayout];
}


- (void)fadeMeOut
{
    [[TSMessage sharedMessage] performSelectorOnMainThread:@selector(fadeOutNotification:) withObject:self waitUntilDone:NO];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.duration == TSMessageNotificationDurationEndless && self.superview && !self.window )
    {
        // view controller was dismissed, let's fade out
        [self fadeMeOut];
    }
}
#pragma mark - Target/Action

- (void)buttonTapped:(id) sender
{
    if (self.buttonCallback)
    {
        self.buttonCallback();
    }

    [self fadeMeOut];
}

- (void)handleTap:(UITapGestureRecognizer *)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateRecognized)
    {
        if (self.callback)
        {
            self.callback();
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ! ([touch.view isKindOfClass:[UIControl class]]);
}

#pragma mark - Grab Image From Pod Bundle
- (UIImage *)bundledImageNamed:(NSString*)name{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *imagePath = [bundle pathForResource:name ofType:nil];
    return [[UIImage alloc] initWithContentsOfFile:imagePath];
}

@end
