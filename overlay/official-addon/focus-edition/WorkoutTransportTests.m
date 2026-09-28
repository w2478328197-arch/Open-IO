#import <Foundation/Foundation.h>
#import "NativeNavigation.h"
#import "A2UIProbe.h"
#include "../../firmware-research/strix-1.0.4.12/native-navigation/workout/workout_wire.h"
static NSDictionary *Ack(uint32_t sid,uint32_t seq,BOOL active,BOOL wrong){
 uint8_t raw[32]={0};memcpy(raw,wrong?"TNA1":"TWA1",4);raw[4]=1;raw[6]=active?3:0;raw[7]=1;tw_p32(raw+8,sid);tw_p32(raw+12,seq);tw_p32(raw+16,60000);tw_p32(raw+20,32);tw_p32(raw+28,tw_crc(raw,28,false));
 NSMutableString *hex=[NSMutableString new];for(unsigned i=0;i<32;i++)[hex appendFormat:@"%02x",raw[i]];
 NSData *payload=TIOA2UIPacket(6,0,@{@"cmd":wrong?@"turbo_nav_v1":@"turbo_wrk_v1",@"payload":@{@"data":hex}});
 return @{@"eventType":@"messageReceived",@"message":@{@"businessId":@15,@"deviceId":@"fixture-device",@"payload":payload}};
}
static NSDictionary *File(NSString *task){return @{@"eventType":@"fileShareSuccess",@"device":@{@"id":@"fixture-device"},@"role":@"sender",@"taskId":task,@"fileName":@"turbo-workout.twk"};}
static NSDictionary *Menu(uint32_t nonce,uint32_t seq,BOOL open,NSString *peer,BOOL corrupt){
 uint8_t raw[20]={0};memcpy(raw,"TWM1",4);raw[4]=1;raw[5]=open;tw_p32(raw+8,nonce);tw_p32(raw+12,seq);tw_p32(raw+16,tw_crc(raw,16,false));if(corrupt)raw[8]^=1;
 NSMutableString *hex=[NSMutableString new];for(unsigned i=0;i<20;i++)[hex appendFormat:@"%02x",raw[i]];
 return @{@"eventType":@"messageReceived",@"message":@{@"businessId":@15,@"deviceId":peer,@"payload":TIOA2UIPacket(6,0,@{@"cmd":@"turbo_wrk_menu",@"payload":@{@"data":hex}})}};
}
int main(void){@autoreleasepool{
 TWKMenuIntent *intent=[TWKMenuIntent new];NSString *device=@"fixture-device";
 NSCAssert(![intent consume:Menu(200,1,YES,@"wrong",NO) device:device now:1],@"Other glasses cannot request a workout");
 NSCAssert(![intent consume:Menu(200,1,YES,device,YES) device:device now:1],@"Corrupt menu events rejected");
 NSCAssert([intent consume:Menu(200,1,YES,device,NO) device:device now:1]&&[intent pendingForDevice:device now:2]==200,@"Fresh local menu requests a start");
 NSCAssert(![intent pendingForDevice:@"wrong" now:2]&&![intent pendingForDevice:device now:5],@"Peer change and missing pulses expire pending starts");
 [intent consume:Menu(200,2,YES,device,NO) device:device now:6];NSCAssert([intent pendingForDevice:device now:7]==200,@"Waiting page pulse renews lease");
 [intent markAttempted];[intent consume:Menu(200,3,YES,device,NO) device:device now:8];NSCAssert(![intent pendingForDevice:device now:9],@"No repeated starts in same menu generation");
 [intent consume:Menu(200,4,NO,device,NO) device:device now:10];[intent consume:Menu(200,3,YES,device,NO) device:device now:11];NSCAssert(!intent.open&&![intent pendingForDevice:device now:11],@"Back wins over delayed open");
 [intent consume:Menu(300,1,YES,device,NO) device:device now:12];NSCAssert([intent pendingForDevice:device now:13]==300,@"Reenter produces a fresh request");
 [intent consume:Menu(200,5,YES,device,NO) device:device now:13];NSCAssert([intent pendingForDevice:device now:13]==300,@"Prior generation cannot replace current request");
 [intent cancel];NSCAssert(![intent pendingForDevice:device now:13],@"Manual stop cancels waiting intent");
 NSCAssert(!TWKDecodeReply(Menu(400,1,YES,device,NO),NULL),@"Menu pulse cannot be mistaken for transfer acknowledgement");
 __block NSTimeInterval now=1;__block NSData *wire;__block NSString *current;__block NSUInteger cleaned=0,sent=0;
 TNVSession *s=[[TNVSession alloc]initWithDevice:@"fixture-device" session:900 clock:^{return now;} sender:^(NSData *p,NSString *task,TNVSubmitted done){wire=p;current=task;sent++;done(YES,task);} cleanup:^(NSString *task){NSCAssert([task isEqual:current],@"clean exact owned file");cleaned++;}];s.workoutProtocol=YES;
 TWData d={146,360,176,105,342000,2120,1800,3,5,0,0,"140-<155"};NSData *frame=[NSData dataWithBytes:&d length:sizeof d];
 NSCAssert([s startWorkout:frame]&&s.busy&&tw_packet_valid(wire.bytes,wire.length),@"First update uses the distinct workout wire protocol");
 NSCAssert(![s consume:Ack(900,1,YES,YES)]&&s.busy,@"Navigation ACK must not complete a workout request");
 [s consume:Ack(900,1,YES,NO)];NSCAssert(s.busy&&cleaned==0,@"AP ACK alone cannot release native file ownership");
 [s consume:File(current)];NSCAssert(!s.busy&&cleaned==1,@"Release file only after both completions");
 now=3;[s offerWorkout:frame];[s setAlways:NO];[s pump];NSCAssert(sent==1,@"No redundant frame or navigation-field mutation");
 d.heart=150;[s offerWorkout:[NSData dataWithBytes:&d length:sizeof d]];[s pump];NSCAssert(sent==2&&tw_packet_valid(wire.bytes,wire.length),@"Latest health values form one complete packet");
 [s consume:File(current)];NSCAssert(s.busy,@"File completion alone is insufficient");[s consume:Ack(900,1,YES,NO)];NSCAssert(s.busy,@"Old ACK cannot complete new update");[s consume:Ack(900,2,YES,NO)];NSCAssert(!s.busy&&cleaned==2,@"Matching update completion");
 now=5;[s stop];NSCAssert(((const uint8_t *)wire.bytes)[5]==4,@"Explicit stop uses native workout STOP");[s consume:Ack(900,3,NO,NO)];[s consume:File(current)];NSCAssert(!s.active&&!s.busy&&cleaned==3,@"Native stop completes and releases resources");
 TNVSession *menuSession=[[TNVSession alloc]initWithDevice:device session:901 clock:^{return now;} sender:^(NSData *p,NSString *task,TNVSubmitted done){wire=p;current=task;done(YES,task);} cleanup:nil];menuSession.workoutProtocol=YES;menuSession.workoutMenuNonce=500;
 NSCAssert([menuSession startWorkout:frame]&&tw_packet_valid(wire.bytes,wire.length)&&tw_u32((const uint8_t *)wire.bytes+24)==500,@"Menu-initiated START includes the native generation and valid CRC");
 [menuSession consume:File(current)];[menuSession consume:Ack(901,1,YES,NO)];NSCAssert(!menuSession.busy&&menuSession.active,@"Bound start completes normally");
 now=8;d.heart=151;[menuSession offerWorkout:[NSData dataWithBytes:&d length:sizeof d]];[menuSession pump];NSCAssert(tw_u32((const uint8_t *)wire.bytes+24)==0&&((const uint8_t *)wire.bytes)[5]==2,@"Only START carries a menu generation");
 NSLog(@"PASS workout menu: strict event parsing, paired identity, expiry, single attempt, back, old generation, bound START and normal UPDATE");
 NSLog(@"PASS TWK1 phone transport: protocol isolation, file/AP ordering, old receipts, complete frames, cleanup and stop");
}return 0;}
