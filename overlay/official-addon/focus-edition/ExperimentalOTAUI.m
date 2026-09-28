#import "ExperimentalOTAUI.h"
#import "ExperimentalOTA.h"
#import "ExperimentalOTAFeed.h"
#import "ExperimentalOTAGuard.h"
#import "ExperimentalOTAFlash.h"
#import "ResearchUI.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <CommonCrypto/CommonDigest.h>

static NSString * const OfficialRoute=@"返回 Turbo IO 的「眼镜」页 → 头像 → 眼镜设置 → 关于本机 → Strix OS 版本。进入版本页会自动检查更新；下载和最后的「开始安装」都在这里。";
static NSURL *OfficialDirectory(void){return [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/ota/Strix_OS_1.0.4.12"] isDirectory:YES];}
static void Notice(UIViewController *vc,NSString *title,NSString *message){UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];[vc presentViewController:a animated:YES completion:nil];}
static void AfterAlert(UIViewController *vc,void (^action)(void)){
 // UIKit dismisses the tapped alert asynchronously. Do not present the result
 // on that outgoing controller (the old flow silently lost its feedback).
 if(vc.presentedViewController){[vc dismissViewControllerAnimated:YES completion:action];}else action();
}
static void RequestAuthorization(UIViewController *vc,NSString *profile,void (^changed)(NSString *)){
 NSString *issue=TIOOTAFlashAuthorizationIssue();
 if(issue){if(changed)changed(issue);Notice(vc,@"安装条件还未满足",issue);return;}
 NSDictionary *gate=TIOOTAFlashStatus();
 if([gate[@"stage"] integerValue]){Notice(vc,@"已有安装会话",[gate[@"stage"] integerValue]>=2?@"安装已开始，请保持 App、连接和供电，等待完成。":@"本次已经授权。回到官方版本页，手动点“开始安装”。");return;}
 UIAlertController *alert=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"授权本次 %@ 安装",profile] message:@"确认眼镜电量至少 50%、已结束其他眼镜任务。实验固件可能无法启动，恢复出厂不保证修复。确认后会重新核对并冻结这份安装包；最终仍由你在官方版本页手动开始。" preferredStyle:UIAlertControllerStyleAlert];
 [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
 [alert addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"确认并授权 %@",profile] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){
  AfterAlert(vc,^{NSError *error=nil;BOOL ok=TIOOTAFlashAuthorizeForProfile(profile,&error);
   NSString *message=ok?[NSString stringWithFormat:@"%@ 的 15 个文件已核对并冻结，授权有效 15 分钟。现在回官方版本页，手动点“开始安装”。尚未向眼镜发送安装指令。",profile]:error.localizedDescription?:@"安装检查未通过，未授权。";
   if(changed)changed(message);TIORefreshExperimentalOTAReport();Notice(vc,ok?@"已可手动开始安装":@"未授权：检查未通过",message);
  });
 }]];[vc presentViewController:alert animated:YES completion:nil];
}
void TIOExperimentalOTAPresentBlockedStart(void){
 dispatch_async(dispatch_get_main_queue(),^{
  static __weak UIAlertController *shown;if(shown.presentingViewController)return;
  UIViewController *top=nil;
  for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){if(scene.activationState!=UISceneActivationStateForegroundActive||![scene isKindOfClass:UIWindowScene.class])continue;for(UIWindow *window in ((UIWindowScene *)scene).windows)if(window.isKeyWindow){top=window.rootViewController;break;}}
  while(top.presentedViewController)top=top.presentedViewController;
  if(!top||[top isKindOfClass:UIAlertController.class])return;
  NSDictionary *gate=TIOOTAFlashStatus();NSString *profile=gate[@"profile"];if(!profile.length)profile=TIOExperimentalOTAProfileCode();
  NSString *reason=TIOOTAFlashAuthorizationIssue()?:gate[@"failure"];
  if(!reason.length)reason=@"还没有授权本次安装。下载完成后仍需要确认这份安装包。";
  NSString *message=[NSString stringWithFormat:@"%@\n\n本次开始请求被手机的安装检查拦住。官方页面的“连接失败”是通用提示，这次没有据此确认蓝牙断开。",reason];
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"尚未开始：安装检查未通过" message:message preferredStyle:UIAlertControllerStyleAlert];shown=alert;
  [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
  if([gate[@"stage"] integerValue]==0&&!TIOOTAFlashAuthorizationIssue()){
   [alert addAction:[UIAlertAction actionWithTitle:@"检查并授权本次安装" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){AfterAlert(top,^{RequestAuthorization(top,profile,nil);});}]];
  }
  [top presentViewController:alert animated:YES completion:nil];
 });
}
static NSString *SHA(NSData *data){unsigned char b[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,b);NSMutableString *s=[NSMutableString new];for(NSUInteger i=0;i<sizeof(b);i++)[s appendFormat:@"%02x",b[i]];return s;}
static void StyleFirmwarePage(UITableViewController *page){
 TIOStyleResearchTable(page);UINavigationBarAppearance *bar=[UINavigationBarAppearance new];[bar configureWithOpaqueBackground];bar.backgroundColor=TIOPaper();bar.titleTextAttributes=@{NSForegroundColorAttributeName:TIOInk()};
 UIBarButtonItemAppearance *button=[UIBarButtonItemAppearance new];button.normal.titleTextAttributes=@{NSForegroundColorAttributeName:TIOAccent()};bar.buttonAppearance=button;bar.backButtonAppearance=button;
 page.navigationItem.standardAppearance=bar;page.navigationItem.scrollEdgeAppearance=bar;page.navigationItem.compactAppearance=bar;
}

