#import "CueCardsCore.h"
#import "reader.h"
#include <assert.h>

static NSDictionary *Card(NSString *title,NSString *text,BOOL important){return @{@"title":title,@"points":@[@{@"text":text,@"important":@(important)}]};}
static void Present(WRReader *reader,NSData *body){memcpy(reader->bank[reader->front^1],body.bytes,body.length);reader->pending=true;reader->active=true;reader->staging_revision++;wr_publish(reader);}
int main(void){@autoreleasepool {
    NSString *error=nil;
    assert(TCCueCommandFresh(@{@"issuedAt":@100},110));
    assert(!TCCueCommandFresh(@{@"issuedAt":@100},116));
    assert(!TCCueCommandFresh(@{@"issuedAt":@200},110));
    assert(!TCCueCommandFresh(@{},110));
    NSMutableDictionary *input=[@{@"title":@"项目演示",@"cards":@[Card(@"现状",@"已完成数据整理",YES),Card(@"结果",@"保留事实与限制",NO),Card(@"下一步",@"完成实机验证",YES)]} mutableCopy];
    NSDictionary *project=TCCueProject(input,&error);assert(project&&error==nil);
    NSDictionary *watchCard=TCCueCardFromText(@"手表新增",@"* 重点内容\n普通要点\n\n★ 第二条重点",&error);
    assert(watchCard&&[watchCard[@"points"] count]==3);
    assert([watchCard[@"points"][0][@"important"] boolValue]);
    assert(![watchCard[@"points"][1][@"important"] boolValue]);
    assert([watchCard[@"points"][2][@"important"] boolValue]);
    assert(!TCCueCardFromText(@"",@"正文",&error));
    assert(!TCCueCardFromText(@"无效",@"一\n二\n三\n四\n五",&error));
    assert(!wr_should_close_for_idle(false,90000));assert(wr_should_close_for_idle(false,90001));assert(!wr_should_close_for_idle(true,UINT32_MAX));
    NSArray *defaults=TCCueDefaultProjects();
    assert(defaults.count==2);
    assert([defaults[0][@"title"] isEqual:@"产品演示"]&&[defaults[1][@"title"] isEqual:@"原神启动"]);
    for(NSDictionary *demo in defaults)assert([demo[@"cards"] count]>=5);
    NSDictionary *emptyReport=TCCueProject(@{@"id":@"empty-report",@"title":@"产品进展报告",@"cards":@[]},&error);
    NSDictionary *emptyDemo=TCCueProject(@{@"id":@"empty-demo",@"title":@"产品演示",@"cards":@[]},&error);
    BOOL seeded=NO;NSArray *seededProjects=TCCueSeedDemoProjectsIfCardless(@[emptyReport,emptyDemo],&seeded,&error);
    assert(seeded&&seededProjects.count==3);
    assert([seededProjects[0][@"title"] isEqual:@"产品演示"]&&[seededProjects[0][@"id"] isEqual:@"empty-demo"]&&[seededProjects[0][@"cards"] count]>=5);
    assert([seededProjects[1][@"title"] isEqual:@"原神启动"]&&[seededProjects[1][@"cards"] count]>=5);
    assert([seededProjects[2][@"id"] isEqual:@"empty-report"]&&[seededProjects[2][@"cards"] count]==0);
    BOOL repeatedSeed=YES;NSArray *sameProjects=TCCueSeedDemoProjectsIfCardless(seededProjects,&repeatedSeed,&error);
    assert(!repeatedSeed&&[sameProjects isEqualToArray:seededProjects]);
    BOOL skippedSeed=YES;NSArray *nonEmpty=TCCueSeedDemoProjectsIfCardless(@[project],&skippedSeed,&error);
    assert(!skippedSeed&&nonEmpty.count==1&&[nonEmpty[0][@"cards"] count]==3);
    NSString *anchorID=project[@"cards"][0][@"id"];
    NSDictionary *inserted=TCCueInsertCardAfter(project,@"Watch 新增",@"* 重要提醒\n后续说明",@"watch-request-1",anchorID,&error);
    assert(inserted&&[inserted[@"cards"] count]==4&&[inserted[@"cards"][1][@"id"] isEqual:@"watch-request-1"]&&[inserted[@"cards"][2][@"id"] isEqual:project[@"cards"][1][@"id"]]);
    NSDictionary *retried=TCCueInsertCardAfter(inserted,@"Watch 新增",@"* 重要提醒\n后续说明",@"watch-request-1",anchorID,&error);
    assert(retried&&[retried[@"cards"] count]==4);
    assert(!TCCueInsertCardAfter(retried,@"冲突请求",@"不同内容",@"watch-request-1",anchorID,&error));
    assert(!TCCueInsertCardAfter(project,@"孤立插入",@"正文",@"watch-request-2",@"missing-card",&error));
    NSDictionary *emptyDeck=TCCueProject(@{@"id":@"empty-deck",@"title":@"空项目",@"cards":@[]},&error);
    NSDictionary *firstInserted=TCCueInsertCardAfter(emptyDeck,@"第一张卡",@"从 Watch 开始录入",@"watch-first-card",@"",&error);
    assert(firstInserted&&[firstInserted[@"cards"] count]==1&&[firstInserted[@"cards"][0][@"id"] isEqual:@"watch-first-card"]);
    NSDictionary *firstRetry=TCCueInsertCardAfter(firstInserted,@"第一张卡",@"从 Watch 开始录入",@"watch-first-card",@"",&error);
    assert(firstRetry&&[firstRetry[@"cards"] count]==1);
    assert(!TCCueInsertCardAfter(firstInserted,@"越权位置",@"正文",@"watch-empty-anchor-invalid",@"",&error));
    assert(!TCCueInsertCardAfter(emptyDeck,@"不存在锚点",@"正文",@"watch-missing-anchor",@"not-empty",&error));
    NSString *markdown=@"\ufeff# 项目汇报\r\n\r\n## 当前进展\r\n- **资料已整理**\r\n- 结论待复核\r\n\r\n## 下一步\r\n- 完成验证\r\n";
    NSDictionary *imported=TCCueImport([markdown dataUsingEncoding:NSUTF8StringEncoding],@"md",@"文件名",&error);
    assert(imported&&[imported[@"title"] isEqual:@"项目汇报"]&&[imported[@"cards"] count]==2);
    assert([imported[@"cards"][0][@"points"][0][@"important"] boolValue]);
    assert(![imported[@"cards"][0][@"points"][1][@"important"] boolValue]);
    NSData *json=[NSJSONSerialization dataWithJSONObject:project options:0 error:nil];
    NSDictionary *jsonImport=TCCueImport(json,@"JSON",@"无关文件名",&error);
    assert(jsonImport&&![jsonImport[@"id"] isEqual:project[@"id"]]);
    assert([jsonImport[@"cards"] isEqual:project[@"cards"]]);
    assert(!TCCueImport([@"## 空卡片\n" dataUsingEncoding:NSUTF8StringEncoding],@"md",@"汇报",&error));
    assert(!TCCueImport([@"## 标题\n这段不会被悄悄丢弃" dataUsingEncoding:NSUTF8StringEncoding],@"md",@"汇报",&error));
    assert(!TCCueImport([@"[]" dataUsingEncoding:NSUTF8StringEncoding],@"json",@"汇报",&error));
    assert(!TCCueImport([NSMutableData dataWithLength:2*1024*1024+1],@"md",@"汇报",&error));
    NSDictionary *textImport=TCCueImport([@"## 一张卡\n- 一个要点" dataUsingEncoding:NSUTF8StringEncoding],@"txt",@"文件名项目",&error);
    assert(textImport&&[textImport[@"title"] isEqual:@"文件名项目"]);
    assert([TCCueLines(project[@"cards"][0],&error)[0] hasPrefix:@"★ "]);
    assert(!TCCueProject(@{@"title":@"项目",@"cards":@[Card(@"过长",[@"长文字" stringByPaddingToLength:200 withString:@"长文字" startingAtIndex:0],NO)]},&error));
    assert([error containsString:@"四行"]);
    assert(!TCCueProject(@{@"title":@"项目",@"cards":@[@{@"title":@"无效",@"points":@[@{@"text":@"字段缺失"}]}]},&error));
    assert(!TCCueProject(@{@"title":@"项目",@"cards":@[project[@"cards"][0],project[@"cards"][0]]},&error));
    assert(!TCCueProject(@{@"title":@"项目",@"cards":@[Card(@"控制字符",@"第一行\n第二行",NO)]},&error));
    TCCueCursor *cursor=[[TCCueCursor alloc] initWithProject:project];NSDictionary *first=[cursor snapshot];
    assert([first[@"lines"] count]==1&&[first[@"lines"][0] hasPrefix:@"★ 已完成数据整理"]);
    assert(![cursor move:-1 session:first[@"session"] card:first[@"card"] revision:0]);
    assert(![cursor move:1 session:@"old-session" card:first[@"card"] revision:0]);
    assert(![cursor move:2 session:first[@"session"] card:first[@"card"] revision:0]);
    assert([cursor move:1 session:first[@"session"] card:first[@"card"] revision:0]);
    assert(![cursor move:1 session:first[@"session"] card:first[@"card"] revision:0]);
    NSDictionary *second=[cursor snapshot];
    assert([cursor move:-1 session:second[@"session"] card:second[@"card"] revision:1]);
    // A very late command for card 1 is still stale after returning to card 1.
    assert(![cursor move:1 session:first[@"session"] card:first[@"card"] revision:0]);
    assert([cursor move:1 session:first[@"session"] card:first[@"card"] revision:2]);
    assert([cursor move:1 session:second[@"session"] card:second[@"card"] revision:3]);
    NSDictionary *last=[cursor snapshot];assert(![cursor move:1 session:last[@"session"] card:last[@"card"] revision:4]);
    input[@"cards"]=@[];assert([cursor.project[@"cards"] count]==3);
    NSData *body=TCCueBody(project,0,42);assert(body&&wr_validate(body.bytes,body.length));
    assert(!TCCueBody(project,3,42));assert(!TCCueBody(project,0,0));
    WRReader *reader=calloc(1,sizeof *reader);Present(reader,body);
    assert(!reader->automatic&&reader->row==0);
    wr_wheel(reader,-1,1000);assert(reader->event==0);
    wr_press(reader,2000);assert(reader->event==WR_WINDOW&&reader->event_value==1&&!reader->automatic);
    uint32_t request=reader->event_id;wr_press(reader,2600);wr_wheel(reader,1,3100);assert(reader->event_id==request);
    Present(reader,TCCueBody(project,1,42));wr_wheel(reader,-1,4000);assert(reader->event==WR_WINDOW&&reader->event_value==0);
    Present(reader,TCCueBody(project,2,42));wr_press(reader,5000);assert(reader->event==0&&!reader->automatic);
    wr_tick(reader,6000);assert(reader->row==2&&!reader->automatic);
    assert(!wr_back(reader)); // Card long press goes directly to native close.
    NSMutableData *invalid=[body mutableCopy];wr_put((uint8_t *)invalid.mutableBytes+24,1);assert(!wr_validate(invalid.bytes,invalid.length));
    invalid=[body mutableCopy];wr_put((uint8_t *)invalid.mutableBytes+12,5);assert(!wr_validate(invalid.bytes,invalid.length));
    invalid=[body mutableCopy];wr_put((uint8_t *)invalid.mutableBytes+4,3);assert(!wr_validate(invalid.bytes,invalid.length));
    invalid=[body mutableCopy];((uint8_t *)invalid.mutableBytes)[256]=0xc0;assert(!wr_validate(invalid.bytes,invalid.length));
    free(reader);
    puts("PASS cue cards: Markdown/JSON/TXT import, no import overwrite, watch card entry validation, default demo projects, validation, emphasis, snapshot isolation, stale/repeated commands, boundaries, whole-card input, no auto-scroll, malformed wire");
}return 0;}