@interface TIOWorkoutFirmwareLab:UITableViewController
@property(nonatomic,strong) NSArray *samples;
@property(nonatomic,copy) NSString *failure;
@end
@implementation TIOWorkoutFirmwareLab
- (void)viewDidLoad{
 [super viewDidLoad];self.title=@"运动看板 · 本机实验";StyleFirmwarePage(self);
 NSURL *root=[NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"TurboWorkoutLab" isDirectory:YES];
 NSData *data=[NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:@"manifest.json"]];
 NSDictionary *manifest=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
 BOOL valid=[manifest[@"firmwareSHA256"] isEqual:TIOExperimentalOTAProfile(@"TWK1")[@"sha256"]];
 NSArray *items=manifest[@"samples"];valid=valid&&[items isKindOfClass:NSArray.class]&&items.count==5;
 NSMutableArray *loaded=[NSMutableArray new];
 for(NSDictionary *item in valid?items:@[]){NSString *name=item[@"file"];if(![name isKindOfClass:NSString.class]||![name.lastPathComponent isEqual:name]){valid=NO;break;}
  NSData *bytes=[NSData dataWithContentsOfURL:[root URLByAppendingPathComponent:name]];UIImage *picture=bytes?[UIImage imageWithData:bytes]:nil;
  if(!picture||![SHA(bytes) isEqual:item[@"sha256"]]){valid=NO;break;}[loaded addObject:@{@"title":item[@"title"]?:@"实验画面",@"image":picture}];}
 self.samples=valid?loaded:@[];if(!valid)self.failure=@"实验资源缺失或与本次固件不匹配；未展示旧图。";
}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)section{return 1+self.samples.count;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];TIOStyleResearchCell(c);c.selectionStyle=UITableViewCellSelectionStyleNone;
 if(!p.row){c.textLabel.text=@"离线实验 · 合成数据";c.detailTextLabel.text=self.failure?:@"五种状态取自本次固件的数字位图和控件位置。数字与布局已离线测试；文字使用替代字体，镜片效果仍须佩戴验收。此页面不会连接、传数据或刷写眼镜。";return c;}
 NSDictionary *sample=self.samples[p.row-1];UILabel *label=[UILabel new];label.text=sample[@"title"];label.textColor=UIColor.labelColor;label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
 UIImageView *picture=[[UIImageView alloc]initWithImage:sample[@"image"]];picture.contentMode=UIViewContentModeScaleAspectFit;picture.backgroundColor=UIColor.blackColor;picture.accessibilityLabel=sample[@"title"];picture.isAccessibilityElement=YES;
 UIStackView *stack=[[UIStackView alloc]initWithArrangedSubviews:@[label,picture]];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=12;stack.translatesAutoresizingMaskIntoConstraints=NO;[c.contentView addSubview:stack];
 [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:c.contentView.leadingAnchor constant:16],[stack.trailingAnchor constraintEqualToAnchor:c.contentView.trailingAnchor constant:-16],[stack.topAnchor constraintEqualToAnchor:c.contentView.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:c.contentView.bottomAnchor constant:-16],[picture.heightAnchor constraintEqualToAnchor:picture.widthAnchor multiplier:1.0/3.0]]];return c;
}
@end
UIViewController *TIOWorkoutFirmwareLabController(void){return [[TIOWorkoutFirmwareLab alloc]initWithStyle:UITableViewStyleInsetGrouped];}

@interface TIOExperimentalOTAPage:UITableViewController<UIDocumentPickerDelegate>
@property(nonatomic,copy) NSString *profile;
@property(nonatomic,copy) NSString *statusText;
@property(nonatomic,copy) NSString *directoryStatus;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL packageVerified;
@property(nonatomic,strong) NSTimer *statusTimer;
@end
@implementation TIOExperimentalOTAPage
- (NSDictionary *)info{return TIOExperimentalOTAProfile(self.profile);}
- (NSURL *)storedArchive{return [TIOExperimentalOTAStoreDirectory(self.profile) URLByAppendingPathComponent:[self.info[@"sha256"] stringByAppendingString:@".zip"]];}
- (NSURL *)bundledArchive{return [NSBundle.mainBundle URLForResource:self.info[@"resource"] withExtension:@"zip"];}
- (void)viewDidLoad{
 [super viewDidLoad];self.title=self.info[@"title"];self.directoryStatus=@"尚未核对本次下载。";StyleFirmwarePage(self);
 self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"刷新" style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
 self.navigationItem.rightBarButtonItem.tintColor=TIOAccent();
 [self verifyLocalPackage];
}
- (void)refresh{TIORefreshExperimentalOTAReport();[self.tableView reloadData];}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self refresh];}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];__weak typeof(self) weak=self;self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){if(!weak){[timer invalidate];return;}if(!weak.busy)[weak.tableView reloadData];}];}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[self.statusTimer invalidate];self.statusTimer=nil;}
- (void)verifyLocalPackage{
 if(self.busy)return;self.busy=YES;self.packageVerified=NO;self.statusText=@"正在核对安装包，仅保存在手机…";[self.tableView reloadData];
 NSString *profile=[self.profile copy];NSURL *directory=TIOExperimentalOTAStoreDirectory(profile),*stored=self.storedArchive;
 NSURL *source=[NSFileManager.defaultManager fileExistsAtPath:stored.path]?stored:self.bundledArchive;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *e=nil;NSDictionary *result=source?TIOImportExperimentalOTAForProfile(source,directory,profile,&e):nil;
  dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;self.packageVerified=result!=nil;self.statusText=result?@"本机校验通过。安装包已准备，不会自动下载到眼镜或开始安装。":e.localizedDescription?:@"未找到内置安装包，请从文件导入相同的已核验 ZIP。";[self.tableView reloadData];});});
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return 4;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return s==0?([self.profile isEqual:@"TWK1"]?2:1):s==1?3:s==2?6:3;}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s{return @[@"1 · 本机实验与校验",@"2 · 安装包",@"3 · 下载与安装",@"当前状态"][s];}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{
 if(s==1)return @"每份固件使用独立入口和本机存档。导航、提词卡和运动看板包互不覆盖。";
 if(s==2)return @"开始前关闭官方自动更新，眼镜电量至少 50%，结束眼镜上的录音、语音、音乐、阅读、计时和导航。最终安装由你在官方页点击；实验固件仍可能无法启动，恢复出厂不保证修复。";
 return nil;
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];TIOStyleResearchCell(c);BOOL actionable=YES;
 if(p.section==0){
  if(p.row==0){c.textLabel.text=self.busy?@"正在进行本机校验…":@"重新运行本机校验";c.detailTextLabel.text=self.statusText;c.accessibilityIdentifier=@"firmware-local-check";}
  else{c.textLabel.text=@"查看五种状态的实验预览";c.detailTextLabel.text=@"运动中、暂停、数据过期、两位数、边界值。使用合成数据，不连接眼镜。";c.accessibilityIdentifier=@"workout-firmware-lab";}
 }else if(p.section==1){
  if(p.row==0){c.textLabel.text=[NSString stringWithFormat:@"%@ · %.1f MB",self.profile,[self.info[@"bytes"] doubleValue]/1000000.0];c.detailTextLabel.text=[NSString stringWithFormat:@"%@\n%@\n本机存档：ExperimentalOTA/%@\nSHA-256：%@",self.info[@"name"],self.packageVerified?@"安装包已内置并校验":@"等待安装包校验",self.profile,self.info[@"sha256"]];actionable=NO;}
  else if(p.row==1){c.textLabel.text=@"保存安装包到“文件”";c.detailTextLabel.text=@"选择保存位置，留存这份经过核验的 ZIP。";c.accessibilityIdentifier=@"firmware-export-package";}
  else{c.textLabel.text=@"从“文件”导入安装包";c.detailTextLabel.text=[NSString stringWithFormat:@"仅接受本次 %@ 的固定包；其他版本不会替换当前文件。",self.profile];c.accessibilityIdentifier=@"firmware-import-package";}
 }else if(p.section==2){
  NSDictionary *feed=TIOExperimentalOTAFeedStatus(),*gate=TIOOTAFlashStatus();BOOL own=[feed[@"profile"] isEqual:self.profile]&&[feed[@"armed"] boolValue];
  NSString *download=own?@"下载入口已开启（15 分钟有效）":@"准备下载与安装";
  NSString *progress=own?([feed[@"downloadRequests"] integerValue]?@"官方页已请求安装包。点此查看文件检查和安装下一步。":@"等待官方版本页下载。这里不显示下载进度；点此查看下一步。"):@"点后会立即显示准备结果和下一步。下载进度在官方版本页，最终由你手动开始安装。";
  NSArray *titles=@[@"官方下载／安装在哪里",download,@"关闭下载准备",@"核对已下载的 15 个文件",[NSString stringWithFormat:@"检查并授权 %@ 安装",self.profile],@"撤销尚未开始的授权"];
  NSArray *details=@[OfficialRoute,progress,@"结束本份固件的下载准备，再切换其他固件。",self.directoryStatus,[gate[@"authorized"] boolValue]?@"本次已授权；回官方版本页手动开始安装。":@"检查自动更新、当前版本和 15 个文件；结果会立即弹出。",@"只撤销本份固件尚未开始的授权；安装开始后保持 App、连接和供电。"];
  c.textLabel.text=titles[p.row];c.detailTextLabel.text=details[p.row];c.accessibilityIdentifier=@[@"firmware-official-location",@"experimental-ota-prepare-only",@"experimental-ota-cancel",@"experimental-ota-check-directory",@"experimental-ota-authorize",@"experimental-ota-revoke"][p.row];
  if((p.row==1||p.row==4)&&!TIOOTAFlashBuild()&&!TIOOTAPreparationBuild()){actionable=NO;c.detailTextLabel.text=@"本构建仅供本机实验，不能下载到眼镜或安装。";}
 }else{
  NSDictionary *f=TIOExperimentalOTAFeedStatus(),*g=TIOOTAFlashStatus();actionable=NO;
  if(p.row==0){c.textLabel.text=@"当前下载与安装对象";c.detailTextLabel.text=[NSString stringWithFormat:@"下载：%@\n授权／传输：%@",[f[@"armed"] boolValue]?f[@"profile"]?:@"未知":@"未开启",[g[@"stage"] integerValue]?g[@"profile"]?:@"未知":@"未开始"];}
  else if(p.row==1){c.textLabel.text=@"安装前检查";c.detailTextLabel.text=[NSString stringWithFormat:@"版本：%@\n自动更新：%@",[g[@"recentTargetVersionRead"] boolValue]?@"两分钟内读到 Strix OS 1.0.4.12":@"请进入官方版本页重新检查",[g[@"automaticUpdateDisabled"] boolValue]?@"已关闭":@"尚未确认关闭"];}
  else{c.textLabel.text=@"验收范围";c.detailTextLabel.text=@"本机实验与文件校验通过不代表已刷入。安装后须确认重启重连、镜片布局、实时数据及返回操作。";}
 }
 c.selectionStyle=actionable&&!self.busy?UITableViewCellSelectionStyleDefault:UITableViewCellSelectionStyleNone;if(actionable)c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return c;
}
- (BOOL)ownsState:(NSDictionary *)state{
 NSString *profile=state[@"profile"];if(!profile.length||[profile isEqual:self.profile])return YES;
 Notice(self,@"当前是另一份固件",[NSString stringWithFormat:@"请在 %@ 的入口完成或关闭当前操作。",profile]);return NO;
}
- (void)prepareDownload{
 if(!self.packageVerified){Notice(self,@"先完成本机校验",@"请点“重新运行本机校验”，等校验完成。");return;}
 if([TIOOTAFlashStatus()[@"stage"] integerValue]!=0){Notice(self,@"已有安装授权或传输",@"本次已经授权时，直接回官方页手动开始；安装已开始时请等待完成。");return;}
 self.busy=YES;self.statusText=@"正在准备下载入口并检查已下载文件…";[self.tableView reloadData];NSString *profile=self.profile;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *error=nil;BOOL ok=TIOBeginExperimentalOTAPreparationForProfile(profile,&error);NSString *failure=error.localizedDescription;
  NSDictionary *directory=ok?TIOCheckExperimentalOTADirectoryForProfile(OfficialDirectory(),profile,nil):nil;
  dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;
   if(!ok){self.statusText=failure?:@"下载服务未就绪，未开放安装包。";[self refresh];Notice(self,@"下载准备失败",self.statusText);return;}
   BOOL downloaded=directory!=nil;self.directoryStatus=downloaded?@"已下载的 15 个文件全部匹配。":@"等待官方版本页下载这份安装包。";
   NSString *issue=TIOOTAFlashAuthorizationIssue();
   NSString *message=downloaded?[NSString stringWithFormat:@"%@ 安装包已经在手机，15 个文件全部匹配，无需再次下载。\n\n%@",profile,issue?:@"下一步：检查并授权，然后回官方版本页手动开始安装。"]:[NSString stringWithFormat:@"%@ 下载入口已开放 15 分钟。\n\n%@\n\n%@",profile,OfficialRoute,issue?:@"下载后点官方“开始安装”，本次授权提示会直接显示；也可回本页检查并授权。"];
   self.statusText=message;[self refresh];UIAlertController *alert=[UIAlertController alertControllerWithTitle:downloaded?@"安装包已下载":@"下载入口已准备" message:message preferredStyle:UIAlertControllerStyleAlert];
   [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleCancel handler:nil]];
   if(downloaded&&!issue)[alert addAction:[UIAlertAction actionWithTitle:@"检查并授权本次安装" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){AfterAlert(self,^{RequestAuthorization(self,profile,^(NSString *text){self.statusText=text;[self refresh];});});}]];
   [self presentViewController:alert animated:YES completion:nil];
  });
 });
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];if(self.busy){Notice(self,@"正在核对安装包",@"本机校验正在进行，完成后即可继续。尚未向眼镜发送固件。");return;}
 if(p.section==0){if(!p.row)[self verifyLocalPackage];else [self.navigationController pushViewController:TIOWorkoutFirmwareLabController() animated:YES];return;}
 if(p.section==1){
  if(p.row==0)return;
  if(p.row==1){NSError *e=nil;if(!TIOReadExperimentalOTAForProfile(self.storedArchive,self.profile,&e)){Notice(self,@"未导出",e.localizedDescription);return;}
   NSURL *url=self.bundledArchive?:self.storedArchive;if(!TIOReadExperimentalOTAForProfile(url,self.profile,&e)){Notice(self,@"未导出",e.localizedDescription);return;}
   UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForExportingURLs:@[url] asCopy:YES];[self presentViewController:picker animated:YES completion:nil];
  }else{UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc]initForOpeningContentTypes:@[UTTypeZIP] asCopy:YES];picker.delegate=self;picker.allowsMultipleSelection=NO;[self presentViewController:picker animated:YES completion:nil];}return;
 }
 if(p.section!=2)return;
 if(p.row==0){Notice(self,@"官方下载与安装位置",[OfficialRoute stringByAppendingString:@"\n\n下载后回本页核对 15 个文件，再授权本次安装。仅显示相同版本号不代表已经装入运动看板。"]);return;}
 if(p.row==1){
  [self prepareDownload];return;
 }
 if(p.row==2){if(![self ownsState:TIOExperimentalOTAFeedStatus()])return;if([TIOOTAFlashStatus()[@"stage"] integerValue]>=2){Notice(self,@"安装已开始",@"保持 App、连接和供电，等待完成。");return;}TIOCancelExperimentalOTAPreparation();[self refresh];return;}
 if(p.row==3){self.busy=YES;self.directoryStatus=@"正在逐个核对 15 个文件…";[self.tableView reloadData];NSString *profile=self.profile;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{NSError *e=nil;NSDictionary *r=TIOCheckExperimentalOTADirectoryForProfile(OfficialDirectory(),profile,&e);
   dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;self.directoryStatus=r?[NSString stringWithFormat:@"15 个文件全部匹配 %@，尚未授权或发送。",profile]:e.localizedDescription;[self.tableView reloadData];Notice(self,r?@"已下载文件检查通过":@"已下载文件不匹配",self.directoryStatus);});});return;}
 if(p.row==5){if(![self ownsState:TIOOTAFlashStatus()])return;self.statusText=TIOOTAFlashCancel()?@"未开始的授权已撤销。":@"安装已经开始，未中断；请等待完成。";[self refresh];return;}
 if(!TIOOTAFlashBuild()){Notice(self,@"本构建不能安装",@"只能进行本机实验或下载准备。");return;}
 RequestAuthorization(self,self.profile,^(NSString *text){self.statusText=text;[self refresh];});
}
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls{
 if(self.busy||urls.count!=1)return;self.busy=YES;self.packageVerified=NO;[self.tableView reloadData];NSURL *source=urls.firstObject;NSString *profile=self.profile;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED,0),^{BOOL access=[source startAccessingSecurityScopedResource];NSError *e=nil;NSDictionary *r=TIOImportExperimentalOTAForProfile(source,TIOExperimentalOTAStoreDirectory(profile),profile,&e);if(access)[source stopAccessingSecurityScopedResource];dispatch_async(dispatch_get_main_queue(),^{self.busy=NO;self.packageVerified=r!=nil;self.statusText=r?@"导入和校验通过，未发送到眼镜。":e.localizedDescription;[self.tableView reloadData];});});
}
@end
UIViewController *TIOExperimentalOTAControllerForProfile(NSString *profile){TIOExperimentalOTAPage *p=[[TIOExperimentalOTAPage alloc]initWithStyle:UITableViewStyleInsetGrouped];p.profile=TIOExperimentalOTAProfile(profile)?profile:@"TFP1";return p;}
// Keep the existing navigation route bound to its original firmware.
UIViewController *TIOExperimentalOTAController(void){return TIOExperimentalOTAControllerForProfile(@"TFP1");}
